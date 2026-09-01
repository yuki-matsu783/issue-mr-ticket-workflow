#!/usr/bin/env bash
# test_frontmatter.sh — frontmatter.sh のテスト（仕様のテスト ID: FR-T01〜05）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*frontmatter*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

LIB="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts/frontmatter.sh"
make_tmp_dir
cd "$TMP_DIR" || exit 2

# ---- フィクスチャ ----
cat > ticket.md <<'EOF'
---
type: ticket
ticket_type: implementation   # 行末コメント
predecessors: ["0006", '0007']
executor: "sonnet"
human_review: {required: true, reason: "a: b, c"}
adversarial_review: {required: false, reason: 'x #1'}
allow:
  write: ["src/auth/**", "tests/auth/**"]
  ops: ["read", "build-test"]
started_at: ""
---

# 本文
predecessors: ["9999"]
EOF
printf '%s\r\n' '---' 'ticket_type  :  design  ' 'predecessors: [ "0001" ,"0002" ]  # c' 'allow:' '  ops: ["read"]' '---' 'body' > crlf.md
printf '%s\n' '# 見出しだけ' 'ticket_type: nope' > nofm.md
printf '%s\n' '---' 'predecessors:' '  - a' '  - b' 'ticket_type: x' '---' > block.md

# 純 bash で呼ぶ: PATH を無効化した bash の中で source して実行する（外部プロセスを起動していれば command not found が出る）
fm() { # $1=関数 $2=file $3=key
  run_cmd bash -c 'PATH=/nonexistent; source "$1" || exit 9; "$2" "$3" "$4"' _ "$LIB" "$1" "$2" "$3"
}

# FR-T01 フラットなスカラーとフロー配列
fm fm_get ticket.md ticket_type
assert_eq "FR-T01" "implementation" "$R_OUT"
fm fm_list ticket.md predecessors
assert_eq "FR-T01" $'0006\n0007' "$R_OUT"
fm fm_get ticket.md executor
assert_eq "FR-T01" "sonnet" "$R_OUT"
fm fm_get ticket.md type
assert_eq "FR-T01" "ticket" "$R_OUT"

# FR-T02 入れ子マッピング
fm fm_list ticket.md allow.write
assert_eq "FR-T02" $'src/auth/**\ntests/auth/**' "$R_OUT"
fm fm_list ticket.md allow.ops
assert_eq "FR-T02" $'read\nbuild-test' "$R_OUT"
fm fm_has ticket.md allow
assert_exit "FR-T02" 0
fm fm_has ticket.md allow.ops
assert_exit "FR-T02" 0

# FR-T03 インラインマップ。クォート内の : と , を区切りにしない
fm fm_get ticket.md human_review.required
assert_eq "FR-T03" "true" "$R_OUT"
fm fm_get ticket.md human_review.reason
assert_eq "FR-T03" "a: b, c" "$R_OUT"
fm fm_get ticket.md adversarial_review.reason
assert_eq "FR-T03" "x #1" "$R_OUT"
fm fm_get ticket.md adversarial_review.required
assert_eq "FR-T03" "false" "$R_OUT"

# FR-T04 CRLF・キー前後の空白・行末コメント
fm fm_get crlf.md ticket_type
assert_eq "FR-T04" "design" "$R_OUT"
fm fm_list crlf.md predecessors
assert_eq "FR-T04" $'0001\n0002' "$R_OUT"
fm fm_list crlf.md allow.ops
assert_eq "FR-T04" "read" "$R_OUT"
fm fm_get ticket.md started_at
assert_eq "FR-T04" "" "$R_OUT"
assert_exit "FR-T04" 0

# FR-T05 frontmatter 無し・キー無し・ブロック配列は空 + 1。外部プロセスを起動しない
fm fm_get nofm.md ticket_type
assert_exit "FR-T05" 1
assert_eq "FR-T05" "" "$R_OUT"
fm fm_get ticket.md nosuchkey
assert_exit "FR-T05" 1
fm fm_get ticket.md allow.nosuch
assert_exit "FR-T05" 1
fm fm_list block.md predecessors
assert_exit "FR-T05" 1
assert_eq "FR-T05" "" "$R_OUT"
fm fm_get block.md ticket_type
assert_eq "FR-T05" "x" "$R_OUT"
assert_not_contains "FR-T05" "not found"
fm fm_get ticket.md human_review.required
assert_not_contains "FR-T05" "not found"

finish
