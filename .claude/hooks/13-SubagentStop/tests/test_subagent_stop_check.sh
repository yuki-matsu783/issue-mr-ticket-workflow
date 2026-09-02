#!/usr/bin/env bash
# test_subagent_stop_check.sh — subagent-stop-check.sh のテスト（仕様のテスト ID: SP-T01〜SP-T08）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*subagent_stop_check*'
# テストは set -e を使わない（終了コードは hook_run が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SRC="$LOGGER_ROOT/.claude/hooks"
SKILL_SCRIPTS="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/13-SubagentStop" "$TMP_REPO/.claude/hooks/lib" "$TMP_REPO/.claude/hooks/config" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts" \
         "$TMP_REPO/wip/10_tickets/00_todo" "$TMP_REPO/wip/10_tickets/10_doing" "$TMP_REPO/wip/10_tickets/20_done" \
         "$TMP_REPO/src" "$TMP_REPO/docs"
cp "$SRC/13-SubagentStop/subagent-stop-check.sh" "$TMP_REPO/.claude/hooks/13-SubagentStop/"
cp "$SRC/lib/hook-common.sh" "$SRC/lib/scope.sh" "$SRC/lib/probe-4c.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$SKILL_SCRIPTS/logger.sh" "$SKILL_SCRIPTS/frontmatter.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"
cp "$SRC/config/scope-limits.json" "$SRC/config/model-aliases.txt" "$TMP_REPO/.claude/hooks/config/"
TMP_HOOK="$TMP_REPO/.claude/hooks/13-SubagentStop/subagent-stop-check.sh"
DEC="$TMP_REPO/logs/hooks/decisions.jsonl"

printf 'print("a")\n' > "$TMP_REPO/src/a.py"
printf '# doc\n' > "$TMP_REPO/docs/keep.md"

cd "$TMP_REPO" || exit 2
git add -A >/dev/null 2>&1
git commit -q -m "setup"

# ---- 補助 ----
write_ticket() { # $1=パス $2=ticket_type $3=executor $4=現在地に本文を書くか（1/0）
  {
    printf -- '---\n'
    printf 'type: ticket\n'
    printf 'ticket_type: %s\n' "$2"
    [[ -n "$3" ]] && printf 'executor: %s\n' "$3"
    printf 'allow:\n'
    printf '  write: ["wip/10_tickets/**"]\n'
    printf '  ops: ["read"]\n'
    printf 'base_sha: "abc1234"\n'
    printf -- '---\n\n# テスト用チケット\n\n## 作業ログ\n\n### 現在地\n\n'
    (( $4 )) && printf '途中まで進めた\n'
    printf '\n### 判断と根拠\n\n'
  } > "$1"
}

reset_all() {
  git -C "$TMP_REPO" checkout -q -- . 2>/dev/null
  git -C "$TMP_REPO" clean -qfdx 2>/dev/null
  mkdir -p "$TMP_REPO/wip/10_tickets/00_todo" "$TMP_REPO/wip/10_tickets/10_doing" "$TMP_REPO/wip/10_tickets/20_done"
}

mk_payload() { # $1=event $2=tool $3=model $4=subagent_type $5=status $6=agentId $7=agent_id
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc \
    --arg ev "$1" --arg tn "$2" --arg model "$3" --arg st "$4" --arg status "$5" \
    --arg rid "$6" --arg aid "$7" --arg cwd "$TMP_REPO" '
    {hook_event_name: $ev, session_id: "testsession", cwd: $cwd, tool_input: {}}
    | (if $tn != "" then .tool_name = $tn else . end)
    | (if $model != "" then .tool_input.model = $model else . end)
    | (if $st != "" then .tool_input.subagent_type = $st else . end)
    | (if $status != "" or $rid != "" then .tool_response = {} else . end)
    | (if $status != "" then .tool_response.status = $status else . end)
    | (if $rid != "" then .tool_response.agentId = $rid else . end)
    | (if $aid != "" then .agent_id = $aid else . end)' | tr -d '\r'
}

hook_run() {
  R_ERR=""
  R_OUT="$(mk_payload "$@" | bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  return 0
}

post() { hook_run PostToolUse Agent "${2:-}" "${3:-}" "${1:-completed}" "${4:-A1}" ""; }
stop() { hook_run SubagentStop "" "" "" "" "" "${1:-A1}"; }

seed_start_check() { # $1=decision — subagent-start-check の記録を仕込む
  mkdir -p "$TMP_REPO/logs/hooks"
  printf '{"ts":"2026-09-01T00:00:00+0900","session_id":"testsession","hook":"subagent-start-check","event":"PreToolUse","decision":"%s","id":"","tool":"Agent","target":"","ticket":"","note":""}\n' \
    "$1" >> "$DEC"
}

# ---- SP-T01: 作業中なし・差分なしで何も伝えない ----
case_quiet() {
  reset_all
  post completed
  assert_eq "SP-T01" "" "$R_OUT"
  assert_exit "SP-T01" 0
  stop
  assert_eq "SP-T01" "" "$R_OUT"
  assert_exit "SP-T01" 0
}

# ---- SP-T02: 作業中のまま残ったチケットで WF811 と対処 3 点 ----
case_doing_left() {
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation sonnet 1
  post completed
  assert_contains "SP-T02" "WF811"
  assert_contains "SP-T02" "0100-implementation（種類: implementation / 作業ログ「現在地」の記載: 有り）"
  assert_contains "SP-T02" "結果報告と突き合わせる"
  assert_contains "SP-T02" "ticket.sh complete"
  assert_contains "SP-T02" "勝手に完了にしないこと"
  assert_exit "SP-T02" 0

  # 現在地が空なら「無し」
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation sonnet 0
  post completed
  assert_contains "SP-T02" "作業ログ「現在地」の記載: 無し"
}

# ---- SP-T03: 未コミット 3 件のうち logs/ を除いた 2 件だけ列挙する ----
case_uncommitted() {
  reset_all
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  printf '# new\n' > "$TMP_REPO/docs/b.md"
  mkdir -p "$TMP_REPO/logs" "$TMP_REPO/wip/tmp"
  printf 'log\n' > "$TMP_REPO/logs/x.log"
  printf 'tmp\n' > "$TMP_REPO/wip/tmp/y.txt"
  post completed
  assert_contains "SP-T03" "WF812"
  assert_contains "SP-T03" "- src/a.py"
  assert_contains "SP-T03" "- docs/b.md"
  assert_not_contains "SP-T03" "logs/x.log"
  assert_not_contains "SP-T03" "wip/tmp/y.txt"
  assert_exit "SP-T03" 0
}

# ---- SP-T04: 禁止範囲の差分で WF813 ----
case_out_of_scope() {
  reset_all
  # investigation は src/** / docs/** / .claude/** を禁止範囲に持つ
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-investigation.md" investigation sonnet 1
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  post completed
  assert_contains "SP-T04" "WF813"
  assert_contains "SP-T04" "src/a.py"
  assert_contains "SP-T04" "0100-investigation.md"
  assert_exit "SP-T04" 0

  # 許可範囲だけなら WF813 は出ない（WF811 / WF812 は出る）
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-investigation.md" investigation sonnet 1
  post completed
  assert_not_contains "SP-T04" "WF813"
}

# ---- SP-T05: SubagentStop で記録し PostToolUse で同じ内容を伝える ----
case_record_replay() {
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation sonnet 1
  stop A1
  assert_eq "SP-T05" "" "$R_OUT"
  if [[ -f "$TMP_REPO/logs/sessions/testsession/subagent-A1.json" ]]; then pass "SP-T05"; else fail "SP-T05" "検査結果が記録されていない"; fi

  # 作業中チケットを片付けても、記録から同じ内容が出る（記録を読んでいる証拠）
  rm -f "$TMP_REPO"/wip/10_tickets/10_doing/*.md
  post completed
  assert_contains "SP-T05" "WF811"
  assert_contains "SP-T05" "0100-implementation"

  # tool_response.agentId で引く。別の id では記録が見つからず、その場の検査になる（該当なし）
  post completed "" "" A2
  assert_eq "SP-T05" "" "$R_OUT"
}

# ---- SP-T06: git が使えない環境で無出力・終了 0 ----
case_no_git() {
  reset_all
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  make_restricted_path jq bash cat mkdir mv rm find tail
  R_ERR=""
  R_OUT="$(mk_payload PostToolUse Agent "" "" completed A1 "" | env PATH="$RESTRICTED_PATH" bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  assert_eq "SP-T06" "" "$R_OUT"
  assert_exit "SP-T06" 0
}

# ---- SP-T07: async_launched では作業後の検査をせず WF814 だけ ----
case_async() {
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-investigation.md" investigation sonnet 1
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  post async_launched
  assert_contains "SP-T07" "WF814"
  # WF814 の文面が「WF811〜813」に言及するので、識別子ではなく各検査の文面で判定する
  assert_not_contains "SP-T07" "作業中のまま残っている"
  assert_not_contains "SP-T07" "未コミットの変更・未追跡が残っている"
  assert_not_contains "SP-T07" "許可範囲外のパスに差分が残っている"
  assert_contains "SP-T07" "run_in_background: false"
  assert_exit "SP-T07" 0

  # 同じ作業領域で completed なら従来どおり出る
  post completed
  assert_contains "SP-T07" "作業中のまま残っている"
  assert_contains "SP-T07" "未コミットの変更・未追跡が残っている"
  assert_contains "SP-T07" "許可範囲外のパスに差分が残っている"
  assert_not_contains "SP-T07" "WF814"
}

# ---- SP-T08: 縮退時だけ自分で WF801 を判定する ----
case_degraded() {
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation opus 1
  # subagent-start-check の記録が 1 件も無い = 縮退
  post completed 'claude-sonnet-4-5-20250929' task-executor A1
  assert_contains "SP-T08" "WF801"
  assert_contains "SP-T08" "executor は opus"

  # skip の記録があれば判定済みなので出さない
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation opus 1
  seed_start_check skip
  post completed 'claude-sonnet-4-5-20250929' task-executor A1
  assert_not_contains "SP-T08" "WF801"

  # notify の記録があれば通知済みなので出さない
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation opus 1
  seed_start_check notify
  post completed 'claude-sonnet-4-5-20250929' task-executor A1
  assert_not_contains "SP-T08" "WF801"

  # task-executor 以外・model 無し・一致では出ない
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation opus 1
  post completed 'claude-sonnet-4-5-20250929' adversarial-reviewer A1
  assert_not_contains "SP-T08" "WF801"
  post completed '' task-executor A1
  assert_not_contains "SP-T08" "WF801"
  post completed 'claude-opus-5' task-executor A1
  assert_not_contains "SP-T08" "WF801"

  # async_launched でも縮退判定は行う
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation opus 1
  post async_launched 'claude-sonnet-4-5-20250929' task-executor A1
  assert_contains "SP-T08" "WF801"
  assert_contains "SP-T08" "WF814"
}

# ---- 停止中とプローブの既定 ----
case_enforce_and_probe() {
  reset_all
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation sonnet 1
  R_ERR=""
  R_OUT="$(mk_payload PostToolUse Agent "" "" completed A1 "" | WORKFLOW_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  assert_eq "SP-T01" "" "$R_OUT"
  assert_exit "SP-T01" 0
  if [[ ! -f "$TMP_REPO/logs/hooks/probe-4c.jsonl" ]]; then pass "SP-T01"; else fail "SP-T01" "既定でプローブが書かれている"; fi
}

case_quiet
case_doing_left
case_uncommitted
case_out_of_scope
case_record_replay
case_no_git
case_async
case_degraded
case_enforce_and_probe
cd "$LOGGER_ROOT" || true
finish
