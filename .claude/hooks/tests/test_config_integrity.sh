#!/usr/bin/env bash
# test_config_integrity.sh — 設定の整合テスト（HK-T01 / HK-T02 / HK-T09）
#   HK-T01: settings.json の登録が フック共通仕様 §1 の表（期待値 fixtures/settings-hooks.expected.tsv）と一致する
#   HK-T02: scope-limits.json の types / task-types.tsv の type / work-defaults.md の行の 3 つのキー集合が一致する
#   HK-T09: 拒否側の登録ラッパーが、本体を起動できないときだけ deny（WFx09）を出す
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
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

# ---- HK-T01: settings.json の登録が §1 の表と一致する ----
# 位置は「同じイベント内の配列上の位置」（matcher のグループを跨いでフック単位で数える）。実行順ではない
EXPECTED="$LOGGER_ROOT/.claude/hooks/tests/fixtures/settings-hooks.expected.tsv"
SETTINGS="$LOGGER_ROOT/.claude/settings.json"

hk01_actual() {
  tl_jq -r '
    ["SessionStart","UserPromptSubmit","PreToolUse","PostToolUse","SubagentStart","SubagentStop","Stop"][] as $ev
    | [ (.hooks[$ev] // [])[] | (.matcher // "") as $m | (.hooks // [])[] | [$m, (.command // "")] ]
    | to_entries[]
    | [$ev, .value[0], (.key + 1 | tostring), .value[1]]
    | @tsv' "$SETTINGS"
}
hk01_expected() { grep -v '^#' "$EXPECTED" | tr -d '\r' | grep -v '^$'; }

if [[ -f "$EXPECTED" ]]; then pass "HK-T01"; else fail "HK-T01" "期待値が無い: $EXPECTED"; fi
# 16 行（当初 17 行。T9 が外れて PreToolUse `Agent` の subagent-start-check を外した縮退。0031 の作業ログ）
assert_eq "HK-T01" "16" "$(hk01_expected | grep -c .)"
# 引数を取る 2 行（--accumulate）
assert_eq "HK-T01" "2" "$(hk01_expected | grep -c -- '--accumulate$')"
# 実体のディレクトリと登録先イベントが一致しない行。仕様 §1 は 4 行（12-SubagentStart → PreToolUse /
# 13-SubagentStop → PostToolUse / 22-PostToolUse → SubagentStop・Stop）と書くが、機械的に数えると 5 行になる。
# 内訳の差は 2 つ: workflow-entry（実体は 10-UserPromptSubmit）の PreToolUse 2 行（Skill と未宣言の拒否）が
# 数え漏れている（+2）／T9 の縮退で 12-SubagentStart → PreToolUse の 1 行が消えた（-1）。どちらも 0032 へ
assert_eq "HK-T01" "5" "$(hk01_expected | awk -F'\t' '
  BEGIN { map["SessionStart"] = "00-SessionStart"; map["UserPromptSubmit"] = "10-UserPromptSubmit";
          map["PreToolUse"] = "20-PreToolUse"; map["PostToolUse"] = "22-PostToolUse";
          map["SubagentStart"] = "12-SubagentStart"; map["SubagentStop"] = "13-SubagentStop"; map["Stop"] = "-" }
  { d = $4; sub(/.*\/\.claude\/hooks\//, "", d); sub(/\/.*/, "", d); if (d != map[$1]) n++ }
  END { print n + 0 }')"
# 拒否側 5 行のラッパーの識別子（百の位）がフック名と対応している
assert_eq "HK-T01" "5" "$(hk01_expected | grep -c -F "|| printf '%s'")"
for hk01_pair in workflow-entry:WF109 workflow-guard:WF209 workflow-state-guard:WF309 block-direct-git:WF409 block-chmod:WF509; do
  hk01_name="${hk01_pair%%:*}"; hk01_id="${hk01_pair#*:}"
  hk01_line="$(hk01_expected | grep -F "/$hk01_name.sh\" ||")" || hk01_line=""
  if [[ "$hk01_line" == *"$hk01_id: フック $hk01_name を実行できない"* ]]; then
    pass "HK-T01"
  else
    fail "HK-T01" "$hk01_name のラッパーが $hk01_id で登録されていない"
  fi
done

# 実登録との照合（未登録の段では差分が出る = 登録が終わるまで落ち続ける）
hk01_diff="$(diff <(hk01_expected) <(hk01_actual) 2>&1)" || true
if [[ -z "$hk01_diff" ]]; then
  pass "HK-T01"
else
  fail "HK-T01" "settings.json が期待値と違う（< 期待 / > 実際）: $(printf '%s' "$hk01_diff" | tr '\n' ' ' | head -c 400)"
fi

# ---- HK-T09: 拒否側の登録ラッパー ----
# 期待値の command 文字列をそのまま使い、CLAUDE_PROJECT_DIR を一時リポジトリに向けて実行する。
# 実登録のフックを壊す破壊試験ではない（壊すと自分自身をロックアウトする）
make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/20-PreToolUse"
HK09_CMD="$(hk01_expected | awk -F'\t' '$4 ~ /block-direct-git/ { print $4 }')"
HK09_SH="$TMP_REPO/.claude/hooks/20-PreToolUse/block-direct-git.sh"
hk09_run() { run_cmd env "CLAUDE_PROJECT_DIR=$TMP_REPO" bash -c "$HK09_CMD"; }

# (1) 本体が無い → deny（WF409）
rm -f "$HK09_SH"
hk09_run
assert_contains "HK-T09" "WF409"
assert_contains "HK-T09" '"permissionDecision":"deny"'
# (2) 本体が構文エラー → deny（WF409）
printf '%s\n' 'if ( then fi' > "$HK09_SH"
hk09_run
assert_contains "HK-T09" "WF409"
# (3) 本体が deny を出す → その deny が 1 つだけ出て、ラッパーの deny は重ならない
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'printf "%s" "{\\\"hookSpecificOutput\\\":{\\\"permissionDecision\\\":\\\"deny\\\",\\\"permissionDecisionReason\\\":\\\"WF401\\\"}}"'
  printf '%s\n' 'exit 0'
} > "$HK09_SH"
hk09_run
assert_contains "HK-T09" "WF401"
assert_not_contains "HK-T09" "WF409"
assert_eq "HK-T09" "1" "$(printf '%s' "$R_OUT" | grep -o 'hookSpecificOutput' | grep -c .)"
# (4) 本体が許可（無出力・終了 0）→ ラッパーも何も出さない
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$HK09_SH"
hk09_run
assert_eq "HK-T09" "" "$R_OUT"
assert_exit "HK-T09" 0

finish
