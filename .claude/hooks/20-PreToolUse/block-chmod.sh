#!/usr/bin/env bash
# block-chmod.sh — 禁止コマンド（既定は chmod）の実行を拒否する
# 仕様: .claude/docs/10_spec/hooks/20-PreToolUse/block-chmod.md（判定順・エラー識別子の正）
# 登録: PreToolUse / matcher `Bash|PowerShell`（フック共通仕様 §1 の PreToolUse 4 行目。位置であって実行順ではない）
# 出力: deny（WF501 / WF509）または無出力の許可
set -euo pipefail

# 判定不能で拒否側に倒すときの識別子。読み込み行より前に置く（読み込み行の deny ポリシーが参照する）
HOOK_DENY_ID="WF509"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__bc_dir="${BASH_SOURCE[0]%/*}"
case "$__bc_dir" in /*|[A-Za-z]:/*) ;; *) __bc_dir="$PWD/$__bc_dir" ;; esac
# shellcheck source=/dev/null
. "$__bc_dir/../lib/hook-common.sh"

hook_init block-chmod deny WF509
hook_fail_closed

# 制御方式 1: 停止中なら何もしない（§4）
hook_enforce_enabled || hook_disabled

# 入力（jq 1 回。副入力は要らない）
hook_read_input || hook_fail "入力を読めない"

# 禁止コマンドの一覧（1 行 1 コマンド。`#` はコメント。一覧をコードに埋めない）
_bc_blocked=()
_bc_load_blocked() {
  local f="$HOOK_ROOT/.claude/hooks/config/blocked-commands.txt" line
  _bc_blocked=()
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] && _bc_blocked+=("${line,,}")
  done < "$f"
  return 0
}
_bc_load_blocked

# 一覧が空なら拒否するものが無い
(( ${#_bc_blocked[@]} > 0 )) || hook_allow

# 制御方式 2: 高速前置判定（外部プロセスなし・cmdpos.sh も読まない）。
# 生の文字列だけを見ると `c\hmod` `ch""mod` のようにクォート・エスケープで隠せるので、
# それらを取り除いた複製にも当てる（パラメータ展開 3 回。ここは毎ツール呼び出しで走る）
_bc_lower="${HOOK_COMMAND,,}"
_bc_dequoted="${HOOK_COMMAND//\\/}"
_bc_dequoted="${_bc_dequoted//\"/}"
_bc_dequoted="${_bc_dequoted//\'/}"
_bc_dequoted="${_bc_dequoted,,}"
_bc_hit=0
for _bc_c in "${_bc_blocked[@]}"; do
  if [[ "$_bc_lower" == *"$_bc_c"* || "$_bc_dequoted" == *"$_bc_c"* ]]; then _bc_hit=1; break; fi
done
(( _bc_hit )) || hook_allow

# ここから先だけ cmdpos.sh を読む（前置判定で落ちる大多数は読み込まない）
# shellcheck source=/dev/null
. "$__bc_dir/../lib/cmdpos.sh"

_bc_deny() { # $1=コマンド名 $2=判定不能か
  local name="$1" degraded="$2" msg
  msg="禁止コマンド '$name' の実行"
  (( degraded )) && msg+="（コード文字列・クォートで判定できないため拒否側に倒した）"
  msg+="。実行権限の変更は不要で、スクリプトは 'bash <パス>' で実行する。"
  msg+="権限変更が本当に必要なら、迂回せずユーザーに提案すること"
  hook_deny WF501 "$msg" "$name: ${HOOK_COMMAND:0:120}"
}

# 制御方式 3: 実行位置の実行体（basename）が一覧に一致したら拒否。提供コマンドは対象外
_bc_check_exes() { # 解析済みの CP_* を見て、実行位置が一覧に一致したら拒否（戻らない）
  local i c
  for (( i = 0; i < CP_COUNT; i++ )); do
    [[ -n "${CP_PROVIDED[$i]:-}" ]] && continue
    for c in "${_bc_blocked[@]}"; do
      [[ "${CP_EXE[$i]:-}" == "$c" ]] && _bc_deny "$c" 0
    done
  done
  return 0
}
cmdpos_parse "$HOOK_COMMAND"
_bc_check_exes

# 制御方式 4: 判定不能な位置（opaque / 縮退）で一覧の語が現れたら拒否側に倒す。
#   (a) opaque な段の引数に一覧の語がそのまま出る（`ls | xargs chmod +x`）→ その語で拒否
#   (b) 中身が見えない形（クォートが `_` に潰れている / 実行体が変数 / 解析が縮退）→ コマンド全体を見る
#   コマンド全体を見るのは (b) だけにする。全段で見ると `grep chmod f | xargs echo` のように
#   別の段のデータとして現れただけの語で拒否してしまう（過剰拒否）
_bc_seg_unknown() { # $1=段 → 中身が見えないなら 0
  local i="$1" t
  [[ "${CP_EXE[$i]:-}" == \$* ]] && return 0
  local IFS=$'\x1e'
  for t in ${CP_ARGS[$i]:-}; do [[ "$t" == "_" ]] && return 0; done
  return 1
}
if (( CP_DEGRADED )); then _bc_deny "${_bc_blocked[0]}" 1; fi
for (( _bc_i = 0; _bc_i < CP_COUNT; _bc_i++ )); do
  if [[ "${CP_OPAQUE[$_bc_i]:-0}" == 1 ]]; then
    _bc_seg=" ${CP_EXE[$_bc_i]:-} ${CP_ARGS[$_bc_i]//$'\x1e'/ } "
    for _bc_c in "${_bc_blocked[@]}"; do
      [[ "$_bc_seg" == *" $_bc_c "* ]] && _bc_deny "$_bc_c" 1
    done
  fi
  if [[ "${CP_OPAQUE[$_bc_i]:-0}" == 1 ]] && _bc_seg_unknown "$_bc_i"; then
    for _bc_c in "${_bc_blocked[@]}"; do
      [[ "${CP_LOWER}" == *"$_bc_c"* || "$_bc_dequoted" == *"$_bc_c"* ]] && _bc_deny "$_bc_c" 1
    done
  fi
  :
done

# 制御方式 5: クォート・エスケープを取り除いた形でも実行位置を見る。
#   `ch""mod` は正規化だけでは実行体が chmod にならない（`ch_mod` になる）。
#   取り除いた文字列を別に解析して実行位置だけを照合するので、`echo "chmod"` は exe=echo のまま通る
if [[ "$_bc_dequoted" != "$_bc_lower" ]]; then
  cmdpos_parse "$_bc_dequoted"
  _bc_check_exes
fi

# 制御方式 6: それ以外は許可（記録しない）
hook_allow
