#!/usr/bin/env bash
# test_hook_common.sh — hook-common.sh のテスト（仕様のテスト ID: HK-T03（lib 部分）/ HK-T04 / HK-T06 / HK-T07 / HK-T08 / HK-T10）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*hook_common*'
# テストは set -e を使わない（終了コードは run_cmd が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

LIB="$LOGGER_ROOT/.claude/hooks/lib/hook-common.sh"
export LIB

make_tmp_repo
cd "$TMP_REPO" || exit 2
export HOOK_ROOT="$TMP_REPO"
DEC="$TMP_REPO/logs/hooks/decisions.jsonl"

# ドライバ: drv.sh <フック名> <side> <action> [args...]（stdin = フック入力 JSON）
cat > "$TMP_REPO/drv.sh" <<'DRV'
#!/usr/bin/env bash
. "$LIB"
hook_init "$1" "$2" "WF909"
action="$3"; shift 3
case "$action" in
  read) hook_read_input; rc=$?; printf 'rc=%s sid=%s tool=%s ev=%s cmd=%s\n' "$rc" "$HOOK_SESSION_ID" "$HOOK_TOOL" "$HOOK_EVENT" "$HOOK_COMMAND" ;;
  enforce) if hook_enforce_enabled; then echo enabled; else hook_disabled; fi ;;
  deny) hook_read_input; hook_deny "$1" "$2" "${3:-}" ;;
  ask) hook_read_input; hook_ask "$1" "$2" "${3:-}" "${4:-}" ;;
  fail) hook_read_input || hook_fail "入力不正"; hook_require_jq; echo ok ;;
  notify) hook_read_input; hook_notify PostToolUse "$1" "$2"; echo after ;;
  session) hook_read_input; hook_session_write st.json "$1"; hook_session_read st.json ;;
  session-read) hook_read_input; hook_session_read st.json || echo none ;;
  redact) redact "$1" ;;
  rel) hook_rel_path "$1" >/dev/null; printf '%s\n' "$REPLY" ;;
  class) tool_class "$1" "${2:-}" ;;
  errtrap) hook_read_input; hook_fail_closed; nonexistent_command_xyz_123; echo "not reached" ;;
esac
DRV

payload() { hook_payload PreToolUse Bash command='git status'; }
last_decision() { tail -n 1 "$DEC" 2>/dev/null | tr -d '\r'; }

# ---- HK-T03（lib 部分）: 緊急停止の判定と disabled の記録 ----
case_hk_t03() {
  rm -f "$DEC"
  run_cmd env WORKFLOW_ENFORCE=0 bash "$TMP_REPO/drv.sh" workflow-guard deny enforce < <(payload)
  assert_exit "HK-T03" 0
  assert_eq "HK-T03" "" "$R_OUT"
  run_cmd tail -n 1 "$DEC"
  assert_contains "HK-T03" '"decision":"disabled"'
  assert_contains "HK-T03" '"hook":"workflow-guard"'
  run_cmd env WORKFLOW_GUARD_ENFORCE=0 bash "$TMP_REPO/drv.sh" workflow-guard deny enforce < <(payload)
  assert_eq "HK-T03" "" "$R_OUT"
  run_cmd env WORKFLOW_BLOCK_DIRECT_GIT_ENFORCE=0 bash "$TMP_REPO/drv.sh" block-direct-git deny enforce < <(payload)
  assert_eq "HK-T03" "" "$R_OUT"
  # 別フックの停止変数は効かない
  run_cmd env WORKFLOW_ENTRY_ENFORCE=0 bash "$TMP_REPO/drv.sh" workflow-guard deny enforce < <(payload)
  assert_eq "HK-T03" "enabled" "$R_OUT"
  run_cmd bash "$TMP_REPO/drv.sh" workflow-guard deny enforce < <(payload)
  assert_eq "HK-T03" "enabled" "$R_OUT"
}

# ---- HK-T04: 依存（入力不正・jq 不在・内部エラー）で拒否側は deny、案内側は無出力で通す ----
case_hk_t04() {
  run_cmd bash "$TMP_REPO/drv.sh" workflow-guard deny fail <<<'not json'
  assert_exit "HK-T04" 0
  assert_contains "HK-T04" '"permissionDecision":"deny"'
  assert_contains "HK-T04" 'WF909: 機構の不調'
  assert_eq "HK-T04" "1" "$(printf '%s\n' "$R_OUT" | grep -c .)"
  run_cmd bash "$TMP_REPO/drv.sh" session-start guide fail <<<'not json'
  assert_exit "HK-T04" 0
  assert_eq "HK-T04" "" "$R_OUT"
  run_cmd tail -n 1 "$DEC"
  assert_contains "HK-T04" '"decision":"skip"'
  # jq 不在
  make_restricted_path bash cat mkdir mv rm tail printf env
  run_cmd env PATH="$RESTRICTED_PATH" bash "$TMP_REPO/drv.sh" workflow-guard deny fail < <(payload)
  assert_exit "HK-T04" 0
  assert_contains "HK-T04" '"permissionDecision":"deny"'
  run_cmd env PATH="$RESTRICTED_PATH" bash "$TMP_REPO/drv.sh" workflow-diff-check guide fail < <(payload)
  assert_eq "HK-T04" "" "$R_OUT"
  # 内部エラー（未捕捉）→ fail-closed で deny JSON 1 行・終了 0
  run_cmd bash "$TMP_REPO/drv.sh" workflow-guard deny errtrap < <(payload)
  assert_exit "HK-T04" 0
  assert_contains "HK-T04" '"permissionDecision":"deny"'
  assert_not_contains "HK-T04" "not reached"
  assert_eq "HK-T04" "1" "$(printf '%s\n' "$R_OUT" | grep -c .)"
  run_cmd bash "$TMP_REPO/drv.sh" workflow-diff-check guide errtrap < <(payload)
  assert_eq "HK-T04" "" "$R_OUT"
}

# ---- HK-T06: decisions.jsonl の 1 行がスキーマを満たし機密情報を含まない ----
case_hk_t06() {
  rm -f "$DEC"
  run_cmd bash "$TMP_REPO/drv.sh" workflow-guard deny deny WF201 "保護範囲への書き込み token=abc123 ghp_ABCDEFGHIJ0123456789" ".env" < <(payload)
  assert_exit "HK-T06" 0
  assert_contains "HK-T06" '"permissionDecision":"deny"'
  assert_contains "HK-T06" 'WF201: 保護範囲への書き込み token=*** ***'
  run_cmd tl_jq -e -r 'keys | join(",")' "$DEC"
  assert_exit "HK-T06" 0
  assert_eq "HK-T06" "decision,event,hook,id,note,session_id,target,ticket,tool,ts" "$R_OUT"
  run_cmd tl_jq -r '[.decision, .id, .tool, .target, .event, .session_id, .hook] | join(" ")' "$DEC"
  assert_eq "HK-T06" "deny WF201 Bash .env PreToolUse testsession workflow-guard" "$R_OUT"
  run_cmd cat "$DEC"
  assert_not_contains "HK-T06" "abc123"
  assert_not_contains "HK-T06" "ghp_ABCDEF"
  assert_contains "HK-T06" '"ts":"20'
  # 作業中チケットがあれば ticket 欄に入る
  mkdir -p "$TMP_REPO/wip/10_tickets/10_doing"
  printf -- '---\ntype: ticket\n---\n' > "$TMP_REPO/wip/10_tickets/10_doing/0007-implementation.md"
  run_cmd bash "$TMP_REPO/drv.sh" workflow-guard deny notify WF601 "範囲外の差分 secret=xyz" < <(payload)
  assert_contains "HK-T06" '"additionalContext":"WF601: 範囲外の差分 secret=***"'
  assert_contains "HK-T06" "after"
  run_cmd tl_jq -r '.ticket + " " + .decision' "$DEC"
  assert_contains "HK-T06" "0007-implementation.md notify"
  rm -rf "$TMP_REPO/wip"
}

# ---- HK-T07: セッション状態が session_id ごとに分離される ----
case_hk_t07() {
  local pa pb pe
  pa='{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"sessA","tool_input":{"command":"ls"}}'
  pb='{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"sessB","tool_input":{"command":"ls"}}'
  pe='{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"../evil","tool_input":{"command":"ls"}}'
  run_cmd bash "$TMP_REPO/drv.sh" workflow-entry deny session '{"prompt_seq":3}' <<<"$pa"
  assert_eq "HK-T07" '{"prompt_seq":3}' "$R_OUT"
  run_cmd bash "$TMP_REPO/drv.sh" workflow-entry deny session-read <<<"$pb"
  assert_eq "HK-T07" "none" "$R_OUT"
  run_cmd bash "$TMP_REPO/drv.sh" workflow-entry deny session-read <<<"$pa"
  assert_eq "HK-T07" '{"prompt_seq":3}' "$R_OUT"
  assert_eq "HK-T07" "yes" "$([[ -f "$TMP_REPO/logs/sessions/sessA/st.json" ]] && echo yes || echo no)"
  assert_eq "HK-T07" "no" "$([[ -d "$TMP_REPO/logs/sessions/sessB" ]] && echo yes || echo no)"
  # session_id のサニタイズ（パストラバーサル）
  run_cmd bash "$TMP_REPO/drv.sh" workflow-entry deny read <<<"$pe"
  assert_contains "HK-T07" "sid=evil"
  # 入力の共通フィールド
  run_cmd bash "$TMP_REPO/drv.sh" workflow-entry deny read < <(hook_payload PreToolUse Bash command=$'git status\necho x')
  assert_contains "HK-T07" "rc=0 sid=testsession tool=Bash ev=PreToolUse cmd=git status"
  assert_contains "HK-T07" "echo x"
}

# ---- HK-T08: ヘッドレスで ask が deny になる ----
case_hk_t08() {
  run_cmd bash "$TMP_REPO/drv.sh" workflow-guard deny ask WF202 "未記載のパス" "src/x.ts" WF213 < <(payload)
  assert_exit "HK-T08" 0
  assert_contains "HK-T08" '"permissionDecision":"ask"'
  assert_contains "HK-T08" 'WF202: 未記載のパス'
  run_cmd env WORKFLOW_HEADLESS=1 bash "$TMP_REPO/drv.sh" workflow-guard deny ask WF202 "未記載のパス" "src/x.ts" WF213 < <(payload)
  assert_exit "HK-T08" 0
  assert_contains "HK-T08" '"permissionDecision":"deny"'
  assert_contains "HK-T08" 'WF213: 未記載のパス'
  assert_contains "HK-T08" '計画タスクで宣言を十分に列挙する必要がある'
  assert_not_contains "HK-T08" '"ask"'
  # 負のコントロール: CI=false / CI=0 はヘッドレスではない（ask のまま）
  run_cmd env CI=false bash "$TMP_REPO/drv.sh" workflow-guard deny ask WF202 "未記載のパス" "src/x.ts" < <(payload)
  assert_contains "HK-T08" '"permissionDecision":"ask"'
  run_cmd env CI=0 bash "$TMP_REPO/drv.sh" workflow-guard deny ask WF202 "未記載のパス" "src/x.ts" < <(payload)
  assert_contains "HK-T08" '"permissionDecision":"ask"'
  run_cmd env CI=true bash "$TMP_REPO/drv.sh" workflow-guard deny ask WF202 "未記載のパス" "src/x.ts" < <(payload)
  assert_contains "HK-T08" '"permissionDecision":"deny"'
  assert_contains "HK-T08" 'WF202: 未記載のパス'
  run_cmd tail -n 1 "$DEC"
  assert_contains "HK-T08" '"decision":"deny"'
}

# ---- HK-T10: redact がパターンを *** に置換し、通常のパス・日本語を壊さない ----
case_hk_t10() {
  local -a cases=(
    'ghp_1234567890abcdefGHIJ|***'
    'gho_abc gho_def|*** ***'
    'token github_pat_11ABC_def|token ***'
    'glpat-xyz123 end|*** end'
    'Authorization: Bearer abc.def-ghi|Authorization: Bearer ***'
    'url?token=xyz&x=1|url?token=***&x=1'
    'PASSWORD=s3cret;|PASSWORD=***;'
    'api_key=k1 api-key=k2 apikey=k3 secret=s|api_key=*** api-key=*** apikey=*** secret=***'
    'AKIAABCDEFGHIJKLMNOP|***'
    'sha 0123456789abcdef0123456789abcdef01234567 x|sha *** x'
    'b64 QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVowMTIzNDU2Nzg5|b64 ***'
    '.claude/skills/20-common-step-shell-script/scripts/logger.sh|.claude/skills/20-common-step-shell-script/scripts/logger.sh'
    'wip/30_reports/0013-ai-asset-implementation.md|wip/30_reports/0013-ai-asset-implementation.md'
    '日本語のディレクトリ/ファイル名.md を編集した|日本語のディレクトリ/ファイル名.md を編集した'
    'git commit -m "docs: 説明を直す" a.md|git commit -m "docs: 説明を直す" a.md'
    'abc123 short hex 0123456789abcdef|abc123 short hex 0123456789abcdef'
    'tokens=5 mytoken=x|tokens=5 mytoken=***'
    'AWS_SECRET_ACCESS_KEY=abcd1234/EFGH5678/ijkl9012MNOPqrstUVWXyz0123|AWS_SECRET_ACCESS_KEY=***'
    'PRIVATE_KEY=abc client-key=def access_key=ghi|PRIVATE_KEY=*** client-key=*** access_key=***'
    'X-Api-Key: 0123456789ABCDEF0123456789abcdef012345678|X-Api-Key: ***'
    'branch feature-6-workflow-foundation-and-more-stuff pushed|branch feature-6-workflow-foundation-and-more-stuff pushed'
    '0025-ai-asset-implementation-review-followup-ticket-name|0025-ai-asset-implementation-review-followup-ticket-name'
    'some_very_long_function_name_that_is_over_forty_chars|some_very_long_function_name_that_is_over_forty_chars'
  )
  local c in exp
  for c in "${cases[@]}"; do
    in="${c%%|*}"; exp="${c#*|}"
    run_cmd bash "$TMP_REPO/drv.sh" x guide redact "$in"
    assert_eq "HK-T10" "$exp" "$R_OUT"
  done
}

# 付随: tool_class と hook_rel_path（§2。専用の ID は無いので HK-T07 に付ける）
case_misc() {
  run_cmd bash "$TMP_REPO/drv.sh" x guide class Edit
  assert_eq "HK-T07" "write" "$R_OUT"
  run_cmd bash "$TMP_REPO/drv.sh" x guide class PowerShell
  assert_eq "HK-T07" "exec" "$R_OUT"
  run_cmd bash "$TMP_REPO/drv.sh" x guide class Skill 00-workflow-quick-request
  assert_eq "HK-T07" "declare" "$R_OUT"
  run_cmd bash "$TMP_REPO/drv.sh" x guide class Skill 20-common-step-ticket
  assert_eq "HK-T07" "read" "$R_OUT"
  run_cmd bash "$TMP_REPO/drv.sh" x guide class Agent
  assert_eq "HK-T07" "spawn" "$R_OUT"
  # §2 の分類表を全行踏む
  local pair
  for pair in Edit=write Write=write MultiEdit=write NotebookEdit=write Bash=exec PowerShell=exec EnterPlanMode=plan Agent=spawn Workflow=spawn Read=read Grep=read Glob=read WebFetch=read Unknown=read; do
    run_cmd bash "$TMP_REPO/drv.sh" x guide class "${pair%%=*}"
    assert_eq "HK-T07" "${pair#*=}" "$R_OUT"
  done
  run_cmd bash "$TMP_REPO/drv.sh" x guide rel "$TMP_REPO/src/a.ts"
  assert_eq "HK-T07" "src/a.ts" "$R_OUT"
  run_cmd bash "$TMP_REPO/drv.sh" x guide rel "./src//b.ts"
  assert_eq "HK-T07" "src/b.ts" "$R_OUT"
  run_cmd bash "$TMP_REPO/drv.sh" x guide rel 'wip\tmp\x.md'
  assert_eq "HK-T07" "wip/tmp/x.md" "$R_OUT"
}

case_hk_t03
case_hk_t04
case_hk_t06
case_hk_t07
case_hk_t08
case_hk_t10
case_misc
finish
