#!/usr/bin/env bash
# test_config_integrity.sh — 出荷される設定の整合テスト（HK-T01 / HK-T02 / HK-T09）
#   HK-T01: settings.json の登録が フック共通仕様 §1 の表（期待値 fixtures/settings-hooks.expected.tsv）と一致する
#   HK-T02: scope-limits.json の types / task-types.tsv の type / work-defaults.md の行の 3 つのキー集合が一致し、
#           出荷される scope-limits.json の許可範囲が フック共通仕様 §8 の初期値どおりに判定される
#   HK-T09: 拒否側の登録ラッパーが、本体を起動できないときだけ deny（WFx09）を出す
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

# shellcheck disable=SC1091
. "$LOGGER_ROOT/.claude/hooks/lib/cmdpos.sh"
# shellcheck disable=SC1091
. "$LOGGER_ROOT/.claude/hooks/lib/scope.sh"

JSON="$LOGGER_ROOT/.claude/hooks/config/scope-limits.json"
TSV="$LOGGER_ROOT/.claude/hooks/config/task-types.tsv"
WD="$LOGGER_ROOT/.claude/rules/work-defaults.md"

# 上限設定は hook_read_input が HC_LIMITS に読む形になった（DDR i0009-48）。
# 出荷される scope-limits.json をそのまま偽のルートに置き、最小の stdin で HC_LIMITS を作る。
# shellcheck disable=SC1091
. "$LOGGER_ROOT/.claude/hooks/lib/hook-common.sh"
CI_FAKE_ROOT="$(mktemp -d)"
mkdir -p "$CI_FAKE_ROOT/.claude/hooks/config"
cat "$JSON" > "$CI_FAKE_ROOT/.claude/hooks/config/scope-limits.json"
load_shipped_limits() {
  HOOK_ROOT="$CI_FAKE_ROOT" hook_read_input limits <<<'{"session_id":"t","tool_name":"Bash"}' || true
}

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
# 出荷される scope-limits.json を読んだうえで、コマンドの分類を実際に走らせる
classify_real() { # $1=コマンド → 分類
  load_shipped_limits
  scope_load implementation >/dev/null || { echo "load-error"; return; }
  cmdpos_parse "$1"
  scope_classify 0 >/dev/null
  printf '%s\n' "$SC_CLASS"
}
has_build_test_cmd() { # $1=コマンド文字列 → yes/no（列挙に含まれるか）
  if [ "$(tl_jq -r --arg c "$1" '.commands["build-test"] | index($c) != null' "$JSON")" = "true" ]; then echo yes; else echo no; fi
}

# HK-T02 アプリのテスト手順がクリーンな作業ツリーで最後まで通る形で列挙されている
# （完全一致では見ない。アプリが増えたり形が足されたりしても、必要な形が残っていることだけを固定する）
for c in "npm ci" "npm run compile" "npm test" \
         "npm --prefix apl/vscode-ticket-board ci" \
         "npm --prefix apl/vscode-ticket-board run compile" \
         "npm --prefix apl/vscode-ticket-board test"; do
  assert_eq "HK-T02" "yes" "$(has_build_test_cmd "$c")"
done
# npm install は列挙しない（package-lock.json を書き換えうるので人間の確認を通す）
assert_eq "HK-T02" "no" "$(has_build_test_cmd "npm install")"

# HK-T02 列挙した形が実際に build-test に分類され、列挙に無い形は分類されない（文字列の一致だけでなく振る舞いを見る）
assert_eq "HK-T02" "build-test" "$(classify_real 'npm ci')"
assert_eq "HK-T02" "build-test" "$(classify_real 'npm run compile')"
assert_eq "HK-T02" "build-test" "$(classify_real 'npm test')"
assert_eq "HK-T02" "build-test" "$(classify_real 'npm --prefix apl/vscode-ticket-board ci')"
assert_eq "HK-T02" "build-test" "$(classify_real 'npm --prefix apl/vscode-ticket-board test')"
assert_eq "HK-T02" "unknown" "$(classify_real 'npm install')"
assert_eq "HK-T02" "unknown" "$(classify_real 'npm publish')"
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

# HK-T09 の make_tmp_repo が cwd を一時リポジトリに移すので、出荷物を読む検査の前に戻す
cd "$LOGGER_ROOT" || true

# ---- HK-T02（続き）: 出荷される scope-limits.json の許可範囲が §8 の初期値どおりに判定される ----
# 出荷される scope-limits.json をそのまま読んで判定を出す（雛形ではなく実物の許可範囲を見る）
resolve_real() { # $1=type $2=path
  load_shipped_limits
  scope_load "$1" || { echo "load-error rc=$? $SC_ERROR"; return; }
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
# 旧置き場（リポジトリ直下の src/ docs/）の移行は完了済み。特別扱いを残さず、他の未記載のパスと同じ ask WF202 に落ちる
assert_eq "HK-T02" "ask WF202 7 docs/10_spec" "$(resolve_real investigation docs/10_spec/x.md)"
assert_eq "HK-T02" "ask WF202 7 src/vscode-ticket-board/src" "$(resolve_real implementation-plan src/vscode-ticket-board/src/a.ts)"
# 計画・調査タスクは成果物（apl/**）を書けない状態を保つ。7 type すべてを見る（1 つでも緩むと計画タスクが成果物を触れる）
for t in investigation investigation-plan design-plan implementation-plan \
         design-feedback-plan ai-asset-design-plan ai-asset-implementation-plan; do
  assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real "$t" apl/vscode-ticket-board/src/core/a.ts)"
  assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real "$t" apl/vscode-ticket-board/docs/10_spec/x.md)"
  assert_eq "HK-T02" "deny WF201 3 -" "$(resolve_real "$t" apl/vscode-ticket-board/package.json)"
  # .claude/** は common.protected でもあるので、type の deny より先に判定順 (2) で落ちる
  assert_eq "HK-T02" "deny WF201 2 -" "$(resolve_real "$t" .claude/rules/x.md)"
done

finish
