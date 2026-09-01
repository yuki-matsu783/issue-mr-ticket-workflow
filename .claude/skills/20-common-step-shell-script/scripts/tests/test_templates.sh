#!/usr/bin/env bash
# test_templates.sh — script.template.sh / test.template.sh と読み込み行のテスト（仕様のテスト ID: SS-T01〜04）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*templates*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SKILL="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script"
make_tmp_repo
make_tmp_dir
# 一時リポジトリに共通ライブラリを置く（読み込み行が解決する先）
mkdir -p "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts"
cp "$SKILL/scripts/logger.sh" "$SKILL/scripts/test-lib.sh" "$SKILL/scripts/frontmatter.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"

# 雛形をコピーして {{名前}} を埋める: fill_script <出力先> <NAME>
fill_script() {
  mkdir -p "$(dirname "$1")"
  sed -e "s|{{NAME}}|$2|g; s|{{PURPOSE}}|テスト用|g; s|{{SPEC_PATH}}|spec.md|g; s|{{INVOKE_PATH}}|$1|g; s|{{PREFIX}}|XX|g; s|{{SUBCOMMANDS}}|run|g; s|{{OPTIONS}}|なし|g; s|{{ARG_ERROR_NO}}|001|g" \
    "$SKILL/assets/script.template.sh" > "$1"
}

cd "$TMP_REPO" || exit 2

# SS-T01 雛形からコピーした sh が bash -n を通り、logger を source して結果出力の型で終了する
fill_script ".claude/skills/x/scripts/x.sh" x
run_cmd bash -n .claude/skills/x/scripts/x.sh
assert_exit "SS-T01" 0
run_cmd bash .claude/skills/x/scripts/x.sh
assert_exit "SS-T01" 0
assert_eq "SS-T01" "OK: x 実行" "${R_OUT##*$'\n'}"
if grep -q 'OK: x 実行' logs/sh/x.log 2>/dev/null; then pass "SS-T01"; else fail "SS-T01" "logs/sh/x.log に OK 行が無い"; fi
run_cmd bash .claude/skills/x/scripts/x.sh --bogus
assert_exit "SS-T01" 2
assert_eq "SS-T01" "XX001: 不明なオプション: --bogus" "${R_OUT##*$'\n'}"
if grep -q '{{' .claude/skills/x/scripts/x.sh; then fail "SS-T01" "プレースホルダが残っている"; else pass "SS-T01"; fi

# SS-T02 テスト雛形が失敗ケースを検出して非 0 で終了する
fill_test() { # $1=出力先 $2=FIRST_ARGS
  mkdir -p "$(dirname "$1")"
  sed -e "s|{{NAME}}|x|g; s|{{TARGET}}|x.sh|g; s|{{TEST_IDS}}|SS-T00|g; s|{{TARGET_PATH}}|.claude/skills/x/scripts/x.sh|g; s|{{FIRST_ID_FUNC}}|ss_t00|g; s|{{FIRST_ID}}|SS-T00|g; s|{{FIRST_ARGS}}|$2|g" \
    "$SKILL/assets/test.template.sh" > "$1"
}
fill_test ".claude/skills/x/scripts/tests/test_x.sh" "--bogus"
run_cmd bash .claude/skills/x/scripts/tests/test_x.sh
assert_exit "SS-T02" 1
assert_contains "SS-T02" "FAIL SS-T00"
assert_contains "SS-T02" "failures=2"
fill_test ".claude/skills/x/scripts/tests/test_x.sh" ""
run_cmd bash .claude/skills/x/scripts/tests/test_x.sh
assert_exit "SS-T02" 0
assert_contains "SS-T02" "PASS SS-T00"

# SS-T03 読み込み行が 4 通りの深さから logger を解決する（git 無し・CLAUDE_PROJECT_DIR 無しの経路）。ログの出どころは $0 の basename
make_restricted_path bash mkdir cat sed
fill_script ".claude/skills/x/scripts/a.sh" depth-a
fill_script ".claude/hooks/20-PreToolUse/b.sh" depth-b
fill_script ".claude/skills/x/scripts/tests/c.sh" depth-c
fill_script ".claude/hooks/20-PreToolUse/tests/d.sh" depth-d
nogit() { # $1=スクリプトのパス（相対 or 絶対） — git 不在・CLAUDE_PROJECT_DIR 未設定で実行
  run_cmd bash -c 'unset CLAUDE_PROJECT_DIR LOGGER_ROOT; export PATH="$1"; exec bash "$2"' _ "$RESTRICTED_PATH" "$1"
}
for pair in ".claude/skills/x/scripts/a.sh:a" ".claude/hooks/20-PreToolUse/b.sh:b" ".claude/skills/x/scripts/tests/c.sh:c" ".claude/hooks/20-PreToolUse/tests/d.sh:d"; do
  p="${pair%%:*}"; nm="${pair##*:}"
  nogit "$p"
  assert_exit "SS-T03" 0
  if [ -f "logs/sh/$nm.log" ]; then pass "SS-T03"; else fail "SS-T03" "$p: logs/sh/$nm.log が無い（stderr: $R_ERR）"; fi
done
# 別の cwd から絶対パスで起動しても、スクリプトの場所からルートを解決する
rm -f logs/sh/b.log
cd "$TMP_DIR" || exit 2
nogit "$TMP_REPO/.claude/hooks/20-PreToolUse/b.sh"
assert_exit "SS-T03" 0
if [ -f "$TMP_REPO/logs/sh/b.log" ]; then pass "SS-T03"; else fail "SS-T03" "絶対パス起動で $TMP_REPO/logs/sh/b.log が無い"; fi
cd "$TMP_REPO" || exit 2

# SS-T04 git 不在・リポジトリ外・CLAUDE_PROJECT_DIR 未設定でも読み込み行が失敗せず、logger が no-op になって本体が続行する
mkdir -p "$TMP_DIR/standalone"
fill_script "$TMP_DIR/standalone/z.sh" z
cd "$TMP_DIR/standalone" || exit 2
nogit "z.sh"
assert_exit "SS-T04" 0
assert_eq "SS-T04" "OK: z 実行" "${R_OUT##*$'\n'}"
assert_eq "SS-T04" "" "$R_ERR"
if [ -d "$TMP_DIR/standalone/logs" ] || [ -d "$TMP_DIR/logs" ]; then fail "SS-T04" "リポジトリ外に logs/ が作られた"; else pass "SS-T04"; fi
cd "$TMP_REPO" || exit 2

finish
