#!/usr/bin/env bash
# hook-common.sh — フック共通ライブラリ（source 専用）
# 仕様: .claude/docs/10_spec/フック共通仕様.md §2（入力）・§3（制御方式・redact）・§4（緊急停止）・§5（記録と状態）・§10（ヘッドレス）
# 提供: hook_init / hook_read_input / hook_field / tool_class / hook_enforce_enabled / hook_headless / redact / hook_jq /
#       hook_record / hook_deny / hook_ask / hook_notify / hook_inject / hook_allow / hook_disabled / hook_fail /
#       hook_fail_closed / hook_require_jq / hook_session_read / hook_session_write / hook_rel_path / hook_doing_ticket /
#       hook_read_state / hc_append_jsonl / hc_json_write / hc_lock / hc_unlock
# 方針: 出力（deny / ask / additionalContext）と記録（decisions.jsonl・実行ログ）に載せる文字列は、ヘルパの内側で必ず
#       redact を通す（H1: redact を通す前にログへ書く経路を残さない）。ホットパスは外部プロセスを起動しない
#       （JSON の組み立て・redact・時刻は純 bash。jq を使うのは入力 JSON の読み取りと hook_field だけ）。

# 直接実行されたら何もしない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi

# ---- 置き場とルート ----
__hc_dir="${BASH_SOURCE[0]%/*}"
case "$__hc_dir" in /*|[A-Za-z]:/*) ;; *) __hc_dir="$PWD/$__hc_dir" ;; esac
__hc_root="${__hc_dir%/*}"; __hc_root="${__hc_root%/*}"; __hc_root="${__hc_root%/*}"   # lib → hooks → .claude → ルート
HOOK_ROOT="${HOOK_ROOT:-${LOGGER_ROOT:-$__hc_root}}"
HOOK_ROOT="${HOOK_ROOT//\\//}"
LOGGER_ROOT="$HOOK_ROOT"; export LOGGER_ROOT
HOOK_NAME="${HOOK_NAME:-hook}"
HOOK_SIDE="${HOOK_SIDE:-guide}"          # deny（拒否側）| guide（案内側）
HOOK_DENY_ID="${HOOK_DENY_ID:-WF009}"     # 判定不能で拒否側に倒すときの識別子（WFx09）
HOOK_INPUT=""; HOOK_SESSION_ID="unknown"; HOOK_TRANSCRIPT_PATH=""; HOOK_CWD=""; HOOK_EVENT=""; HOOK_PERMISSION_MODE=""
HOOK_TOOL=""; HOOK_AGENT_ID=""; HOOK_AGENT_TYPE=""; HOOK_PROMPT_ID=""; HOOK_COMMAND=""; HOOK_FILE_PATH=""; HOOK_SKILL=""
HOOK_SUBAGENT_TYPE=""; HOOK_MODEL=""; HOOK_DOING_COUNT=0
HOOK_PROMPT=""; HOOK_SOURCE=""; HOOK_RESPONSE_STATUS=""; HOOK_RESPONSE_AGENT_ID=""; HOOK_RUN_IN_BACKGROUND=""
HOOK_AGENT_TRANSCRIPT_PATH=""; HOOK_FM_KEYS_TOUCHED=0; HOOK_DRAFT=""
# 作業ツリー（§2）。スクリプトの置き場は常に HOOK_ROOT、logs/ と wip/ はこちらを基準にする
HOOK_WORKTREE="$HOOK_ROOT"
# 区切りバイト。stdin のフィールドは 0x1E、副入力はセクション 0x1D・レコード 0x1E・キー/値 0x1F
__HC_US=$'\x1e'
__HC_GS=$'\x1d'
__HC_RS=$'\x1f'
# 副入力の状態（ok / missing / broken）。読み手のフックが扱いを決める
HC_LIMITS=""; HC_LIMITS_STATE="missing"; HC_LIMITS_ERROR=""
HC_REVIEW=""; HC_REVIEW_STATE="missing"; HC_REVIEW_ERROR=""
HC_MERGE=""; HC_MERGE_STATE="missing"; HC_MERGE_ERROR=""
HC_APPROVALS=""; HC_APPROVALS_STATE="missing"; HC_APPROVALS_ERROR=""
HC_ENTRY=""; HC_ENTRY_STATE="missing"; HC_ENTRY_ERROR=""

# logger が未読み込みなら無音のスタブ（hook_init で本物に置き換わる）
if ! declare -F log_info >/dev/null 2>&1; then
  log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }
fi

# ---- 初期化 ----
# hook_init <フック名> [deny|guide] [判定不能の識別子]
hook_init() {
  HOOK_NAME="${1:-hook}"; HOOK_SIDE="${2:-$HOOK_SIDE}"; HOOK_DENY_ID="${3:-$HOOK_DENY_ID}"
  LOGGER_NAME="hook-$HOOK_NAME"; export LOGGER_NAME
  local lg="$__hc_dir/../../skills/20-common-step-shell-script/scripts/logger.sh"
  # shellcheck disable=SC1090
  if [[ -f "$lg" ]]; then . "$lg"; fi
  return 0
}

# ---- 純 bash の補助 ----
# JSON 文字列のエスケープ（REPLY に返す）
__hc_json_str() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
  REPLY="$s"
}

# 機密情報のマスク（§3。REPLY に返す）。パターンが当たらない値はマスクできない — 一次防御は「値を出さない」こと
__HC_REDACT_LONG_WORD=256   # これより長い語が出たら位置ベースの走査に切り替える
# 規則 5 の位置ベースの走査。`${s%%"$m"*}` が使えない（語が長すぎる）ときだけ使う。
# 区切りを改行に置換した同じ長さの複製から語を読み、位置で元の区切りを拾って組み直す
__hc_redact_rule5_scan() {
  local str="$1"
  local tmp="${str//[!A-Za-z0-9+=_-]/$'
'}"
  local -a parts=()
  local pos=0 w keep slen="${#str}"
  while IFS= read -r w || [[ -n "$w" ]]; do
    keep=1
    if (( ${#w} >= 40 )); then
      if [[ ( "$w" == *-*-* && "$w" != *[A-Z]* ) || "$w" != *[A-Z0-9+=-]* ]]; then keep=1; else keep=0; fi
    fi
    if (( keep )); then parts+=("$w"); else parts+=("***"); fi
    pos=$(( pos + ${#w} ))
    if (( pos < slen )); then parts+=("${str:pos:1}"); pos=$(( pos + 1 )); fi
  done <<< "$tmp"
  printf -v REPLY '%s' "${parts[@]}"
}
__hc_redact_to_reply() {
  local s="$1" m pre post nc=0
  shopt -q nocasematch && nc=1
  shopt -u nocasematch
  # 1. 接頭辞付きトークン
  while [[ "$s" =~ (ghp_|gho_|github_pat_|glpat-)[A-Za-z0-9_-]+ ]]; do
    m="${BASH_REMATCH[0]}"; pre="${s%%"$m"*}"; post="${s#*"$m"}"; s="${pre}***${post}"
  done
  # 2. Bearer <語>
  while [[ "$s" =~ ([Bb][Ee][Aa][Rr][Ee][Rr][[:space:]]+)[^[:space:]\"\'\*]+ ]]; do
    m="${BASH_REMATCH[0]}"; pre="${s%%"$m"*}"; post="${s#*"$m"}"; s="${pre}${BASH_REMATCH[1]}***${post}"
  done
  # 3. key=value（token / password / passwd / secret / api_key・access_key・private_key 等の *_key）。大文字小文字を問わない。値に / を含む秘密（AWS シークレット等）もここで拾う
  shopt -s nocasematch
  while [[ "$s" =~ ((token|password|passwd|secret|(api|access|private|auth|client|secret[_-]?access)[_-]?key)=)[^[:space:]\&\;\"\'\*]+ ]]; do
    m="${BASH_REMATCH[0]}"; pre="${s%%"$m"*}"; post="${s#*"$m"}"; s="${pre}${BASH_REMATCH[1]}***${post}"
  done
  shopt -u nocasematch
  # 4. AWS アクセスキー（AKIA + 16 文字）
  while [[ "$s" =~ AKIA[A-Z0-9]{16} ]]; do
    m="${BASH_REMATCH[0]}"; pre="${s%%"$m"*}"; post="${s#*"$m"}"; s="${pre}***${post}"
  done
  # 5. 40 文字以上の 16 進 / base64 様の語（`/` を含む語はパスと区別できないので対象外）。
  #    ハイフン区切りで大文字を含まない語（ブランチ名・チケット名）と、英小文字と _ だけの語（識別子）は秘密と見なさず残す。
  #    まず 40 文字以上の語が 1 つも無ければ丸ごと飛ばす（現実の入力はほぼこちら。走査 1 回で済む）。
  #    当たったときは、当たりの個数に比例する形で置き換える（正規表現で 1 個ずつ取り、前後で切る）。
  #    ただし `${s%%"$m"*}` は $m が長いと壊滅的に遅くなる（4000 文字で約 58 秒）ので、
  #    語が長いときだけ位置ベースの走査に切り替える。区切りの多い入力で語ごとにループすると
  #    区切りの個数に比例してしまい、SHA を 1 個含む 250 文字の行でも 10 ms 級になる。
  if [[ "$s" =~ [A-Za-z0-9+=_-]{40,} ]]; then
    local rest="$s" head="" m pre post keep
    while [[ "$rest" =~ [A-Za-z0-9+=_-]{40,} ]]; do
      m="${BASH_REMATCH[0]}"
      if (( ${#m} > __HC_REDACT_LONG_WORD )); then __hc_redact_rule5_scan "$head$rest"; head="$REPLY"; rest=""; break; fi
      pre="${rest%%"$m"*}"; post="${rest:${#pre}+${#m}}"
      if [[ ( "$m" == *-*-* && "$m" != *[A-Z]* ) || "$m" != *[A-Z0-9+=-]* ]]; then keep="$m"; else keep="***"; fi
      head+="${pre}${keep}"; rest="$post"
    done
    s="${head}${rest}"
  fi
  (( nc )) && shopt -s nocasematch
  REPLY="$s"
}
redact() { __hc_redact_to_reply "${1:-}"; printf '%s\n' "$REPLY"; }

# ISO 8601 の現在時刻（REPLY）。fork しない
__hc_now() {
  local ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  REPLY="${ts:0:22}:${ts:22}"
}

# US 区切りの 1 行を配列 REPLY_FIELDS に分解する（末尾の空フィールドも保つ）
__hc_split_us() {
  local s="$1"
  REPLY_FIELDS=()
  while [[ "$s" == *"$__HC_US"* ]]; do
    REPLY_FIELDS+=("${s%%"$__HC_US"*}")
    s="${s#*"$__HC_US"}"
  done
  REPLY_FIELDS+=("$s")
}

# ---- jq（CR 除去付き。Windows ネイティブ jq は CRLF を出す） ----
hook_jq() {
  local out rc
  out="$(jq "$@")"; rc=$?
  printf '%s\n' "${out//$'\r'/}"
  return "$rc"
}

hook_require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  hook_fail "jq が見つからない（フックの依存）"
}

# ---- jq プログラム（1 回目・2 回目。§1 の「jq は最大 2 回」）----
# 出力の形: <セクション1> 0x1D <セクション2>。セクション内のレコードは 0x1E、レコードの key/value は 0x1F 区切り。
# 値に紛れ込んだ 0x1C〜0x1F は空白へ潰す（区切りを壊さないため）。検証エラーは error() ではなく __error レコードで返す
# （error() で落とすと stdin の解析ごと巻き添えになる。DDR i0009-47・HK-T18）。
__HC_JQ_INPUT='
def v: tostring | gsub("[-]"; " ");
def fmkeys: "(^|\\n)[ \\t-]*(ticket_type|allow|executor|human_review|adversarial_review|predecessors)[ \\t]*:";
def touched($s): if ($s|type) == "string" then ($s | test(fmkeys)) else false end;
def verr($l):
  (if ($l.common|type) != "object" then ["common missing"]
   else ((["allow","protected","confirm","file_granular","state_files"] - ($l.common|keys)) as $m
         | (($l.common|keys) - ["allow","protected","confirm","file_granular","state_files"]) as $e
         | (if ($m|length) > 0 then ["common missing keys: " + ($m|join(","))] else [] end)
         + (if ($e|length) > 0 then ["common unknown keys: " + ($e|join(","))] else [] end))
   end)
  + (if ($l.types|type) != "object" then ["types missing"]
     else (if ([ $l.types | to_entries[] | (.value|type) == "object" and (.value|has("ops"))
                 and ((((.value|keys) - ["allow","deny","confirm","ops","plan_mode"])|length) == 0) ] | all)
           then [] else ["types entry invalid (ops required / unknown keys)"] end)
     end)
  + (if (($l.commands // {})|type) != "object" then ["commands invalid"] else [] end);
def limitrecs($l):
  [ ($l.common.allow[]?         | "common.allow" + v),
    ($l.common.protected[]?     | "common.protected" + v),
    ($l.common.confirm[]?       | "common.confirm" + v),
    ($l.common.file_granular[]? | "common.file_granular" + v),
    ($l.common.state_files[]?   | "common.state_files" + v),
    ($l.types | keys[]?         | "type" + v),
    ($l.types | to_entries[]? | .key as $k | .value as $t
       | ( ($t.allow[]?   | "t." + $k + ".allow" + v),
           ($t.deny[]?    | "t." + $k + ".deny" + v),
           ($t.confirm[]? | "t." + $k + ".confirm" + v),
           ($t.ops[]?     | "t." + $k + ".ops" + v),
           ("t." + $k + ".plan_mode" + (($t.plan_mode // false) | v)) ) ),
    ((($l.commands // {})["build-test"] // [])[]? | "build-test" + v) ];
if type != "object" then error("not an object") else . end
| . as $in
| ($limits | if type == "string" then (fromjson? // "__broken") else null end) as $lim
| ( [ ($in.session_id // ""), ($in.transcript_path // ""), ($in.cwd // ""), ($in.hook_event_name // ""),
      ($in.permission_mode // ""), ($in.tool_name // ""), ($in.agent_id // ""), ($in.agent_type // ""),
      ($in.prompt_id // ""), ($in.tool_input.command // ""),
      ($in.tool_input.file_path // $in.tool_input.notebook_path // ""), ($in.tool_input.skill // ""),
      ($in.tool_input.subagent_type // ""), ($in.tool_input.model // $in.model // ""),
      ((($in.prompt // "") | tostring | split("\n"))[0] // ""),
      ($in.source // ""),
      ($in.tool_response.status // ""), ($in.tool_response.agentId // ""),
      (if ($in.tool_input.run_in_background == null) then "" else ($in.tool_input.run_in_background | tostring) end),
      ($in.agent_transcript_path // ""),
      (if (touched($in.tool_input.old_string) or touched($in.tool_input.new_string) or touched($in.tool_input.content)
           or ([ ($in.tool_input.edits // [])[] | (touched(.old_string) or touched(.new_string)) ] | any))
       then "1" else "0" end),
      (if ($in.tool_input.draft == null) then "" else ($in.tool_input.draft | tostring) end),
      "end" ]
    | map(v) | join("") )
+ ""
+ ( if ($lim | type) == "object" then
      ( (verr($lim)) as $e
        | if ($e | length) > 0 then ("__error" + ($e | join("; ")))
          else (limitrecs($lim) | join("")) end )
    elif $lim == "__broken" then "__statebroken"
    else "__statemissing" end )
'

# 2 回目: 作業ツリー / session_id に依存する副入力を 4 つまとめて読む。要求しなかったものは null（= missing）
__HC_JQ_STATE='
def v: tostring | gsub("[-]"; " ");
def recs($j):
  if ($j|type) == "array" then
    [ $j[] | if type == "object" then ("scope" + ((.scope // "") | v)) else ("item" + v) end ]
  elif ($j|type) == "object" then
    [ $j | to_entries[]
      | select((.value|type) as $t | $t == "string" or $t == "number" or $t == "boolean")
      | (.key + "" + (.value | v)) ]
  else [] end;
def sec($x):
  if ($x|type) == "string" then
    (($x | fromjson? // "__broken") as $j
     | if $j == "__broken" then "__statebroken" else (recs($j) | join("")) end)
  else "__statemissing" end;
[ ($names | split(" "))[]
  | if . == "review" then sec($review)
    elif . == "merge" then sec($merge)
    elif . == "approvals" then sec($approvals)
    elif . == "entry" then sec($entry)
    else "__statemissing" end ]
| join("")
'
# ---- 作業ツリーの解決（§2・DDR i0009-55）----
# cwd が HOOK_ROOT と異なるとき、cwd から上向きに .claude を持つディレクトリを探して HOOK_WORKTREE に置く。
# ただし候補が HOOK_ROOT の worktree であることを必ず確かめる（cd だけでも cwd は動くため。参考実装の .claude を拾うと
# 作業中チケットが 0 枚に見えてガードが全面バイパスされる）。fork ゼロ（[ -d ] / [ -f ] / $(<file) だけ）。
# $1=パス → REPLY に正規化（区切りは / 、/c/… は C:/… に、`.` と `..` を畳み、末尾の / を落とす）
# `..` を畳まないと、前方一致で場所を検査している側（__hc_is_worktree_of）が
# `<root>/.git/worktrees/../../wip/tmp/x` のような指し先を見逃す。fork しないセグメント走査で畳む
__hc_winpath() {
  local p="${1//\\//}" head="" seg rest
  if [[ "$p" =~ ^/([A-Za-z])/(.*)$ ]]; then p="${BASH_REMATCH[1]^^}:/${BASH_REMATCH[2]}"; fi
  case "$p" in
    [A-Za-z]:/*) head="${p:0:3}"; rest="${p:3}" ;;
    /*)          head="/";        rest="${p:1}" ;;
    *)           head="";         rest="$p" ;;
  esac
  # 負の添字（`${out[-1]}` / `unset 'out[-1]'`）は bash 4.3 以降。
  # 本体は 4.0 以降を前提にしているので、長さを自分で持って添字を正にする
  local -a out=()
  local nout=0
  while [[ -n "$rest" ]]; do
    if [[ "$rest" == */* ]]; then seg="${rest%%/*}"; rest="${rest#*/}"; else seg="$rest"; rest=""; fi
    case "$seg" in
      ""|".") ;;
      "..")   if (( nout > 0 )) && [[ "${out[nout-1]}" != ".." ]]; then nout=$(( nout - 1 ))
              elif [[ -z "$head" ]]; then out[nout]=".."; nout=$(( nout + 1 ))
              fi ;;                       # 絶対パスの根を越える `..` は落とす
      *)      out[nout]="$seg"; nout=$(( nout + 1 )) ;;
    esac
  done
  p="$head"
  local i first=1
  for (( i = 0; i < nout; i++ )); do
    if (( first )) || [[ "$p" == */ ]]; then p+="${out[i]}"; first=0; else p+="/${out[i]}"; fi
  done
  [[ "$p" == */ && ${#p} -gt 1 ]] && p="${p%/}"
  REPLY="$p"
}
# $1=候補（正規化済み） $2=HOOK_ROOT（正規化済み） → 候補が $2 の worktree なら 0
# 「.git ファイルの gitdir: が worktrees/ を指す」だけでは、そのファイルを 1 本置くだけで偽装できる
# （置き場は wip/tmp/** で承認なしに書ける）。指す先の実在と、そこからの相互参照まで要求する。
__hc_is_worktree_of() {
  local c="$1" root="$2" g s n
  [[ "${c,,}" == "${root,,}" ]] && return 0
  # 本流の配下でも、相互参照が完全に成立するなら正当な worktree（`git worktree add ./sub-wt`）。
  # 配下を一律で弾くと、その中で機構が本流の wip/ logs/ を見てしまう（DDR i0009-55 が防ぐ状態そのもの）。
  # 参考実装の .claude や wip/tmp の細工は、下の相互参照の要求だけで落ちる（`..` は __hc_winpath が畳む）
  # (a) 候補の .git ファイルから管理ディレクトリを引き、そこから候補へ戻れることを確かめる（O(1)）
  g="$c/.git"
  if [[ -f "$g" ]]; then
    s="$(<"$g")" || s=""
    s="${s//$'\r'/}"; s="${s//$'\n'/}"; s="${s#gitdir:}"; s="${s# }"
    __hc_winpath "$s"; s="$REPLY"
    if [[ -n "$s" && "${s,,}" == "${root,,}/.git/worktrees/"* && -d "$s" && -f "$s/gitdir" ]]; then
      n="$(<"$s/gitdir")" || n=""
      n="${n//$'\r'/}"; n="${n//$'\n'/}"
      __hc_winpath "$n"; n="$REPLY"
      [[ "${n,,}" == "${c,,}/.git" ]] && return 0
    fi
  fi
  # 登録側（`<root>/.git/worktrees/*/gitdir`）だけから探す経路は置かない。
  # 片方向だと、worktree を作って消した後の stale な登録が残っているだけで、
  # そのパスに後から置いたディレクトリ（`wip/tmp/wt/.claude` など）が worktree として信用される。
  # 相互参照を要求するなら候補側の .git を必ず読むことになり、(a) と同じ検査になる
  return 1
}
__hc_resolve_worktree() {
  local d root
  __hc_winpath "$HOOK_ROOT"; root="$REPLY"
  HOOK_WORKTREE="$HOOK_ROOT"
  [[ -n "${HOOK_CWD:-}" ]] || return 0
  __hc_winpath "$HOOK_CWD"; d="$REPLY"
  [[ "${d,,}" == "${root,,}" ]] && return 0
  while [[ -n "$d" ]]; do
    if [[ -d "$d/.claude" ]] && __hc_is_worktree_of "$d" "$root"; then HOOK_WORKTREE="$d"; return 0; fi
    case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac
  done
  return 0
}

# ---- 入力（§2）----
# hook_read_input [limits]
#   stdin の JSON と、パスが stdin に依存しない副入力（scope-limits.json）を 1 回の jq で読む（§1 の 1 回目）。
#   副入力は存在するものだけ --rawfile で渡し、無いものは --argjson <名前> null に差し替える（--slurpfile は使わない。
#   破損・不在で呼び出しごと失敗して stdout が空になり、tool_name の取得すら奪われるため。DDR i0009-47）。
#   結果: 共通フィールドは HOOK_*、副入力は HC_LIMITS（0x1F 区切りの key/value を 0x1E で連ねたもの）と HC_LIMITS_STATE。
#   戻り 1 = 入力不正、2 = jq 不在
hook_read_input() {
  local line raw f sec1 sec2 want_limits=0 a
  for a in "$@"; do case "$a" in limits) want_limits=1 ;; esac; done
  HOOK_INPUT="$(cat 2>/dev/null)" || HOOK_INPUT=""
  [[ -n "$HOOK_INPUT" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 2
  local -a jqargs=()
  f="$HOOK_ROOT/.claude/hooks/config/scope-limits.json"
  if (( want_limits )) && [[ -f "$f" ]]; then jqargs+=(--rawfile limits "$f"); else jqargs+=(--argjson limits null); fi
  line="$(printf '%s' "$HOOK_INPUT" | jq -r "${jqargs[@]}" "$__HC_JQ_INPUT" 2>/dev/null)" || return 1
  line="${line//$'\r'/}"
  [[ -n "$line" ]] || return 1
  # セクション分割（0x1D）: 1 = stdin のフィールド、2 = 副入力 limits
  sec1="${line%%"$__HC_GS"*}"
  sec2=""; [[ "$line" == *"$__HC_GS"* ]] && sec2="${line#*"$__HC_GS"}"
  __hc_split_us "$sec1"
  [[ "${#REPLY_FIELDS[@]}" -ge 23 ]] || return 1
  raw="${REPLY_FIELDS[0]}"
  HOOK_SESSION_ID="${raw//[^A-Za-z0-9_-]/}"; [[ -n "$HOOK_SESSION_ID" ]] || HOOK_SESSION_ID="unknown"
  HOOK_TRANSCRIPT_PATH="${REPLY_FIELDS[1]}"; HOOK_CWD="${REPLY_FIELDS[2]}"; HOOK_EVENT="${REPLY_FIELDS[3]}"
  HOOK_PERMISSION_MODE="${REPLY_FIELDS[4]}"; HOOK_TOOL="${REPLY_FIELDS[5]}"; HOOK_AGENT_ID="${REPLY_FIELDS[6]}"
  HOOK_AGENT_TYPE="${REPLY_FIELDS[7]}"; HOOK_PROMPT_ID="${REPLY_FIELDS[8]}"; HOOK_COMMAND="${REPLY_FIELDS[9]}"
  HOOK_FILE_PATH="${REPLY_FIELDS[10]}"; HOOK_SKILL="${REPLY_FIELDS[11]}"; HOOK_SUBAGENT_TYPE="${REPLY_FIELDS[12]}"
  HOOK_MODEL="${REPLY_FIELDS[13]}"; HOOK_PROMPT="${REPLY_FIELDS[14]}"; HOOK_SOURCE="${REPLY_FIELDS[15]}"
  HOOK_RESPONSE_STATUS="${REPLY_FIELDS[16]}"; HOOK_RESPONSE_AGENT_ID="${REPLY_FIELDS[17]}"
  HOOK_RUN_IN_BACKGROUND="${REPLY_FIELDS[18]}"; HOOK_AGENT_TRANSCRIPT_PATH="${REPLY_FIELDS[19]}"
  HOOK_FM_KEYS_TOUCHED=0; [[ "${REPLY_FIELDS[20]}" == "1" ]] && HOOK_FM_KEYS_TOUCHED=1
  HOOK_DRAFT="${REPLY_FIELDS[21]}"
  __hc_side_state limits "$sec2"
  __hc_resolve_worktree
  return 0
}

# 副入力 1 つ分の結果を HC_<名前> / HC_<名前>_STATE に置く（先頭が __state なら状態、それ以外は本体）
__hc_side_state() { # $1=名前（小文字） $2=セクション
  local nm="${1^^}" body="$2" st="ok" err=""
  case "$body" in
    "__state${__HC_RS}missing"*) st="missing"; body="" ;;
    "__state${__HC_RS}broken"*)  st="broken";  body="" ;;
    # 解釈はできたが検証に落ちた（設定不正）。使えない点は破損と同じなので broken に倒し、理由を残す
    "__error${__HC_RS}"*)        st="broken";  err="${body#*"$__HC_RS"}"; err="${err%%"$__HC_US"*}"; body="" ;;
    "") st="missing" ;;
  esac
  printf -v "HC_$nm" '%s' "$body"
  printf -v "HC_${nm}_STATE" '%s' "$st"
  printf -v "HC_${nm}_ERROR" '%s' "$err"
}

# __hc_state_arg <名前> <パス> → __HC_STATE_ARG に jq の引数を組む（存在すれば --rawfile、無ければ --argjson null）
__hc_state_arg() {
  if [[ -f "$2" ]]; then __HC_STATE_ARG=(--rawfile "$1" "$2"); else __HC_STATE_ARG=(--argjson "$1" null); fi
}

# hook_read_state [review] [merge] [approvals] [entry]
#   作業ツリーと session_id に依存する副入力を 1 回の jq でまとめて読む（§1 の 2 回目。要るフックだけが呼ぶ）。
#   §1 の表は review-state / merge-state を 1 回目に置くが、§2 が logs/ を作業ツリー側と定めており、作業ツリーは
#   cwd（= stdin）を読んで初めて決まるため 1 回目には渡せない。よって 2 回目に移している（逸脱。0032 で書き戻す）。
#   戻り 1 = jq 不在（呼び手が扱いを決める）
hook_read_state() {
  local a out sec nm want
  local -a names=() jqargs=()
  for a in "$@"; do
    case "$a" in review|merge|approvals|entry) names+=("$a") ;; esac
  done
  [[ "${#names[@]}" -gt 0 ]] || return 0
  # jq のプログラムは 4 つの変数をすべて参照するので、要求されていないものも `null` で必ず定義する。
  # 1 つでも欠けると jq がコンパイルに失敗し、出力が空になって**全部が missing に化ける**（実測で確認）
  for nm in review merge approvals entry; do
    want=0
    for a in "${names[@]}"; do [[ "$a" == "$nm" ]] && want=1; done
    if (( want )); then
      case "$nm" in
        review)    __hc_state_arg review    "$HOOK_WORKTREE/logs/review-state.json" ;;
        merge)     __hc_state_arg merge     "$HOOK_WORKTREE/logs/merge-state.json" ;;
        approvals) __hc_state_arg approvals "$HOOK_WORKTREE/logs/sessions/$HOOK_SESSION_ID/approvals.json" ;;
        entry)     __hc_state_arg entry     "$HOOK_WORKTREE/logs/sessions/$HOOK_SESSION_ID/entry.json" ;;
      esac
    else
      __HC_STATE_ARG=(--argjson "$nm" null)
    fi
    jqargs+=("${__HC_STATE_ARG[@]}")
  done
  if ! command -v jq >/dev/null 2>&1; then
    for nm in "${names[@]}"; do __hc_side_state "$nm" ""; done
    return 1
  fi
  jqargs+=(--arg names "${names[*]}")
  out="$(printf '%s' '{}' | jq -r "${jqargs[@]}" "$__HC_JQ_STATE" 2>/dev/null)" || out=""
  out="${out//$'\r'/}"
  for nm in "${names[@]}"; do
    sec="${out%%"$__HC_GS"*}"
    if [[ "$out" == *"$__HC_GS"* ]]; then out="${out#*"$__HC_GS"}"; else out=""; fi
    __hc_side_state "$nm" "$sec"
  done
  return 0
}

# 任意のフィールドを jq のパスで取る（例: hook_field '.tool_response.exit_code'）。無ければ空
hook_field() {
  [[ -n "$HOOK_INPUT" ]] || return 1
  printf '%s' "$HOOK_INPUT" | jq -r "($1) // empty" 2>/dev/null | tr -d '\r'
}

# ツールの分類（§2 の表）: write / exec / read / plan / spawn / declare
tool_class() { # $1=tool_name [$2=tool_input.skill]
  case "$1" in
    Edit|Write|MultiEdit|NotebookEdit) printf 'write\n' ;;
    Bash|PowerShell) printf 'exec\n' ;;
    EnterPlanMode) printf 'plan\n' ;;
    Agent|Workflow) printf 'spawn\n' ;;
    Skill) printf 'declare\n' ;;   # tool_input.skill の値は見ない（DDR i0009-03）
    *) printf 'read\n' ;;
  esac
}

# ---- 緊急停止（§4）とヘッドレス（§10）----
# 停止中なら 1。WORKFLOW_ENFORCE=0（全体）/ WORKFLOW_<NAME>_ENFORCE=0（フック単位。NAME は先頭の workflow- を除いた大文字スネーク）
hook_enforce_enabled() {
  local n="${1:-$HOOK_NAME}" v
  [[ "${WORKFLOW_ENFORCE:-1}" == "0" ]] && return 1
  n="${n#workflow-}"; n="${n^^}"; n="${n//-/_}"
  v="WORKFLOW_${n}_ENFORCE"
  [[ "${!v:-1}" == "0" ]] && return 1
  return 0
}

hook_headless() {
  [[ "${WORKFLOW_HEADLESS:-}" == "1" ]] && return 0
  case "${CI:-}" in 1|true|TRUE|True|yes|YES) return 0 ;; esac
  return 1
}

# ---- 作業中チケット ----
# 作業中チケットの basename を REPLY に、枚数を HOOK_DOING_COUNT に置く（0 枚なら REPLY は空）
hook_doing_ticket() {
  local f ng=0
  shopt -q nullglob && ng=1
  shopt -s nullglob
  local -a files=("$HOOK_WORKTREE"/wip/10_tickets/10_doing/*.md)
  (( ng )) || shopt -u nullglob
  HOOK_DOING_COUNT="${#files[@]}"
  REPLY=""
  if (( HOOK_DOING_COUNT > 0 )); then f="${files[0]}"; REPLY="${f##*/}"; fi
  return 0
}

# ---- 記録の書き込みヘルパ（§5。各フックが自作しない。DDR i0009-38）----
# 上限はこの節が持ち、呼び手は指定も切り詰めもしない（DDR i0009-60）
__HC_MAX_LINE=4096        # JSONL 1 行の上限（バイト。POSIX の追記が原子的である範囲に収める）
__HC_MAX_FIELD=512        # target / note の 1 つあたりの上限（合わせて 1 KB）
__HC_LOCK_WAIT=2          # 秒。取得を諦めるまで
__HC_LOCK_STALE_MIN=1     # 分。これより古いロックは陳腐化とみなす（= 60 秒。DDR i0009-60）
__HC_LOCKS=()

# JSON 1 行の中の "<key>":"<値>" を max 文字に切り詰める（REPLY）。値は __hc_json_str 済みの前提。
# 文字単位のループは使わない（長い行で O(n^2) になり実質ハングする）。パラメータ展開だけで O(n)。
__hc_cap_json_field() { # $1=行 $2=キー $3=上限
  local line="$1" key="$2" max="$3" marker pre post scan seg acc="" bs val tail
  local bsc='\'                                # バックスラッシュ 1 文字（クォートの入れ子を避ける）
  marker="\"$key\":\""
  if [[ "$line" != *"$marker"* ]]; then REPLY="$line"; return 0; fi
  pre="${line%%"$marker"*}"
  post="${line#*"$marker"}"
  # エスケープされていない最初の " までが値。`"` の出現回数だけ回る（通常 1 回）
  scan="$post"
  while :; do
    seg="${scan%%\"*}"
    acc+="$seg"
    [[ "$scan" == *\"* ]] || break            # 閉じ引用符が無い（壊れた行）
    bs="${seg##*[!"$bsc"]}"                        # seg 末尾の連続する \ 
    if (( ${#bs} % 2 == 1 )); then             # 奇数ならエスケープされた " なので続ける
      acc+='"'; scan="${scan#*\"}"; continue
    fi
    break
  done
  val="$acc"
  tail="${post:${#val}}"                       # 閉じ引用符から後ろ
  __hc_bytelen "$val"
  if (( REPLY > max )); then
    # 上限はバイト。多バイト文字が入ると文字数と食い違うので、収まる最大の長さを二分探索で決める
    # （比例で引くだけだと 1 回で負に振り切れて全部落ちる）
    # 末尾に付ける `…` も上限の内側。先にその分を引いておかないと 3 バイト超える
    local ell="…" ellb budget
    __hc_bytelen "$ell"; ellb="$REPLY"
    budget=$(( max - ellb ))
    if (( budget < 0 )); then ell=""; budget="$max"; fi
    local lo=0 hi="$budget" mid
    (( hi > ${#val} )) && hi=${#val}
    while (( lo < hi )); do
      mid=$(( (lo + hi + 1) / 2 ))
      __hc_bytelen "${val:0:mid}"
      if (( REPLY <= budget )); then lo=$mid; else hi=$(( mid - 1 )); fi
    done
    val="${val:0:lo}"
    while [[ "$val" == *"$bsc" ]]; do val="${val%"$bsc"}"; done   # 末尾の \ を落として不正なエスケープを作らない
    val+="$ell"
  fi
  REPLY="${pre}${marker}${val}${tail}"
}

# hc_append_jsonl <file> <line>
#   redact を通し、この関数が上限まで切り詰めて（… を付けて）追記する。呼び手は切り詰めない。戻り 1 = 書けない
# バイト長（ロケールに依らない。fork しない）。LC_ALL の代入は bash がその場でロケールに反映する
__hc_bytelen() { local LC_ALL=C; REPLY="${#1}"; }
# 行全体の最後の切り詰め。個別フィールドを詰めても収まらない行が来たときの最後の砦。
# 元の行をそのまま切って `…"}` を足す形は使えない — 切断点が JSON の構造の途中（`{"k":"a","` の後ろなど）に
# 落ちると閉じられず、末尾が `\` なら壊れたエスケープになる。内容を 1 つの文字列フィールドに入れ直し、
# エスケープは「切ってから」掛けることで、どこで切っても妥当な 1 行になるようにする。
__hc_cap_line_to_reply() {
  local line="$1" raw esc="" pre cut n
  __hc_bytelen "$line"; n="$REPLY"
  pre="{\"truncated\":true,\"bytes\":$n,\"head\":\""
  # エスケープで伸びる量は内容次第（1〜6 倍）なので、収まる最大の長さを二分探索で決める。
  # 半分で止めると、エスケープの要らない普通の内容で上限の 50% しか使えない
  local lo=0 hi mid budget=$(( __HC_MAX_LINE - ${#pre} - 6 ))
  hi=${#line}
  (( hi > budget )) && hi=$budget
  esc=""
  while (( lo < hi )); do
    mid=$(( (lo + hi + 1) / 2 ))
    __hc_json_str "${line:0:mid}"; raw="$REPLY"
    __hc_bytelen "$pre$raw"
    if (( REPLY <= __HC_MAX_LINE - 6 )); then lo=$mid; esc="$raw"; else hi=$(( mid - 1 )); fi
  done
  (( lo > 0 )) || esc=""
  REPLY="${pre}${esc}…\"}"
}
hc_append_jsonl() {
  local f="$1" line="$2" dir
  __hc_redact_to_reply "$line"; line="$REPLY"
  # 上限はバイトなので、判定もバイトで行う（${#line} はロケール次第で文字数になり、
  # UTF-8 環境では多バイトの行が門を素通りしてそのまま追記される）
  __hc_bytelen "$line"
  if (( REPLY >= __HC_MAX_LINE )); then
    __hc_cap_json_field "$line" target "$__HC_MAX_FIELD"; line="$REPLY"
    __hc_cap_json_field "$line" note   "$__HC_MAX_FIELD"; line="$REPLY"
    __hc_bytelen "$line"
  fi
  if (( REPLY >= __HC_MAX_LINE )); then __hc_cap_line_to_reply "$line"; line="$REPLY"; fi
  dir="${f%/*}"
  if [[ "$dir" != "$f" ]]; then mkdir -p "$dir" 2>/dev/null || return 1; fi
  printf '%s\n' "$line" >> "$f" 2>/dev/null || return 1
  return 0
}

# hc_json_write <file> <content>
#   <name>.tmp.<pid> へ書いて mv で置き換える。呼び手は一時ファイル名を作らない。戻り 1 = 書けない
hc_json_write() {
  local f="$1" content="$2" dir tmp
  dir="${f%/*}"
  if [[ "$dir" != "$f" ]]; then mkdir -p "$dir" 2>/dev/null || return 1; fi
  tmp="$f.tmp.$$"
  printf '%s\n' "$content" > "$tmp" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  mv -f "$tmp" "$f" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  return 0
}

# hc_lock <name>
#   mkdir <name>.lock で取る。取得を試みる前に、既存のロックが 60 秒より古ければ陳腐化とみなして rmdir し、
#   強制解放を実行ログに 1 行残す（打ち切りでは trap も || も効かないため。§3・DDR i0009-60）。
#   2 秒で取れなければ 1 を返す。2 秒と 60 秒はこの関数が持ち、呼び手は指定しない。
#   注: find を 1 回起動するため、ホットパス（§1 の 5 本）からは呼ばない
hc_lock() {
  local name="$1" d i
  d="$HOOK_WORKTREE/logs/locks/$name.lock"
  mkdir -p "${d%/*}" 2>/dev/null || return 1
  if [[ -d "$d" ]] && [[ -n "$(find "$d" -maxdepth 0 -mmin "+$__HC_LOCK_STALE_MIN" 2>/dev/null)" ]]; then
    if rmdir "$d" 2>/dev/null; then log_warn "陳腐化したロックを強制解放した name=$name"; fi
  fi
  for (( i = 0; i < __HC_LOCK_WAIT * 10; i++ )); do
    if mkdir "$d" 2>/dev/null; then
      __HC_LOCKS+=("$name")
      trap '__hc_unlock_all' EXIT
      return 0
    fi
    sleep 0.1 2>/dev/null || true
  done
  return 1
}

# hc_unlock <name>。取っていなくても失敗しない（冪等）
hc_unlock() {
  local name="$1" n
  local -a keep=()
  rmdir "$HOOK_WORKTREE/logs/locks/$name.lock" 2>/dev/null || true
  for n in ${__HC_LOCKS[@]+"${__HC_LOCKS[@]}"}; do
    [[ "$n" == "$name" ]] || keep+=("$n")
  done
  __HC_LOCKS=(${keep[@]+"${keep[@]}"})
  return 0
}
__hc_unlock_all() {
  local n
  for n in ${__HC_LOCKS[@]+"${__HC_LOCKS[@]}"}; do
    rmdir "$HOOK_WORKTREE/logs/locks/$n.lock" 2>/dev/null || true
  done
  __HC_LOCKS=()
}

# ---- 記録（§5 decisions.jsonl）----
# hook_record <decision> <id> <target> <note>。書けなくても本体を止めない。target / note は redact を通す
hook_record() {
  local decision="$1" id="${2:-}" target="${3:-}" note="${4:-}" ts ticket line
  __hc_now; ts="$REPLY"
  hook_doing_ticket; ticket="$REPLY"
  __hc_redact_to_reply "$target"; __hc_json_str "$REPLY"; target="$REPLY"
  __hc_redact_to_reply "$note"; __hc_json_str "$REPLY"; note="$REPLY"
  __hc_json_str "$HOOK_TOOL"; local tool="$REPLY"
  __hc_json_str "$ticket"; ticket="$REPLY"
  __hc_json_str "$decision"; decision="$REPLY"
  __hc_json_str "$id"; id="$REPLY"
  # HOOK_EVENT も外部（stdin）由来なので、他のフィールドと同じくエスケープを通す（rules/logger.md のセキュリティ節）
  __hc_json_str "$HOOK_EVENT"; local ev="$REPLY"
  line="{\"ts\":\"$ts\",\"session_id\":\"$HOOK_SESSION_ID\",\"hook\":\"$HOOK_NAME\",\"event\":\"$ev\",\"decision\":\"$decision\",\"id\":\"$id\",\"tool\":\"$tool\",\"target\":\"$target\",\"ticket\":\"$ticket\",\"note\":\"$note\"}"
  hc_append_jsonl "$HOOK_WORKTREE/logs/hooks/decisions.jsonl" "$line" || log_warn "decisions.jsonl に追記できない"
  log_info "decision=$decision id=$id tool=$tool target=$target"
  return 0
}

# ---- 出力（§3）----
__hc_emit_decision() { # $1=deny|ask $2=理由（redact 済み）
  __hc_json_str "$2"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$REPLY"
}
__hc_emit_context() { # $1=イベント $2=本文（redact 済み）
  __hc_json_str "$2"
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$1" "$REPLY"
}

# hook_deny <識別子> <理由と対処> [対象]。deny JSON を 1 つだけ出して終了 0
hook_deny() {
  local id="$1" msg="${2:-}" target="${3:-}"
  trap - ERR
  hook_record deny "$id" "$target" "$msg"
  __hc_redact_to_reply "$id: $msg"
  __hc_emit_decision deny "$REPLY"
  exit 0
}

# hook_ask <識別子> <確認の根拠> [対象] [ヘッドレス時の識別子]。ヘッドレスでは deny に置き換える（§10）
hook_ask() {
  local id="$1" msg="${2:-}" target="${3:-}" hid="${4:-$1}"
  if hook_headless; then
    hook_deny "$hid" "$msg（ヘッドレス実行のため確認できない。計画タスクで宣言を十分に列挙する必要がある）" "$target"
  fi
  trap - ERR
  hook_record ask "$id" "$target" "$msg"
  __hc_redact_to_reply "$id: $msg"
  __hc_emit_decision ask "$REPLY"
  exit 0
}

# hook_notify <イベント> <識別子> <本文> [対象]。additionalContext（PostToolUse など）。終了しない（呼び手が続きを決める）
hook_notify() {
  local ev="$1" id="$2" msg="${3:-}" target="${4:-}"
  hook_record notify "$id" "$target" "$msg"
  __hc_redact_to_reply "$id: $msg"
  __hc_emit_context "$ev" "$REPLY"
  return 0
}

# hook_inject <イベント> <識別子> <本文>。SessionStart は stdout のテキスト、他は additionalContext。終了しない
hook_inject() {
  local ev="$1" id="$2" msg="${3:-}"
  hook_record inject "$id" "" "${msg:0:200}"
  __hc_redact_to_reply "$msg"
  if [[ "$ev" == "SessionStart" ]]; then printf '%s\n' "$REPLY"; else __hc_emit_context "$ev" "$REPLY"; fi
  return 0
}

# 許可（何も出力せず終了 0。記録は任意）
hook_allow() { # [識別子] [対象] [note] — 引数があれば allow を記録する
  trap - ERR
  if [[ -n "${1:-}" ]]; then hook_record allow "$1" "${2:-}" "${3:-}"; fi
  exit 0
}

# 停止中（§4）: disabled を記録して終了 0
hook_disabled() {
  trap - ERR
  hook_record disabled "" "" "WORKFLOW_ENFORCE / WORKFLOW_<NAME>_ENFORCE=0"
  exit 0
}

# 判定不能: 拒否側は deny（HOOK_DENY_ID）、案内側は skip を記録して無出力で終了 0（§3）
hook_fail() {
  local msg="${1:-判定できない}"
  trap - ERR
  if [[ "$HOOK_SIDE" == "deny" ]]; then
    hook_deny "$HOOK_DENY_ID" "機構の不調 — $msg。フックの依存（jq・設定・入力）を確認する"
  fi
  hook_record skip "$HOOK_DENY_ID" "" "$msg"
  exit 0
}

# fail-closed: 以後の未捕捉エラーを hook_fail に倒す（拒否側フックの冒頭で呼ぶ）
__hc_on_err() { hook_fail "フックの内部エラー（${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]:-?}）"; }
hook_fail_closed() {
  set -E
  trap '__hc_on_err' ERR
  return 0
}

# ---- セッション状態（§5。session_id ごとに分離）----
hook_session_dir() { REPLY="$HOOK_WORKTREE/logs/sessions/$HOOK_SESSION_ID"; }
hook_session_read() { # $1=ファイル名 → 内容を出力（無ければ何も出さず 1）
  hook_session_dir
  [[ -f "$REPLY/$1" ]] || return 1
  cat "$REPLY/$1" 2>/dev/null
}
hook_session_write() { # $1=ファイル名 $2=内容。置き換えは hc_json_write（一時ファイル + mv）に委ねる
  local dir
  hook_session_dir; dir="$REPLY"
  hc_json_write "$dir/$1" "$2"
}

# ---- パス正規化（リポジトリルート相対。REPLY に返し、出力もする）----
hook_rel_path() {
  local p="${1:-}" root="$HOOK_WORKTREE" lr lp
  p="${p//\\//}"
  # /c/Users/... → C:/Users/...
  if [[ "$p" =~ ^/([A-Za-z])/(.*)$ ]]; then p="${BASH_REMATCH[1]^^}:/${BASH_REMATCH[2]}"; fi
  if [[ "$root" =~ ^/([A-Za-z])/(.*)$ ]]; then root="${BASH_REMATCH[1]^^}:/${BASH_REMATCH[2]}"; fi
  lr="${root,,}"; lp="${p,,}"
  if [[ "$lp" == "$lr/"* ]]; then p="${p:$(( ${#root} + 1 ))}"; elif [[ "$lp" == "$lr" ]]; then p="."; fi
  while [[ "$p" == ./* ]]; do p="${p:2}"; done
  while [[ "$p" == *//* ]]; do p="${p//\/\///}"; done
  REPLY="$p"
  printf '%s\n' "$p"
}
