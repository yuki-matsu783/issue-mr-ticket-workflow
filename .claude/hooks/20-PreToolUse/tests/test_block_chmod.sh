#!/usr/bin/env bash
# test_block_chmod.sh — block-chmod.sh のテスト（仕様のテスト ID: BC-T01〜BC-T06）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*block_chmod*'
# テストは set -e を使わない（終了コードは run_cmd が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

HOOK="$LOGGER_ROOT/.claude/hooks/20-PreToolUse/block-chmod.sh"
CFG_DIR="$LOGGER_ROOT/.claude/hooks/config"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/config" "$TMP_REPO/.claude/hooks/20-PreToolUse" "$TMP_REPO/.claude/hooks/lib" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts"
cp "$HOOK" "$TMP_REPO/.claude/hooks/20-PreToolUse/"
cp "$LOGGER_ROOT/.claude/hooks/lib/hook-common.sh" "$LOGGER_ROOT/.claude/hooks/lib/cmdpos.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts/logger.sh" \
   "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/" 2>/dev/null || true
cp "$CFG_DIR/blocked-commands.txt" "$TMP_REPO/.claude/hooks/config/"
TMP_HOOK="$TMP_REPO/.claude/hooks/20-PreToolUse/block-chmod.sh"

# 判定を 1 語にする: WF501 / WF509 / allow
judge() { # $1=コマンド文字列
  local out
  out="$(hook_payload PreToolUse Bash command="$1" | bash "$TMP_HOOK" 2>/dev/null)" || true
  case "$out" in
    *WF501*) printf 'WF501\n' ;;
    *WF509*) printf 'WF509\n' ;;
    "")      printf 'allow\n' ;;
    *)       printf 'other:%s\n' "$out" ;;
  esac
}

# ---- BC-T01: 複合・ラッパー・パス付きの chmod を拒否する ----
case_block() {
  assert_eq "BC-T01" "WF501" "$(judge 'chmod +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge 'ls && chmod +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge 'sudo chmod 755 a')"
  assert_eq "BC-T01" "WF501" "$(judge '/usr/bin/chmod +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'cd x; chmod 644 y')"
  assert_eq "BC-T01" "WF501" "$(judge 'env FOO=1 chmod +x a')"
}

# ---- BC-T02: クォート・検索語・地の文の chmod は通る ----
case_pass() {
  assert_eq "BC-T02" "allow" "$(judge 'grep chmod README.md')"
  assert_eq "BC-T02" "allow" "$(judge 'echo "chmod"')"
  assert_eq "BC-T02" "allow" "$(judge "grep -n 'chmod' .claude/docs/x.md")"
  assert_eq "BC-T02" "allow" "$(judge 'ls -la')"
}

# ---- BC-T03: bash -c / xargs 経由でも拒否する ----
case_wrapper() {
  assert_eq "BC-T03" "WF501" "$(judge 'bash -c "chmod +x a"')"
  assert_eq "BC-T03" "WF501" "$(judge 'ls | xargs chmod +x')"
}

# ---- BC-T04: 一覧に足すと拒否され、外すと通る（一覧をコードに埋めていない） ----
case_list() {
  local f="$TMP_REPO/.claude/hooks/config/blocked-commands.txt"
  assert_eq "BC-T04" "allow" "$(judge 'chown user a')"
  printf '# c\nchmod\nchown\n' > "$f"
  assert_eq "BC-T04" "WF501" "$(judge 'chown user a')"
  assert_eq "BC-T04" "WF501" "$(judge 'chmod +x a')"
  printf '# c\nchown\n' > "$f"
  assert_eq "BC-T04" "allow" "$(judge 'chmod +x a')"
  assert_eq "BC-T04" "WF501" "$(judge 'chown user a')"
  # 空の一覧なら何も拒否しない
  printf '# コメントだけ\n\n' > "$f"
  assert_eq "BC-T04" "allow" "$(judge 'chmod +x a')"
  printf '# c\nchmod\n' > "$f"
}

# ---- BC-T05: 一覧の語を含まないコマンドは cmdpos.sh を呼ばずに通る（高速前置判定） ----
case_fastpath() {
  # cmdpos.sh を壊しても、一覧の語を含まないコマンドは通る（= 読み込み前に判定している）
  local bak="$TMP_REPO/.claude/hooks/lib/cmdpos.sh.bak"
  cp "$TMP_REPO/.claude/hooks/lib/cmdpos.sh" "$bak"
  assert_eq "BC-T05" "allow" "$(judge 'ls -la')"
  assert_eq "BC-T05" "allow" "$(judge 'git status')"
  cp "$bak" "$TMP_REPO/.claude/hooks/lib/cmdpos.sh"
  # 前置判定は大文字小文字を問わない
  assert_eq "BC-T05" "WF501" "$(judge 'CHMOD +x a')"
}

# ---- BC-T06: 入力不正で WF509 ----
case_bad_input() {
  local out
  out="$(printf '%s' 'not json' | bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_contains_out() { [[ "$out" == *"$1"* ]] && pass "BC-T06" || fail "BC-T06" "出力に '$1' が無い: $out"; }
  assert_contains_out "WF509"
  assert_contains_out '"permissionDecision":"deny"'
  out="$(printf '%s' '' | bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_contains_out "WF509"
}

# ---- 付随: 緊急停止（§4）では何も出さない ----
case_enforce() {
  local out
  out="$(hook_payload PreToolUse Bash command='chmod +x a' | WORKFLOW_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "BC-T01" "" "$out"
  out="$(hook_payload PreToolUse Bash command='chmod +x a' | WORKFLOW_BLOCK_CHMOD_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "BC-T01" "" "$out"
}

# ---- 付随: 拒否は decisions.jsonl に残り、許可は残らない ----
case_record() {
  local dec="$TMP_REPO/logs/hooks/decisions.jsonl" n1 n2
  rm -f "$dec"
  judge 'ls -la' > /dev/null
  n1=$([[ -f "$dec" ]] && wc -l < "$dec" || echo 0)
  judge 'chmod +x a' > /dev/null
  n2=$([[ -f "$dec" ]] && wc -l < "$dec" || echo 0)
  assert_eq "BC-T01" "0" "${n1// /}"
  assert_eq "BC-T01" "1" "${n2// /}"
  local body; body="$(cat "$dec")"
  [[ "$body" == *WF501* ]] && pass "BC-T01" || fail "BC-T01" "decisions.jsonl に WF501 が無い"
}

case_block
case_pass
case_wrapper
case_list
case_fastpath
case_bad_input
case_enforce
case_record
finish
