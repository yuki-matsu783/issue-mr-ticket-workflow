#!/usr/bin/env bash
# test_run_tests.sh — run-tests.sh のテスト（仕様のテスト ID: TR-T01〜05）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*run_tests*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SKILL="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script"
make_tmp_repo
cd "$TMP_REPO" || exit 2
mkdir -p .claude/skills/20-common-step-shell-script/scripts wip/10_tickets/00_todo wip/10_tickets/10_doing wip/10_tickets/20_done
cp "$SKILL"/scripts/*.sh .claude/skills/20-common-step-shell-script/scripts/
RUNNER=".claude/skills/20-common-step-shell-script/scripts/run-tests.sh"

# 偽テストを置く: fake <path> <本文...>
fake() { local p="$1"; shift; mkdir -p "$(dirname "$p")"; printf '#!/usr/bin/env bash\n%s\n' "$*" > "$p"; }
fake ".claude/hooks/lib/tests/test_ok1.sh" 'echo "PASS AA-T01"; echo "passed=1 failures=0"; exit 0'
fake ".claude/skills/foo/scripts/tests/test_ok2.sh" 'echo "PASS BB-T01"; echo "PASS BB-T02"; echo "passed=2 failures=0"; exit 0'

# 作業中チケットを置く: doing_ticket <ops の JSON 配列文字列 or ->（- で削除）
doing_ticket() {
  rm -f wip/10_tickets/10_doing/*.md
  [ "$1" = "-" ] && return 0
  printf -- '---\ntype: ticket\nticket_type: ai-asset-implementation\npredecessors: []\nallow:\n  write: [".claude/**"]\n  ops: %s\n---\n# t\n' "$1" > wip/10_tickets/10_doing/0001-ai-asset-implementation.md
}

# TR-T01 2 つの置き場を列挙し、全 PASS で OK と ID 数
run_cmd bash "$RUNNER"
assert_exit "TR-T01" 0
assert_eq "TR-T01" "OK: 2 本 / 3 件" "${R_OUT##*$'\n'}"
assert_contains "TR-T01" ".claude/hooks/lib/tests/test_ok1.sh | PASS"
assert_contains "TR-T01" ".claude/skills/foo/scripts/tests/test_ok2.sh | PASS"

# TR-T02 FAIL を含むテストで TR002 とファイル・ID の列挙、非 0
fake ".claude/skills/foo/scripts/tests/test_bad.sh" 'echo "PASS CC-T01"; echo "FAIL CC-T02: boom"; echo "passed=1 failures=1"; exit 1'
run_cmd bash "$RUNNER"
assert_exit "TR-T02" 1
assert_contains "TR-T02" "TR002:"
assert_contains "TR-T02" "test_bad.sh"
assert_contains "TR-T02" "CC-T02"
# 終了コード 0 でも FAIL 行があれば FAIL
fake ".claude/skills/foo/scripts/tests/test_bad.sh" 'echo "FAIL CC-T03: silent"; exit 0'
run_cmd bash "$RUNNER"
assert_exit "TR-T02" 1
assert_contains "TR-T02" "CC-T03"
rm -f .claude/skills/foo/scripts/tests/test_bad.sh

# TR-T03 無限ループするテストが TR003 で止まる
fake ".claude/hooks/lib/tests/test_loop.sh" 'while :; do sleep 1; done'
run_cmd bash "$RUNNER" --timeout 1
assert_exit "TR-T03" 1
assert_contains "TR-T03" "TR003:"
assert_contains "TR-T03" "test_loop.sh"
rm -f .claude/hooks/lib/tests/test_loop.sh

# TR-T04 --filter の絞り込みと 0 本のときの TR001、--ids の一覧と重複 ID の報告、引数不正 TR004
run_cmd bash "$RUNNER" --filter '*foo*'
assert_exit "TR-T04" 0
assert_eq "TR-T04" "OK: 1 本 / 2 件" "${R_OUT##*$'\n'}"
run_cmd bash "$RUNNER" --filter '*nomatch*'
assert_exit "TR-T04" 1
assert_contains "TR-T04" "TR001:"
run_cmd bash "$RUNNER" --ids
assert_exit "TR-T04" 0
assert_contains "TR-T04" "PASS ID: AA-T01 BB-T01 BB-T02"
assert_contains "TR-T04" "重複 ID: なし"
fake ".claude/skills/foo/scripts/tests/test_dup.sh" 'echo "PASS AA-T01"; exit 0'
run_cmd bash "$RUNNER" --ids
assert_exit "TR-T04" 0
assert_contains "TR-T04" "AA-T01 (.claude/hooks/lib/tests/test_ok1.sh, .claude/skills/foo/scripts/tests/test_dup.sh)"
rm -f .claude/skills/foo/scripts/tests/test_dup.sh
run_cmd bash "$RUNNER" --bogus
assert_exit "TR-T04" 2
assert_contains "TR-T04" "TR004:"
run_cmd bash "$RUNNER" --timeout abc
assert_exit "TR-T04" 2
assert_contains "TR-T04" "TR004:"
# timeout コマンド不在は環境の不備 TR005・終了 2（引数の誤り TR004 と区別する）。bash / jq は残す
make_restricted_path bash sh jq cat sed grep awk sort uniq wc tr find mkdir rm date basename dirname head tail cut comm env
run_cmd bash -c 'export PATH="$1"; exec bash "$2"' _ "$RESTRICTED_PATH" "$RUNNER"
assert_exit "TR-T04" 2
assert_eq "TR-T04" "TR005" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
assert_contains "TR-T04" "timeout"
assert_not_contains "TR-T04" "TR004"
assert_not_contains "TR-T04" "| PASS |"

# TR-T05 allow.ops に build-test の無い作業中チケットがあるときは TR006 で実行しない。作業中チケットが無ければ実行する
doing_ticket '["read"]'
run_cmd bash "$RUNNER"
assert_exit "TR-T05" 1
assert_contains "TR-T05" "TR006:"
assert_contains "TR-T05" "build-test"
assert_not_contains "TR-T05" "| PASS |"
doing_ticket '["read", "build-test"]'
run_cmd bash "$RUNNER"
assert_exit "TR-T05" 1
assert_contains "TR-T05" "TR006:"
assert_contains "TR-T05" "hook-test"
run_cmd bash "$RUNNER" --filter '*skills*'
assert_exit "TR-T05" 0
doing_ticket '["read", "build-test", "hook-test"]'
run_cmd bash "$RUNNER"
assert_exit "TR-T05" 0
doing_ticket -
run_cmd bash "$RUNNER"
assert_exit "TR-T05" 0

finish
