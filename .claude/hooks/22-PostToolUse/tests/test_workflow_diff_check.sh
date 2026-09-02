#!/usr/bin/env bash
# test_workflow_diff_check.sh — workflow-diff-check.sh のテスト（仕様のテスト ID: DC-T01〜DC-T07）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*workflow_diff_check*'
# テストは set -e を使わない（終了コードは hook_run が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SRC="$LOGGER_ROOT/.claude/hooks"
SKILL_SCRIPTS="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/22-PostToolUse" "$TMP_REPO/.claude/hooks/lib" "$TMP_REPO/.claude/hooks/config" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts" \
         "$TMP_REPO/wip/10_tickets/00_todo" "$TMP_REPO/wip/10_tickets/10_doing" "$TMP_REPO/wip/10_tickets/20_done" \
         "$TMP_REPO/src" "$TMP_REPO/docs"
cp "$SRC/22-PostToolUse/workflow-diff-check.sh" "$TMP_REPO/.claude/hooks/22-PostToolUse/"
cp "$SRC/lib/hook-common.sh" "$SRC/lib/cmdpos.sh" "$SRC/lib/scope.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$SKILL_SCRIPTS/logger.sh" "$SKILL_SCRIPTS/frontmatter.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"
cp "$SRC/config/scope-limits.json" "$TMP_REPO/.claude/hooks/config/"
TMP_HOOK="$TMP_REPO/.claude/hooks/22-PostToolUse/workflow-diff-check.sh"
LIMITS="$TMP_REPO/.claude/hooks/config/scope-limits.json"
LIMITS_JSON="$(cat "$LIMITS")"   # 復元用。控えをリポジトリ内に置くと、それ自体が範囲外の差分になる

printf 'print("a")\n' > "$TMP_REPO/src/a.py"
printf 'print("old")\n' > "$TMP_REPO/src/old.py"
printf '# doc\n' > "$TMP_REPO/docs/keep.md"

# 素の状態を先にコミットする（start_case の git clean -qfdx が下ごしらえごと消さないように）
git -C "$TMP_REPO" add -A >/dev/null 2>&1
git -C "$TMP_REPO" commit -q -m "setup" >/dev/null 2>&1

TK="0100-work.md"
TKP="wip/10_tickets/10_doing/$TK"
BASE=""

# ---- 補助 ----
write_ticket() { # $1=ticket_type $2=base_sha $3=predecessors（配列の中身。空可）
  mkdir -p "$TMP_REPO/wip/10_tickets/10_doing"
  {
    printf -- '---\n'
    printf 'type: ticket\n'
    printf 'ticket_type: %s\n' "$1"
    printf 'predecessors: [%s]\n' "$3"
    printf 'allow:\n'
    printf '  write: []\n'
    printf '  ops: ["read"]\n'
    printf 'base_sha: "%s"\n' "$2"
    printf -- '---\n\n# 0100 テスト用チケット\n'
  } > "$TMP_REPO/$TKP"
}

# 基準点を作る: 素の状態をコミットしてから、チケットに base_sha を書き戻す
# （実運用と同じく、基準点のコミットにはチケットの「元の姿」が入る）
start_case() { # $1=ticket_type $2=predecessors
  git -C "$TMP_REPO" checkout -q -- . 2>/dev/null
  git -C "$TMP_REPO" clean -qfdx 2>/dev/null
  mkdir -p "$TMP_REPO/wip/10_tickets/00_todo" "$TMP_REPO/wip/10_tickets/20_done"
  rm -f "$TMP_REPO"/wip/10_tickets/10_doing/*.md
  write_ticket "$1" "PLACEHOLDER" "$2"
  git -C "$TMP_REPO" add -A >/dev/null 2>&1
  git -C "$TMP_REPO" commit -q -m "case" >/dev/null 2>&1
  BASE="$(git -C "$TMP_REPO" rev-parse --short HEAD)"
  write_ticket "$1" "$BASE" "$2"
  return 0
}

HOOK_ENV=()
hook_run() { # $@ = hook_payload の引数（event tool [key=value ...]）
  R_ERR=""
  R_OUT="$( ( cd "$TMP_REPO" && hook_payload "$@" ) \
            | ( cd "$TMP_REPO" && env ${HOOK_ENV[@]+"${HOOK_ENV[@]}"} bash "$TMP_HOOK" ) 2>/dev/null )"
  R_EXIT=$?
  return 0
}

# 書き込み以外の操作（Bash の読み取り）で差分だけを見せる既定の呼び出し
hook_run_read() { hook_run PostToolUse Bash command='ls -la'; }

approvals_file() { printf '%s\n' "$TMP_REPO/logs/sessions/testsession/approvals.json"; }

# ---- DC-T01: 作業中 0 枚 / 許可範囲内だけなら何も出さない ----
case_quiet() {
  start_case investigation ""
  rm -f "$TMP_REPO"/wip/10_tickets/10_doing/*.md
  hook_run_read
  assert_eq "DC-T01" "" "$R_OUT"
  assert_exit "DC-T01" 0

  # 許可範囲内の差分（チケット自身の base_sha 書き戻し + wip/20_plans の新規）だけなら黙る
  start_case investigation ""
  mkdir -p "$TMP_REPO/wip/20_plans"
  printf 'plan\n' > "$TMP_REPO/wip/20_plans/p.md"
  hook_run_read
  assert_eq "DC-T01" "" "$R_OUT"
  assert_exit "DC-T01" 0
}

# ---- DC-T02: 範囲外の変更・未追跡・移動先を WF601 に並べ、logs/ と wip/tmp/ は除外する ----
case_out_of_scope() {
  start_case investigation ""
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"          # 変更（tracked）
  printf '# new\n' > "$TMP_REPO/docs/b.md"                     # 未追跡
  git -C "$TMP_REPO" mv src/old.py src/new.py >/dev/null 2>&1  # 移動先で判定する
  mkdir -p "$TMP_REPO/logs" "$TMP_REPO/wip/tmp" "$TMP_REPO/wip/20_plans"
  printf 'log\n' > "$TMP_REPO/logs/x.log"                      # 除外
  printf 'tmp\n' > "$TMP_REPO/wip/tmp/y.txt"                   # 除外
  printf 'plan\n' > "$TMP_REPO/wip/20_plans/p.md"              # 許可範囲
  mkdir -p "$TMP_REPO/docs/sub"
  printf '# deep\n' > "$TMP_REPO/docs/sub/c.md"                 # 未追跡ディレクトリの中身も 1 件ずつ出す

  hook_run_read
  assert_contains "DC-T02" "WF601"
  # 既定の git status は未追跡をディレクトリに畳むが、それでは中身の許可範囲を判定できない（-uall）
  assert_contains "DC-T02" "docs/sub/c.md（未追跡"
  assert_contains "DC-T02" "src/a.py（変更"
  assert_contains "DC-T02" "docs/b.md（未追跡"
  assert_contains "DC-T02" "src/new.py（移動先"
  assert_not_contains "DC-T02" "logs/x.log"
  assert_not_contains "DC-T02" "wip/tmp/y.txt"
  assert_not_contains "DC-T02" "wip/20_plans/p.md"
  # 復旧の指示（巻き戻しは AI が行う）
  assert_contains "DC-T02" "git checkout $BASE --"
  assert_exit "DC-T02" 0

  # 一覧は 20 件で打ち切る（超過分は件数だけ）。subagent-stop-check の WF812 / WF813 と同じ上限
  start_case investigation ""
  local i
  for (( i = 1; i <= 25; i++ )); do printf '# g\n' > "$TMP_REPO/docs/g$i.md"; done
  hook_run_read
  assert_contains "DC-T02" "（他 5 件）"
  assert_eq "DC-T02" "20" "$(printf '%s' "$R_OUT" | grep -o 'docs/g[0-9]*\.md（未追跡' | wc -l | tr -d ' ')"
  rm -f "$TMP_REPO"/docs/g*.md

  # 停止中は何も出さない
  start_case investigation ""
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  HOOK_ENV=(WORKFLOW_ENFORCE=0)
  hook_run_read
  assert_eq "DC-T02" "" "$R_OUT"
  HOOK_ENV=(WORKFLOW_DIFF_CHECK_ENFORCE=0)
  hook_run_read
  assert_eq "DC-T02" "" "$R_OUT"
  HOOK_ENV=()
}

# ---- DC-T03: 承認の記憶（親ディレクトリ / file_granular はファイル単位 / confirm は記憶しない）----
case_approvals() {
  start_case investigation ""
  mkdir -p "$TMP_REPO/notes"
  printf 'memo\n' > "$TMP_REPO/notes/memo.md"
  hook_run PostToolUse Write "file_path=$TMP_REPO/notes/memo.md"
  local f; f="$(approvals_file)"
  if [[ -f "$f" ]]; then pass "DC-T03"; else fail "DC-T03" "approvals.json が作られていない"; fi
  assert_eq "DC-T03" "notes" "$(tl_jq -r '[.[].scope] | join(",")' "$f" 2>/dev/null)"
  # 承認された範囲は同じ操作の差分判定でも許可になる（WF601 を出さない）
  assert_eq "DC-T03" "" "$R_OUT"

  # file_granular（CLAUDE.md）はファイル単位
  printf '# CLAUDE\n' > "$TMP_REPO/CLAUDE.md"
  hook_run PostToolUse Write "file_path=$TMP_REPO/CLAUDE.md"
  assert_eq "DC-T03" "notes,CLAUDE.md" "$(tl_jq -r '[.[].scope] | join(",")' "$f" 2>/dev/null)"

  # 同じ範囲を二重に記録しない
  hook_run PostToolUse Write "file_path=$TMP_REPO/notes/other.md"
  assert_eq "DC-T03" "notes,CLAUDE.md" "$(tl_jq -r '[.[].scope] | join(",")' "$f" 2>/dev/null)"

  # Bash のリダイレクト先も承認単位になる（ツールの種類を問わない）
  hook_run PostToolUse Bash 'command=printf x > out/z.txt'
  assert_eq "DC-T03" "notes,CLAUDE.md,out" "$(tl_jq -r '[.[].scope] | join(",")' "$f" 2>/dev/null)"

  # リポジトリの外のパスは承認単位にしない（hook_rel_path は外のパスを絶対パスのまま返す）
  hook_run PostToolUse Write "file_path=/tmp/outside/evil.md"
  assert_eq "DC-T03" "notes,CLAUDE.md,out" "$(tl_jq -r '[.[].scope] | join(",")' "$f" 2>/dev/null)"

  # 毎回確認（WF203）の範囲は記憶しない。ai-asset-implementation では .claude/hooks/** が type の許可範囲で、
  # .claude/hooks/config/** だけが confirm になる
  start_case ai-asset-implementation ""
  hook_run PostToolUse Write "file_path=$TMP_REPO/.claude/hooks/config/new.json"
  f="$(approvals_file)"
  if [[ ! -f "$f" ]]; then pass "DC-T03"; else fail "DC-T03" "confirm 範囲が記憶されている: $(cat "$f")"; fi
}

# ---- DC-T04: 先行チケットの未完了 ----
case_predecessors() {
  start_case investigation '"0001"'
  hook_run_read
  assert_contains "DC-T04" "WF602"
  assert_contains "DC-T04" "0001"

  printf 'done\n' > "$TMP_REPO/wip/10_tickets/20_done/0001-investigation.md"
  hook_run_read
  assert_not_contains "DC-T04" "WF602"
  assert_exit "DC-T04" 0
}

# ---- DC-T05: 種類の改変 ----
case_type_changed() {
  start_case investigation ""
  write_ticket design "$BASE" ""
  hook_run_read
  assert_contains "DC-T05" "WF603"
  assert_contains "DC-T05" "元: investigation"
  assert_contains "DC-T05" "現在: design"
  assert_exit "DC-T05" 0

  # 基準点にチケットが無ければ（持ち越しの未追跡チケット）検査しない
  start_case investigation ""
  git -C "$TMP_REPO" rm -q --cached "$TKP" >/dev/null 2>&1
  git -C "$TMP_REPO" commit -q -m "untrack" >/dev/null 2>&1
  BASE="$(git -C "$TMP_REPO" rev-parse --short HEAD)"   # 基準点にチケットが入っていないコミット
  write_ticket design "$BASE" ""
  hook_run_read
  assert_not_contains "DC-T05" "WF603"
}

# ---- DC-T06: 基準点なし / 作業中 2 枚 / 設定不正 ----
case_boundary() {
  start_case investigation ""
  write_ticket investigation "" ""
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  hook_run_read
  assert_contains "DC-T06" "WF604"
  assert_not_contains "DC-T06" "WF601"
  assert_exit "DC-T06" 0

  # 作業中 2 枚は判定不能として黙る
  start_case investigation ""
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  cp "$TMP_REPO/$TKP" "$TMP_REPO/wip/10_tickets/10_doing/0101-work.md"
  hook_run_read
  assert_eq "DC-T06" "" "$R_OUT"
  assert_exit "DC-T06" 0

  # 設定不正（scope-limits.json が壊れている）も黙る
  start_case investigation ""
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  printf 'broken' > "$LIMITS"
  hook_run_read
  assert_eq "DC-T06" "" "$R_OUT"
  assert_exit "DC-T06" 0
  printf '%s\n' "$LIMITS_JSON" > "$LIMITS"

  # 種類が上限設定に無いときも黙る
  start_case investigation ""
  write_ticket no-such-type "$BASE" ""
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  hook_run_read
  assert_eq "DC-T06" "" "$R_OUT"
  assert_exit "DC-T06" 0

  # 基準点が解決できない値なら差分の取得に失敗したのと同じで黙る
  # （続けると WF601 に解決できない値を「基準点は X」と書き、復旧指示も動かない）
  start_case investigation ""
  write_ticket investigation "deadbee" ""
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  hook_run_read
  assert_eq "DC-T06" "" "$R_OUT"
  assert_exit "DC-T06" 0
}

# ---- DC-T07: git が使えない環境では何も出さずに終了 0 ----
case_no_git() {
  start_case investigation ""
  printf 'print("changed")\n' > "$TMP_REPO/src/a.py"
  make_restricted_path jq bash cat mkdir mv rm find printf
  HOOK_ENV=("PATH=$RESTRICTED_PATH")
  hook_run_read
  assert_eq "DC-T07" "" "$R_OUT"
  assert_exit "DC-T07" 0
  HOOK_ENV=()
}

case_quiet
case_out_of_scope
case_approvals
case_predecessors
case_type_changed
case_boundary
case_no_git
finish
