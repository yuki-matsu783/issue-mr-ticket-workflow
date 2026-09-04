#!/usr/bin/env bash
# test_session_start.sh — session-start.sh のテスト（仕様のテスト ID: SE-T01〜10）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*session_start*'
# テストは set -e を使わない（終了コードは hook_run が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

REAL="$LOGGER_ROOT/.claude"

make_tmp_repo
cd "$TMP_REPO" || exit 2
mkdir -p .claude/hooks/00-SessionStart .claude/hooks/lib .claude/hooks/config \
         .claude/skills/20-common-step-shell-script/scripts \
         .claude/skills/20-common-step-commit-push/scripts .claude/skills/20-common-step-commit-push/assets \
         .claude/skills/20-common-step-ticket/scripts .claude/skills/20-common-step-ticket/assets \
         .claude/skills/00-workflow-issue-mr-driven/scripts
cp "$REAL/hooks/00-SessionStart/session-start.sh" .claude/hooks/00-SessionStart/
cp "$REAL/hooks/lib/hook-common.sh" .claude/hooks/lib/
cp "$REAL/hooks/config/task-types.tsv" .claude/hooks/config/
cp "$REAL"/skills/20-common-step-shell-script/scripts/*.sh .claude/skills/20-common-step-shell-script/scripts/
cp "$REAL"/skills/20-common-step-commit-push/scripts/*.sh .claude/skills/20-common-step-commit-push/scripts/
cp "$REAL"/skills/20-common-step-commit-push/assets/exclude-patterns.txt .claude/skills/20-common-step-commit-push/assets/
cp "$REAL"/skills/20-common-step-ticket/scripts/*.sh .claude/skills/20-common-step-ticket/scripts/
cp "$REAL"/skills/20-common-step-ticket/assets/ticket.template.md .claude/skills/20-common-step-ticket/assets/
cp "$REAL"/skills/00-workflow-issue-mr-driven/scripts/boundary.sh .claude/skills/00-workflow-issue-mr-driven/scripts/
TMP_HOOK="$TMP_REPO/.claude/hooks/00-SessionStart/session-start.sh"
B=".claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh"

printf 'logs/\n' > .gitignore
printf '# t\n' > README.md
git add -A >/dev/null 2>&1
git commit -q -m "chore: init"
git remote add origin https://github.com/acme/demo.git
git checkout -q -b feature-12-login

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
item_lines() { printf '%s\n' "$R_OUT" | grep -c '^- ' || true; }
last_note() { tail -n 1 "$TMP_REPO/logs/hooks/decisions.jsonl" 2>/dev/null | tl_jq -r '.note // ""'; }

mk_ticket() { # $1=番号 $2=種類 $3=置き場 $4=human_review
  mkdir -p "wip/10_tickets/$3"
  cat > "wip/10_tickets/$3/$1-$2.md" <<TICKETEOF
---
type: ticket
ticket_type: $2
predecessors: []
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

# $1 テスト
TICKETEOF
}
reset_all() { rm -rf wip logs; mkdir -p logs; }
mk_mr() { printf '{"host":"github","issue":12,"mr":13,"url":"https://github.com/acme/demo/pull/13"}\n' > logs/mr.json; }
mk_review() { # $1=state $2=task_type $3=last_done
  printf '{"mr":13,"boundary":{"task_type":"%s","tickets":["%s"],"last_done":"%s"},"state":"%s","via":"cli","requested_at":"2026-09-01T10:00:00+09:00"}\n' \
    "$2" "$3" "$3" "$1" > logs/review-state.json
}

# ================================================================ SE-T01
# チケットあり・MR あり・requested で 6 行の形式と「レビュー待ち」「応答を終える」が出る
reset_all
mk_ticket 0003 investigation 20_done false
mk_ticket 0005 design-plan 00_todo false
mk_mr
mk_review requested investigation 0003
hook_run startup ""
assert_exit "SE-T01" 0
assert_contains "SE-T01" "[WF701] 現在地（機構が導出）"
assert_eq "SE-T01" "6" "$(item_lines)"
assert_contains "SE-T01" "レビュー待ち"
assert_contains "SE-T01" "応答を終える"
assert_contains "SE-T01" "#13 https://github.com/acme/demo/pull/13"
assert_contains "SE-T01" "（issue #12）"

# ================================================================ SE-T02
# チケットも MR も無ければ 2 行だけ。default ブランチでも同じ
reset_all
hook_run startup ""
assert_exit "SE-T02" 0
assert_eq "SE-T02" "1" "$(item_lines)"
assert_contains "SE-T02" "進行中の作業は無い"
OUT_FEATURE="$R_OUT"
git checkout -q main
hook_run startup ""
assert_eq "SE-T02" "$OUT_FEATURE" "$R_OUT"
git checkout -q feature-12-login

# ================================================================ SE-T03
# チケットあり・MR 無しで「全体計画の途中」と 10-task-overall-plan
reset_all
mk_ticket 0001 overall-plan 10_doing false
hook_run startup ""
assert_exit "SE-T03" 0
assert_contains "SE-T03" "全体計画の途中（issue 確定前）"
assert_contains "SE-T03" "10-task-overall-plan"

# ================================================================ SE-T04
# チケット無し・merge-state.state=cleaned で「マージ前作業中」と release の再実行
reset_all
mk_mr
printf '{"issue":12,"mr":13,"state":"cleaned","via":"cli"}\n' > logs/merge-state.json
hook_run startup ""
assert_exit "SE-T04" 0
assert_contains "SE-T04" "マージ前作業中（merge-state: cleaned"
assert_contains "SE-T04" "finalize.sh release"
assert_contains "SE-T04" "- マージ前作業: cleaned（draft 未解除"

# ================================================================ SE-T05
# 前半: review-state.json 破損で WF702 が該当行に出て他の行は出る
reset_all
mk_ticket 0003 investigation 20_done false
mk_mr
printf '{壊れている\n' > logs/review-state.json
hook_run startup ""
assert_exit "SE-T05" 0
assert_contains "SE-T05" "[WF702] 破損: logs/review-state.json"
assert_contains "SE-T05" "- ブランチ: feature-12-login"
assert_contains "SE-T05" "- マージ前作業: 無し"

# 後半: jq が無ければ無出力・終了 0
make_restricted_path bash cat find rm mkdir mv printf git grep sed awk
R_ERR=""
R_OUT="$(mk_payload startup "" | env PATH="$RESTRICTED_PATH" bash "$TMP_HOOK" 2>/dev/null)"
R_EXIT=$?
assert_eq "SE-T05" "" "$R_OUT"
assert_exit "SE-T05" 0

# ================================================================ SE-T06
# 前半: source=compact でも startup と同じ内容。後半: サブエージェントの開始では無出力
reset_all
mk_ticket 0003 investigation 20_done false
mk_ticket 0005 design-plan 00_todo false
mk_mr
mk_review requested investigation 0003
hook_run startup ""
OUT_STARTUP="$R_OUT"
hook_run compact ""
assert_eq "SE-T06" "$OUT_STARTUP" "$R_OUT"

hook_run startup agent1
assert_eq "SE-T06" "" "$R_OUT"
assert_exit "SE-T06" 0
hook_run startup "" CLAUDE_AGENT_ID=agent2
assert_eq "SE-T06" "" "$R_OUT"
assert_exit "SE-T06" 0

# 停止中は 1 行だけ
hook_run startup "" WORKFLOW_ENFORCE=0
assert_contains "SE-T06" "機構は停止中"
hook_run startup "" WORKFLOW_SESSION_START_ENFORCE=0
assert_contains "SE-T06" "機構は停止中"

# ================================================================ SE-T07
# 8 KB 超で警告行が先頭に付き、切り詰めない
reset_all
mk_ticket 0003 investigation 20_done false
LONG="$(printf 'x%.0s' $(seq 1 9000))"
MSYS_NO_PATHCONV=1 jq -nc --arg u "https://github.com/acme/demo/pull/13?$LONG" \
  '{host:"github",issue:12,mr:13,url:$u}' > logs/mr.json
hook_run startup ""
assert_exit "SE-T07" 0
if printf '%s' "$R_OUT" | head -n 1 | grep -q '^\[警告\] 注入が 8 KB を超過'; then pass "SE-T07"; else fail "SE-T07" "警告行が先頭に無い: $(printf '%s' "$R_OUT" | head -n 1 | cut -c1-60)"; fi
if printf '%s' "$R_OUT" | grep -q "$LONG"; then pass "SE-T07"; else fail "SE-T07" "切り詰められている"; fi
assert_contains "SE-T07" "[WF701] 現在地（機構が導出）"

# ================================================================ SE-T08
# boundary.sh status --offline と同じ position を伝える（両者の結果を同じ入力で比較）
expect_label() {
  case "$1" in
    in_task) printf 'タスクの途中' ;;
    before_request) printf 'レビュー依頼前' ;;
    requested) printf 'レビュー待ち' ;;
    completed) printf 'レビュー済み' ;;
    merge_prep) printf 'マージ前作業中' ;;
    *) printf '進行中の作業は無い' ;;
  esac
}
check_same_position() { # $1=テスト ID
  local pos
  pos="$(bash "$B" status --offline 2>/dev/null | tl_jq -r '.position')"
  hook_run startup ""
  assert_contains "$1" "$(expect_label "$pos")"
}
reset_all; mk_ticket 0003 investigation 20_done false; mk_ticket 0005 design-plan 00_todo false; mk_mr
check_same_position "SE-T08"                                  # before_request
mk_review requested investigation 0003
check_same_position "SE-T08"                                  # requested
reset_all; mk_ticket 0004 investigation 10_doing false; mk_mr
check_same_position "SE-T08"                                  # in_task
reset_all; mk_mr; printf '{"issue":12,"mr":13,"state":"pushed"}\n' > logs/merge-state.json
check_same_position "SE-T08"                                  # merge_prep

# ================================================================ SE-T09
# CLI の有無・GH_TOKEN の有無で出力が変わらない
reset_all
mk_ticket 0003 investigation 20_done false
mk_ticket 0005 design-plan 00_todo false
mk_mr
mk_review requested investigation 0003
hook_run startup ""
OUT_PLAIN="$R_OUT"
make_tmp_dir; FAKE="$TMP_DIR"
printf '#!/bin/bash\nprintf "gh を呼んではならない\\n" >&2\nexit 1\n' > "$FAKE/gh"; chmod +x "$FAKE/gh"
printf '#!/bin/bash\nprintf "glab を呼んではならない\\n" >&2\nexit 1\n' > "$FAKE/glab"; chmod +x "$FAKE/glab"
hook_run startup "" "PATH=$FAKE:$PATH" GH_TOKEN=dummy-token
assert_eq "SE-T09" "$OUT_PLAIN" "$R_OUT"
hook_run startup "" GH_TOKEN=another-token
assert_eq "SE-T09" "$OUT_PLAIN" "$R_OUT"

# ================================================================ SE-T10
# boundary.sh を新しい置き場に置くと注入され、旧い置き場だけに置くと注入されず skip の理由が「不在」になる
reset_all
mk_ticket 0003 investigation 20_done false
mk_mr
hook_run startup ""
assert_contains "SE-T10" "[WF701] 現在地（機構が導出）"

rm -rf logs/hooks
mv "$B" .claude/hooks/boundary.sh          # 旧い置き場だけに置く
hook_run startup ""
assert_eq "SE-T10" "" "$R_OUT"
assert_exit "SE-T10" 0
if [[ "$(last_note)" == *"boundary.sh 不在"* ]]; then pass "SE-T10"; else fail "SE-T10" "skip の理由が不在になっていない: $(last_note)"; fi
mkdir -p "${B%/*}"; mv .claude/hooks/boundary.sh "$B"

finish
