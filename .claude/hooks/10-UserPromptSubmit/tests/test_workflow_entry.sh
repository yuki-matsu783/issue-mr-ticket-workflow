#!/usr/bin/env bash
# test_workflow_entry.sh — workflow-entry.sh のテスト（仕様のテスト ID: WE-T01〜WE-T09, WE-T11）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*workflow_entry*'
# WE-T10（boundary.sh status --offline との一致）は 3/3（issue #10）へ送る。DDR i0009-04
# テストは set -e を使わない（終了コードは judge が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SRC="$LOGGER_ROOT/.claude/hooks"
SK="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/10-UserPromptSubmit" "$TMP_REPO/.claude/hooks/lib" "$TMP_REPO/.claude/hooks/config" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts" \
         "$TMP_REPO/wip/10_tickets/00_todo" "$TMP_REPO/wip/10_tickets/10_doing" "$TMP_REPO/wip/10_tickets/20_done" \
         "$TMP_REPO/logs"
cp "$SRC/10-UserPromptSubmit/workflow-entry.sh" "$TMP_REPO/.claude/hooks/10-UserPromptSubmit/"
cp "$SRC/lib/hook-common.sh" "$SRC/lib/cmdpos.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$SK/logger.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"
cp "$SRC/config/entry-skills.txt" "$TMP_REPO/.claude/hooks/config/"
TMP_HOOK="$TMP_REPO/.claude/hooks/10-UserPromptSubmit/workflow-entry.sh"
ENTRY="$TMP_REPO/logs/sessions/s1/entry.json"

lab() {
  case "$1" in
    *WF101*) printf 'WF101\n' ;; *WF102*) printf 'WF102\n' ;; *WF109*) printf 'WF109\n' ;;
    "")      printf 'allow\n' ;; *) printf 'other:%s\n' "$1" ;;
  esac
}

# $1=event $2=tool $3=キー種別（command|file_path|skill|none） $4=値 [$5=session]
payload() {
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc \
    --arg ev "$1" --arg tn "$2" --arg k "$3" --arg v "$4" --arg sid "${5:-s1}" --arg cwd "$TMP_REPO" '
    {hook_event_name: $ev, session_id: $sid, cwd: $cwd, tool_input: {}}
    | (if $tn != "" then .tool_name = $tn else . end)
    | (if $k == "command" then .tool_input.command = $v
       elif $k == "file_path" then .tool_input.file_path = $v
       elif $k == "skill" then .tool_input.skill = $v
       elif $k == "prompt" then .prompt = $v
       else . end)' | tr -d '\r'
}
run() { lab "$(payload "$@" | bash "$TMP_HOOK" 2>/dev/null)"; }

prompt() { run UserPromptSubmit "" prompt "${1:-何かして}" "${2:-s1}"; }
skill()  { run PreToolUse Skill skill "$1" "${2:-s1}"; }
write()  { run PreToolUse Write file_path "$TMP_REPO/a.md" "${1:-s1}"; }
bashcmd(){ run PreToolUse Bash command "${1:-ls -la}" "${2:-s1}"; }
readtool(){ run PreToolUse Read file_path "$TMP_REPO/a.md" "${1:-s1}"; }

reset_all() {
  rm -rf "$TMP_REPO/logs"
  rm -f "$TMP_REPO"/wip/10_tickets/*/*.md
}
entry_of() { tl_jq -r "$1" "$ENTRY" 2>/dev/null; }

# ---- WE-T01: プロンプトごとに宣言が消え prompt_seq が進む ----
case_reset() {
  reset_all
  assert_eq "WE-T01" "allow" "$(prompt '何かして')"
  assert_eq "WE-T01" "1" "$(entry_of '.prompt_seq')"
  assert_eq "WE-T01" "" "$(entry_of '.declared_skill')"
  assert_eq "WE-T01" "allow" "$(skill 00-workflow-quick-request)"
  assert_eq "WE-T01" "00-workflow-quick-request" "$(entry_of '.declared_skill')"
  # フォローアップでも宣言は消える
  assert_eq "WE-T01" "allow" "$(prompt 'はい')"
  assert_eq "WE-T01" "2" "$(entry_of '.prompt_seq')"
  assert_eq "WE-T01" "" "$(entry_of '.declared_skill')"
}

# ---- WE-T02: 宣言すると以後の Write / Bash が通る ----
case_declared() {
  reset_all
  prompt '何かして' > /dev/null
  assert_eq "WE-T02" "WF101" "$(write)"
  assert_eq "WE-T02" "allow" "$(skill 00-workflow-issue-mr-driven)"
  assert_eq "WE-T02" "allow" "$(write)"
  assert_eq "WE-T02" "allow" "$(bashcmd 'ls -la')"
  # 振り分け以外のスキルは宣言にならない
  prompt '次の依頼' > /dev/null
  assert_eq "WE-T02" "allow" "$(skill 20-common-step-ticket)"
  assert_eq "WE-T02" "WF101" "$(write)"
}

# ---- WE-T03: 未宣言の書き込み・実行・プランモード・起動は拒否、読み取りは通る ----
case_deny_targets() {
  reset_all
  prompt '何かして' > /dev/null
  assert_eq "WE-T03" "WF101" "$(write)"
  assert_eq "WE-T03" "WF101" "$(bashcmd 'ls')"
  assert_eq "WE-T03" "WF101" "$(run PreToolUse EnterPlanMode none '')"
  assert_eq "WE-T03" "WF101" "$(run PreToolUse Agent none '')"
  assert_eq "WE-T03" "WF101" "$(run PreToolUse Edit file_path "$TMP_REPO/a.md")"
  # 読み取り系は通る
  assert_eq "WE-T03" "allow" "$(readtool)"
  assert_eq "WE-T03" "allow" "$(run PreToolUse Grep none '')"
  assert_eq "WE-T03" "allow" "$(run PreToolUse Glob none '')"
}

# ---- WE-T04: スラッシュ起動が宣言になる ----
case_slash() {
  reset_all
  assert_eq "WE-T04" "allow" "$(prompt '/00-workflow-quick-request README の誤字を直す')"
  assert_eq "WE-T04" "00-workflow-quick-request" "$(entry_of '.declared_skill')"
  assert_eq "WE-T04" "allow" "$(write)"
  assert_eq "WE-T04" "allow" "$(prompt '/00-workflow-issue-mr-driven')"
  assert_eq "WE-T04" "00-workflow-issue-mr-driven" "$(entry_of '.declared_skill')"
  # 振り分け以外のスラッシュは宣言にならない
  assert_eq "WE-T04" "allow" "$(prompt '/clear')"
  assert_eq "WE-T04" "" "$(entry_of '.declared_skill')"
  assert_eq "WE-T04" "WF101" "$(write)"
}

# ---- WE-T05: チケットがあれば未宣言でも通る ----
case_tickets() {
  local d
  for d in 00_todo 10_doing 20_done; do
    reset_all
    prompt '何かして' > /dev/null
    assert_eq "WE-T05" "WF101" "$(write)"
    printf 'ticket\n' > "$TMP_REPO/wip/10_tickets/$d/0001-x.md"
    assert_eq "WE-T05" "allow" "$(write)"
    local body; body="$(cat "$TMP_REPO/logs/hooks/decisions.jsonl" 2>/dev/null)"
    case "$body" in *"continuation: tickets"*) pass "WE-T05" ;; *) fail "WE-T05" "$d で continuation: tickets が記録されない" ;; esac
    rm -f "$TMP_REPO/wip/10_tickets/$d/0001-x.md"
  done
}

# ---- WE-T06 / WE-T11: レビュー待ち・マージ前作業中 ----
case_continuation() {
  reset_all
  prompt '何かして' > /dev/null
  printf '{"state":"requested"}\n' > "$TMP_REPO/logs/review-state.json"
  assert_eq "WE-T06" "allow" "$(write)"
  rm -f "$TMP_REPO/logs/review-state.json"

  # マージ前作業中は提供コマンドの再実行だけ通る
  printf '{"state":"cleaned"}\n' > "$TMP_REPO/logs/merge-state.json"
  assert_eq "WE-T06" "allow" "$(bashcmd 'bash .claude/hooks/finalize.sh release')"
  assert_eq "WE-T11" "allow" "$(bashcmd 'bash .claude/hooks/boundary.sh status')"
  assert_eq "WE-T06" "WF101" "$(write)"
  assert_eq "WE-T06" "WF101" "$(bashcmd 'ls -la')"
  # 宣言済みなら Write も通る
  skill 00-workflow-issue-mr-driven > /dev/null
  assert_eq "WE-T11" "allow" "$(write)"
  rm -f "$TMP_REPO/logs/merge-state.json"
}

# ---- WE-T07: entry-skills.txt と CLAUDE.md の表が一致する ----
case_skill_names() {
  local f="$LOGGER_ROOT/.claude/hooks/config/entry-skills.txt" s n=0
  while IFS= read -r s || [[ -n "$s" ]]; do
    s="${s//$'\r'/}"; s="${s%%#*}"
    s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"
    [[ -n "$s" ]] || continue
    n=$(( n + 1 ))
    if grep -q -F "\`$s\`" "$LOGGER_ROOT/CLAUDE.md"; then pass "WE-T07"; else fail "WE-T07" "CLAUDE.md に $s が無い"; fi
  done < "$f"
  assert_eq "WE-T07" "2" "$n"
}

# ---- WE-T08: entry.json 破損・jq 不在 ----
case_broken() {
  reset_all
  prompt '何かして' > /dev/null
  printf 'broken' > "$ENTRY"
  assert_eq "WE-T08" "WF102" "$(write)"
  rm -f "$ENTRY"
  assert_eq "WE-T08" "WF102" "$(write)"

  # jq が無ければ WF109（入力を読めない）
  reset_all
  make_restricted_path bash cat mkdir mv rm find printf
  local out
  out="$(payload PreToolUse Write file_path "$TMP_REPO/a.md" | env PATH="$RESTRICTED_PATH" bash "$TMP_HOOK" 2>/dev/null)"
  case "$out" in *WF109*) pass "WE-T08" ;; *) fail "WE-T08" "jq 不在で WF109 が出ない: $out" ;; esac
}

# ---- WE-T09: 別の session_id の宣言は効かない ----
case_session() {
  reset_all
  prompt '何かして' s1 > /dev/null
  prompt '何かして' s2 > /dev/null
  skill 00-workflow-quick-request s1 > /dev/null
  assert_eq "WE-T09" "allow" "$(write s1)"
  assert_eq "WE-T09" "WF101" "$(write s2)"
}

# ---- WE-T11: MCP ツールも宣言が要る（種別の判定はしない）----
case_mcp() {
  reset_all
  prompt '何かして' > /dev/null
  assert_eq "WE-T11" "WF101" "$(run PreToolUse mcp__github__add_issue_comment none '')"
  assert_eq "WE-T11" "WF101" "$(run PreToolUse mcp__github__get_issue none '')"
  skill 00-workflow-quick-request > /dev/null
  assert_eq "WE-T11" "allow" "$(run PreToolUse mcp__github__add_issue_comment none '')"
  assert_eq "WE-T11" "allow" "$(run PreToolUse mcp__github__get_issue none '')"
}

# ---- 停止中・外部プロセス ----
case_misc() {
  reset_all
  prompt '何かして' > /dev/null
  local out
  out="$(payload PreToolUse Write file_path "$TMP_REPO/a.md" | WORKFLOW_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "WE-T03" "" "$out"
  out="$(payload PreToolUse Write file_path "$TMP_REPO/a.md" | WORKFLOW_ENTRY_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "WE-T03" "" "$out"

  # jq は 2 回まで（入力 + 副入力）。git / date / sed / find は呼ばない
  make_counting_path jq git date sed find awk grep cat tr cut head tail wc sort uniq
  local bash_bin; bash_bin="$(command -v bash)"
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" -c \
    "printf '%s' '$(payload PreToolUse Write file_path "$TMP_REPO/a.md")' | '$bash_bin' '$TMP_HOOK'"
  assert_eq "WE-T03" "2" "$(counted_calls jq)"
  assert_eq "WE-T03" "0" "$(counted_calls git)"
  assert_eq "WE-T03" "0" "$(counted_calls date)"
  assert_eq "WE-T03" "0" "$(counted_calls sed)"
  assert_eq "WE-T03" "0" "$(counted_calls find)"

  # チケットがある経路では副入力を読まない（jq 1 回）
  printf 'ticket\n' > "$TMP_REPO/wip/10_tickets/10_doing/0001-x.md"
  make_counting_path jq git date sed find awk grep cat tr cut head tail wc sort uniq
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" -c \
    "printf '%s' '$(payload PreToolUse Write file_path "$TMP_REPO/a.md")' | '$bash_bin' '$TMP_HOOK'"
  assert_eq "WE-T05" "1" "$(counted_calls jq)"
  rm -f "$TMP_REPO/wip/10_tickets/10_doing/0001-x.md"
}

case_reset
case_declared
case_deny_targets
case_slash
case_tickets
case_continuation
case_skill_names
case_broken
case_session
case_mcp
case_misc
finish
