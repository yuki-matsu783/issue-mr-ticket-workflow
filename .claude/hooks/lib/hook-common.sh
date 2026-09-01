#!/usr/bin/env bash
# hook-common.sh — フック共通ライブラリ（source 専用）
# 仕様: .claude/docs/10_spec/フック共通仕様.md §2（入力）・§3（制御方式・redact）・§4（緊急停止）・§5（記録と状態）・§10（ヘッドレス）
# 提供: hook_init / hook_read_input / hook_field / tool_class / hook_enforce_enabled / hook_headless / redact / hook_jq /
#       hook_record / hook_deny / hook_ask / hook_notify / hook_inject / hook_allow / hook_disabled / hook_fail /
#       hook_fail_closed / hook_require_jq / hook_session_read / hook_session_write / hook_rel_path / hook_doing_ticket
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
__HC_US=$'\x1e'

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
  # 3. key=value（token / password / secret / api_key / api-key / apikey）。大文字小文字を問わない
  shopt -s nocasematch
  while [[ "$s" =~ ((token|password|secret|api[_-]?key)=)[^[:space:]\&\;\"\'\*]+ ]]; do
    m="${BASH_REMATCH[0]}"; pre="${s%%"$m"*}"; post="${s#*"$m"}"; s="${pre}${BASH_REMATCH[1]}***${post}"
  done
  shopt -u nocasematch
  # 4. AWS アクセスキー（AKIA + 16 文字）
  while [[ "$s" =~ AKIA[A-Z0-9]{16} ]]; do
    m="${BASH_REMATCH[0]}"; pre="${s%%"$m"*}"; post="${s#*"$m"}"; s="${pre}***${post}"
  done
  # 5. 40 文字以上の 16 進 / base64 様の語（`/` を含む語はパスと区別できないので対象外）
  while [[ "$s" =~ [A-Za-z0-9+=_-]{40,} ]]; do
    m="${BASH_REMATCH[0]}"; pre="${s%%"$m"*}"; post="${s#*"$m"}"; s="${pre}***${post}"
  done
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

# ---- 入力（§2）----
# stdin の JSON を HOOK_INPUT に読み、共通フィールドを HOOK_* に置く。戻り 1 = 入力不正、2 = jq 不在
hook_read_input() {
  local line raw
  HOOK_INPUT="$(cat 2>/dev/null)" || HOOK_INPUT=""
  [[ -n "$HOOK_INPUT" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 2
  line="$(printf '%s' "$HOOK_INPUT" | jq -r '
    if type != "object" then error("not an object") else . end
    | [ (.session_id // ""), (.transcript_path // ""), (.cwd // ""), (.hook_event_name // ""), (.permission_mode // ""),
        (.tool_name // ""), (.agent_id // ""), (.agent_type // ""), (.prompt_id // ""),
        (.tool_input.command // ""), (.tool_input.file_path // .tool_input.notebook_path // ""), (.tool_input.skill // ""),
        (.tool_input.subagent_type // ""), (.tool_input.model // .model // ""), "end" ]
    | map(tostring | gsub("\u001e"; " ")) | join("\u001e")' 2>/dev/null)" || return 1
  line="${line//$'\r'/}"
  [[ -n "$line" ]] || return 1
  __hc_split_us "$line"
  [[ "${#REPLY_FIELDS[@]}" -ge 15 ]] || return 1
  raw="${REPLY_FIELDS[0]}"
  HOOK_SESSION_ID="${raw//[^A-Za-z0-9_-]/}"; [[ -n "$HOOK_SESSION_ID" ]] || HOOK_SESSION_ID="unknown"
  HOOK_TRANSCRIPT_PATH="${REPLY_FIELDS[1]}"; HOOK_CWD="${REPLY_FIELDS[2]}"; HOOK_EVENT="${REPLY_FIELDS[3]}"
  HOOK_PERMISSION_MODE="${REPLY_FIELDS[4]}"; HOOK_TOOL="${REPLY_FIELDS[5]}"; HOOK_AGENT_ID="${REPLY_FIELDS[6]}"
  HOOK_AGENT_TYPE="${REPLY_FIELDS[7]}"; HOOK_PROMPT_ID="${REPLY_FIELDS[8]}"; HOOK_COMMAND="${REPLY_FIELDS[9]}"
  HOOK_FILE_PATH="${REPLY_FIELDS[10]}"; HOOK_SKILL="${REPLY_FIELDS[11]}"; HOOK_SUBAGENT_TYPE="${REPLY_FIELDS[12]}"
  HOOK_MODEL="${REPLY_FIELDS[13]}"
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
    Skill) case "${2:-}" in 00-workflow-*) printf 'declare\n' ;; *) printf 'read\n' ;; esac ;;
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
  local -a files=("$HOOK_ROOT"/wip/10_tickets/10_doing/*.md)
  (( ng )) || shopt -u nullglob
  HOOK_DOING_COUNT="${#files[@]}"
  REPLY=""
  if (( HOOK_DOING_COUNT > 0 )); then f="${files[0]}"; REPLY="${f##*/}"; fi
  return 0
}

# ---- 記録（§5 decisions.jsonl）----
# hook_record <decision> <id> <target> <note>。書けなくても本体を止めない。target / note は redact を通す
hook_record() {
  local decision="$1" id="${2:-}" target="${3:-}" note="${4:-}" ts ticket line dir
  __hc_now; ts="$REPLY"
  hook_doing_ticket; ticket="$REPLY"
  __hc_redact_to_reply "$target"; __hc_json_str "$REPLY"; target="$REPLY"
  __hc_redact_to_reply "$note"; __hc_json_str "$REPLY"; note="$REPLY"
  __hc_json_str "$HOOK_TOOL"; local tool="$REPLY"
  __hc_json_str "$ticket"; ticket="$REPLY"
  line="{\"ts\":\"$ts\",\"session_id\":\"$HOOK_SESSION_ID\",\"hook\":\"$HOOK_NAME\",\"event\":\"$HOOK_EVENT\",\"decision\":\"$decision\",\"id\":\"$id\",\"tool\":\"$tool\",\"target\":\"$target\",\"ticket\":\"$ticket\",\"note\":\"$note\"}"
  dir="$HOOK_ROOT/logs/hooks"
  { mkdir -p "$dir" && printf '%s\n' "$line" >> "$dir/decisions.jsonl"; } 2>/dev/null || true
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
hook_session_dir() { REPLY="$HOOK_ROOT/logs/sessions/$HOOK_SESSION_ID"; }
hook_session_read() { # $1=ファイル名 → 内容を出力（無ければ何も出さず 1）
  hook_session_dir
  [[ -f "$REPLY/$1" ]] || return 1
  cat "$REPLY/$1" 2>/dev/null
}
hook_session_write() { # $1=ファイル名 $2=内容。tmp → mv -f の原子的置換
  local dir tmp
  hook_session_dir; dir="$REPLY"
  mkdir -p "$dir" 2>/dev/null || return 1
  tmp="$dir/$1.tmp.$$"
  printf '%s\n' "$2" > "$tmp" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  mv -f "$tmp" "$dir/$1" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  return 0
}

# ---- パス正規化（リポジトリルート相対。REPLY に返し、出力もする）----
hook_rel_path() {
  local p="${1:-}" root="$HOOK_ROOT" lr lp
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
