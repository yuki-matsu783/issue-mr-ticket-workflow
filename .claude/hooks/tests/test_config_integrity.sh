#!/usr/bin/env bash
# test_config_integrity.sh — 3 つのデータ（scope-limits.json の types / task-types.tsv の type / work-defaults.md の行）の整合テスト（HK-T02）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

JSON="$LOGGER_ROOT/.claude/hooks/config/scope-limits.json"
TSV="$LOGGER_ROOT/.claude/hooks/config/task-types.tsv"
WD="$LOGGER_ROOT/.claude/rules/work-defaults.md"

# 3 つのキー集合（ソート済み・1 行 1 type）
json_types="$(tl_jq -r '.types | keys[]' "$JSON" | sort)"
tsv_types="$(grep -v '^#' "$TSV" | cut -f2 | tr -d '\r' | sort)"
wd_types="$(grep -E '^\| [a-z-]+ \| (サブエージェント|メインエージェント)' "$WD" | cut -d'|' -f2 | tr -d ' \r' | sort)"

# HK-T02 3 つのキー集合が一致し、15 種ある
assert_eq "HK-T02" "$json_types" "$tsv_types"
assert_eq "HK-T02" "$json_types" "$wd_types"
assert_eq "HK-T02" "15" "$(printf '%s\n' "$json_types" | grep -c .)"

# 付随: scope-limits.json の形式（common 5 キー・types 全件に ops・commands.build-test が配列）と tsv の 6 列
assert_eq "HK-T02" "allow confirm file_granular protected state_files" "$(tl_jq -r '.common | keys | join(" ")' "$JSON")"
assert_eq "HK-T02" "true" "$(tl_jq -r '[.types[] | has("ops")] | all' "$JSON")"
assert_eq "HK-T02" "array" "$(tl_jq -r '.commands["build-test"] | type' "$JSON")"
assert_eq "HK-T02" "6" "$(awk -F'\t' '{ print NF }' "$TSV" | sort -u | tr -d '\n')"
# 対の相手が type 集合の中にあるか（- を除く）
bad_pairs="$(grep -v '^#' "$TSV" | cut -f6 | tr -d '\r' | grep -v '^-$' | sort -u | comm -23 - <(printf '%s\n' "$json_types"))"
assert_eq "HK-T02" "" "$bad_pairs"

finish
