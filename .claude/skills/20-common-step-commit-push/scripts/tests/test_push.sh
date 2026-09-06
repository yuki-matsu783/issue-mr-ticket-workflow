#!/usr/bin/env bash
# test_push.sh — push.sh のテスト（仕様のテスト ID: CP-T05〜07・CP-T11）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_push*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

REAL="$LOGGER_ROOT/.claude/skills"
make_tmp_dir
REMOTE="$TMP_DIR/remote.git"
git init -q --bare -b main "$REMOTE"
make_tmp_repo
cd "$TMP_REPO" || exit 2
mkdir -p .claude/skills/20-common-step-shell-script/scripts .claude/skills/20-common-step-commit-push/scripts .claude/skills/20-common-step-commit-push/assets
cp "$REAL"/20-common-step-shell-script/scripts/*.sh .claude/skills/20-common-step-shell-script/scripts/
cp "$REAL"/20-common-step-commit-push/scripts/*.sh .claude/skills/20-common-step-commit-push/scripts/
cp "$REAL"/20-common-step-commit-push/assets/exclude-patterns.txt .claude/skills/20-common-step-commit-push/assets/
PUSH=".claude/skills/20-common-step-commit-push/scripts/push.sh"
git remote add origin "$REMOTE"
mkdir -p wip/10_tickets/00_todo wip/10_tickets/10_doing wip/10_tickets/20_done wip/30_reports wip/20_plans logs
printf '%s\n' "logs/" > .gitignore
touch wip/10_tickets/00_todo/.gitkeep wip/10_tickets/10_doing/.gitkeep wip/10_tickets/20_done/.gitkeep wip/30_reports/.gitkeep wip/20_plans/.gitkeep
git add -A && git commit -q -m "chore: init"
commit_all() { git add -A && git commit -q -m "${1:-chore: t}"; }
ticket() { # $1=ops JSON
  printf -- '---\ntype: ticket\nticket_type: investigation\npredecessors: []\nallow:\n  write: ["wip/**"]\n  ops: %s\n---\n# t\n' "$1" > wip/10_tickets/10_doing/0001-investigation.md
}

# 初回 push（上流未設定 → --set-upstream）
run_cmd bash "$PUSH"
assert_exit "CP-T05" 0
assert_contains "CP-T05" "OK: push した（main、1 コミット）。スキップ: なし"
assert_eq "CP-T05" "origin/main" "$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}')"

# CP-T05 未充足が全件列挙される（1 未コミット / 2 作業中 / 3 対の不揃い / 4 draft 解除後の wip）
echo x > dirty.txt
ticket '["read"]'
echo "# r" > wip/30_reports/0003-investigation.md
echo "# a" > wip/30_reports/0003-investigation-appendix-A.md
echo "# p" > wip/20_plans/0002-investigation-plan.md
echo "<p>" > wip/20_plans/0002-investigation-plan.html
echo "<p>" > wip/20_plans/0009-orphan.html
printf '{"state":"ready"}\n' > logs/merge-state.json
run_cmd bash "$PUSH"
assert_exit "CP-T05" 1
assert_contains "CP-T05" "CP005:"
assert_contains "CP-T05" "項目 1: 未コミットの変更が"
assert_contains "CP-T05" "項目 2: 作業中のチケットがある（0001-investigation.md）"
assert_contains "CP-T05" "0003-investigation.md に .html が無い"
assert_contains "CP-T05" "0009-orphan.html に .md が無い"
assert_not_contains "CP-T05" "appendix-A.md に .html が無い"
assert_contains "CP-T05" "項目 4: draft 解除後"
assert_contains "CP-T05" "未充足 4 件"
assert_eq "CP-T05" "1" "$(git -C "$REMOTE" rev-list --count main)"
# 引数は受け付けない（引数の誤りは CP007・終了 2）
run_cmd bash "$PUSH" --force
assert_exit "CP-T11" 2
assert_eq "CP-T11" "CP007" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
# 全部直すと push できる
rm -f logs/merge-state.json wip/20_plans/0009-orphan.html wip/10_tickets/10_doing/0001-investigation.md
echo "<p>" > wip/30_reports/0003-investigation.html
commit_all "chore: fix all"
run_cmd bash "$PUSH"
assert_exit "CP-T05" 0
assert_contains "CP-T05" "OK: push した（main、1 コミット）"
# リモート拒否は CP006（存在しない URL）
git remote set-url origin "$TMP_DIR/nowhere.git"
echo y > y.txt; commit_all "chore: y"
run_cmd bash "$PUSH"
assert_exit "CP-T05" 1
assert_contains "CP-T05" "CP006:"
git remote set-url origin "$REMOTE"
run_cmd bash "$PUSH"
assert_exit "CP-T05" 0

# CP-T06 スキップ記録がある項目だけ飛び、出力に明記される。項目 4 は飛ばせない
rm -f wip/30_reports/0003-investigation.html
printf '%s\n' "# push 前チェックのスキップ記録" "- 項目 3: check-html.sh 未完成のため HTML は後で作る" > wip/push-check-skip.md
run_cmd bash "$PUSH"
assert_exit "CP-T06" 1
assert_contains "CP-T06" "項目 1: 未コミットの変更が"   # 記録ファイル自体が未コミット
commit_all "chore: skip 記録"
run_cmd bash "$PUSH"
assert_exit "CP-T06" 0
assert_contains "CP-T06" "skip 項目 3:"
assert_contains "CP-T06" "スキップ: 項目 3"
# 記録はコミット済みの版（HEAD）だけ読む: 作業ツリーだけの「- 項目 1:」では項目 1 を飛ばせず、記録は必ず MR の差分に載る
printf '%s\n' "- 項目 1: 飛ばしたい" >> wip/push-check-skip.md
echo dirty > dirty.txt
run_cmd bash "$PUSH"
assert_exit "CP-T06" 1
assert_contains "CP-T06" "項目 1: 未コミットの変更が"
assert_not_contains "CP-T06" "skip 項目 1"
rm -f dirty.txt
git checkout -q -- wip/push-check-skip.md
printf '%s\n' "- 項目 3: x" "- 項目 4: 飛ばしたい" >> wip/push-check-skip.md
printf '{"state":"ready"}\n' > logs/merge-state.json
commit_all "chore: skip 4"
run_cmd bash "$PUSH"
assert_exit "CP-T06" 1
assert_contains "CP-T06" "項目 4 の指定は無効"
assert_contains "CP-T06" "項目 4: draft 解除後"
rm -f logs/merge-state.json

# CP-T07 宣言済み作業中チケット（remote-write:push）があるときの push が項目 2 を通る
ticket '["read", "remote-write:push"]'
commit_all "chore: ticket with push"
run_cmd bash "$PUSH"
assert_exit "CP-T07" 0
assert_contains "CP-T07" "push を宣言済み（remote-write:push）"
ticket '["read", "remote-read"]'
commit_all "chore: ticket without push"
run_cmd bash "$PUSH"
assert_exit "CP-T07" 1
assert_contains "CP-T07" "項目 2: 作業中のチケットがある"
rm -f wip/10_tickets/10_doing/0001-investigation.md; commit_all "chore: no ticket"

# CP-T11 push.sh の引数・環境の誤り（不明な引数・git / jq 不在・detached HEAD）は CP007・終了 2。
# CP005 は検査未充足、CP006 はリモート拒否だけ。commit.sh 側の同じ観点は CP-T08（別ファイル・別 ID）
make_restricted_path bash
run_cmd env PATH="$RESTRICTED_PATH" bash "$PUSH"
assert_exit "CP-T11" 2
assert_eq "CP-T11" "CP007" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
printf '{"state":"ready"}\n' > logs/merge-state.json
make_restricted_path bash git tr sed wc head tail find sort grep ls cat cut uniq awk basename dirname comm mktemp rm
run_cmd env PATH="$RESTRICTED_PATH" bash "$PUSH"
assert_exit "CP-T11" 2
assert_eq "CP-T11" "CP007" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
assert_contains "CP-T11" "jq"
rm -f logs/merge-state.json
git checkout -q --detach
run_cmd bash "$PUSH"
assert_exit "CP-T11" 2
assert_eq "CP-T11" "CP007" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
git checkout -q main
# 正のコントロール: 環境が揃っていれば検査未充足は CP005 のまま
echo z > z.txt
run_cmd bash "$PUSH"
assert_exit "CP-T11" 1
assert_eq "CP-T11" "CP005" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
rm -f z.txt

# CP-T12 作業ツリーからの push が項目 5 の未充足で CP005 になり、git push を実行しない。
# wip/push-check-skip.md に項目 5 を書いてコミットしても飛ばせない（項目 4 と同じ扱い）。
# 負のコントロール: 同じリポジトリの本流では項目 5 が通る。commit.sh は作業ツリーでも成功する
remote_count() { git -C "$REMOTE" rev-list --count main; }
before_remote="$(remote_count)"
WT12="${TMP_REPO}-wt12"
_TL_TMPS+=("$WT12")
git worktree add -q -b wtcp12 "$WT12" HEAD
WT12_PUSH="$WT12/.claude/skills/20-common-step-commit-push/scripts/push.sh"
WT12_COMMIT="$WT12/.claude/skills/20-common-step-commit-push/scripts/commit.sh"
run_cmd bash "$WT12_PUSH"
assert_exit "CP-T12" 1
assert_eq "CP-T12" "CP005" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
assert_contains "CP-T12" "項目 5: 本流で実行している"
assert_contains "CP-T12" "未充足 1 件"
assert_eq "CP-T12" "$before_remote" "$(remote_count)"
if git -C "$REMOTE" rev-parse --verify -q wtcp12 >/dev/null 2>&1; then fail "CP-T12" "サブブランチがリモートに push された"; else pass "CP-T12"; fi
if git -C "$WT12" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then fail "CP-T12" "作業ツリーのサブブランチに上流が作られた"; else pass "CP-T12"; fi
# commit.sh は作業ツリーでも成功し、その作業ツリーの差分をコミットする
wt_head_before="$(git -C "$WT12" rev-parse HEAD)"
printf '%s\n' "- 項目 5: 飛ばしたい" >> "$WT12/wip/push-check-skip.md"
run_cmd bash "$WT12_COMMIT" -m "chore: 項目 5 のスキップ記録を置く" wip/push-check-skip.md
assert_exit "CP-T12" 0
if [ "$wt_head_before" != "$(git -C "$WT12" rev-parse HEAD)" ]; then pass "CP-T12"; else fail "CP-T12" "作業ツリーでの commit.sh が commit を作っていない"; fi
assert_eq "CP-T12" "$wt_head_before" "$(git rev-parse HEAD)"   # 本流の HEAD は動かない
# 記録に書いても項目 5 は飛ばせない
run_cmd bash "$WT12_PUSH"
assert_exit "CP-T12" 1
assert_eq "CP-T12" "CP005" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
assert_contains "CP-T12" "項目 5 の指定は無効"
assert_not_contains "CP-T12" "skip 項目 5"
assert_eq "CP-T12" "$before_remote" "$(remote_count)"
if git -C "$REMOTE" rev-parse --verify -q wtcp12 >/dev/null 2>&1; then fail "CP-T12" "サブブランチがリモートに push された"; else pass "CP-T12"; fi
# 負のコントロール: 同じリポジトリの本流では項目 5 が通る
run_cmd bash "$PUSH"
assert_exit "CP-T12" 0
assert_contains "CP-T12" "✓ 項目 5: 本流で実行している"

finish
