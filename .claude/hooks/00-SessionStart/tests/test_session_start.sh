#!/usr/bin/env bash
# test_session_start.sh — session-start.sh のテスト（仕様のテスト ID: SE-T05 後半 / SE-T06 後半）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*session_start*'
#
# SE-T01〜T04・T05 前半・T06 前半・T07〜T09 は boundary.sh（3/3・issue #10）に依存するのでここでは書かない
# （偽実装で代えると「本物と一致するか」という観点そのものが失われる。DDR i0009-09）。
# テストは set -e を使わない（終了コードは hook_run が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SRC="$LOGGER_ROOT/.claude/hooks"
SKILL_SCRIPTS="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/00-SessionStart" "$TMP_REPO/.claude/hooks/lib" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts"
cp "$SRC/00-SessionStart/session-start.sh" "$TMP_REPO/.claude/hooks/00-SessionStart/"
cp "$SRC/lib/hook-common.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$SKILL_SCRIPTS/logger.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"
TMP_HOOK="$TMP_REPO/.claude/hooks/00-SessionStart/session-start.sh"

mk_payload() { # $1=source $2=agent_id
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc --arg src "$1" --arg aid "$2" --arg cwd "$TMP_REPO" '
    {hook_event_name: "SessionStart", session_id: "testsession", cwd: $cwd, source: $src, tool_input: {}}
    | (if $aid != "" then .agent_id = $aid else . end)' | tr -d '\r'
}

hook_run() { # $1=source $2=agent_id [$3..=env]
  R_ERR=""
  R_OUT="$(mk_payload "$1" "$2" | env "${@:3}" bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  return 0
}

# ---- SE-T05 後半: jq が無ければ無出力・終了 0 ----
case_no_jq() {
  # jq 不在では hook_read_input が 2 を返し、案内側なので何も出さずに終了 0（hook_fail）
  make_restricted_path bash cat find rm mkdir mv printf
  R_ERR=""
  R_OUT="$(mk_payload startup "" | env PATH="$RESTRICTED_PATH" bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  assert_eq "SE-T05" "" "$R_OUT"
  assert_exit "SE-T05" 0
}

# ---- SE-T06 後半: サブエージェントの開始では何も注入しない ----
case_subagent() {
  rm -rf "$TMP_REPO/logs"
  hook_run startup agent1
  assert_eq "SE-T06" "" "$R_OUT"
  assert_exit "SE-T06" 0
  # 環境変数 CLAUDE_AGENT_ID でも同じ
  hook_run startup "" CLAUDE_AGENT_ID=agent2
  assert_eq "SE-T06" "" "$R_OUT"
  assert_exit "SE-T06" 0
  # メインのセッションでは（boundary.sh が無いので）無出力だが、skip の記録が残る
  hook_run startup ""
  assert_eq "SE-T06" "" "$R_OUT"
  assert_exit "SE-T06" 0
  if [[ -f "$TMP_REPO/logs/hooks/decisions.jsonl" ]]; then pass "SE-T06"; else fail "SE-T06" "記録が残っていない"; fi
}

# ---- 停止中（この issue で実装した範囲）----
case_enforce() {
  rm -rf "$TMP_REPO/logs"
  hook_run startup "" WORKFLOW_ENFORCE=0
  assert_contains "SE-T05" "WF701"
  assert_contains "SE-T05" "機構は停止中"
  assert_exit "SE-T05" 0

  hook_run startup "" WORKFLOW_SESSION_START_ENFORCE=0
  assert_contains "SE-T05" "WF701"

  # プローブは既定では副作用ゼロ
}

# ---- SE-T06 前半: source=compact でも startup と同じ内容 ----
case_compact() {
  rm -rf "$TMP_REPO/logs"
  hook_run compact ""
  assert_eq "SE-T06" "" "$R_OUT"
  assert_exit "SE-T06" 0
  if [[ -f "$TMP_REPO/logs/hooks/decisions.jsonl" ]]; then pass "SE-T06"; else fail "SE-T06" "compact で記録が残っていない"; fi
}

case_no_jq
case_subagent
case_enforce
case_compact
finish
