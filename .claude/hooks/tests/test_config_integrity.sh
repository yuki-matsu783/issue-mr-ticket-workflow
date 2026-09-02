#!/usr/bin/env bash
# test_config_integrity.sh — 出荷される設定の整合テスト（HK-T02）。3 つのデータ（scope-limits.json の types / task-types.tsv の type / work-defaults.md の行）のキー集合と、scope-limits.json の許可範囲が フック共通仕様 §8 の初期値どおりに判定されるか
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

# shellcheck disable=SC1091
. "$LOGGER_ROOT/.claude/hooks/lib/scope.sh"

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

# 出荷される scope-limits.json をそのまま読んで判定を出す（雛形ではなく実物の許可範囲を見る）
resolve_real() { # $1=type $2=path
  scope_load "$JSON" "$1" || { echo "load-error rc=$? $SC_ERROR"; return; }
  SC_DECL_WRITE=(); SC_DECL_OPS=(); SC_APPROVED=()
  scope_resolve "$2"
  printf '%s %s %s %s\n' "$SC_DECISION" "${SC_ID:--}" "$SC_STAGE" "${SC_ASK_SCOPE:--}"
}

# HK-T02 アプリルート（apl/）の許可範囲が §8 の初期値どおりに判定される
# 実施タスクは自分のアプリのソース・テスト・列挙したビルド設定を書ける
assert_eq "HK-T02" "allow - 5 -" "$(resolve_real implementation apl/vscode-ticket-board/src/core/a.ts)"
assert_eq "HK-T02" "allow - 5 -" "$(resolve_real implementation apl/vscode-ticket-board/test/a.test.ts)"
assert_eq "HK-T02" "allow - 5 -" "$(resolve_real implementation apl/vscode-ticket-board/README.md)"
assert_eq "HK-T02" "allow - 5 -" "$(resolve_real implementation apl/vscode-ticket-board/package-lock.json)"
# 入れ子の .gitignore は common.protected だが type の allow に明示があるので判定順 (2) を通る
assert_eq "HK-T02" "allow - 5 -" "$(resolve_real implementation apl/vscode-ticket-board/.gitignore)"
assert_eq "HK-T02" "deny WF201 2 -" "$(resolve_real design apl/vscode-ticket-board/.gitignore)"
# ビルド設定は毎回確認（type の confirm）
assert_eq "HK-T02" "ask WF203 4 -" "$(resolve_real implementation apl/vscode-ticket-board/package.json)"
assert_eq "HK-T02" "ask WF203 4 -" "$(resolve_real implementation apl/vscode-ticket-board/tsconfig.json)"
# アプリルート直下は列挙。列挙外（エージェントの指示文・任意のファイル）は無確認で通さない
assert_eq "HK-T02" "ask WF202 7 apl/vscode-ticket-board/CLAUDE.md" "$(resolve_real implementation apl/vscode-ticket-board/CLAUDE.md)"
assert_eq "HK-T02" "ask WF202 7 apl/vscode-ticket-board" "$(resolve_real implementation apl/vscode-ticket-board/.gitattributes)"
assert_eq "HK-T02" "ask WF202 7 apl/vscode-ticket-board" "$(resolve_real implementation apl/vscode-ticket-board/anything.txt)"
# common.file_granular に載るアプリルート直下のファイルは、承認単位が親ディレクトリでなくファイル
assert_eq "HK-T02" "ask WF202 7 apl/vscode-ticket-board/README.md" "$(resolve_real design apl/vscode-ticket-board/README.md)"
assert_eq "HK-T02" "ask WF202 7 apl/vscode-ticket-board/package.json" "$(resolve_real design apl/vscode-ticket-board/package.json)"
assert_eq "HK-T02" "ask WF202 7 apl/vscode-ticket-board/tsconfig.json" "$(resolve_real design apl/vscode-ticket-board/tsconfig.json)"
assert_eq "HK-T02" "ask WF202 7 apl/vscode-ticket-board" "$(resolve_real design apl/vscode-ticket-board/other.txt)"
# 設計文書は実施タスクでは書けず、設計タスクだけが書ける
assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real implementation apl/vscode-ticket-board/docs/10_spec/x.md)"
assert_eq "HK-T02" "allow - 5 -" "$(resolve_real design apl/vscode-ticket-board/docs/10_spec/x.md)"
assert_eq "HK-T02" "allow - 5 -" "$(resolve_real design-feedback apl/vscode-ticket-board/docs/00_requirement/x.md)"
assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real design apl/vscode-ticket-board/src/core/a.ts)"
assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real design-feedback apl/vscode-ticket-board/test/a.test.ts)"
# アプリと AI アセットは互いに書けない
assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real ai-asset-implementation apl/vscode-ticket-board/src/core/a.ts)"
assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real ai-asset-design apl/vscode-ticket-board/docs/10_spec/x.md)"
assert_eq "HK-T02" "deny WF201 2 -" "$(resolve_real implementation .claude/skills/x/SKILL.md)"
# アプリルートの外側（apl/ 直下のファイル）は許可範囲に入らない
assert_eq "HK-T02" "ask WF202 7 apl" "$(resolve_real implementation apl/README.md)"
# 旧置き場: 計画・調査は deny、実施タスクは ask WF202（移行の一度きりの承認を通す）
assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real investigation docs/10_spec/x.md)"
assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real implementation-plan src/vscode-ticket-board/src/a.ts)"
assert_eq "HK-T02" "ask WF202 7 src/vscode-ticket-board/src" "$(resolve_real implementation src/vscode-ticket-board/src/a.ts)"
assert_eq "HK-T02" "ask WF202 7 docs/10_spec" "$(resolve_real design-feedback docs/10_spec/x.md)"

finish
