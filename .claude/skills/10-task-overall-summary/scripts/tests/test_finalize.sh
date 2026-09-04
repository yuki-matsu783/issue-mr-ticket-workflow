#!/usr/bin/env bash
# test_finalize.sh — finalize.sh のテスト（仕様のテスト ID: FN-T01〜09）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_finalize*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

REAL="$LOGGER_ROOT/.claude"

# ---- リモート（bare）と作業リポジトリ ----
make_tmp_dir; ORIGIN="$TMP_DIR/origin.git"
git init -q --bare -b main "$ORIGIN"
make_tmp_repo
cd "$TMP_REPO" || exit 2

mkdir -p .claude/skills/20-common-step-shell-script/scripts \
         .claude/skills/20-common-step-commit-push/scripts .claude/skills/20-common-step-commit-push/assets \
         .claude/skills/20-common-step-ticket/scripts .claude/skills/20-common-step-ticket/assets \
         .claude/skills/20-common-step-report-view/scripts .claude/skills/20-common-step-report-view/assets \
         .claude/skills/10-task-overall-summary/scripts .claude/hooks/config
cp "$REAL"/skills/20-common-step-shell-script/scripts/*.sh .claude/skills/20-common-step-shell-script/scripts/
cp "$REAL"/skills/20-common-step-commit-push/scripts/*.sh .claude/skills/20-common-step-commit-push/scripts/
cp "$REAL"/skills/20-common-step-commit-push/assets/exclude-patterns.txt .claude/skills/20-common-step-commit-push/assets/
cp "$REAL"/skills/20-common-step-ticket/scripts/*.sh .claude/skills/20-common-step-ticket/scripts/
cp "$REAL"/skills/20-common-step-ticket/assets/ticket.template.md .claude/skills/20-common-step-ticket/assets/
cp "$REAL"/skills/20-common-step-report-view/scripts/check-html.sh .claude/skills/20-common-step-report-view/scripts/
cp "$REAL"/skills/20-common-step-report-view/assets/*.html .claude/skills/20-common-step-report-view/assets/
cp "$REAL"/skills/10-task-overall-summary/scripts/finalize.sh .claude/skills/10-task-overall-summary/scripts/
cp "$REAL"/hooks/config/task-types.tsv .claude/hooks/config/
F=".claude/skills/10-task-overall-summary/scripts/finalize.sh"

printf 'logs/\n' > .gitignore
printf '# t\n' > README.md
mkdir -p wip/10_tickets/00_todo wip/10_tickets/10_doing wip/10_tickets/20_done wip/20_plans wip/30_reports wip/tmp

# ---- 全体まとめチケット（完了検査を通る形） ----
cat > wip/10_tickets/10_doing/0009-overall-summary.md <<'TICKETEOF'
---
type: ticket
ticket_type: overall-summary
predecessors: []
executor: main
human_review: {required: false, reason: "テスト"}
adversarial_review: {required: false, reason: "テスト"}
allow:
  write: ["wip/**", "logs/**"]
  ops: ["read", "remote-write:push"]
started_at: "2026-09-04T00:00:00+09:00"
completed_at: ""
base_sha: ""
---

# 0009 全体まとめ

## 目的

issue の作業を締める

## DoD

- [x] 別 issue に起票すべき内容を確認した（根拠: 統括レポート「別 issue」節）
- [x] 統括レポート（md + HTML）がある（根拠: wip/30_reports/0009-overall-summary.md）
- [x] MR 本文の `## 統括` 節に要約が書き写されている（根拠: MR 本文）

## 作業内容

- 締める

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- 通った

### うまくいかなかったこと

- 無し

### 仕様からの逸脱

- 無し

### 判断と根拠

- 無し

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- finalize.sh

### スコープ外で見つけたこと

- 無し

### AI アセットに反映すべき内容

- 無し（テスト用チケット）

### 備考

- テスト
TICKETEOF

# ---- 統括レポート（md + HTML） ----
cat > wip/30_reports/0009-overall-summary.md <<'REPEOF'
---
type: report
title: 0009 統括レポート
description: テスト用の統括レポート
tags: [report, overall-summary]
keywords: [統括, テスト]
---

# 0009 統括レポート

## サマリ

テスト用。
REPEOF
sed 's/{{[a-z_0-9]*}}/記載なし/g' .claude/skills/20-common-step-report-view/assets/report.template.html \
  > wip/30_reports/0009-overall-summary.html

git add -A >/dev/null 2>&1
git commit -q -m "chore: init"
git remote add origin "$ORIGIN"
git push -q -u origin main
git checkout -q -b feature-x
git commit -q --allow-empty -m "chore: start"
git push -q -u origin feature-x
BASE="$(git rev-parse HEAD)"

# ---- gh スタブ ----
make_tmp_dir; FIX="$TMP_DIR"
make_tmp_dir; STUB="$TMP_DIR"
export GH_FIX="$FIX"
cat > "$STUB/gh" <<'STUBEOF'
#!/bin/bash
case "$1 $2" in
  "pr view")
    if printf '%s ' "$@" | grep -q 'isDraft'; then cat "$GH_FIX/draft.txt"; else cat "$GH_FIX/body.md"; fi; exit 0 ;;
  "pr edit")
    body=""
    while [ $# -gt 0 ]; do if [ "$1" = "--body-file" ]; then body="$2"; fi; shift; done
    if [ -n "$body" ]; then cp "$body" "$GH_FIX/body.md"; fi; exit 0 ;;
  "pr ready") printf 'false\n' > "$GH_FIX/draft.txt"; exit 0 ;;
  "repo view") printf 'main\n'; exit 0 ;;
esac
exit 1
STUBEOF
chmod +x "$STUB/gh"
PATH="$STUB:$PATH"; export PATH

reset_body() {
  cat > "$FIX/body.md" <<'BODYEOF'
## 概要

テスト用の MR 本文。

## 統括

受け入れ条件は満たした。

### 成果物

| レポート | 内容 | リンク |
|---|---|---|

人間が添付: https://example.test/human-attached.html
BODYEOF
  printf 'true\n' > "$FIX/draft.txt"
}

setup_logs() {
  mkdir -p logs
  printf '{"host":"github","issue":10,"mr":1,"url":"https://github.com/acme/demo/pull/1"}\n' > logs/mr.json
  printf '{"mr":1,"boundary":{"task_type":"overall-summary","tickets":["0009"],"last_done":"0009"},"state":"skipped"}\n' > logs/review-state.json
  rm -f logs/merge-state.json
}

restore() {
  git reset -q --hard "$BASE"
  git clean -qfd
  git push -q -f origin feature-x
  git push -q -f origin "$BASE:main"
  setup_logs
  reset_body
}
restore

# ================================================================ FN-T01
# release が完了検査 → 書き出しと push → リンク一覧 → 片付け → push → 解除 を 1 回で行い ready になる
run_cmd bash "$F" release
assert_exit "FN-T01" 0
assert_contains "FN-T01" "draft を解除した"
assert_eq "FN-T01" "ready" "$(tl_jq -r '.state' logs/merge-state.json)"
assert_eq "FN-T01" "false" "$(cat "$FIX/draft.txt" | tr -d '\r')"
assert_eq "FN-T01" "" "$(find wip -type f ! -name .gitkeep 2>/dev/null | tr '\n' ' ')"
PRE_SHA="$(tl_jq -r '.pre_cleanup_sha' logs/merge-state.json)"

# ================================================================ FN-T06
# 本文のリンクが pre_cleanup_sha に固定され、片付けの後もそのリンクから成果物が辿れる
if grep -q "blob/$PRE_SHA/wip/30_reports/0009-overall-summary.html" "$FIX/body.md"; then pass "FN-T06"; else fail "FN-T06" "本文に pre_cleanup_sha 固定のリンクが無い: $(grep -c blob "$FIX/body.md") 件"; fi
if git cat-file -e "$PRE_SHA:wip/30_reports/0009-overall-summary.html" 2>/dev/null; then pass "FN-T06"; else fail "FN-T06" "$PRE_SHA に成果物が無い"; fi
if grep -q "<!-- finalize:linked $PRE_SHA -->" "$FIX/body.md"; then pass "FN-T06"; else fail "FN-T06" "固定マーカーが無い"; fi

# ================================================================ FN-T07
# 完了検査の結果が pre_cleanup_sha のコミットの統括レポートに含まれている
if git show "$PRE_SHA:wip/30_reports/0009-overall-summary.md" 2>/dev/null | grep -q '^## 完了検査'; then pass "FN-T07"; else fail "FN-T07" "統括レポート（$PRE_SHA）に完了検査の節が無い"; fi
if git show "$PRE_SHA:wip/30_reports/0009-overall-summary.md" 2>/dev/null | grep -q '別 issue に起票すべき内容を確認した'; then pass "FN-T07"; else fail "FN-T07" "DoD 1 件ごとの行が無い"; fi
if git show "$PRE_SHA:wip/30_reports/0009-overall-summary.html" 2>/dev/null | grep -q 'id="completion-check"'; then pass "FN-T07"; else fail "FN-T07" "HTML に完了検査の節が無い"; fi

# ================================================================ FN-T09
# 段階 4 の本文書き換えが、リンク一覧の表の中身だけを置き換え、要約と人間の添付を残す
if grep -q '人間が添付: https://example.test/human-attached.html' "$FIX/body.md"; then pass "FN-T09"; else fail "FN-T09" "人間が添付したリンクが消えた"; fi
if grep -q '受け入れ条件は満たした。' "$FIX/body.md"; then pass "FN-T09"; else fail "FN-T09" "処理フロー 5 の要約が消えた"; fi
if grep -q '^## 概要' "$FIX/body.md"; then pass "FN-T09"; else fail "FN-T09" "他の節が消えた"; fi
assert_eq "FN-T09" "1" "$(grep -c '^| 0009-overall-summary |' "$FIX/body.md")"

# ================================================================ FN-T05
# ready 後の再実行が何もせず成功する（冪等）
HEAD_BEFORE="$(git rev-parse HEAD)"
run_cmd bash "$F" release
assert_exit "FN-T05" 0
assert_eq "FN-T05" "ready" "$(tl_jq -r '.state' logs/merge-state.json)"
assert_eq "FN-T05" "$HEAD_BEFORE" "$(git rev-parse HEAD)"

# ================================================================ FN-T02
# 他のチケットが残っている release が FN001、DoD 未充足が FN002
restore
mkdir -p wip/10_tickets/00_todo   # 空ディレクトリは git が追跡しないので restore では戻らない
cp wip/10_tickets/10_doing/0009-overall-summary.md wip/10_tickets/00_todo/0010-investigation.md
sed -i 's/^ticket_type: overall-summary/ticket_type: investigation/' wip/10_tickets/00_todo/0010-investigation.md
git add -A >/dev/null 2>&1; git commit -q -m "chore: add todo"; git push -q origin feature-x
run_cmd bash "$F" release
assert_exit "FN-T02" 1
assert_contains "FN-T02" "FN001:"
assert_contains "FN-T02" "未着手のチケットが 1 枚"

restore
sed -i '0,/^- \[x\]/s//- [ ]/' wip/10_tickets/10_doing/0009-overall-summary.md
git add -A >/dev/null 2>&1; git commit -q -m "chore: unmet dod"; git push -q origin feature-x
run_cmd bash "$F" release
assert_exit "FN-T02" 1
assert_contains "FN-T02" "FN002:"
assert_contains "FN-T02" "DoD に未チェックの項目がある"

# ================================================================ FN-T03
# base が進んでいる release が FN003 で止まり、片付けは巻き戻らない
restore
git push -q -f origin "$BASE:main"
git commit -q --allow-empty -m "chore: main が進む"
git push -q -f origin "HEAD:main"
git reset -q --hard "$BASE"
git push -q -f origin feature-x
run_cmd bash "$F" release
assert_exit "FN-T03" 1
assert_contains "FN-T03" "FN003:"
assert_eq "FN-T03" "pushed" "$(tl_jq -r '.state' logs/merge-state.json)"
assert_eq "FN-T03" "" "$(find wip -type f ! -name .gitkeep 2>/dev/null | tr '\n' ' ')"

# ================================================================ FN-T04
# push で失敗した後の再実行が片付けをやり直さず push から続く
git push -q -f origin "$BASE:main"          # base の遅れを解消する
tl_jq '.state = "cleaned"' logs/merge-state.json > logs/ms.tmp && mv logs/ms.tmp logs/merge-state.json
HEAD_BEFORE="$(git rev-parse HEAD)"
run_cmd bash "$F" release
assert_exit "FN-T04" 0
assert_eq "FN-T04" "ready" "$(tl_jq -r '.state' logs/merge-state.json)"
assert_eq "FN-T04" "$HEAD_BEFORE" "$(git rev-parse HEAD)"
assert_eq "FN-T04" "" "$(find wip -type f ! -name .gitkeep 2>/dev/null | tr '\n' ' ')"

# ================================================================ FN-T08
# 記録を失った再導出で、本文にリンク一覧の空の表があるだけの状態が linked にならない
restore
printf '\n## 完了検査\n\n通過。\n' >> wip/30_reports/0009-overall-summary.md
git add -A >/dev/null 2>&1; git commit -q -m "chore: 完了検査を書き出す"; git push -q origin feature-x
rm -f logs/merge-state.json
mkdir -p wip/tmp
run_cmd bash "$F" release --external --pr 1 --body-file wip/tmp/out1.md
assert_exit "FN-T08" 0
assert_contains "FN-T08" "段階 4 の本文を書き出した"

# 固定マーカーがあれば linked と判定して段階 4 を飛ばす
restore
printf '\n## 完了検査\n\n通過。\n' >> wip/30_reports/0009-overall-summary.md
git add -A >/dev/null 2>&1; git commit -q -m "chore: 完了検査を書き出す"; git push -q origin feature-x
printf '\n<!-- finalize:linked %s -->\n' "$(git rev-parse HEAD)" >> "$FIX/body.md"
rm -f logs/merge-state.json
run_cmd bash "$F" release --external --pr 1 --body-file wip/tmp/out2.md
assert_not_contains "FN-T08" "段階 4 の本文を書き出した"
assert_eq "FN-T08" "ready" "$(tl_jq -r '.state' logs/merge-state.json)"
# --external は via を残し、draft 解除そのものは呼び出し元に委ねる（段階 7 の代行）
assert_eq "FN-T08" "external" "$(tl_jq -r '.via' logs/merge-state.json)"
assert_eq "FN-T08" "true" "$(cat "$FIX/draft.txt" | tr -d '\r')"

finish
