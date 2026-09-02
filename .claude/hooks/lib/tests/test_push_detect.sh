#!/usr/bin/env bash
# test_push_detect.sh — push-detect.sh のテスト（仕様のテスト ID: HK-T13）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*push_detect*'
# テストは set -e を使わない（終了コードは run_cmd が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

LIB="$LOGGER_ROOT/.claude/hooks/lib/push-detect.sh"
export LIB
PUSH_SH="bash .claude/skills/20-common-step-commit-push/scripts/push.sh"

make_tmp_dir
REMOTE="$TMP_DIR/remote.git"
git init -q --bare -b main "$REMOTE"
make_tmp_repo
cd "$TMP_REPO" || exit 2
export HOOK_ROOT="$TMP_REPO"
git remote add origin "$REMOTE"
printf 'a\n' > a.txt; git add a.txt; git commit -q -m "init"
git push -q -u origin main 2>/dev/null

# ドライバ（別プロセスで実行し、fork の有無を stderr で観察できるようにする）: drv.sh <command> <tool_response> [shell]
cat > "$TMP_REPO/drv.sh" <<'DRV'
#!/usr/bin/env bash
. "$LIB"
push_detect "$1" "${2:-}" "${3:-bash}" "$HOOK_ROOT"; rc=$?
printf 'rc=%s reason=%s branch=%s head=%s prev=%s count=%s\n' "$rc" "$PD_REASON" "$PD_BRANCH" "$PD_HEAD" "$PD_PREV_SHA" "$PD_COUNT"
DRV

head_sha() { git rev-parse HEAD | tr -d '\r'; }

case_hk_t13_success() {
  local h; h="$(head_sha)"
  run_cmd bash "$TMP_REPO/drv.sh" "$PUSH_SH" '{"exit_code":0,"stdout":"OK: push した"}'
  assert_contains "HK-T13" "rc=0 reason=pushed branch=main head=$h prev= count=0"
  run_cmd bash "$TMP_REPO/drv.sh" 'git push origin main' '{"stdout":"","stderr":"","interrupted":false}'
  assert_contains "HK-T13" "rc=0 reason=pushed"
  run_cmd bash "$TMP_REPO/drv.sh" 'cd sub && git push' ''
  assert_contains "HK-T13" "rc=0 reason=pushed"
  run_cmd bash "$TMP_REPO/drv.sh" '& git push' '{"exit_code":0}' powershell
  assert_contains "HK-T13" "rc=0 reason=pushed"
}

case_hk_t13_negative() {
  run_cmd bash "$TMP_REPO/drv.sh" "$PUSH_SH" '{"exit_code":1}'
  assert_contains "HK-T13" "rc=1 reason=exit-1"
  run_cmd bash "$TMP_REPO/drv.sh" 'git push' '{"interrupted":true}'
  assert_contains "HK-T13" "rc=1 reason=exit-1"
  run_cmd bash "$TMP_REPO/drv.sh" 'git status' ''
  assert_contains "HK-T13" "rc=1 reason=no-push-word"
  run_cmd bash "$TMP_REPO/drv.sh" 'grep "git push" x.sh' ''
  assert_contains "HK-T13" "rc=1 reason=not-a-push"
  run_cmd bash "$TMP_REPO/drv.sh" 'echo push' ''
  assert_contains "HK-T13" "rc=1 reason=not-a-push"
  run_cmd bash "$TMP_REPO/drv.sh" 'bash push.sh' ''
  assert_contains "HK-T13" "rc=1 reason=not-a-push"
  run_cmd bash "$TMP_REPO/drv.sh" $'cat <<EOF\ngit push\nEOF' ''
  assert_contains "HK-T13" "rc=1 reason=not-a-push"
  # 前置フィルタと cmdpos は fork ゼロ: PATH を空にしても外部コマンド不在のエラーが出ない
  local bash_bin; bash_bin="$(command -v bash)"
  run_cmd env PATH="" "$bash_bin" "$TMP_REPO/drv.sh" 'git status' ''
  assert_contains "HK-T13" "rc=1 reason=no-push-word"
  assert_eq "HK-T13" "" "$R_ERR"
  run_cmd env PATH="" "$bash_bin" "$TMP_REPO/drv.sh" 'grep "git push" x' ''
  assert_contains "HK-T13" "rc=1 reason=not-a-push"
  assert_eq "HK-T13" "" "$R_ERR"
  # 呼び出しを数える PATH: 2>/dev/null で隠した fork も数える。push でなければ外部コマンドは 0 回
  make_counting_path git jq sed grep awk cat tr cut head tail wc sort uniq date
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" "$TMP_REPO/drv.sh" 'git status' ''
  assert_contains "HK-T13" "rc=1 reason=no-push-word"
  assert_eq "HK-T13" "0" "$(counted_calls)"
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" "$TMP_REPO/drv.sh" 'grep "git push" x' ''
  assert_contains "HK-T13" "rc=1 reason=not-a-push"
  assert_eq "HK-T13" "0" "$(counted_calls)"
  # 正のコントロール: 実際の push では git が呼ばれる（計数が動いている）
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" "$TMP_REPO/drv.sh" 'git push' '{"exit_code":0}'
  if [ "$(counted_calls git)" -gt 0 ]; then pass "HK-T13"; else fail "HK-T13" "計数 PATH で git が数えられない（$(counted_calls) 回）"; fi
}

case_hk_t13_state() {
  local h; h="$(head_sha)"
  mkdir -p logs
  printf '{"main":{"sha":"%s","at":"2026-09-01T00:00:00+09:00","count":1}}\n' "$h" > logs/push-state.json
  run_cmd bash "$TMP_REPO/drv.sh" "$PUSH_SH" '{"exit_code":0}'
  assert_contains "HK-T13" "rc=1 reason=not-advanced"
  # 進めたが push していない → HEAD != upstream
  printf 'b\n' > b.txt; git add b.txt; git commit -q -m "second"
  run_cmd bash "$TMP_REPO/drv.sh" "$PUSH_SH" '{"exit_code":0}'
  assert_contains "HK-T13" "rc=1 reason=head-not-on-upstream"
  git push -q origin main 2>/dev/null
  local h2; h2="$(head_sha)"
  run_cmd bash "$TMP_REPO/drv.sh" "$PUSH_SH" '{"exit_code":0}'
  assert_contains "HK-T13" "rc=0 reason=pushed branch=main head=$h2 prev=$h count=1"
  # 記録が壊れていても止まらない（初回扱い）
  printf 'broken' > logs/push-state.json
  run_cmd bash "$TMP_REPO/drv.sh" "$PUSH_SH" '{"exit_code":0}'
  assert_contains "HK-T13" "rc=0 reason=pushed"
  rm -f logs/push-state.json
}

case_hk_t13_upstream_fallback() {
  # 上流未設定だが origin/<b> がある（git push origin feat。-u なし）
  git checkout -q -b feat
  printf 'c\n' > c.txt; git add c.txt; git commit -q -m "feat"
  git push -q origin feat 2>/dev/null
  run_cmd bash "$TMP_REPO/drv.sh" 'git push origin feat' '{"exit_code":0}'
  assert_contains "HK-T13" "rc=0 reason=pushed branch=feat"
  printf 'c2\n' >> c.txt; git add c.txt; git commit -q -m "feat 2"
  run_cmd bash "$TMP_REPO/drv.sh" 'git push origin feat' '{"exit_code":0}'
  assert_contains "HK-T13" "rc=1 reason=head-not-on-origin-branch"
  git push -q origin feat 2>/dev/null
  run_cmd bash "$TMP_REPO/drv.sh" 'git push origin feat' '{"exit_code":0}'
  assert_contains "HK-T13" "rc=0 reason=pushed branch=feat"
  # 上流も origin/<b> も無い → 終了コード 0 で反映されたとみなす（縮退）
  git checkout -q -b feat2
  printf 'd\n' > d.txt; git add d.txt; git commit -q -m "feat2"
  run_cmd bash "$TMP_REPO/drv.sh" "$PUSH_SH" '{"exit_code":0}'
  assert_contains "HK-T13" "rc=0 reason=degraded-exit-code branch=feat2"
  run_cmd bash "$TMP_REPO/drv.sh" "$PUSH_SH" '{"exit_code":128}'
  assert_contains "HK-T13" "rc=1 reason=exit-128"
  git checkout -q main
}

case_hk_t13_degraded() {
  local long
  printf -v long 'echo %*s; git push' 4090 ''
  run_cmd bash "$TMP_REPO/drv.sh" "$long" '{"exit_code":0}'
  assert_contains "HK-T13" "rc=0 reason=pushed"
  printf -v long 'echo %*s; echo pushed' 4090 ''
  run_cmd bash "$TMP_REPO/drv.sh" "$long" '{"exit_code":0}'
  assert_contains "HK-T13" "rc=1 reason=degraded-no-push"
}

case_hk_t13_success
case_hk_t13_negative
case_hk_t13_state
case_hk_t13_upstream_fallback
case_hk_t13_degraded
finish
