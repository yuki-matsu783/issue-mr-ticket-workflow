#!/usr/bin/env bash
# scope.sh — 許可範囲の判定（source 専用）
# 仕様: .claude/docs/10_spec/フック共通仕様.md §8（上限設定・判定順・glob 規則・ops の分類）、§9（チケットの機械可読項目）
# 提供: scope_load <scope-limits.json> [type] / scope_load_ticket <チケット> / scope_load_approvals <approvals.json> /
#       scope_match <glob> <path> / scope_resolve <path> / scope_op_declared <分類> / scope_classify <セグメント番号>
# 結果: scope_resolve → SC_DECISION（skip|deny|ask|allow）/ SC_ID（WF201|WF202|WF203|空）/ SC_STAGE（判定順の番号）/
#       SC_ASK_SCOPE（WF202 の承認単位）。scope_classify → 分類名を出力し SC_CLASS / SC_TARGETS（US 区切り）に置く
# 依存: frontmatter.sh（読み込み行。読めなければ deny に倒す）、cmdpos.sh（scope_classify が CP_* を読む）
# 規則: `*` は `/` を跨がず `**` は跨ぐ。宣言（allow.write / allow.ops）は上限の内側で絞る役（上限外の要素は無視）。
#       `common.confirm` はどの type の allow より優先して ask になる。純 bash（jq は設定の読み込みで 1 回）

# 直接実行されたら何もしない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load frontmatter deny

_SC_US=$'\x1e'   # レコード区切り（hook_read_input の副入力と同じ）
_SC_KV=$'\x1f'   # レコードの key/value 区切り
SC_ERROR=""; SC_TYPE=""; SC_TYPES=()
SC_COMMON_ALLOW=(); SC_COMMON_PROTECTED=(); SC_COMMON_CONFIRM=(); SC_COMMON_FILE_GRANULAR=(); SC_COMMON_STATE_FILES=()
SC_TYPE_ALLOW=(); SC_TYPE_DENY=(); SC_TYPE_CONFIRM=(); SC_TYPE_OPS=(); SC_TYPE_PLAN_MODE="false"
SC_BUILD_TEST_CMDS=(); SC_TICKET_TYPE=""; SC_DECL_WRITE=(); SC_DECL_OPS=(); SC_TICKET_LOADED=0; SC_APPROVED=()
SC_DECISION=""; SC_ID=""; SC_STAGE=0; SC_ASK_SCOPE=""; SC_CLASS=""; SC_TARGETS=""
declare -A _SC_RE_CACHE=()

# 読み取り系コマンド（状態を変えない）。git / gh / glab / sed / find / bash は個別規則
_SC_READ_ONLY_CMDS=' ls cat head tail grep rg egrep fgrep jq wc sort uniq diff cmp test [ [[ echo printf true false pwd which type shellcheck stat file date basename dirname realpath readlink cut tr awk fold column od xxd sha256sum md5sum sha1sum less more tree du df printenv hostname whoami id uname seq expr bc comm join paste rev nl tac strings fmt yq column '
_SC_GIT_READ_SUBCMDS=' status log diff show branch rev-parse fetch ls-files ls-remote ls-tree rev-list describe blame shortlog cat-file merge-base reflog grep for-each-ref symbolic-ref check-ignore var count-objects whatchanged name-rev show-ref diff-tree diff-index diff-files '

# ---- 上限設定の読み込み（§8）----
# scope_load [type]
#   hook_read_input が読んだ HC_LIMITS を SC_* に詰め替えるだけで、JSON のファイルを開かない（DDR i0009-48）。
#   JSON を読むのは jq 1 か所に限り、scope.sh を source する 4 本のフックが「自分が何回 jq を呼ぶか」を数えられるようにする。
#   戻り 1 = 設定が読めない / 設定不正 / types に無い種類（SC_ERROR に理由。呼び手は WF210 / WF211）
scope_load() {
  local t="${1:-}" s rec k v found=0 x
  SC_ERROR=""; SC_TYPE="$t"; SC_TYPES=()
  SC_COMMON_ALLOW=(); SC_COMMON_PROTECTED=(); SC_COMMON_CONFIRM=(); SC_COMMON_FILE_GRANULAR=(); SC_COMMON_STATE_FILES=()
  SC_TYPE_ALLOW=(); SC_TYPE_DENY=(); SC_TYPE_CONFIRM=(); SC_TYPE_OPS=(); SC_TYPE_PLAN_MODE="false"; SC_BUILD_TEST_CMDS=()
  case "${HC_LIMITS_STATE:-missing}" in
    ok) ;;
    broken) SC_ERROR="${HC_LIMITS_ERROR:-設定を解釈できない}"; return 1 ;;
    *)      SC_ERROR="設定ファイルが無い（.claude/hooks/config/scope-limits.json）"; return 1 ;;
  esac
  s="${HC_LIMITS:-}"
  while [[ -n "$s" ]]; do
    if [[ "$s" == *"$_SC_US"* ]]; then rec="${s%%"$_SC_US"*}"; s="${s#*"$_SC_US"}"; else rec="$s"; s=""; fi
    [[ "$rec" == *"$_SC_KV"* ]] || continue
    k="${rec%%"$_SC_KV"*}"; v="${rec#*"$_SC_KV"}"
    case "$k" in
      common.allow)          SC_COMMON_ALLOW+=("$v") ;;
      common.protected)      SC_COMMON_PROTECTED+=("$v") ;;
      common.confirm)        SC_COMMON_CONFIRM+=("$v") ;;
      common.file_granular)  SC_COMMON_FILE_GRANULAR+=("$v") ;;
      common.state_files)    SC_COMMON_STATE_FILES+=("$v") ;;
      type)                  SC_TYPES+=("$v") ;;
      build-test)            SC_BUILD_TEST_CMDS+=("$v") ;;
      "t.$t.allow")          SC_TYPE_ALLOW+=("$v") ;;
      "t.$t.deny")           SC_TYPE_DENY+=("$v") ;;
      "t.$t.confirm")        SC_TYPE_CONFIRM+=("$v") ;;
      "t.$t.ops")            SC_TYPE_OPS+=("$v") ;;
      "t.$t.plan_mode")      SC_TYPE_PLAN_MODE="$v" ;;
    esac
  done
  if [[ -n "$t" ]]; then
    for x in ${SC_TYPES[@]+"${SC_TYPES[@]}"}; do [[ "$x" == "$t" ]] && found=1; done
    (( found )) || { SC_ERROR="types に無い種類: $t"; return 1; }
  fi
  return 0
}

# ---- チケットの宣言（§9）----
# scope_load_ticket <チケットファイル>
#   戻り 0 = 読めた / 1 = frontmatter は読めたが ticket_type が無い・対象外の形（呼び手は WF211）/
#        2 = frontmatter.sh を読み込めていない（機構の破損。呼び手は WFx09。DDR i0009-16）
#   呼び出し規約（DDR i0009-35）: local と代入を同じ行に書かず、`|| true` で戻り値を捨てない
scope_load_ticket() {
  local f="$1" v rc=0
  SC_TICKET_TYPE=""; SC_DECL_WRITE=(); SC_DECL_OPS=(); SC_TICKET_LOADED=0
  if [[ "${FM_AVAILABLE:-0}" != "1" ]]; then SC_ERROR="frontmatter.sh を読み込めていない"; return 2; fi
  [[ -f "$f" ]] || { SC_ERROR="チケットが無い: $f"; return 1; }
  local tt
  tt="$(fm_get "$f" ticket_type)" || rc=$?
  (( rc == 2 )) && { SC_ERROR="frontmatter.sh を読み込めていない"; return 2; }
  SC_TICKET_TYPE="${tt//$'\r'/}"
  [[ -n "$SC_TICKET_TYPE" ]] || { SC_ERROR="ticket_type が無い: $f"; return 1; }
  while IFS= read -r v; do v="${v//$'\r'/}"; [[ -n "$v" ]] && SC_DECL_WRITE+=("$v"); done < <(fm_list "$f" allow.write)
  while IFS= read -r v; do v="${v//$'\r'/}"; [[ -n "$v" ]] && SC_DECL_OPS+=("$v"); done < <(fm_list "$f" allow.ops)
  SC_TICKET_LOADED=1
  return 0
}

# scope_load_approvals
#   hook_read_state が読んだ HC_APPROVALS を SC_APPROVED に詰め替えるだけ（パスを引数に取らない。DDR i0009-48）
#   戻り 1 = 記録が壊れている（呼び手は無視して続けてよい。承認の記憶が空になるだけ）
scope_load_approvals() {
  local s rec k v
  SC_APPROVED=()
  case "${HC_APPROVALS_STATE:-missing}" in
    ok) ;;
    broken) SC_ERROR="承認の記憶を解釈できない"; return 1 ;;
    *) return 0 ;;
  esac
  s="${HC_APPROVALS:-}"
  while [[ -n "$s" ]]; do
    if [[ "$s" == *"$_SC_US"* ]]; then rec="${s%%"$_SC_US"*}"; s="${s#*"$_SC_US"}"; else rec="$s"; s=""; fi
    [[ "$rec" == *"$_SC_KV"* ]] || continue
    k="${rec%%"$_SC_KV"*}"; v="${rec#*"$_SC_KV"}"
    [[ "$k" == "scope" && -n "$v" ]] && SC_APPROVED+=("$v")
  done
  return 0
}

# ---- glob ----
_sc_glob_to_re() { # glob → 拡張正規表現（REPLY）。`*` は `/` を跨がず、`**` は 0 個以上のディレクトリ
  local g="$1" out="" i c n=${#1}
  for ((i = 0; i < n; i++)); do
    c="${g:i:1}"
    case "$c" in
      '*')
        if [[ "${g:i+1:1}" == '*' ]]; then
          if [[ "${g:i+2:1}" == '/' ]]; then out+='(.*/)?'; i=$((i + 2)); else out+='.*'; i=$((i + 1)); fi
        else out+='[^/]*'; fi ;;
      '?') out+='[^/]' ;;
      '.'|'+'|'('|')'|'['|']'|'{'|'}'|'^'|'$'|'|'|'\') out+="\\$c" ;;
      *) out+="$c" ;;
    esac
  done
  REPLY="^${out}\$"
}

# scope_match <glob> <ルート相対パス>
scope_match() {
  local g="$1" p="$2" re
  re="${_SC_RE_CACHE[$g]:-}"
  if [[ -z "$re" ]]; then _sc_glob_to_re "$g"; re="$REPLY"; _SC_RE_CACHE[$g]="$re"; fi
  [[ "$p" =~ $re ]]
}

_sc_any_match() { # $1=path $2..=globs
  local p="$1" g
  shift
  for g in "$@"; do scope_match "$g" "$p" && return 0; done
  return 1
}

# ---- 判定順（§8 (1)〜(7)）----
# scope_resolve <ルート相対パス>
scope_resolve() {
  local p="$1" in_type_allow=0 a
  SC_DECISION=""; SC_ID=""; SC_STAGE=0; SC_ASK_SCOPE=""
  # (1) logs/**（state_files を除く）は対象外
  if scope_match 'logs/**' "$p" && ! _sc_any_match "$p" "${SC_COMMON_STATE_FILES[@]}"; then
    SC_DECISION="skip"; SC_STAGE=1; return 0
  fi
  _sc_any_match "$p" "${SC_TYPE_ALLOW[@]}" && in_type_allow=1
  # (2) 共通保護範囲（type の allow に明示されていなければ拒否）
  if (( in_type_allow == 0 )) && _sc_any_match "$p" "${SC_COMMON_PROTECTED[@]}"; then
    SC_DECISION="deny"; SC_ID="WF201"; SC_STAGE=2; return 0
  fi
  # (3) type の禁止範囲
  if _sc_any_match "$p" "${SC_TYPE_DENY[@]}"; then SC_DECISION="deny"; SC_ID="WF201"; SC_STAGE=3; return 0; fi
  # (4) 毎回確認（common.confirm はどの allow より優先）
  if _sc_any_match "$p" "${SC_COMMON_CONFIRM[@]}" || _sc_any_match "$p" "${SC_TYPE_CONFIRM[@]}"; then
    SC_DECISION="ask"; SC_ID="WF203"; SC_STAGE=4; return 0
  fi
  # (5) 許可範囲 A = common.allow ∪（宣言があれば d.write ∩ types[t].allow、無ければ types[t].allow）
  if _sc_any_match "$p" "${SC_COMMON_ALLOW[@]}"; then SC_DECISION="allow"; SC_STAGE=5; return 0; fi
  if (( in_type_allow )); then
    if (( ${#SC_DECL_WRITE[@]} == 0 )) || _sc_any_match "$p" "${SC_DECL_WRITE[@]}"; then
      SC_DECISION="allow"; SC_STAGE=5; return 0
    fi
  fi
  # (6) 承認済み範囲
  # 承認単位 "." は認めない（ルート直下のファイルはファイル単位で承認される。"." が入ると全パスが allow になるため）
  for a in "${SC_APPROVED[@]}"; do
    [[ "$a" == "." || -z "$a" ]] && continue
    if [[ "$p" == "$a" || "$p" == "$a/"* ]]; then SC_DECISION="allow"; SC_STAGE=6; return 0; fi
  done
  # (7) 未記載 → 確認。承認単位は親ディレクトリ（file_granular とルート直下のファイルはファイル単位）
  SC_DECISION="ask"; SC_ID="WF202"; SC_STAGE=7
  if _sc_any_match "$p" "${SC_COMMON_FILE_GRANULAR[@]}"; then SC_ASK_SCOPE="$p"
  elif [[ "$p" == */* ]]; then SC_ASK_SCOPE="${p%/*}"
  else SC_ASK_SCOPE="$p"; fi
  return 0
}

# ---- 操作の分類（§8 ops）----
# scope_op_declared <分類>: read / remote-read は常に可。他はチケットの allow.ops と types[t].ops の両方にあるときだけ 0
scope_op_declared() {
  local c="$1" x in_type=0 in_decl=0
  case "$c" in read|remote-read|provided) return 0 ;; esac
  for x in "${SC_TYPE_OPS[@]}"; do [[ "$x" == "$c" ]] && in_type=1; done
  for x in "${SC_DECL_OPS[@]}"; do [[ "$x" == "$c" ]] && in_decl=1; done
  (( in_type && in_decl ))
}

_sc_classify_gh() { # $1=exe(gh|glab) $2..=args → REPLY=分類
  local exe="$1"; shift
  local -a a=("$@")
  local g="${a[0]:-}" v="${a[1]:-}" x method="" haswrite=0 path=""
  case "$g" in
    auth) [[ "$v" == status ]] && REPLY="remote-read" || REPLY="remote-write:other"; return 0 ;;
    api)
      for ((x = 1; x < ${#a[@]}; x++)); do
        case "${a[x]}" in
          -X|--method) method="${a[x+1]:-}"; method="${method^^}"; x=$((x + 1)) ;;
          -X*) method="${a[x]:2}"; method="${method^^}" ;;
          -f|-F|--field|--raw-field|--input) haswrite=1; x=$((x + 1)) ;;
          --input=*|--field=*|--raw-field=*) haswrite=1 ;;
          --jq|-q|-H|--header|--hostname|-p|--preview|--cache) x=$((x + 1)) ;;
          --paginate|-i|--include|--silent|--verbose) ;;
          -*) ;;
          *) [[ -z "$path" ]] && path="${a[x]}" ;;
        esac
      done
      if [[ -z "$method" ]]; then (( haswrite )) && method="POST" || method="GET"; fi
      if [[ "$method" == GET ]]; then REPLY="remote-read"; return 0; fi
      case "$path" in
        *uploads*) REPLY="remote-write:attach" ;;
        *notes*|*comments*) REPLY="remote-write:mr-comment" ;;
        *merge_requests/*|*pulls/*) [[ "$method" == POST ]] && REPLY="remote-write:mr-comment" || REPLY="remote-write:mr-edit" ;;
        *merge_requests*|*pulls*) [[ "$method" == POST ]] && REPLY="remote-write:mr-create" || REPLY="remote-write:mr-edit" ;;
        *issues/*) REPLY="remote-write:issue-append" ;;
        *issues*) [[ "$method" == POST ]] && REPLY="remote-write:issue-create" || REPLY="remote-write:issue-append" ;;
        *) REPLY="remote-write:other" ;;
      esac
      return 0 ;;
    issue)
      case "$v" in view|list|status) REPLY="remote-read" ;; create) REPLY="remote-write:issue-create" ;; edit|update) REPLY="remote-write:issue-append" ;; *) REPLY="remote-write:other" ;; esac; return 0 ;;
    pr|mr)
      case "$v" in view|list|status|diff|checks) REPLY="remote-read" ;; create) REPLY="remote-write:mr-create" ;; edit|update) REPLY="remote-write:mr-edit" ;; comment|note) REPLY="remote-write:mr-comment" ;; ready) REPLY="remote-write:draft-ready" ;; *) REPLY="remote-write:other" ;; esac; return 0 ;;
    repo|run|workflow|release|label|search|project|ci|pipeline)
      case "$v" in view|list|status|watch|download) REPLY="remote-read" ;; upload) REPLY="remote-write:attach" ;; *) REPLY="remote-write:other" ;; esac; return 0 ;;
    version|help|--version|--help|status) REPLY="remote-read"; return 0 ;;
    *) REPLY="remote-write:other"; return 0 ;;
  esac
}

# ---- curl / wget の 3 段判定（§8・DDR i0009-56 / i0009-57）----
# 判定順を変えると穴が開く: (1) 送信側 → remote-write:upload（呼び手は宣言を見ずに deny WF206）/
# (2) 出力先を持つ形 → write（SC_TARGETS に出力先。呼び手は §8 の判定を当てて WF205）/ (3) 残りが web。
# 出力先は cmdpos_operands では取れない（オプション本体が落ち、URL と出力先を区別できない）。
# cmdpos_args の引数列を先頭から走査し、出力先オプションの「次の語」を取る。`://` を含む語は URL とみなす。
# `-O` / `--remote-name` と wget の既定は出力先の語を取らず、URL の basename を作業ツリー基準のカレントに作る（`_`）。
# 注: curl は 200 以上のオプションを持つので、この列挙が網羅的かは確かめられない（.curlrc 経由の指定も見ていない）
_SC_WEB_CMDS=' curl wget '
_sc_web_is_get() { local m="${1^^}"; [[ "$m" == GET || "$m" == HEAD ]]; }
_sc_classify_web() { # $1=実行体（REPLY_ARGS は呼び手が cmdpos_args 済み）
  local exe="$1" a nxt val i n send=0 seen_o=0 dash_o=0
  local -a outs=()
  n="${#REPLY_ARGS[@]}"
  for (( i = 0; i < n; i++ )); do
    a="${REPLY_ARGS[i]}"
    nxt="${REPLY_ARGS[i+1]:-}"
    if [[ "$exe" == curl ]]; then
      case "$a" in
        -T|--upload-file|-d|--data|--data-raw|--data-binary|--data-urlencode|-F|--form) send=1 ;;
        --data=*|--data-raw=*|--data-binary=*|--data-urlencode=*|--form=*|--upload-file=*) send=1 ;;
        -X|--request) _sc_web_is_get "$nxt" || send=1 ;;
        --request=*) val="${a#*=}"; _sc_web_is_get "$val" || send=1 ;;
        -X?*) val="${a#-X}"; _sc_web_is_get "$val" || send=1 ;;
        -o|--output|--output-dir) seen_o=1; [[ "$nxt" == "-" ]] && dash_o=1 || { [[ -n "$nxt" && "$nxt" != *://* ]] && outs+=("$nxt"); } ;;
        --output=*|--output-dir=*) val="${a#*=}"; if [[ "$val" == "-" ]]; then dash_o=1; else seen_o=1; [[ -n "$val" && "$val" != *://* ]] && outs+=("$val"); fi ;;
        -O|--remote-name) seen_o=1; outs+=("_") ;;
      esac
    else
      case "$a" in
        --post-file|--post-data|--body-file|--body-data) send=1 ;;
        --post-file=*|--post-data=*|--body-file=*|--body-data=*) send=1 ;;
        --method) _sc_web_is_get "$nxt" || send=1 ;;
        --method=*) val="${a#*=}"; _sc_web_is_get "$val" || send=1 ;;
        -O|--output-document) seen_o=1; [[ "$nxt" == "-" ]] && dash_o=1 || { [[ -n "$nxt" && "$nxt" != *://* ]] && outs+=("$nxt"); } ;;
        --output-document=*) val="${a#*=}"; if [[ "$val" == "-" ]]; then dash_o=1; else seen_o=1; [[ -n "$val" && "$val" != *://* ]] && outs+=("$val"); fi ;;
      esac
    fi
  done
  # (1) 送信側は宣言の有無によらず拒否側へ（remote-write:<種別> の統制が迂回されるため）
  if (( send )); then SC_CLASS="remote-write:upload"; SC_TARGETS=""; return 0; fi
  # wget は既定で URL の basename に書く（-O - でなければ出力先を持つ）
  if [[ "$exe" == wget ]] && (( ! seen_o )) && (( ! dash_o )); then outs+=("_"); fi
  # (2) 出力先を持つ形は書き込みとして扱う
  if (( ${#outs[@]} > 0 )); then
    SC_CLASS="write"
    SC_TARGETS=""
    for a in "${outs[@]}"; do SC_TARGETS+="${SC_TARGETS:+$_SC_US}$a"; done
    return 0
  fi
  # (3) 残りが web（`curl <url>` の既定は標準出力、`wget -O -` も書き込みに当たらない）
  SC_CLASS="web"; SC_TARGETS=""
  return 0
}

# scope_classify <セグメント番号>（cmdpos_parse 済み）→ provided / hook-test / build-test / read / remote-read /
#   remote-write:<種別> / merge-base / write（SC_TARGETS に宛先）/ opaque / unknown を出力
scope_classify() {
  local i="$1" exe="" first="" segstr="" e t
  exe="${CP_EXE[$i]:-}"
  SC_CLASS="unknown"; SC_TARGETS=""
  cmdpos_args "$i"
  first="${REPLY_ARGS[0]:-}"
  # hook-test（提供コマンドの判定より先: .claude/hooks/**/tests/*.sh は提供コマンドの形にも一致するため）
  if [[ "$exe" == bash || "$exe" == sh ]] && [[ "$first" =~ ^\.claude/hooks/([^/]+/)*tests/[^/]+\.sh$ || "$first" =~ ^\.claude/skills/[^/]+/scripts/tests/[^/]+\.sh$ ]]; then
    SC_CLASS="hook-test"
  elif [[ -n "${CP_PROVIDED[$i]:-}" ]]; then
    SC_CLASS="provided"
  elif [[ "$_SC_WEB_CMDS" == *" $exe "* ]]; then
    _sc_classify_web "$exe"
  elif [[ -n "${CP_REDIRECTS[$i]:-}" || -n "${CP_WRITE_TARGETS[$i]:-}" ]]; then
    SC_CLASS="write"
    SC_TARGETS="${CP_WRITE_TARGETS[$i]:-}${CP_WRITE_TARGETS[$i]:+${CP_REDIRECTS[$i]:+$_SC_US}}${CP_REDIRECTS[$i]:-}"
  elif [[ "${CP_OPAQUE[$i]:-0}" == 1 ]]; then
    SC_CLASS="opaque"
  elif [[ "$exe" == git ]]; then
    local sub="${CP_SUBCMD[$i]:-}"
    if [[ "$_SC_GIT_READ_SUBCMDS" == *" $sub "* ]]; then SC_CLASS="read"
    elif [[ "$sub" == config ]]; then
      SC_CLASS="unknown"; for t in "${REPLY_ARGS[@]}"; do case "$t" in --get|--get-all|--list|-l|--get-regexp) SC_CLASS="read" ;; esac; done
    elif [[ "$sub" == remote ]]; then
      SC_CLASS="read"; for t in "${REPLY_ARGS[@]:1}"; do case "$t" in add|remove|rename|set-url|prune|update) SC_CLASS="unknown" ;; esac; done
    elif [[ "$sub" == merge ]]; then
      SC_CLASS="unknown"; for t in "${REPLY_ARGS[@]}"; do [[ "$t" == origin/* ]] && SC_CLASS="merge-base"; done
    elif [[ "$sub" == push ]]; then SC_CLASS="remote-write:push"
    fi
  elif [[ "$exe" == gh || "$exe" == glab ]]; then
    _sc_classify_gh "$exe" "${REPLY_ARGS[@]}"; SC_CLASS="$REPLY"
  elif [[ "$exe" == bash || "$exe" == sh ]]; then
    if [[ "$first" == -n ]]; then SC_CLASS="read"
    elif [[ "$first" =~ ^(tests|test)/.*\.sh$ ]]; then SC_CLASS="build-test"
    fi
  elif [[ "$exe" == find ]]; then
    SC_CLASS="read"; for t in "${REPLY_ARGS[@]}"; do [[ "$t" == -delete ]] && { SC_CLASS="write"; SC_TARGETS="_"; }; done
  elif [[ "$exe" == sed ]]; then
    SC_CLASS="read"
  elif [[ "$_SC_READ_ONLY_CMDS" == *" $exe "* ]]; then
    SC_CLASS="read"
  fi
  # build-test: 上限設定の commands.build-test に列挙されたコマンドで始まる
  if [[ "$SC_CLASS" == unknown ]]; then
    segstr="$exe"; for t in "${REPLY_ARGS[@]}"; do segstr+=" $t"; done
    for e in "${SC_BUILD_TEST_CMDS[@]}"; do [[ "$segstr" == "$e" || "$segstr" == "$e "* ]] && SC_CLASS="build-test"; done
  fi
  printf '%s\n' "$SC_CLASS"
  return 0
}
