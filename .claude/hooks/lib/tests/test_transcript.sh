#!/usr/bin/env bash
# test_transcript.sh — transcript.sh のテスト（仕様のテスト ID: HK-T14）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*transcript*'
# テストは set -e を使わない（終了コードは run_cmd が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

LIB="$LOGGER_ROOT/.claude/hooks/lib/transcript.sh"
export LIB
# shellcheck disable=SC1090
. "$LIB"

make_tmp_dir
T="$TMP_DIR/t.jsonl"
# 8 行: assistant(usage, tool_use 1) / user(文字列) / user(tool_result) / 壊れた行 / assistant(usage なし) / assistant(usage, tool_use 2) / 空行 / summary
{
  printf '%s\n' '{"type":"assistant","timestamp":"2026-08-31T00:00:00.000Z","message":{"usage":{"input_tokens":100,"output_tokens":20,"cache_read_input_tokens":5,"cache_creation_input_tokens":7},"content":[{"type":"tool_use","name":"Read","id":"1"},{"type":"text","text":"x"}]}}'
  printf '%s\n' '{"type":"user","timestamp":"2026-08-31T00:00:10Z","message":{"content":"hello"}}'
  printf '%s\n' '{"type":"user","timestamp":"2026-08-31T00:00:20Z","message":{"content":[{"type":"tool_result","tool_use_id":"1","content":"ok"}]}}'
  printf '%s\n' '{not json'
  printf '%s\n' '{"type":"assistant","timestamp":"2026-08-31T00:00:30Z","message":{"content":[{"type":"text","text":"no usage"}]}}'
  printf '%s\n' '{"type":"assistant","timestamp":"2026-08-31T00:00:40Z","message":{"usage":{"input_tokens":200,"output_tokens":30},"content":[{"type":"tool_use","name":"Bash","id":"2"},{"type":"tool_use","name":"Edit","id":"3"}]}}'
  printf '\n'
  printf '%s\n' '{"type":"summary","summary":"s"}'
} > "$T"
EPOCH0=1788134400   # 2026-08-31T00:00:00Z

field() { printf '%s' "$R_OUT" | tl_jq -r "$1"; }

case_hk_t14_full() {
  run_cmd transcript_aggregate "$T" 0
  assert_exit "HK-T14" 0
  assert_eq "HK-T14" "1" "$(printf '%s\n' "$R_OUT" | grep -c .)"
  assert_eq "HK-T14" "300 50 5 7 3 3 2 8" "$(field '[.input, .output, .cache_read, .cache_write, .tool_calls, .responses, .parse_errors, .new_offset] | map(tostring) | join(" ")')"
  assert_eq "HK-T14" "a u r a a" "$(field '[.timestamps[][1]] | join(" ")')"
  assert_eq "HK-T14" "$EPOCH0 $((EPOCH0 + 10)) $((EPOCH0 + 20)) $((EPOCH0 + 30)) $((EPOCH0 + 40))" "$(field '[.timestamps[][0]] | map(tostring) | join(" ")')"
}

case_hk_t14_cursor() {
  # 進んだカーソルで呼ぶと差分だけ。末尾のカーソルで呼ぶと 0
  run_cmd transcript_aggregate "$T" 5
  assert_eq "HK-T14" "200 30 0 0 2 1 0 8" "$(field '[.input, .output, .cache_read, .cache_write, .tool_calls, .responses, .parse_errors, .new_offset] | map(tostring) | join(" ")')"
  run_cmd transcript_aggregate "$T" 8
  assert_eq "HK-T14" "0 0 0 0 0 0 0 8" "$(field '[.input, .output, .cache_read, .cache_write, .tool_calls, .responses, .parse_errors, .new_offset] | map(tostring) | join(" ")')"
  assert_eq "HK-T14" "0" "$(field '.timestamps | length')"
  # 同じカーソルで 2 回呼ぶと同じ値
  run_cmd transcript_aggregate "$T" 3
  local first="$R_OUT"
  run_cmd transcript_aggregate "$T" 3
  assert_eq "HK-T14" "$first" "$R_OUT"
  assert_eq "HK-T14" "200 2 8" "$(field '[.input, .parse_errors, .new_offset] | map(tostring) | join(" ")')"
  # カーソルが総行数を超えていても壊れない
  run_cmd transcript_aggregate "$T" 100
  assert_eq "HK-T14" "0 8" "$(field '[.input, .new_offset] | map(tostring) | join(" ")')"
  # 追記されたら追記分だけ
  printf '%s\n' '{"type":"assistant","timestamp":"2026-08-31T00:01:00Z","message":{"usage":{"input_tokens":1,"output_tokens":1},"content":[]}}' >> "$T"
  run_cmd transcript_aggregate "$T" 8
  assert_eq "HK-T14" "1 1 1 0 9" "$(field '[.input, .output, .responses, .tool_calls, .new_offset] | map(tostring) | join(" ")')"
}

case_hk_t14_edge() {
  run_cmd transcript_aggregate "$TMP_DIR/missing.jsonl" 3
  assert_exit "HK-T14" 0
  assert_eq "HK-T14" "0 0 3" "$(field '[.input, .responses, .new_offset] | map(tostring) | join(" ")')"
  : > "$TMP_DIR/empty.jsonl"
  run_cmd transcript_aggregate "$TMP_DIR/empty.jsonl" 0
  assert_exit "HK-T14" 0
  assert_eq "HK-T14" "0 0" "$(field '[.input, .new_offset] | map(tostring) | join(" ")')"
  # CRLF の transcript でも同じ集計
  sed 's/$/\r/' "$T" > "$TMP_DIR/crlf.jsonl"
  run_cmd transcript_aggregate "$TMP_DIR/crlf.jsonl" 0
  assert_eq "HK-T14" "301 51 4 2 9" "$(field '[.input, .output, .responses, .parse_errors, .new_offset] | map(tostring) | join(" ")')"
  # オフセット付きのタイムスタンプは UTC に直す
  printf '%s\n' '{"type":"assistant","timestamp":"2026-08-31T09:00:00+09:00","message":{"usage":{"input_tokens":1,"output_tokens":1},"content":[]}}' > "$TMP_DIR/tz.jsonl"
  run_cmd transcript_aggregate "$TMP_DIR/tz.jsonl" 0
  assert_eq "HK-T14" "$EPOCH0" "$(field '.timestamps[0][0]')"
  # 引数の不正
  run_cmd transcript_aggregate "$T" abc
  assert_eq "HK-T14" "301" "$(field '.input')"
  # jq 不在 → 0 の結果と戻り 1（何もしない）
  make_restricted_path bash
  run_cmd env PATH="$RESTRICTED_PATH" bash -c ". '$LIB'; transcript_aggregate '$T' 0"
  assert_exit "HK-T14" 1
  assert_contains "HK-T14" '"new_offset":0'
}

case_hk_t14_full
case_hk_t14_cursor
case_hk_t14_edge
finish
