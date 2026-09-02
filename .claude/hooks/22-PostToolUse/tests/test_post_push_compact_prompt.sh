#!/usr/bin/env bash
# test_post_push_compact_prompt.sh — post-push-compact-prompt.sh のテスト（仕様のテスト ID: PP-T01〜PP-T08）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*post_push_compact_prompt*'
# テストは set -e を使わない（終了コードは hook_run が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SRC="$LOGGER_ROOT/.claude/hooks"
SKILL_SCRIPTS="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts"

REMOTE="$(mktemp -d)/remote.git"
git init -q --bare -b main "$REMOTE"
make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/22-PostToolUse" "$TMP_REPO/.claude/hooks/lib" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts"
cp "$SRC/22-PostToolUse/post-push-compact-prompt.sh" "$TMP_REPO/.claude/hooks/22-PostToolUse/"
cp "$SRC/lib/hook-common.sh" "$SRC/lib/cmdpos.sh" "$SRC/lib/push-detect.sh" \
   "$TMP_REPO/.claude/hooks/lib/"
cp "$SKILL_SCRIPTS/logger.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"
TMP_HOOK="$TMP_REPO/.claude/hooks/22-PostToolUse/post-push-compact-prompt.sh"
STATE="$TMP_REPO/logs/push-state.json"
PUSH_SH="bash .claude/skills/20-common-step-commit-push/scripts/push.sh"

cd "$TMP_REPO" || exit 2
# 万一 fake URL のまま push しても認証プロンプトで止まらないようにする（即座に失敗させる）
export GIT_TERMINAL_PROMPT=0
git config --local credential.helper ""
git remote add origin "$REMOTE"
printf 'a\n' > a.txt
git add -A >/dev/null 2>&1
git commit -q -m "init"
git push -q -u origin main 2>/dev/null

mk_payload() { # $1=command
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc --arg cmd "$1" --arg cwd "$TMP_REPO" '
    {hook_event_name: "PostToolUse", tool_name: "Bash", session_id: "testsession", cwd: $cwd,
     tool_input: {command: $cmd}}' | tr -d '\r'
}

hook_run() { # $1=command
  R_ERR=""
  R_OUT="$(mk_payload "$1" | bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  return 0
}

do_commit() { # $1=ファイル名
  printf '%s\n' "$RANDOM" >> "${1:-a.txt}"
  git add -A >/dev/null 2>&1
  git commit -q -m "step"
}

# origin の URL はリンクの組み立てを見るための「見せかけ」で、push 先ではない。
# 実際の push は必ずローカルの bare リポジトリへ行う（fake URL のまま push すると
# github.com などへ本当に接続しに行き、認証プロンプトで止まる）
CUR_URL="$REMOTE"
set_origin() { CUR_URL="$1"; git remote set-url origin "$1"; }
do_push() {
  git remote set-url origin "$REMOTE"
  do_commit "${1:-a.txt}"
  git push -q origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null
  git remote set-url origin "$CUR_URL"
}

state_of() { tl_jq -r "$1" "$STATE" 2>/dev/null; }
reset_state() { rm -rf "$TMP_REPO/logs"; }

# ---- PP-T01: push.sh の成功で WF901 と push-state.json の更新 ----
case_success() {
  reset_state
  set_origin "https://github.com/example/repo.git"
  do_push
  hook_run "$PUSH_SH"
  assert_contains "PP-T01" "WF901"
  assert_contains "PP-T01" "push を検知した（ブランチ main / このブランチで 1 回目）"
  assert_exit "PP-T01" 0
  assert_eq "PP-T01" "$(git rev-parse HEAD | tr -d '\r')" "$(state_of '.main.sha')"
  assert_eq "PP-T01" "1" "$(state_of '.main.count')"
}

# ---- PP-T02: push でなければ何もしない ----
case_not_push() {
  reset_state
  do_push
  hook_run 'git status'
  assert_eq "PP-T02" "" "$R_OUT"
  assert_exit "PP-T02" 0
  hook_run 'grep "git push" x.sh'
  assert_eq "PP-T02" "" "$R_OUT"
  hook_run 'echo push'
  assert_eq "PP-T02" "" "$R_OUT"
  if [[ ! -f "$STATE" ]]; then pass "PP-T02"; else fail "PP-T02" "push 以外で状態が作られた"; fi
}

# ---- PP-T03: 直接 git push でも働く ----
case_direct() {
  reset_state
  set_origin "https://github.com/example/repo.git"
  do_push
  hook_run 'git push origin main'
  assert_contains "PP-T03" "WF901"
  assert_exit "PP-T03" 0
}

# ---- PP-T04: GitHub / GitLab の https / ssh でリンク形式が変わる ----
case_links() {
  reset_state
  mkdir -p "$TMP_REPO/logs"
  printf '{"host":"github","issue":9,"mr":12,"url":"https://example.invalid"}\n' > "$TMP_REPO/logs/mr.json"

  set_origin "https://github.com/example/repo.git"
  do_push
  hook_run 'git push'
  assert_contains "PP-T04" "- MR: https://github.com/example/repo/pull/12"
  assert_contains "PP-T04" "- default との差分: https://github.com/example/repo/compare/main...main"

  set_origin "git@github.com:example/repo.git"
  do_push
  hook_run 'git push'
  assert_contains "PP-T04" "https://github.com/example/repo/pull/12"

  set_origin "https://gitlab.com/example/repo.git"
  do_push
  hook_run 'git push'
  assert_contains "PP-T04" "- MR: https://gitlab.com/example/repo/-/merge_requests/12"
  # コメント一覧は「前回 push からの差分」があるとき（= 2 回目以降）だけ付く
  do_push
  hook_run 'git push'
  assert_contains "PP-T04" "- MR のコメント一覧: https://gitlab.com/example/repo/-/merge_requests/12#notes"

  set_origin "git@gitlab.example.com:group/repo.git"
  do_push
  hook_run 'git push'
  assert_contains "PP-T04" "https://gitlab.example.com/group/repo/-/merge_requests/12"
  rm -f "$TMP_REPO/logs/mr.json"
}

# ---- PP-T05: 初回は WF902、MR 未記録は WF903、変更 20 件は 15 件 + 他 5 件 ----
case_boundary() {
  reset_state
  set_origin "https://github.com/example/repo.git"
  do_push
  hook_run 'git push'
  assert_contains "PP-T05" "WF902"
  assert_contains "PP-T05" "WF903: MR が未記録"

  # 2 回目は WF902 が出ない（前回 push の記録がある）
  do_push
  hook_run 'git push'
  assert_not_contains "PP-T05" "WF902"

  # 変更 20 件
  local i
  for (( i = 1; i <= 20; i++ )); do printf 'x\n' > "$TMP_REPO/f$i.txt"; done
  do_push
  hook_run 'git push'
  assert_contains "PP-T05" "- 変更ファイル（"
  assert_contains "PP-T05" "件は省略）"
  # 列挙は 15 件で打ち切る（超過分は件数だけ）
  assert_eq "PP-T05" "15" "$(printf '%s' "$R_OUT" | grep -o '\.txt: https://' | wc -l | tr -d ' ')"
  git rm -q -f f*.txt >/dev/null 2>&1
  git commit -q -m "cleanup"
  git push -q origin main 2>/dev/null
}

# ---- PP-T06: ブランチごとに push-state.json が独立 ----
case_per_branch() {
  reset_state
  set_origin "https://github.com/example/repo.git"
  do_push
  hook_run 'git push'
  git checkout -q -b feature-x
  do_commit
  git push -q -u origin feature-x 2>/dev/null
  hook_run 'git push'
  assert_contains "PP-T06" "ブランチ feature-x / このブランチで 1 回目"
  assert_eq "PP-T06" "1" "$(state_of '.["feature-x"].count')"
  assert_eq "PP-T06" "1" "$(state_of '.main.count')"
  git checkout -q main
}

# ---- PP-T07: origin が取得できない / GitHub でも GitLab でもない ----
case_no_origin() {
  reset_state
  set_origin "https://example.invalid/example/repo.git"
  do_push
  hook_run 'git push'
  assert_contains "PP-T07" "WF903: origin が GitHub / GitLab ではない"
  assert_not_contains "PP-T07" "変更ファイル"
  assert_exit "PP-T07" 0

  git remote remove origin
  do_commit
  hook_run 'git push'
  assert_contains "PP-T07" "WF903"
  assert_exit "PP-T07" 0
  git remote add origin "$REMOTE"
}

# ---- PP-T08: 上流未設定でも検知して状態を作る ----
case_no_upstream() {
  reset_state
  set_origin "https://github.com/example/repo.git"
  git checkout -q -b feature-y
  do_commit
  # origin/feature-y も @{upstream} も無い → 縮退（PostToolUse に届いたこと自体で検知）
  hook_run 'git push'
  assert_contains "PP-T08" "WF901"
  assert_eq "PP-T08" "$(git rev-parse HEAD | tr -d '\r')" "$(state_of '.["feature-y"].sha')"
  git checkout -q main
  git branch -q -D feature-y
}

# ---- 停止中 ----
case_enforce() {
  reset_state
  set_origin "https://github.com/example/repo.git"
  do_push
  R_ERR=""
  R_OUT="$(mk_payload 'git push' | WORKFLOW_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)"
  R_EXIT=$?
  assert_eq "PP-T01" "" "$R_OUT"
  assert_exit "PP-T01" 0
}

case_success
case_not_push
case_direct
case_links
case_boundary
case_per_branch
case_no_origin
case_no_upstream
case_enforce
cd "$LOGGER_ROOT" || true
finish
