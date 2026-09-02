#!/usr/bin/env bash
# test_post_push_usage_report.sh — post-push-usage-report.sh のテスト（仕様のテスト ID: UR-T01〜UR-T07）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*post_push_usage_report*'
# テストは set -e を使わない（終了コードは hook_* ヘルパが取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SRC="$LOGGER_ROOT/.claude/hooks"
SKILL_SCRIPTS="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts"

REMOTE="$(mktemp -d)/remote.git"
git init -q --bare -b main "$REMOTE"
make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/22-PostToolUse" "$TMP_REPO/.claude/hooks/lib" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts" "$TMP_REPO/tr"
cp "$SRC/22-PostToolUse/post-push-usage-report.sh" "$TMP_REPO/.claude/hooks/22-PostToolUse/"
cp "$SRC/lib/hook-common.sh" "$SRC/lib/cmdpos.sh" "$SRC/lib/push-detect.sh" "$SRC/lib/transcript.sh" \
   "$SRC/lib/probe-4c.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$SKILL_SCRIPTS/logger.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"
TMP_HOOK="$TMP_REPO/.claude/hooks/22-PostToolUse/post-push-usage-report.sh"
STATE="$TMP_REPO/logs/usage/main.json"

cd "$TMP_REPO" || exit 2
git remote add origin "$REMOTE"
printf 'a\n' > a.txt
git add a.txt >/dev/null 2>&1
git commit -q -m "init"
git push -q -u origin main 2>/dev/null

# ---- 固定の transcript ----
# assistant 行を 8 分間隔で並べる。9 個の間隔（480 秒）はすべて 10 分以内なので実作業時間に入る
mk_transcript() { # $1=出力パス $2=assistant 行数 $3=開始の時
  local i m h mm n="$2"
  : > "$1"
  for (( i = 0; i < n; i++ )); do
    m=$(( 8 * i ))
    h=$(( $3 + m / 60 )); mm=$(( m % 60 ))
    printf '{"type":"assistant","timestamp":"2026-09-01T%02d:%02d:00+09:00","message":{"usage":{"input_tokens":1234,"output_tokens":678,"cache_read_input_tokens":10000,"cache_creation_input_tokens":2000},"content":[{"type":"tool_use"},{"type":"tool_use"}]}}\n' \
      "$h" "$mm" >> "$1"
  done
}
TR_A="$TMP_REPO/tr/main.jsonl"
TR_B="$TMP_REPO/tr/other.jsonl"
TR_SUB="$TMP_REPO/tr/subagents/agent1.jsonl"
mkdir -p "$TMP_REPO/tr/subagents"
mk_transcript "$TR_A" 10 10     # 入力 12,340 / 出力 6,780 / 読取 100,000 / 書込 20,000 / ツール 20 / 応答 10 / 4320 秒
mk_transcript "$TR_B" 5 10      # 入力 6,170 / 出力 3,390 / ツール 10 / 応答 5
mk_transcript "$TR_SUB" 2 10    # 入力 2,468 / 出力 1,356 / ツール 4 / 応答 2

# ---- 呼び出し ----
mk_payload() { # $1=event $2=tool $3=session $4=transcript $5=agent_transcript $6=agent_id $7=command
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc \
    --arg ev "$1" --arg tn "$2" --arg sid "$3" --arg tp "$4" --arg atp "$5" --arg aid "$6" \
    --arg cmd "$7" --arg cwd "$TMP_REPO" '
    {hook_event_name: $ev, session_id: $sid, cwd: $cwd, transcript_path: $tp, tool_input: {}}
    | (if $tn != "" then .tool_name = $tn else . end)
    | (if $atp != "" then .agent_transcript_path = $atp else . end)
    | (if $aid != "" then .agent_id = $aid else . end)
    | (if $cmd != "" then .tool_input.command = $cmd else . end)' | tr -d '\r'
}

hook_acc() { # $1=event $2=session $3=transcript $4=agent_transcript $5=agent_id
  R_ERR=""
  R_OUT="$(mk_payload "$1" "" "$2" "$3" "${4:-}" "${5:-}" "" | bash "$TMP_HOOK" --accumulate 2>/dev/null)"
  R_EXIT=$?
  return 0
}

hook_push() { # $1=command $2=session $3=transcript
  R_ERR=""
  R_OUT="$(mk_payload PostToolUse Bash "$2" "$3" "" "" "$1" | bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  return 0
}

do_push() { # 新しいコミットを push して HEAD を進める
  printf '%s\n' "$RANDOM" >> a.txt
  git add a.txt >/dev/null 2>&1
  git commit -q -m "step"
  git push -q origin main 2>/dev/null
}

reset_state() { rm -rf "$TMP_REPO/logs"; }

sum_of() { tl_jq -r "$1" "$STATE" 2>/dev/null; }

# ---- UR-T01: 固定 transcript から集計値と本文の整形 ----
case_report() {
  reset_state
  hook_acc Stop sess1 "$TR_A"
  assert_eq "UR-T01" "12340" "$(sum_of '.sessions.sess1.input')"
  assert_eq "UR-T01" "4320" "$(sum_of '.sessions.sess1.active_seconds')"

  do_push
  hook_push 'git push' sess1 "$TR_A"
  assert_contains "UR-T01" "WF911"
  assert_contains "UR-T01" "入力 12,340 / 出力 6,780 / キャッシュ読取 100,000 / キャッシュ書込 20,000"
  assert_contains "UR-T01" "ツール実行: 20 回 / 応答: 10 回 / 実作業時間: 1 時間 12 分"
  assert_contains "UR-T01" "このブランチで 1 回目の push"
  assert_contains "UR-T01" "この集計は Claude Code のセッション記録から機構が機械的に算出したものです"
  assert_exit "UR-T01" 0
  # レポートは logs/usage/ に残る
  if [[ -f "$TMP_REPO/logs/usage/report-main-1.md" ]]; then pass "UR-T01"; else fail "UR-T01" "レポートが保存されていない"; fi
}

# ---- UR-T02: --accumulate を 2 回呼んでも二重計上しない ----
case_no_double() {
  reset_state
  hook_acc Stop sess1 "$TR_A"
  hook_acc Stop sess1 "$TR_A"
  assert_eq "UR-T02" "12340" "$(sum_of '.sessions.sess1.input')"
  assert_eq "UR-T02" "10" "$(sum_of '.sessions.sess1.last_offset')"
  # push 時の取り込みでも増えない（既に処理済みの行はカーソルで飛ばす）
  do_push
  hook_push 'git push' sess1 "$TR_A"
  assert_eq "UR-T02" "12340" "$(sum_of '.sessions.sess1.input')"
}

# ---- UR-T03: 2 セッションの合算とサブエージェント分 ----
case_multi() {
  reset_state
  hook_acc Stop sess1 "$TR_A"
  hook_acc Stop sess2 "$TR_B"
  # SubagentStop は agent_transcript_path を読む（transcript_path はメインのもの）
  hook_acc SubagentStop sess1 "$TR_A" "$TR_SUB" agent1
  assert_eq "UR-T03" "2468" "$(sum_of '.subagents.agent1.input')"
  assert_eq "UR-T03" "1" "$(sum_of '.subagents | length')"

  # 負のケース: agent_transcript_path が無い SubagentStop ではメイン分を subagents に積まない
  hook_acc SubagentStop sess1 "$TR_A" "" agent2
  assert_eq "UR-T03" "1" "$(sum_of '.subagents | length')"

  do_push
  hook_push 'git push' sess1 "$TR_A"
  # 12,340 + 6,170 + 2,468 = 20,978
  assert_contains "UR-T03" "入力 20,978"
  assert_contains "UR-T03" "サブエージェント: 1 体分を含む"
}

# ---- UR-T04: 投稿が完了していなければ繰り越しの注記が付く ----
case_carry_over() {
  reset_state
  hook_acc Stop sess1 "$TR_A"
  do_push
  hook_push 'git push' sess1 "$TR_A"
  assert_not_contains "UR-T04" "繰り越し"

  do_push
  hook_push 'git push' sess1 "$TR_A"
  assert_contains "UR-T04" "前回の投稿が完了していないため、前回分を繰り越して集計している"
  assert_contains "UR-T04" "このブランチで 2 回目の push"

  # boundary.sh が投稿に成功したときの状態（posted:true）では繰り越しの注記が付かない
  tl_jq -c '.posted = true' "$STATE" > "$STATE.new" && mv -f "$STATE.new" "$STATE"
  do_push
  hook_push 'git push' sess1 "$TR_A"
  assert_not_contains "UR-T04" "繰り越し"
}

# ---- UR-T05: 状態破損は WF913 と今回起点、transcript 不読は無出力 ----
case_broken() {
  reset_state
  hook_acc Stop sess1 "$TR_A"
  printf 'broken' > "$STATE"
  do_push
  hook_push 'git push' sess1 "$TR_A"
  assert_contains "UR-T05" "WF913"
  assert_contains "UR-T05" "蓄積の記録が壊れていたため、今回の push を起点に作り直した"
  assert_exit "UR-T05" 0

  # transcript が読めない（蓄積も無い）なら何も出さない
  reset_state
  do_push
  hook_push 'git push' sess1 "$TMP_REPO/tr/none.jsonl"
  assert_eq "UR-T05" "" "$R_OUT"
  assert_exit "UR-T05" 0
}

# ---- UR-T06: MR が無ければ「投稿先が無い」の注記 ----
case_no_mr() {
  reset_state
  hook_acc Stop sess1 "$TR_A"
  do_push
  hook_push 'git push' sess1 "$TR_A"
  assert_contains "UR-T06" "MR が未記録のため投稿先が無い"

  mkdir -p "$TMP_REPO/logs"
  printf '{"host":"github","issue":9,"mr":12,"url":"https://example.invalid/pr/12"}\n' > "$TMP_REPO/logs/mr.json"
  do_push
  hook_push 'git push' sess1 "$TR_A"
  assert_not_contains "UR-T06" "投稿先が無い"
  assert_contains "UR-T06" "boundary.sh request / note"
  rm -f "$TMP_REPO/logs/mr.json"
}

# ---- UR-T07: push でなければ何もしない / 起点は自分の状態から取る ----
case_detect() {
  reset_state
  hook_acc Stop sess1 "$TR_A"
  do_push
  hook_push 'git status' sess1 "$TR_A"
  assert_eq "UR-T07" "" "$R_OUT"
  assert_exit "UR-T07" 0

  # post-push-compact-prompt が先に走って push-state.json を進めていても、
  # 起点は usage/<branch>.json の last_push_sha なので検知は通る（DDR i0009-24）
  mkdir -p "$TMP_REPO/logs"
  printf '{"main":{"sha":"%s","at":"2026-09-01T00:00:00+09:00","count":1}}\n' "$(git rev-parse HEAD | tr -d '\r')" \
    > "$TMP_REPO/logs/push-state.json"
  hook_push 'git push' sess1 "$TR_A"
  assert_contains "UR-T07" "WF911"

  # 同じ HEAD で 2 回目は検知しない（last_push_sha == HEAD）
  hook_push 'git push' sess1 "$TR_A"
  assert_eq "UR-T07" "" "$R_OUT"
  assert_exit "UR-T07" 0
  rm -f "$TMP_REPO/logs/push-state.json"

  # 停止中は何も出さない
  reset_state
  hook_acc Stop sess1 "$TR_A"
  do_push
  R_ERR=""
  R_OUT="$(mk_payload PostToolUse Bash sess1 "$TR_A" "" "" 'git push' | WORKFLOW_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  assert_eq "UR-T07" "" "$R_OUT"
  assert_exit "UR-T07" 0
}

case_report
case_no_double
case_multi
case_carry_over
case_broken
case_no_mr
case_detect
cd "$LOGGER_ROOT" || true
finish
