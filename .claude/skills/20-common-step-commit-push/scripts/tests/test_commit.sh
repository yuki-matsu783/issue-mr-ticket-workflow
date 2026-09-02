#!/usr/bin/env bash
# test_commit.sh — commit.sh のテスト（仕様のテスト ID: CP-T01〜04）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_commit*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
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
# ディレクトリ（末尾 / 付き・symlink 経由を含む）は CP001。除外パターンはファイル単位でしか当たらないので、中の .env がすり抜けない
before="$(count_commits)"
mkdir -p src; echo t > src/.env; echo a > src/a.ts
run_cmd bash "$COMMIT" -m "feat: ディレクトリを指定" src
assert_exit "CP-T03" 2
assert_contains "CP-T03" "CP001:"
assert_contains "CP-T03" "ディレクトリ"
run_cmd bash "$COMMIT" -m "feat: ディレクトリを指定" src/
assert_exit "CP-T03" 2
if ln -s src linkdir 2>/dev/null && [ -d linkdir ]; then
  run_cmd bash "$COMMIT" -m "feat: symlink を指定" linkdir
  assert_exit "CP-T03" 2
fi
rm -rf linkdir
assert_eq "CP-T03" "$before" "$(count_commits)"
if git ls-files --error-unmatch src/.env >/dev/null 2>&1; then fail "CP-T03" "src/.env がコミットされた"; else pass "CP-T03"; fi
# ファイル単位で渡せば .env は除外され a.ts だけがコミットされる
run_cmd bash "$COMMIT" -m "feat: src のファイルを指定" src/a.ts src/.env
assert_exit "CP-T03" 0
assert_contains "CP-T03" "除外: src/.env（.env）"
assert_contains "CP-T03" "OK: 1 ファイルをコミットした"

# CP-T04 全除外が CP003、差分なしが CP004、--allow-empty の空コミット
# （対象未指定・一括指定・glob・存在しないパスの CP001 は仕様が CP-T03 に置くので、この節でも ID は CP-T03）
run_cmd bash "$COMMIT" -m "chore: 秘密" .env
assert_exit "CP-T04" 1
assert_contains "CP-T04" "CP003:"
run_cmd bash "$COMMIT" -m "chore: 変更なし" e.txt
assert_exit "CP-T04" 1
assert_contains "CP-T04" "CP004:"
run_cmd bash "$COMMIT" -m "chore: なし"
assert_exit "CP-T03" 2
assert_eq "CP-T03" "CP001" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
run_cmd bash "$COMMIT" -m "chore: 一括" .
assert_exit "CP-T03" 2
assert_eq "CP-T03" "CP001" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
run_cmd bash "$COMMIT" -m "chore: 一括" -A
assert_exit "CP-T03" 2
run_cmd bash "$COMMIT" -m "chore: glob" '*.txt'
assert_exit "CP-T03" 2
assert_eq "CP-T03" "CP001" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
run_cmd bash "$COMMIT" -m "chore: amend" --amend e.txt
assert_exit "CP-T08" 2   # 存在しないオプションは引数の誤り（CP007）
assert_contains "CP-T08" "CP007:"
run_cmd bash "$COMMIT" -m "chore: 存在しない" nosuch.txt
assert_exit "CP-T03" 2
assert_eq "CP-T03" "CP001" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
before="$(count_commits)"
run_cmd bash "$COMMIT" --allow-empty -m "chore: start #1 x"
assert_exit "CP-T04" 0
assert_contains "CP-T04" "OK: 0 ファイルをコミットした"
assert_eq "CP-T04" "$((before + 1))" "$(count_commits)"
# CP-T08 引数・環境の誤りは CP007（終了 2）、git commit 自体の失敗は CP008（終了 1・git の出力を透過）
echo g > g.txt
run_cmd bash "$COMMIT" g.txt -m
assert_exit "CP-T08" 2
assert_eq "CP-T08" "CP007" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
run_cmd bash "$COMMIT" -m "chore: 不明" --foo g.txt
assert_exit "CP-T08" 2
assert_contains "CP-T08" "CP007:"
# 対象の指定の誤り（未指定・一括・ディレクトリ・ステージ不可）は CP001 のまま（負のケースの正の期待値）
run_cmd bash "$COMMIT" -m "chore: なし"
assert_eq "CP-T08" "CP001" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
before="$(count_commits)"
printf '#!/bin/sh\necho "pre-commit: blocked" >&2\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
run_cmd bash "$COMMIT" -m "chore: フックで止まる" g.txt
assert_exit "CP-T08" 1
assert_eq "CP-T08" "CP008" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
assert_contains "CP-T08" "pre-commit: blocked"
assert_eq "CP-T08" "$before" "$(count_commits)"
rm -f .git/hooks/pre-commit
git reset -q -- g.txt

# 読み込み行の nop: logger.sh が無くても LOGGER_ROOT が決まり、契約どおり OK: / CP<番号>: で終わる（コミット経路のロックアウト対策）
mv .claude/skills/20-common-step-shell-script/scripts/logger.sh logger.sh.bak
run_cmd env -u CLAUDE_PROJECT_DIR -u LOGGER_ROOT bash "$COMMIT" -m "docs: logger 不在でもコミットできる" g.txt
assert_exit "CP-T01" 0
assert_exit "CP-T08" 0   # logger を退避しても最終行の契約が守られる
assert_eq "CP-T08" "OK" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"   # 最終行の型（規約: exact に固定する）
assert_eq "CP-T08" "" "$R_ERR"
assert_contains "CP-T01" "OK: 1 ファイルをコミットした"
echo h > h.txt
run_cmd env -u CLAUDE_PROJECT_DIR -u LOGGER_ROOT bash "$COMMIT" -m "bad subject" h.txt
assert_exit "CP-T01" 1
assert_contains "CP-T01" "CP002:"
assert_eq "CP-T01" "" "$R_ERR"
assert_eq "CP-T08" "CP002" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"   # 失敗側も logger 不在で最終行の型が守られる
mv logger.sh.bak .claude/skills/20-common-step-shell-script/scripts/logger.sh

finish
