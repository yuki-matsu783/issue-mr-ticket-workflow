#!/usr/bin/env bash
# test_boundary.sh — boundary.sh のテスト（仕様のテスト ID: BD-T01〜13）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_boundary*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

REAL="$LOGGER_ROOT/.claude"
make_tmp_repo
cd "$TMP_REPO" || exit 2
mkdir -p .claude/skills/20-common-step-shell-script/scripts \
         .claude/skills/20-common-step-ticket/scripts .claude/skills/20-common-step-ticket/assets \
         .claude/skills/20-common-step-commit-push/scripts .claude/skills/20-common-step-commit-push/assets \
         .claude/skills/00-workflow-issue-mr-driven/scripts .claude/hooks/config
cp "$REAL"/skills/20-common-step-shell-script/scripts/*.sh .claude/skills/20-common-step-shell-script/scripts/
cp "$REAL"/skills/20-common-step-commit-push/scripts/*.sh .claude/skills/20-common-step-commit-push/scripts/
cp "$REAL"/skills/20-common-step-commit-push/assets/exclude-patterns.txt .claude/skills/20-common-step-commit-push/assets/
cp "$REAL"/skills/20-common-step-ticket/scripts/ticket.sh .claude/skills/20-common-step-ticket/scripts/
cp "$REAL"/skills/20-common-step-ticket/assets/ticket.template.md .claude/skills/20-common-step-ticket/assets/
cp "$REAL"/skills/00-workflow-issue-mr-driven/scripts/boundary.sh .claude/skills/00-workflow-issue-mr-driven/scripts/
cp "$REAL"/hooks/config/task-types.tsv .claude/hooks/config/
B=".claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh"
T=".claude/skills/20-common-step-ticket/scripts/ticket.sh"

# wip/ と logs/ を追跡外にする。チケットの出し入れで作業ツリーが汚れないので、
# ケースごとに git commit しなくて済む（テストの実行時間がランナーの既定タイムアウトに収まる）
printf 'logs/\nwip/\n' > .gitignore
printf '# t\n' > README.md
git add -A >/dev/null 2>&1
git commit -q -m "chore: init"
git remote add origin https://github.com/acme/demo.git
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# 「push 済み」を作る（ネットワークを使わずリモート追跡参照を進める）
mark_pushed() { git update-ref "refs/remotes/origin/$BRANCH" HEAD; }
mark_pushed

# ---- gh スタブ（fixture ディレクトリの中身を返す） ----
make_tmp_dir; FIX="$TMP_DIR"
make_tmp_dir; STUB="$TMP_DIR"
export BD_FIX="$FIX"
cat > "$STUB/gh" <<'STUBEOF'
#!/bin/bash
case "$1 $2" in
  "pr view") cat "$BD_FIX/pr.json"; exit 0 ;;
  "repo view")
    if printf '%s ' "$@" | grep -q 'owner'; then printf 'acme\n'; else printf 'demo\n'; fi; exit 0 ;;
  "pr comment")
    body=""
    while [ $# -gt 0 ]; do if [ "$1" = "--body-file" ]; then body="$2"; fi; shift; done
    if [ -n "$body" ]; then cat "$body" >> "$BD_FIX/posted.log"; printf '\n---\n' >> "$BD_FIX/posted.log"; fi
    printf 'https://github.com/acme/demo/pull/1#issuecomment-%s\n' "$RANDOM"; exit 0 ;;
  "api graphql") cat "$BD_FIX/graphql.json"; exit 0 ;;
  "api --paginate") cat "$BD_FIX/comments.json"; exit 0 ;;
esac
exit 1
STUBEOF
chmod +x "$STUB/gh"
PATH="$STUB:$PATH"; export PATH

printf '{"number":1,"url":"https://github.com/acme/demo/pull/1","state":"OPEN"}\n' > "$FIX/pr.json"
: > "$FIX/posted.log"
empty_remote() {
  printf '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]},"reviews":{"nodes":[]}}}}}\n' > "$FIX/graphql.json"
  printf '[]\n' > "$FIX/comments.json"
}
empty_remote

# ---- チケットのひな形（frontmatter だけが判定に効く） ----
mk_ticket() { # $1=番号 $2=種類 $3=置き場(00_todo|10_doing|20_done) $4=human_review $5=predecessors(csv 任意)
  local pred="[]" p out=""
  if [ -n "${5:-}" ]; then
    local IFS=','; for p in $5; do out="$out, \"$p\""; done
    pred="[${out#, }]"
  fi
  mkdir -p "wip/10_tickets/$3"
  cat > "wip/10_tickets/$3/$1-$2.md" <<TICKETEOF
---
type: ticket
ticket_type: $2
predecessors: $pred
executor: main
human_review: {required: $4, reason: "テスト"}
adversarial_review: {required: false, reason: "テスト"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# $1 テスト用チケット
TICKETEOF
}
reset_tickets() { rm -rf wip/10_tickets logs/review-state.json logs/review-history.jsonl logs/mr.json; }
# wip/ は追跡外なのでコミットは要らない。汚したケースの後だけ戻す（git の起動を減らす）
DIRTY=0
commit_all() { if [ "$DIRTY" = "1" ]; then git checkout -- . >/dev/null 2>&1; mark_pushed; DIRTY=0; fi; }
st() { bash "$B" status --offline 2>/dev/null; }

# ================================================================ BD-T01
# at_boundary が doing あり / 同 type の todo 残り / type が変わる / todo 空 で期待どおり
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 investigation 10_doing false
assert_eq "BD-T01" "false" "$(st | tl_jq -r '.at_boundary')"

rm -f wip/10_tickets/10_doing/0002-investigation.md
mk_ticket 0002 investigation 00_todo false
assert_eq "BD-T01" "false" "$(st | tl_jq -r '.at_boundary')"

rm -f wip/10_tickets/00_todo/0002-investigation.md
mk_ticket 0002 design-plan 00_todo false
assert_eq "BD-T01" "true" "$(st | tl_jq -r '.at_boundary')"

rm -f wip/10_tickets/00_todo/0002-design-plan.md
assert_eq "BD-T01" "true" "$(st | tl_jq -r '.at_boundary')"

# ================================================================ BD-T02
# status の next / current が ticket.sh next の出力と同一（透過）
mk_ticket 0002 design-plan 00_todo false
tk="$(bash "$T" next | tr -d '\r')"
bd="$(st)"
assert_eq "BD-T02" "$(printf '%s' "$tk" | tl_jq -r '.next // "null"')" "$(printf '%s' "$bd" | tl_jq -r '.next // "null"')"
assert_eq "BD-T02" "$(printf '%s' "$tk" | tl_jq -r '.current // "null"')" "$(printf '%s' "$bd" | tl_jq -r '.current // "null"')"
assert_eq "BD-T02" "$(printf '%s' "$tk" | tl_jq -r '.type // "null"')" "$(printf '%s' "$bd" | tl_jq -r '.type // "null"')"
assert_eq "BD-T02" "$(printf '%s' "$tk" | tl_jq -r '.skill // "null"')" "$(printf '%s' "$bd" | tl_jq -r '.skill // "null"')"

# ================================================================ BD-T03
# 未コミット・未 push・切れ目でない・二重依頼の request が BD001 で全件列挙
mkdir -p wip
printf 'レビュー観点\n' > wip/req.md
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 investigation 10_doing false      # 切れ目ではない
printf 'unpushed\n' >> README.md
git add README.md >/dev/null 2>&1; git commit -q -m "chore: t3"   # push はしない（origin/BRANCH は古い）
printf 'dirty\n' >> README.md                                      # 未コミットも作る
DIRTY=1
run_cmd bash "$B" request --body-file wip/req.md
assert_exit "BD-T03" 1
assert_contains "BD-T03" "BD001:"
assert_contains "BD-T03" "タスクの切れ目ではない"
assert_contains "BD-T03" "未コミットの変更がある"
assert_contains "BD-T03" "push されていない"

# 二重依頼
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
empty_remote
run_cmd bash "$B" request --body-file wip/req.md
assert_exit "BD-T03" 0
run_cmd bash "$B" request --body-file wip/req.md
assert_exit "BD-T03" 1
assert_contains "BD-T03" "既に requested"

# ================================================================ BD-T04
# request → complete（指摘 0）で completed になり findings が空
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
empty_remote
run_cmd bash "$B" request --body-file wip/req.md
assert_exit "BD-T04" 0
assert_eq "BD-T04" "requested" "$(tl_jq -r '.state' logs/review-state.json)"
run_cmd bash "$B" complete
assert_exit "BD-T04" 0
assert_eq "BD-T04" "completed" "$(tl_jq -r '.state' logs/review-state.json)"
assert_eq "BD-T04" "0" "$(tl_jq -r '.findings | length' logs/review-state.json)"
assert_eq "BD-T04" "completed" "$(st | tl_jq -r '.position')"

# ================================================================ BD-T05
# 未解決スレッドがある complete が BD003、--accept-unresolved で通る。CHANGES_REQUESTED は不可
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
empty_remote
run_cmd bash "$B" request --body-file wip/req.md
cat > "$FIX/graphql.json" <<'GQLEOF'
{"data":{"repository":{"pullRequest":{
  "reviewThreads":{"nodes":[{"id":"TH1","isResolved":false,"isOutdated":false,
    "comments":{"nodes":[{"url":"https://github.com/acme/demo/pull/1#discussion_r1","path":"a.sh","line":3,
      "body":"ここは境界値が漏れている","createdAt":"2099-01-01T00:00:00Z","author":{"login":"reviewer"}}]}}]},
  "reviews":{"nodes":[]}}}}}
GQLEOF
run_cmd bash "$B" complete
assert_exit "BD-T05" 1
assert_contains "BD-T05" "BD003:"
assert_contains "BD-T05" "未解決のレビュースレッド"
run_cmd bash "$B" complete --accept-unresolved
assert_exit "BD-T05" 0
assert_eq "BD-T05" "1" "$(tl_jq -r '.accepted_unresolved | length' logs/review-state.json)"

# CHANGES_REQUESTED は --accept-unresolved でも通らない
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
empty_remote
run_cmd bash "$B" request --body-file wip/req.md
cat > "$FIX/graphql.json" <<'GQLEOF'
{"data":{"repository":{"pullRequest":{
  "reviewThreads":{"nodes":[]},
  "reviews":{"nodes":[{"state":"CHANGES_REQUESTED","submittedAt":"2099-01-01T00:00:00Z",
    "url":"https://github.com/acme/demo/pull/1#pullrequestreview-9","author":{"login":"reviewer"}}]}}}}}
GQLEOF
run_cmd bash "$B" complete --accept-unresolved
assert_exit "BD-T05" 1
assert_contains "BD-T05" "BD003:"
assert_contains "BD-T05" "CHANGES_REQUESTED"

# ================================================================ BD-T06
# 固定マーカー付きコメントだけが findings から除外され、同じログイン名でもマーカーの無いものは残る
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
empty_remote
run_cmd bash "$B" request --body-file wip/req.md
cat > "$FIX/comments.json" <<'CMTEOF'
[{"html_url":"https://github.com/acme/demo/pull/1#issuecomment-1",
  "body":"<!-- boundary:request investigation:0001 -->\n\nレビュー観点","created_at":"2099-01-01T00:00:00Z","user":{"login":"owner"}},
 {"html_url":"https://github.com/acme/demo/pull/1#issuecomment-2",
  "body":"<!-- boundary:usage -->\n\n## 対応工数","created_at":"2099-01-01T00:00:01Z","user":{"login":"owner"}},
 {"html_url":"https://github.com/acme/demo/pull/1#issuecomment-3",
  "body":"人間の指摘: ここは要検討","created_at":"2099-01-01T00:00:02Z","user":{"login":"owner"}}]
CMTEOF
printf '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]},"reviews":{"nodes":[]}}}}}\n' > "$FIX/graphql.json"
run_cmd bash "$B" complete
assert_exit "BD-T06" 0
assert_eq "BD-T06" "1" "$(tl_jq -r '.findings | length' logs/review-state.json)"
assert_eq "BD-T06" "人間の指摘: ここは要検討" "$(tl_jq -r '.findings[0].summary' logs/review-state.json)"
assert_eq "BD-T06" "owner" "$(tl_jq -r '.findings[0].author' logs/review-state.json)"

# ================================================================ BD-T07
# 追加チケットの完了で last_done が変わり、直前の completed が none として扱われる
assert_eq "BD-T07" "completed" "$(st | tl_jq -r '.review.state')"
mk_ticket 0003 investigation 20_done false
bd="$(st)"
assert_eq "BD-T07" "0003" "$(printf '%s' "$bd" | tl_jq -r '.last_task.last_done')"
assert_eq "BD-T07" "none" "$(printf '%s' "$bd" | tl_jq -r '.review.state')"
assert_eq "BD-T07" "before_request" "$(printf '%s' "$bd" | tl_jq -r '.position')"

# ================================================================ BD-T08
# review-state.json を削除しても status が依頼コメントのマーカーから requested を再導出する
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
printf '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]},"reviews":{"nodes":[]}}}}}\n' > "$FIX/graphql.json"
cat > "$FIX/comments.json" <<'CMTEOF'
[{"html_url":"https://github.com/acme/demo/pull/1#issuecomment-7",
  "body":"<!-- boundary:request investigation:0001 -->\n\nレビュー観点","created_at":"2099-01-01T00:00:00Z","user":{"login":"owner"}}]
CMTEOF
rm -f logs/review-state.json
run_cmd bash "$B" status
assert_exit "BD-T08" 0
assert_eq "BD-T08" "requested" "$(printf '%s' "$R_OUT" | tl_jq -r '.review.state')"
assert_eq "BD-T08" "requested" "$(printf '%s' "$R_OUT" | tl_jq -r '.position')"
assert_eq "BD-T08" "requested" "$(tl_jq -r '.state' logs/review-state.json)"

# ================================================================ BD-T09
# レビュー要の切れ目での skip が BD001
reset_tickets
mk_ticket 0001 investigation 20_done true
mk_ticket 0002 design-plan 00_todo false
commit_all
run_cmd bash "$B" skip --reason "軽微なため"
assert_exit "BD-T09" 1
assert_contains "BD-T09" "BD001:"
assert_contains "BD-T09" "省略できない"

# レビュー不要なら通る
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
run_cmd bash "$B" skip --reason "軽微なため"
assert_exit "BD-T09" 0
assert_eq "BD-T09" "skipped" "$(tl_jq -r '.state' logs/review-state.json)"

# ================================================================ BD-T10
# --external / --standalone で via が記録され、complete --external --report-file が同じスキーマで処理される
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
run_cmd bash "$B" request --body-file wip/req.md --external --comment-url "https://example.test/c/1"
assert_exit "BD-T10" 0
assert_eq "BD-T10" "external" "$(tl_jq -r '.via' logs/review-state.json)"
assert_eq "BD-T10" "https://example.test/c/1" "$(tl_jq -r '.request_comment_url' logs/review-state.json)"
cat > wip/report.json <<'RPTEOF'
{"threads":[],"reviews":[],
 "comments":[{"url":"https://example.test/c/2","body":"外部から渡した指摘","author":"human","created_at":"2099-01-01T00:00:00Z"}]}
RPTEOF
run_cmd bash "$B" complete --external --report-file wip/report.json
assert_exit "BD-T10" 0
assert_eq "BD-T10" "1" "$(tl_jq -r '.findings | length' logs/review-state.json)"
assert_eq "BD-T10" "外部から渡した指摘" "$(tl_jq -r '.findings[0].summary' logs/review-state.json)"

reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
run_cmd bash "$B" request --body-file wip/req.md --standalone
assert_exit "BD-T10" 0
assert_eq "BD-T10" "chat" "$(tl_jq -r '.via' logs/review-state.json)"

# ================================================================ BD-T11
# doing が overall-summary 1 枚のとき --final が通り、--final 無しは BD001。position が requested
reset_tickets
mk_ticket 0001 ai-asset-implementation 20_done false
mk_ticket 0009 overall-summary 10_doing false
commit_all
empty_remote
run_cmd bash "$B" request --body-file wip/req.md
assert_exit "BD-T11" 1
assert_contains "BD-T11" "--final を付ける"
run_cmd bash "$B" request --body-file wip/req.md --final
assert_exit "BD-T11" 0
assert_eq "BD-T11" "0009" "$(tl_jq -r '.boundary.last_done' logs/review-state.json)"
assert_eq "BD-T11" "overall-summary" "$(tl_jq -r '.boundary.task_type' logs/review-state.json)"
assert_eq "BD-T11" "requested" "$(st | tl_jq -r '.position')"
run_cmd bash "$B" complete --final
assert_exit "BD-T11" 0
assert_eq "BD-T11" "completed" "$(tl_jq -r '.state' logs/review-state.json)"
rm -f logs/review-state.json
run_cmd bash "$B" skip --final --reason "人間レビュー不要"
assert_exit "BD-T11" 0
assert_eq "BD-T11" "skipped" "$(tl_jq -r '.state' logs/review-state.json)"

# ================================================================ BD-T12
# 同じキーのマーカー付き依頼コメントが 2 件あると status が BD005 で終了コード 1
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0002 design-plan 00_todo false
commit_all
printf '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]},"reviews":{"nodes":[]}}}}}\n' > "$FIX/graphql.json"
cat > "$FIX/comments.json" <<'CMTEOF'
[{"html_url":"https://github.com/acme/demo/pull/1#issuecomment-11",
  "body":"<!-- boundary:request investigation:0001 -->\n\n1 回目","created_at":"2099-01-01T00:00:00Z","user":{"login":"owner"}},
 {"html_url":"https://github.com/acme/demo/pull/1#issuecomment-12",
  "body":"<!-- boundary:request investigation:0001 -->\n\n2 回目","created_at":"2099-01-01T00:00:01Z","user":{"login":"owner"}}]
CMTEOF
rm -f logs/review-state.json
run_cmd bash "$B" status
assert_exit "BD-T12" 1
assert_contains "BD-T12" "BD005:"
assert_contains "BD-T12" "依頼コメントが 2 件"

# ================================================================ BD-T13
# 追加チケットを次の計画チケットの predecessors に加えると next が追加チケットを返し、
# 完了後に last_task が元の種類に戻る
reset_tickets
mk_ticket 0001 investigation 20_done false
mk_ticket 0003 investigation 00_todo false
mk_ticket 0002 design-plan 00_todo false 0003
bd="$(st)"
assert_eq "BD-T13" "0003" "$(printf '%s' "$bd" | tl_jq -r '.next')"
assert_eq "BD-T13" "investigation" "$(printf '%s' "$bd" | tl_jq -r '.type')"
assert_eq "BD-T13" "false" "$(printf '%s' "$bd" | tl_jq -r '.at_boundary')"
mkdir -p wip/10_tickets/20_done
mv wip/10_tickets/00_todo/0003-investigation.md wip/10_tickets/20_done/
bd="$(st)"
assert_eq "BD-T13" "investigation" "$(printf '%s' "$bd" | tl_jq -r '.last_task.task_type')"
assert_eq "BD-T13" "0003" "$(printf '%s' "$bd" | tl_jq -r '.last_task.last_done')"
assert_eq "BD-T13" "true" "$(printf '%s' "$bd" | tl_jq -r '.at_boundary')"

finish
