#!/usr/bin/env bash
# test_commit.sh — commit.sh のテスト（仕様のテスト ID: CP-T01〜04）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_commit*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

REAL="$LOGGER_ROOT/.claude/skills"
make_tmp_repo
cd "$TMP_REPO" || exit 2
# 提供コマンドは自分の置き場のリポジトリに作用するため、一時リポジトリへコピーして実行する
mkdir -p .claude/skills/20-common-step-shell-script/scripts .claude/skills/20-common-step-commit-push/scripts .claude/skills/20-common-step-commit-push/assets
cp "$REAL"/20-common-step-shell-script/scripts/*.sh .claude/skills/20-common-step-shell-script/scripts/
cp "$REAL"/20-common-step-commit-push/scripts/commit.sh .claude/skills/20-common-step-commit-push/scripts/
cp "$REAL"/20-common-step-commit-push/assets/exclude-patterns.txt .claude/skills/20-common-step-commit-push/assets/
COMMIT=".claude/skills/20-common-step-commit-push/scripts/commit.sh"
echo "# t" > README.md
git add -A && git commit -q -m "chore: init"
count_commits() { git rev-list --count HEAD; }

# CP-T01 対象指定コミットと SHA・一覧の出力（オプションは順不同）
echo a > a.txt; echo b > b.txt; echo c > c.txt
run_cmd bash "$COMMIT" -m "docs: a と b を追加" a.txt b.txt
assert_exit "CP-T01" 0
sha="$(git rev-parse --short HEAD)"
assert_eq "CP-T01" "OK: 2 ファイルをコミットした（${sha}）。除外: なし" "${R_OUT##*$'\n'}"
assert_contains "CP-T01" "A	a.txt"
assert_eq "CP-T01" "docs: a と b を追加" "$(git log -1 --pretty=%s)"
if git status --porcelain | grep -q 'c.txt'; then pass "CP-T01"; else fail "CP-T01" "指定外の c.txt がコミットされた"; fi
run_cmd bash "$COMMIT" c.txt -m "chore: c を追加"
assert_exit "CP-T01" 0
assert_contains "CP-T01" "OK: 1 ファイルをコミットした"

# CP-T02 フッター入り・規約違反・複数行のメッセージが CP002（何もコミットされない）
before="$(count_commits)"
echo d > d.txt
run_cmd bash "$COMMIT" -m "$(printf 'feat: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>')" d.txt
assert_exit "CP-T02" 1
assert_contains "CP-T02" "CP002:"
run_cmd bash "$COMMIT" -m "docs: 🤖 Generated with Claude Code" d.txt
assert_exit "CP-T02" 1
assert_contains "CP-T02" "CP002:"
run_cmd bash "$COMMIT" -m "update stuff" d.txt
assert_exit "CP-T02" 1
assert_contains "CP-T02" "CP002:"
run_cmd bash "$COMMIT" -m "docs:改行なし区切り" d.txt
assert_exit "CP-T02" 1
run_cmd bash "$COMMIT" d.txt
assert_exit "CP-T02" 1
assert_contains "CP-T02" "CP002:"
assert_eq "CP-T02" "$before" "$(count_commits)"
# 本文の語としての Claude Code は拒否しない
run_cmd bash "$COMMIT" -m "docs: Claude Code のフック登録手順を追記" d.txt
assert_exit "CP-T02" 0

# CP-T03 除外パターン一致が除外一覧に出て残りがコミットされる
echo e > e.txt; echo s > .env; mkdir -p conf; echo t > conf/api-token.txt
run_cmd bash "$COMMIT" -m "feat: e を追加" e.txt .env conf/api-token.txt
assert_exit "CP-T03" 0
assert_contains "CP-T03" "除外: .env（.env）,conf/api-token.txt（*token*）"
assert_contains "CP-T03" "OK: 1 ファイルをコミットした"
if git show --pretty=format: --name-only HEAD | grep -q '\.env\|token'; then fail "CP-T03" "除外対象がコミットされた"; else pass "CP-T03"; fi

# CP-T04 全除外が CP003、差分なしが CP004、対象未指定・一括指定・glob が CP001、--allow-empty の空コミット
run_cmd bash "$COMMIT" -m "chore: 秘密" .env
assert_exit "CP-T04" 1
assert_contains "CP-T04" "CP003:"
run_cmd bash "$COMMIT" -m "chore: 変更なし" e.txt
assert_exit "CP-T04" 1
assert_contains "CP-T04" "CP004:"
run_cmd bash "$COMMIT" -m "chore: なし"
assert_exit "CP-T04" 2
assert_contains "CP-T04" "CP001:"
run_cmd bash "$COMMIT" -m "chore: 一括" .
assert_exit "CP-T04" 2
assert_contains "CP-T04" "CP001:"
run_cmd bash "$COMMIT" -m "chore: 一括" -A
assert_exit "CP-T04" 2
run_cmd bash "$COMMIT" -m "chore: glob" '*.txt'
assert_exit "CP-T04" 2
assert_contains "CP-T04" "CP001:"
run_cmd bash "$COMMIT" -m "chore: amend" --amend e.txt
assert_exit "CP-T04" 2
run_cmd bash "$COMMIT" -m "chore: 存在しない" nosuch.txt
assert_exit "CP-T04" 2
assert_contains "CP-T04" "CP001:"
before="$(count_commits)"
run_cmd bash "$COMMIT" --allow-empty -m "chore: start #1 x"
assert_exit "CP-T04" 0
assert_contains "CP-T04" "OK: 0 ファイルをコミットした"
assert_eq "CP-T04" "$((before + 1))" "$(count_commits)"

finish
