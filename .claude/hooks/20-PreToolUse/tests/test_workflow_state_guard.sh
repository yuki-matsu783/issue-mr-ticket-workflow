#!/usr/bin/env bash
# test_workflow_state_guard.sh — workflow-state-guard.sh のテスト（仕様のテスト ID: SG-T01〜SG-T13）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*workflow_state_guard*'
# テストは set -e を使わない（終了コードは judge が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SRC="$LOGGER_ROOT/.claude/hooks"
SK="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/20-PreToolUse" "$TMP_REPO/.claude/hooks/lib" "$TMP_REPO/.claude/hooks/config" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts" \
         "$TMP_REPO/wip/10_tickets/00_todo" "$TMP_REPO/wip/10_tickets/10_doing" "$TMP_REPO/wip/10_tickets/20_done" \
         "$TMP_REPO/wip/tmp" "$TMP_REPO/logs"
cp "$SRC/20-PreToolUse/workflow-state-guard.sh" "$TMP_REPO/.claude/hooks/20-PreToolUse/"
cp "$SRC/lib/hook-common.sh" "$SRC/lib/cmdpos.sh" "$SRC/lib/scope.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$SK/logger.sh" "$SK/frontmatter.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"
cp "$SRC/config/scope-limits.json" "$TMP_REPO/.claude/hooks/config/"
TMP_HOOK="$TMP_REPO/.claude/hooks/20-PreToolUse/workflow-state-guard.sh"
LIMITS="$TMP_REPO/.claude/hooks/config/scope-limits.json"
LIMITS_JSON="$(cat "$LIMITS")"

printf 'ticket\n' > "$TMP_REPO/wip/10_tickets/10_doing/0003-implementation.md"
printf 'ticket\n' > "$TMP_REPO/wip/10_tickets/00_todo/0004-implementation.md"
printf 'ticket\n' > "$TMP_REPO/wip/10_tickets/20_done/0001-overall-plan.md"
printf '{}\n' > "$TMP_REPO/logs/review-state.json"
printf '{}\n' > "$TMP_REPO/logs/merge-state.json"

lab() { # $1=フックの出力 → 1 語
  case "$1" in
    *WF301*) printf 'WF301\n' ;; *WF302*) printf 'WF302\n' ;; *WF303*) printf 'WF303\n' ;;
    *WF304*) printf 'WF304\n' ;; *WF309*) printf 'WF309\n' ;;
    "")      printf 'allow\n' ;; *) printf 'other:%s\n' "$1" ;;
  esac
}
payload() { # $1=キー種別（command|file_path|mcp） $2=値 $3=ツール名 [$4=draft]
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc \
    --arg k "$1" --arg v "$2" --arg t "$3" --arg d "${4:-}" --arg cwd "$TMP_REPO" '
    {hook_event_name: "PreToolUse", tool_name: $t, session_id: "testsession", cwd: $cwd, tool_input: {}}
    | (if $k == "command" then .tool_input.command = $v
       elif $k == "file_path" then .tool_input.file_path = $v
       else . end)
    | (if $d != "" then .tool_input.draft = ($d == "true") else . end)' | tr -d '\r'
}
tc() { lab "$(payload command "$1" "${2:-Bash}" | bash "$TMP_HOOK" 2>/dev/null)"; }
tf() { lab "$(payload file_path "$TMP_REPO/$1" "${2:-Write}" | bash "$TMP_HOOK" 2>/dev/null)"; }
tm() { lab "$(payload mcp "" "$1" "${2:-}" | bash "$TMP_HOOK" 2>/dev/null)"; }

# cwd を差し替えた入力（SG-T12 / SG-T13）。MSYS のパス変換を止めないと /tmp/... が Windows パスに化ける
payload_at() { # $1=cwd $2=キー種別（command|file_path） $3=値 $4=ツール名
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc \
    --arg k "$2" --arg v "$3" --arg t "$4" --arg cwd "$1" '
    {hook_event_name: "PreToolUse", tool_name: $t, session_id: "testsession", cwd: $cwd, tool_input: {}}
    | (if $k == "command" then .tool_input.command = $v
       elif $k == "file_path" then .tool_input.file_path = $v
       else . end)' | tr -d '\r'
}
tfa() { lab "$(payload_at "$1" file_path "$2" "${3:-Write}" | bash "$TMP_HOOK" 2>/dev/null)"; }
tca() { lab "$(payload_at "$1" command "$2" "${3:-Bash}" | bash "$TMP_HOOK" 2>/dev/null)"; }

# ---- SG-T01: 進行状態ファイル ----
case_state_files() {
  assert_eq "SG-T01" "WF301" "$(tf 'logs/review-state.json')"
  assert_eq "SG-T01" "WF301" "$(tf 'logs/review-state.json' Edit)"
  assert_eq "SG-T01" "WF301" "$(tf 'logs/mr.json')"
  assert_eq "SG-T01" "WF301" "$(tf 'logs/review-history.jsonl')"
  assert_eq "SG-T01" "WF301" "$(tc 'echo x > logs/review-state.json')"
  assert_eq "SG-T01" "WF301" "$(tc 'rm logs/merge-state.json')"
  assert_eq "SG-T01" "WF301" "$(tc 'git checkout -- logs/review-state.json')"
  assert_eq "SG-T01" "WF301" "$(tc 'git restore logs/review-state.json')"
  assert_eq "SG-T01" "WF301" "$(tc 'cp x logs/review-state.json')"
  assert_eq "SG-T01" "WF301" "$(tc 'jq . a.json > logs/mr.json')"
  # 読むだけは通す
  assert_eq "SG-T01" "allow" "$(tc 'cat logs/review-state.json')"
  assert_eq "SG-T01" "allow" "$(tc 'grep x logs/review-state.json')"
  assert_eq "SG-T01" "allow" "$(tc 'git diff logs/review-state.json')"
  assert_eq "SG-T01" "allow" "$(tc 'jq . logs/mr.json')"
}

# ---- SG-T02: 置き場への移動・作成、置き場からの削除 ----
case_placement() {
  assert_eq "SG-T02" "WF302" "$(tc 'mv wip/10_tickets/00_todo/0004-implementation.md wip/10_tickets/10_doing/')"
  assert_eq "SG-T02" "WF302" "$(tc 'git mv wip/10_tickets/00_todo/0004-implementation.md wip/10_tickets/10_doing/0004.md')"
  assert_eq "SG-T02" "WF303" "$(tc 'mv wip/10_tickets/10_doing/0003-implementation.md wip/10_tickets/20_done/')"
  assert_eq "SG-T02" "WF302" "$(tc 'touch wip/10_tickets/10_doing/x.md')"
  # 元（消える側）
  assert_eq "SG-T02" "WF302" "$(tc 'rm wip/10_tickets/10_doing/0003-implementation.md')"
  assert_eq "SG-T02" "WF302" "$(tc 'git rm wip/10_tickets/10_doing/0003-implementation.md')"
  assert_eq "SG-T02" "WF303" "$(tc 'rm wip/10_tickets/20_done/0001-overall-plan.md')"
  assert_eq "SG-T02" "WF303" "$(tc 'git rm -f wip/10_tickets/20_done/0001-overall-plan.md')"
  # 負のコントロール
  assert_eq "SG-T02" "allow" "$(tc 'rm wip/tmp/x.txt')"
  assert_eq "SG-T02" "allow" "$(tc 'mv a.txt b.txt')"
}

# ---- SG-T03: 作業中チケット本文の編集と未着手への作成は通る ----
case_allowed_writes() {
  assert_eq "SG-T03" "allow" "$(tf 'wip/10_tickets/10_doing/0003-implementation.md' Edit)"
  assert_eq "SG-T03" "allow" "$(tf 'wip/10_tickets/10_doing/0003-implementation.md' Write)"
  assert_eq "SG-T03" "allow" "$(tf 'wip/10_tickets/00_todo/0004-implementation.md' Write)"
  assert_eq "SG-T03" "allow" "$(tf 'wip/10_tickets/00_todo/0005-new.md' Write)"
  assert_eq "SG-T03" "allow" "$(tf 'README.md' Write)"
  # 作業中の置き場への新規作成だけを止める
  assert_eq "SG-T03" "WF302" "$(tf 'wip/10_tickets/10_doing/9999-new.md' Write)"
  # 完了の置き場は既存でも拒否
  assert_eq "SG-T03" "WF303" "$(tf 'wip/10_tickets/20_done/0001-overall-plan.md' Edit)"
}

# ---- SG-T04: draft 解除 ----
case_ready() {
  assert_eq "SG-T04" "WF304" "$(tc 'gh pr ready 13')"
  assert_eq "SG-T04" "WF304" "$(tc 'gh pr edit 13 --ready')"
  assert_eq "SG-T04" "WF304" "$(tc 'glab mr update 13 --ready')"
  assert_eq "SG-T04" "WF304" "$(tc 'gh api repos/o/r/pulls/13 -X PATCH -f draft=false')"
  assert_eq "SG-T04" "allow" "$(tc 'gh pr view 13')"
  assert_eq "SG-T04" "allow" "$(tc 'gh pr list')"
  assert_eq "SG-T04" "allow" "$(tc 'gh issue list --search ready')"
}

# ---- SG-T05: 提供コマンドは通る ----
case_provided() {
  assert_eq "SG-T05" "allow" "$(tc 'bash .claude/skills/20-common-step-ticket/scripts/ticket.sh start 0003')"
  assert_eq "SG-T05" "allow" "$(tc 'bash .claude/skills/20-common-step-ticket/scripts/ticket.sh complete 0003')"
  assert_eq "SG-T05" "allow" "$(tc 'bash .claude/skills/10-task-overall-summary/scripts/finalize.sh release')"
  assert_eq "SG-T05" "allow" "$(tc 'bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh request --body-file x.md')"
}

# ---- SG-T06: opaque ----
case_opaque() {
  assert_eq "SG-T06" "WF309" "$(tc 'bash -c "cat logs/review-state.json"')"
  assert_eq "SG-T06" "WF309" "$(tc 'eval "gh pr ready 13"')"
  assert_eq "SG-T06" "allow" "$(tc 'bash -c "ls -la"')"
  assert_eq "SG-T06" "allow" "$(tc 'eval "echo hello"')"
}

# ---- SG-T07: 作業中チケットの有無で結果が変わらない ----
case_no_ticket() {
  mv "$TMP_REPO/wip/10_tickets/10_doing/0003-implementation.md" "$TMP_REPO/wip/10_tickets/00_todo/" 2>/dev/null
  assert_eq "SG-T07" "WF301" "$(tf 'logs/review-state.json')"
  assert_eq "SG-T07" "WF303" "$(tc 'rm wip/10_tickets/20_done/0001-overall-plan.md')"
  assert_eq "SG-T07" "WF304" "$(tc 'gh pr ready 13')"
  assert_eq "SG-T07" "WF302" "$(tf 'wip/10_tickets/10_doing/9999-new.md' Write)"
  mv "$TMP_REPO/wip/10_tickets/00_todo/0003-implementation.md" "$TMP_REPO/wip/10_tickets/10_doing/" 2>/dev/null
}

# ---- SG-T08: 地の文・コメントでは拒否しない ----
case_text() {
  assert_eq "SG-T08" "allow" "$(tc 'echo "review-state.json は提供コマンドで更新する"')"
  assert_eq "SG-T08" "allow" "$(tc 'ls # 20_done は触らない')"
  assert_eq "SG-T08" "allow" "$(tc $'cat <<EOF\ngh pr ready 13\nEOF')"
  assert_eq "SG-T08" "allow" "$(tc 'grep -r "10_doing" docs/')"
  assert_eq "SG-T08" "allow" "$(tc 'echo "draft を解除する前に確認する"')"
}

# ---- SG-T09: MCP は draft 解除だけを塞ぐ ----
case_mcp() {
  assert_eq "SG-T09" "WF304" "$(tm mcp__github__update_pull_request false)"
  assert_eq "SG-T09" "allow" "$(tm mcp__github__update_pull_request true)"
  assert_eq "SG-T09" "allow" "$(tm mcp__github__update_pull_request)"
  assert_eq "SG-T09" "allow" "$(tm mcp__github__get_issue)"
  assert_eq "SG-T09" "allow" "$(tm mcp__github__add_issue_comment)"
  assert_eq "SG-T09" "allow" "$(tm mcp__github__pull_request_read)"
  assert_eq "SG-T09" "allow" "$(tm mcp__gitlab__list_merge_requests)"
}

# ---- SG-T10: 設定が読めなくても拒否に倒さない ----
case_broken_config() {
  local out
  rm -rf "$TMP_REPO/logs/hooks"
  printf 'broken' > "$LIMITS"
  # 既定の state_files で判定を続ける
  assert_eq "SG-T10" "WF301" "$(tf 'logs/review-state.json')"
  assert_eq "SG-T10" "WF303" "$(tc 'rm wip/10_tickets/20_done/0001-overall-plan.md')"
  assert_eq "SG-T10" "WF304" "$(tc 'gh pr ready 13')"
  # scope-limits.json 自身への書き込みはこのフックを通る（WF210 の復旧経路を潰さない）
  assert_eq "SG-T10" "allow" "$(tf '.claude/hooks/config/scope-limits.json' Write)"
  # フォールバックした旨が記録に残る
  out="$(cat "$TMP_REPO/logs/hooks/decisions.jsonl" 2>/dev/null)"
  case "$out" in *フォールバック*) pass "SG-T10" ;; *) fail "SG-T10" "フォールバックの記録が無い" ;; esac
  case "$out" in *'"decision":"notify"'*) pass "SG-T10" ;; *) fail "SG-T10" "notify で記録されていない" ;; esac

  # 設定が無い場合も同じ
  rm -f "$LIMITS"
  assert_eq "SG-T10" "WF301" "$(tf 'logs/merge-state.json')"
  assert_eq "SG-T10" "allow" "$(tf 'README.md')"
  printf '%s\n' "$LIMITS_JSON" > "$LIMITS"
}

# ---- SG-T11: 置き場ごとの削除 ----
case_wipe() {
  assert_eq "SG-T11" "WF303" "$(tc 'rm -rf wip/10_tickets/20_done')"
  assert_eq "SG-T11" "WF302" "$(tc 'rm -rf wip/10_tickets/10_doing')"
  assert_eq "SG-T11" "WF302" "$(tc 'rm -rf wip/10_tickets')"
  assert_eq "SG-T11" "WF302" "$(tc 'rm -rf wip')"
  assert_eq "SG-T11" "WF302" "$(tc 'rm -rf .')"
  # 負のコントロール
  assert_eq "SG-T11" "allow" "$(tc 'rm -rf wip/tmp')"
  assert_eq "SG-T11" "allow" "$(tc 'rm -rf logs')"
  assert_eq "SG-T11" "allow" "$(tc 'rm -rf node_modules')"
}

# ---- SG-T12: 他の作業ツリーの保護対象を絶対パスで書く ----
# 本流（TMP_REPO）とそこから切った作業ツリーを相互参照付きで用意する（git worktree add は呼ばない）
SG_WT=""; SG_OUT=""
sg_wt_fixture() { # $1=作業ツリーの置き場 $2=登録名
  mkdir -p "$1/.claude" "$1/wip/10_tickets/00_todo" "$1/wip/10_tickets/10_doing" \
           "$1/wip/10_tickets/20_done" "$1/wip/tmp" "$1/logs" "$TMP_REPO/.git/worktrees/$2"
  printf 'gitdir: %s/.git/worktrees/%s\n' "$TMP_REPO" "$2" > "$1/.git"
  printf '%s\n' "$1/.git" > "$TMP_REPO/.git/worktrees/$2/gitdir"
  return 0
}
case_cross_worktree() {
  local bs
  make_tmp_dir
  SG_WT="$TMP_DIR/wt"; SG_OUT="$TMP_DIR/outside"
  sg_wt_fixture "$SG_WT" w1
  mkdir -p "$SG_OUT/logs" "$SG_OUT/wip/10_tickets/20_done"
  printf 'ticket\n' > "$SG_WT/wip/10_tickets/20_done/0002-x.md"
  # cwd=worktree から本流の保護対象を絶対パスで指しても、同じ理由・同じ識別子で拒否される
  assert_eq "SG-T12" "WF303" "$(tfa "$SG_WT" "$TMP_REPO/wip/10_tickets/20_done/0001-overall-plan.md" Write)"
  assert_eq "SG-T12" "WF303" "$(tfa "$SG_WT" "$TMP_REPO/wip/10_tickets/20_done/0001-overall-plan.md" Edit)"
  assert_eq "SG-T12" "WF302" "$(tfa "$SG_WT" "$TMP_REPO/wip/10_tickets/10_doing/9999-new.md" Write)"
  assert_eq "SG-T12" "WF301" "$(tca "$SG_WT" "echo x > $TMP_REPO/logs/mr.json")"
  assert_eq "SG-T12" "WF301" "$(tfa "$SG_WT" "$TMP_REPO/logs/review-state.json" Write)"
  # 自分の作業ツリーの側の保護対象も同じ（保護は作業ツリーの数に依らない）
  assert_eq "SG-T12" "WF303" "$(tfa "$SG_WT" "$SG_WT/wip/10_tickets/20_done/0002-x.md" Edit)"
  # `.` / `..` を挟んだ形
  assert_eq "SG-T12" "WF303" "$(tfa "$SG_WT" "$TMP_REPO/wip/../wip/10_tickets/20_done/0001-overall-plan.md" Write)"
  assert_eq "SG-T12" "WF301" "$(tca "$SG_WT" "echo x > $TMP_REPO/logs/./mr.json")"
  # `\` 区切りの形
  bs="${TMP_REPO//\//\\}"
  assert_eq "SG-T12" "WF303" "$(tfa "$SG_WT" "$bs\\wip\\10_tickets\\20_done\\0001-overall-plan.md" Write)"
  assert_eq "SG-T12" "WF301" "$(tfa "$SG_WT" "$bs\\logs\\review-state.json" Write)"
  # 根の配下に置かれた作業ツリー（`git worktree add ./sub-wt`・隔離が作る <root>/.claude/worktrees/<名前>）も同じ。
  # 畳み込みを前方一致の順で決めると短いほうの根（本流）に先に畳まれ、
  # `sub-wt/wip/10_tickets/20_done/…` というルート相対に化けて保護が外れる
  sg_wt_fixture "$TMP_REPO/sub-wt" w2
  sg_wt_fixture "$TMP_REPO/.claude/worktrees/nw" w3
  printf 'ticket\n' > "$TMP_REPO/sub-wt/wip/10_tickets/20_done/0003-y.md"
  printf 'ticket\n' > "$TMP_REPO/.claude/worktrees/nw/wip/10_tickets/20_done/0004-z.md"
  assert_eq "SG-T12" "WF303" "$(tfa "$SG_WT" "$TMP_REPO/sub-wt/wip/10_tickets/20_done/0003-y.md" Write)"
  assert_eq "SG-T12" "WF302" "$(tfa "$SG_WT" "$TMP_REPO/sub-wt/wip/10_tickets/10_doing/9999-new.md" Write)"
  assert_eq "SG-T12" "WF301" "$(tca "$SG_WT" "echo x > $TMP_REPO/sub-wt/logs/mr.json")"
  assert_eq "SG-T12" "WF303" "$(tfa "$SG_WT" "$TMP_REPO/.claude/worktrees/nw/wip/10_tickets/20_done/0004-z.md" Edit)"
  assert_eq "SG-T12" "WF301" "$(tfa "$SG_WT" "$TMP_REPO/.claude/worktrees/nw/logs/review-state.json" Write)"
  # 作業ツリーの中でも、既存の作業中チケットの更新は通る（畳んだ根から実在を見る）
  printf 'ticket\n' > "$TMP_REPO/sub-wt/wip/10_tickets/10_doing/0005-w.md"
  assert_eq "SG-T12" "allow" "$(tfa "$SG_WT" "$TMP_REPO/sub-wt/wip/10_tickets/10_doing/0005-w.md" Edit)"
  # 負のコントロール: 接頭辞が同じだけの別ディレクトリは本流のパスのまま（保護対象に当たらない）
  assert_eq "SG-T12" "allow" "$(tfa "$SG_WT" "$TMP_REPO/sub-wt-x/wip/10_tickets/20_done/0003-y.md" Write)"
  # 負のコントロール: 同一リポジトリの外の同名ファイルは通る
  assert_eq "SG-T12" "allow" "$(tfa "$SG_WT" "$SG_OUT/logs/mr.json" Write)"
  assert_eq "SG-T12" "allow" "$(tca "$SG_WT" "echo x > $SG_OUT/logs/mr.json")"
  assert_eq "SG-T12" "allow" "$(tfa "$SG_WT" "$SG_OUT/wip/10_tickets/20_done/0001-x.md" Write)"
}

# ---- SG-T13: 作業ツリーの集合を読めないときは許可に倒さない ----
case_worktrees_unreadable() {
  # `.git/worktrees` が在るのに列挙できない状態（ディレクトリでない）にする
  rm -rf "$TMP_REPO/.git/worktrees"
  printf 'not a directory\n' > "$TMP_REPO/.git/worktrees"
  assert_eq "SG-T13" "WF309" "$(tfa "$TMP_REPO" "$SG_OUT/logs/mr.json" Write)"
  assert_eq "SG-T13" "WF309" "$(tca "$TMP_REPO" "echo x > $SG_OUT/logs/mr.json")"
  assert_eq "SG-T13" "WF309" "$(tfa "$TMP_REPO" "$SG_OUT/wip/10_tickets/20_done/0001-x.md" Write)"
  # 全面拒否にはならない（リポジトリ内と確定できるパスは従来どおり判定できる）
  assert_eq "SG-T13" "WF301" "$(tf 'logs/review-state.json')"
  assert_eq "SG-T13" "allow" "$(tf 'README.md')"
  # 負のコントロール: worktree が 1 つも無い（.git/worktrees が存在しない）だけなら WF309 にならない
  rm -f "$TMP_REPO/.git/worktrees"
  assert_eq "SG-T13" "allow" "$(tfa "$TMP_REPO" "$SG_OUT/logs/mr.json" Write)"
  assert_eq "SG-T13" "allow" "$(tfa "$TMP_REPO" "$SG_OUT/wip/10_tickets/20_done/0001-x.md" Write)"
  assert_eq "SG-T13" "WF301" "$(tf 'logs/review-state.json')"
  assert_eq "SG-T13" "allow" "$(tf 'README.md')"
}

# ---- 停止中・入力不正・外部プロセス ----
case_misc() {
  local out rc
  out="$(payload file_path "$TMP_REPO/logs/review-state.json" Write | WORKFLOW_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "SG-T07" "" "$out"
  out="$(payload file_path "$TMP_REPO/logs/review-state.json" Write | WORKFLOW_STATE_GUARD_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "SG-T07" "" "$out"

  out="$(printf 'これは JSON ではない' | bash "$TMP_HOOK" 2>/dev/null)"; rc=$?
  case "$out" in *WF309*) pass "SG-T07" ;; *) fail "SG-T07" "入力不正で WF309 が出ない: $out" ;; esac
  assert_eq "SG-T07" "0" "$rc"

  # ホットパス: jq は 1 回、git / date / sed / find を呼ばない
  make_counting_path jq git date sed find awk grep cat tr cut head tail wc sort uniq
  local bash_bin; bash_bin="$(command -v bash)"
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" -c \
    "printf '%s' '$(payload command 'ls -la' Bash)' | '$bash_bin' '$TMP_HOOK'"
  assert_eq "SG-T07" "1" "$(counted_calls jq)"
  assert_eq "SG-T07" "0" "$(counted_calls git)"
  assert_eq "SG-T07" "0" "$(counted_calls date)"
  assert_eq "SG-T07" "0" "$(counted_calls sed)"
  assert_eq "SG-T07" "0" "$(counted_calls find)"
}

case_state_files
case_placement
case_allowed_writes
case_ready
case_provided
case_opaque
case_no_ticket
case_text
case_mcp
case_broken_config
case_wipe
# 作業ツリーの fixture は本流に .git/worktrees/<名前> を足し、SG-T13 はそれを壊すので他のケースの後に置く
case_cross_worktree
case_worktrees_unreadable
case_misc
finish
