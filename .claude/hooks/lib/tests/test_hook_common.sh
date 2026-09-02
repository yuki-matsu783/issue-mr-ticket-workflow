#!/usr/bin/env bash
# test_hook_common.sh — hook-common.sh のテスト（仕様のテスト ID: HK-T03（lib 部分）/ HK-T04 / HK-T06 / HK-T07 / HK-T08 / HK-T10）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*hook_common*'
# テストは set -e を使わない（終了コードは run_cmd が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
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
  # 入力は test-lib の hook_payload --session で組む（session_id だけが違う 2 セッション）
  pa="$(hook_payload PreToolUse Bash --session sessA command=ls)"
  pb="$(hook_payload PreToolUse Bash --session sessB command=ls)"
  pe="$(hook_payload PreToolUse Bash --session '../evil' command=ls)"
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
  # --session は第 3 引数の位置でだけ解釈され、tool_input のフィールドにはならない（既定は testsession のまま）
  run_cmd bash "$TMP_REPO/drv.sh" workflow-entry deny read < <(hook_payload PreToolUse Bash --session sessC command='git status')
  assert_contains "HK-T07" "rc=0 sid=sessC tool=Bash ev=PreToolUse cmd=git status"
  assert_eq "HK-T07" "sessA" "$(hook_payload PreToolUse Bash --session sessA command=ls | tl_jq -r '.session_id')"
  assert_eq "HK-T07" "null" "$(hook_payload PreToolUse Bash --session sessA command=ls | tl_jq -r '.tool_input["--session"]')"
  assert_eq "HK-T07" "testsession" "$(hook_payload PreToolUse Bash command=ls | tl_jq -r '.session_id')"
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
  # ヘッドレスの deny は入力の session_id で記録される（--session で変えた ID が決定ログに載る）
  run_cmd env WORKFLOW_HEADLESS=1 bash "$TMP_REPO/drv.sh" workflow-guard deny ask WF202 "未記載のパス" "src/x.ts" WF213 < <(hook_payload PreToolUse Bash --session sessH command='git status')
  assert_contains "HK-T08" '"permissionDecision":"deny"'
  run_cmd tail -n 1 "$DEC"
  assert_contains "HK-T08" '"session_id":"sessH"'
  assert_not_contains "HK-T08" '"session_id":"testsession"'
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
  assert_eq "HK-T07" "declare" "$R_OUT"   # skill の値を見ずに常に declare（DDR i0009-03）
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
# ---- HK-T17 / HK-T18 / HK-T19 / HK-T20: 副入力・記録ヘルパ・ロック ----
# 直接 source して関数を試す（フックの起動を挟まない lib 単体の観点）
# shellcheck disable=SC1090
. "$LIB"
export HOOK_ROOT="$TMP_REPO"; HOOK_WORKTREE="$TMP_REPO"

# HK-T18: 副入力が壊れていても不在でも、stdin の解析が巻き添えにならない（DDR i0009-47）
case_side_input() {
  local cfg="$TMP_REPO/.claude/hooks/config/scope-limits.json"
  mkdir -p "${cfg%/*}"
  local IN='{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"ls"}}'
  rm -f "$cfg"
  hook_read_input limits <<<"$IN"
  assert_eq "HK-T18" "Bash" "$HOOK_TOOL"
  assert_eq "HK-T18" "missing" "$HC_LIMITS_STATE"
  printf '%s' '{ not json' > "$cfg"
  hook_read_input limits <<<"$IN"
  assert_eq "HK-T18" "Bash" "$HOOK_TOOL"
  assert_eq "HK-T18" "broken" "$HC_LIMITS_STATE"
  printf '%s' '{"common":{"allow":[]},"types":{}}' > "$cfg"
  hook_read_input limits <<<"$IN"
  assert_eq "HK-T18" "Bash" "$HOOK_TOOL"
  assert_eq "HK-T18" "broken" "$HC_LIMITS_STATE"
  [[ "$HC_LIMITS_ERROR" == *"common missing keys"* ]] && pass "HK-T18" || fail "HK-T18" "検証の理由が残らない: $HC_LIMITS_ERROR"
  printf '%s' '{"common":{"allow":["a/**"],"protected":[],"confirm":[],"file_granular":[],"state_files":[]},"types":{"design":{"ops":["read"]}},"commands":{"build-test":[]}}' > "$cfg"
  hook_read_input limits <<<"$IN"
  assert_eq "HK-T18" "ok" "$HC_LIMITS_STATE"
  rm -f "$cfg"
}

# HK-T19: 副入力を要求しても jq の呼び出しは 1 回（要求しなければ 1 回）
case_jq_count() {
  local cfg="$TMP_REPO/.claude/hooks/config/scope-limits.json" n
  mkdir -p "${cfg%/*}"
  printf '%s' '{"common":{"allow":[],"protected":[],"confirm":[],"file_granular":[],"state_files":[]},"types":{},"commands":{"build-test":[]}}' > "$cfg"
  make_counting_path jq
  ( PATH="$COUNTING_PATH:$PATH"; hash -r; hook_read_input limits <<<'{"session_id":"s1","tool_name":"Bash"}' )
  n="$(counted_calls jq)"
  assert_eq "HK-T19" "1" "$n"
  make_counting_path jq
  ( PATH="$COUNTING_PATH:$PATH"; hash -r; hook_read_input <<<'{"session_id":"s1","tool_name":"Bash"}' )
  n="$(counted_calls jq)"
  assert_eq "HK-T19" "1" "$n"
  # 2 回目（hook_read_state）を足しても合計 2 回
  make_counting_path jq
  ( PATH="$COUNTING_PATH:$PATH"; hash -r
    hook_read_input limits <<<'{"session_id":"s1","tool_name":"Bash"}'
    hook_read_state approvals entry )
  n="$(counted_calls jq)"
  assert_eq "HK-T19" "2" "$n"
  rm -f "$cfg"
}

# HK-T17: hc_append_jsonl / hc_json_write（切り詰めと原子的置換は関数が持つ）
case_write_helpers() {
  local f="$TMP_REPO/logs/hooks/t.jsonl" long line
  rm -f "$f"
  hc_append_jsonl "$f" '{"a":"1"}'
  hc_append_jsonl "$f" '{"a":"2"}'
  assert_eq "HK-T17" "2" "$(wc -l < "$f" | tr -d ' ')"
  # 秘密は redact を通る（呼び手が通していなくても）
  hc_append_jsonl "$f" '{"note":"token=abcdefgh"}'
  [[ "$(tail -1 "$f")" == *'token=***'* ]] && pass "HK-T17" || fail "HK-T17" "redact を通っていない: $(tail -1 "$f")"
  # 長い行はこの関数が切り詰める（呼び手は切り詰めない）
  long="$(printf 'x%.0s' $(seq 1 6000))"
  hc_append_jsonl "$f" "{\"target\":\"$long\",\"note\":\"$long\"}"
  line="$(tail -1 "$f")"
  [[ "${#line}" -lt 4096 ]] && pass "HK-T17" || fail "HK-T17" "4 KB 未満に切り詰まっていない: ${#line}"
  [[ "$line" == *"…"* ]] && pass "HK-T17" || fail "HK-T17" "切り詰めの印が無い"
  # hc_json_write は一時ファイルを残さない
  hc_json_write "$TMP_REPO/logs/x.json" '{"k":1}'
  assert_eq "HK-T17" '{"k":1}' "$(cat "$TMP_REPO/logs/x.json")"
  assert_eq "HK-T17" "0" "$(find "$TMP_REPO/logs" -name 'x.json.tmp.*' | wc -l | tr -d ' ')"
}

# HK-T20: 陳腐化したロックからの回復（打ち切りで残置しても次の実行が回復する。DDR i0009-60）
case_lock() {
  local d="$TMP_REPO/logs/locks/t.lock"
  rm -rf "$TMP_REPO/logs/locks"
  hc_lock t && pass "HK-T20" || fail "HK-T20" "ロックを取れない"
  # 取得中は 2 回目が取れない（2 秒で諦める）
  ( hc_lock t ) && fail "HK-T20" "保持中のロックを二重に取れてしまう" || pass "HK-T20"
  hc_unlock t
  assert_eq "HK-T20" "no" "$([[ -d "$d" ]] && echo yes || echo no)"
  # hc_unlock は取っていなくても失敗しない（冪等）
  hc_unlock t && pass "HK-T20" || fail "HK-T20" "hc_unlock が冪等でない"
  # 陳腐化したロック（打ち切りの残置を模す）は強制解放して取り直せる
  mkdir -p "$d"
  touch -d '2 hours ago' "$d" 2>/dev/null || touch -t 200001010000 "$d"
  hc_lock t && pass "HK-T20" || fail "HK-T20" "陳腐化したロックから回復できない"
  hc_unlock t
  # 新しいロックは奪わない
  mkdir -p "$d"
  ( hc_lock t ) && fail "HK-T20" "生きているロックを奪ってしまう" || pass "HK-T20"
  rmdir "$d"
}

case_side_input
case_jq_count
case_write_helpers
case_lock

# ---- 付随: 作業ツリーの解決（§2・DDR i0009-55）。専用の ID は無いので HK-T18 に付ける ----
case_worktree() {
  local root="$TMP_REPO/wtroot" wt="$TMP_REPO/wtside" fake="$TMP_REPO/fakeclaude"
  mkdir -p "$root/.claude" "$root/.git/worktrees/side" "$wt/.claude" "$fake/.claude"
  printf 'gitdir: %s
' "$root/.git/worktrees/side" > "$wt/.git"
  printf '%s
' "$wt/.git" > "$root/.git/worktrees/side/gitdir"
  resolve_wt() { # $1=cwd → 解決した作業ツリー
    HOOK_ROOT="$root" HOOK_CWD="$1" __hc_resolve_worktree; printf '%s
' "$HOOK_WORKTREE"
  }
  local save_root="$HOOK_ROOT"
  HOOK_ROOT="$root"
  # cwd がルート自身・その配下 → ルート
  assert_eq "HK-T18" "$root" "$(resolve_wt "$root")"
  mkdir -p "$root/sub"
  assert_eq "HK-T18" "$root" "$(resolve_wt "$root/sub")"
  # cwd が本流の worktree → worktree 側
  assert_eq "HK-T18" "$wt" "$(resolve_wt "$wt")"
  mkdir -p "$wt/sub"
  assert_eq "HK-T18" "$wt" "$(resolve_wt "$wt/sub")"
  # cwd が .claude を持つだけの別リポジトリ（参考実装など）→ 拾わずルートに留まる
  assert_eq "HK-T18" "$root" "$(resolve_wt "$fake")"
  # .git が worktree でない実体（普通の別クローン）でも拾わない
  mkdir -p "$fake/.git"
  assert_eq "HK-T18" "$root" "$(resolve_wt "$fake")"
  # 存在しない cwd → ルート
  assert_eq "HK-T18" "$root" "$(resolve_wt "$TMP_REPO/nope/x")"
  HOOK_ROOT="$save_root"
}
case_worktree

finish
