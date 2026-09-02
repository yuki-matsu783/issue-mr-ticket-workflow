#!/usr/bin/env bash
# test_subagent_start_check.sh — subagent-start-check.sh のテスト（仕様のテスト ID: SA-T01〜SA-T09）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*subagent_start_check*'
# テストは set -e を使わない（終了コードは hook_run が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SRC="$LOGGER_ROOT/.claude/hooks"
SKILL_SCRIPTS="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/12-SubagentStart" "$TMP_REPO/.claude/hooks/lib" "$TMP_REPO/.claude/hooks/config" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts" \
         "$TMP_REPO/wip/10_tickets/00_todo" "$TMP_REPO/wip/10_tickets/10_doing"
cp "$SRC/12-SubagentStart/subagent-start-check.sh" "$TMP_REPO/.claude/hooks/12-SubagentStart/"
cp "$SRC/lib/hook-common.sh" "$SRC/lib/probe-4c.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$SKILL_SCRIPTS/logger.sh" "$SKILL_SCRIPTS/frontmatter.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"
cp "$SRC/config/model-aliases.txt" "$TMP_REPO/.claude/hooks/config/"
TMP_HOOK="$TMP_REPO/.claude/hooks/12-SubagentStart/subagent-start-check.sh"
DEC="$TMP_REPO/logs/hooks/decisions.jsonl"

# ---- 補助 ----
write_ticket() { # $1=パス $2=ticket_type $3=executor $4=DoD 件数
  local i
  {
    printf -- '---\n'
    printf 'type: ticket\n'
    printf 'ticket_type: %s\n' "$2"
    [[ -n "$3" ]] && printf 'executor: %s\n' "$3"
    printf 'allow:\n'
    printf '  write: [".claude/hooks/**", "wip/10_tickets/**"]\n'
    printf '  ops: ["read", "hook-test"]\n'
    printf 'base_sha: "abc1234"\n'
    printf -- '---\n\n# テスト用チケット\n\n## DoD\n\n'
    for (( i = 1; i <= $4; i++ )); do
      printf -- '- [ ] DoD の %d 件目（根拠: ）\n' "$i"
    done
    printf '\n## 作業ログ\n\n### 現在地\n\nここは注入されない\n'
  } > "$1"
}

clear_tickets() { rm -f "$TMP_REPO"/wip/10_tickets/10_doing/*.md "$TMP_REPO"/wip/10_tickets/00_todo/*.md; }
clear_logs() { rm -rf "$TMP_REPO/logs"; }

mk_payload() { # $1=event $2=tool $3=model $4=subagent_type $5=run_in_background（空=キー無し） $6=agent_id
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc \
    --arg ev "$1" --arg tn "$2" --arg model "$3" --arg st "$4" --arg bg "$5" --arg aid "$6" \
    --arg cwd "$TMP_REPO" '
    {hook_event_name: $ev, session_id: "testsession", cwd: $cwd, tool_input: {}}
    | (if $tn != "" then .tool_name = $tn else . end)
    | (if $model != "" then .tool_input.model = $model else . end)
    | (if $st != "" then .tool_input.subagent_type = $st else . end)
    | (if $bg != "" then .tool_input.run_in_background = ($bg == "true") else . end)
    | (if $aid != "" then .agent_id = $aid else . end)' | tr -d '\r'
}

hook_run() { # $1..=mk_payload の引数
  R_ERR=""
  R_OUT="$(mk_payload "$@" | bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  return 0
}

pre() { hook_run PreToolUse Agent "$1" "$2" "$3" ""; }        # model / subagent_type / background
start() { hook_run SubagentStart "" "" "" "" "agent1"; }

# 記録の note を 1 件抜く（最後の行）
last_note() { tail -n 1 "$DEC" 2>/dev/null | tl_jq -r '.note // ""' 2>/dev/null; }
last_decision() { tail -n 1 "$DEC" 2>/dev/null | tl_jq -r '.decision // ""' 2>/dev/null; }

# ---- SA-T01: 一致なら通知しない。SubagentStart では要点を注入する ----
case_match() {
  clear_tickets; clear_logs
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation sonnet 3
  pre 'claude-sonnet-4-5-20250929' task-executor false
  assert_eq "SA-T01" "" "$R_OUT"
  assert_exit "SA-T01" 0

  start
  assert_contains "SA-T01" "WF802"
  assert_contains "SA-T01" "0100-implementation"
  assert_contains "SA-T01" "タスクの種類: implementation"
  assert_contains "SA-T01" ".claude/hooks/**, wip/10_tickets/**"
  assert_contains "SA-T01" "read, hook-test"
  assert_contains "SA-T01" "DoD の 1 件目"
  # 根拠欄と作業ログは注入しない
  assert_not_contains "SA-T01" "根拠"
  assert_not_contains "SA-T01" "ここは注入されない"
  assert_exit "SA-T01" 0
}

# ---- SA-T02: 不一致は systemMessage と additionalContext の両方に出る。起動は止めない ----
case_mismatch() {
  clear_tickets; clear_logs
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation opus 2
  pre 'claude-sonnet-4-5-20250929' task-executor false
  assert_contains "SA-T02" "WF801"
  assert_contains "SA-T02" '"systemMessage"'
  assert_contains "SA-T02" '"additionalContext"'
  assert_not_contains "SA-T02" "permissionDecision"
  assert_exit "SA-T02" 0
  assert_eq "SA-T02" "notify" "$(last_decision)"
}

# ---- SA-T03: 作業中が無ければ未着手の先頭。1 枚も無ければ無出力 ----
case_target() {
  clear_tickets; clear_logs
  write_ticket "$TMP_REPO/wip/10_tickets/00_todo/0002-design.md" design opus 1
  write_ticket "$TMP_REPO/wip/10_tickets/00_todo/0001-investigation.md" investigation opus 1
  start
  assert_contains "SA-T03" "0001-investigation"
  assert_not_contains "SA-T03" "0002-design"

  clear_tickets
  start
  assert_eq "SA-T03" "" "$R_OUT"
  assert_exit "SA-T03" 0
  pre 'claude-opus-5' task-executor false
  assert_eq "SA-T03" "" "$R_OUT"
}

# ---- SA-T04: model が無ければ比較しない。SubagentStart でも通知しない ----
case_no_model() {
  clear_tickets; clear_logs
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation opus 1
  pre '' task-executor false
  assert_not_contains "SA-T04" "WF801"
  assert_eq "SA-T04" "" "$R_OUT"
  assert_exit "SA-T04" 0

  start
  assert_not_contains "SA-T04" "WF801"
  assert_contains "SA-T04" "WF802"
}

# ---- SA-T05: frontmatter が壊れていれば無出力・終了 0 ----
case_broken() {
  clear_tickets; clear_logs
  printf 'これは frontmatter ではない\n' > "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md"
  pre 'claude-sonnet-4-5' task-executor false
  assert_eq "SA-T05" "" "$R_OUT"
  assert_exit "SA-T05" 0
  start
  assert_eq "SA-T05" "" "$R_OUT"
  assert_exit "SA-T05" 0
}

# ---- SA-T06: DoD が 4 KB を超えたら件数と先頭 10 件 ----
case_dod_cap() {
  clear_tickets; clear_logs
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation sonnet 200
  start
  assert_contains "SA-T06" "DoD は全 200 件"
  assert_contains "SA-T06" "DoD の 10 件目"
  assert_not_contains "SA-T06" "DoD の 11 件目"
  assert_not_contains "SA-T06" "ここは注入されない"
}

# ---- SA-T07: task-executor 以外では判定しない ----
case_subagent_type() {
  clear_tickets; clear_logs
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation opus 1
  pre 'claude-sonnet-4-5' adversarial-reviewer false
  assert_eq "SA-T07" "" "$R_OUT"
  pre 'claude-sonnet-4-5' Explore false
  assert_eq "SA-T07" "" "$R_OUT"
  pre 'claude-sonnet-4-5' '' false
  assert_eq "SA-T07" "" "$R_OUT"
  # 正のコントロール
  pre 'claude-sonnet-4-5' task-executor false
  assert_contains "SA-T07" "WF801"
}

# ---- SA-T08: 通知しなかったときも skip が理由つきで残る ----
case_record() {
  clear_tickets; clear_logs
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation sonnet 1
  pre 'claude-sonnet-4-5' task-executor false
  assert_eq "SA-T08" "skip" "$(last_decision)"
  case "$(last_note)" in *一致*) pass "SA-T08" ;; *) fail "SA-T08" "一致の理由が残っていない: $(last_note)" ;; esac

  clear_logs
  pre 'claude-sonnet-4-5' adversarial-reviewer false
  case "$(last_note)" in *subagent_type*) pass "SA-T08" ;; *) fail "SA-T08" "subagent_type の理由が残っていない: $(last_note)" ;; esac

  clear_logs
  pre '' task-executor false
  case "$(last_note)" in *model*) pass "SA-T08" ;; *) fail "SA-T08" "model の理由が残っていない: $(last_note)" ;; esac

  clear_logs; clear_tickets
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation '' 1
  pre 'claude-sonnet-4-5' task-executor false
  case "$(last_note)" in *executor*) pass "SA-T08" ;; *) fail "SA-T08" "executor の理由が残っていない: $(last_note)" ;; esac

  clear_logs; clear_tickets
  pre 'claude-sonnet-4-5' task-executor false
  case "$(last_note)" in *対象チケット*) pass "SA-T08" ;; *) fail "SA-T08" "対象なしの理由が残っていない: $(last_note)" ;; esac

  # PreToolUse `Agent` の経路が生きている印をセッション内に残す
  # （subagent-stop-check の縮退判定が decisions.jsonl の行数に依存しないようにするため）
  local mark="$TMP_REPO/logs/sessions/testsession/subagent-start-check.json"
  clear_logs; clear_tickets
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation sonnet 1
  pre 'claude-sonnet-4-5' task-executor false
  if [[ -f "$mark" ]]; then pass "SA-T08"; else fail "SA-T08" "経路の印が残っていない"; fi
  # SubagentStart は PreToolUse の経路とは別なので印を置かない
  clear_logs
  start
  if [[ ! -f "$mark" ]]; then pass "SA-T08"; else fail "SA-T08" "SubagentStart で印が置かれた"; fi
}

# ---- SA-T09: background 起動の警告 ----
case_background() {
  clear_tickets; clear_logs
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation sonnet 1
  # run_in_background のキーが無い
  pre 'claude-sonnet-4-5' task-executor ''
  assert_contains "SA-T09" "WF803"
  assert_contains "SA-T09" '"systemMessage"'
  assert_contains "SA-T09" '"additionalContext"'
  assert_exit "SA-T09" 0
  # true
  pre 'claude-sonnet-4-5' task-executor true
  assert_contains "SA-T09" "WF803"
  # false なら出ない
  pre 'claude-sonnet-4-5' task-executor false
  assert_not_contains "SA-T09" "WF803"
  # task-executor 以外では run_in_background を問わず出ない
  pre 'claude-sonnet-4-5' adversarial-reviewer ''
  assert_not_contains "SA-T09" "WF803"
  pre 'claude-sonnet-4-5' Explore true
  assert_not_contains "SA-T09" "WF803"
}

# ---- 停止中とプローブの既定 ----
case_enforce_and_probe() {
  clear_tickets; clear_logs
  write_ticket "$TMP_REPO/wip/10_tickets/10_doing/0100-implementation.md" implementation opus 1
  R_ERR=""
  R_OUT="$(mk_payload PreToolUse Agent 'claude-sonnet-4-5' task-executor false "" | WORKFLOW_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  assert_eq "SA-T02" "" "$R_OUT"
  assert_exit "SA-T02" 0
  # プローブは既定では副作用ゼロ（probe-4c.jsonl を作らない）
  clear_logs
  pre 'claude-sonnet-4-5' task-executor false
  if [[ ! -f "$TMP_REPO/logs/hooks/probe-4c.jsonl" ]]; then pass "SA-T02"; else fail "SA-T02" "既定でプローブが書かれている"; fi
}

case_match
case_mismatch
case_target
case_no_model
case_broken
case_dod_cap
case_subagent_type
case_record
case_background
case_enforce_and_probe
finish
