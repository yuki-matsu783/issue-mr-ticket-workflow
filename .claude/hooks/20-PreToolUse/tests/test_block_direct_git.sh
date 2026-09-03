#!/usr/bin/env bash
# test_block_direct_git.sh — block-direct-git.sh のテスト（仕様のテスト ID: BG-T01〜BG-T11）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*block_direct_git*'
# テストは set -e を使わない（終了コードは judge が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

HOOK="$LOGGER_ROOT/.claude/hooks/20-PreToolUse/block-direct-git.sh"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/20-PreToolUse" "$TMP_REPO/.claude/hooks/lib" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts"
cp "$HOOK" "$TMP_REPO/.claude/hooks/20-PreToolUse/"
cp "$LOGGER_ROOT/.claude/hooks/lib/hook-common.sh" "$LOGGER_ROOT/.claude/hooks/lib/cmdpos.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts/logger.sh" \
   "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/" 2>/dev/null || true
TMP_HOOK="$TMP_REPO/.claude/hooks/20-PreToolUse/block-direct-git.sh"

# 判定を 1 語にする: WF401 / WF402 / WF403 / WF409 / allow
judge() { # $1=コマンド文字列 [$2=ツール名（既定 Bash）]
  local out rc
  out="$(hook_payload PreToolUse "${2:-Bash}" command="$1" | bash "$TMP_HOOK" 2>/dev/null)"; rc=$?
  case "$out" in
    *WF401*) printf 'WF401\n' ;;
    *WF402*) printf 'WF402\n' ;;
    *WF403*) printf 'WF403\n' ;;
    *WF409*) printf 'WF409\n' ;;
    "")      if (( rc == 0 )); then printf 'allow\n'; else printf 'exit%d\n' "$rc"; fi ;;
    *)       printf 'other:%s\n' "$out" ;;
  esac
}

# ---- BG-T01: 複合・ラッパー・パス付き・グローバルオプション ----
case_deny() {
  assert_eq "BG-T01" "WF401" "$(judge 'git commit -m x')"
  assert_eq "BG-T01" "WF401" "$(judge 'cd a && git commit')"
  assert_eq "BG-T01" "WF402" "$(judge 'x; git push')"
  assert_eq "BG-T01" "WF402" "$(judge 'ls | git push')"
  assert_eq "BG-T01" "WF402" "$(judge 'sudo git push')"
  assert_eq "BG-T01" "WF401" "$(judge 'if true; then git commit; fi')"
  assert_eq "BG-T01" "WF401" "$(judge '/usr/bin/git commit')"
  assert_eq "BG-T01" "WF402" "$(judge './git push')"
  assert_eq "BG-T01" "WF401" "$(judge 'git.exe commit')"
  assert_eq "BG-T01" "WF401" "$(judge 'git -C . commit')"
  assert_eq "BG-T01" "WF401" "$(judge 'git -c user.name=x commit')"
  assert_eq "BG-T01" "WF402" "$(judge 'git push --force')"
  assert_eq "BG-T01" "WF401" "$(judge 'git commit --amend --no-verify')"
  # クォートで語が割れてサブコマンドが特定できない形は WF403
  assert_eq "BG-T01" "WF403" "$(judge "git 'commit'")"
  assert_eq "BG-T01" "WF403" "$(judge 'git "push"')"
}

# ---- BG-T02: 地の文・クォート・コメント・ヒアドキュメントでは拒否しない ----
case_pass_text() {
  assert_eq "BG-T02" "allow" "$(judge 'grep "git commit" x.sh')"
  assert_eq "BG-T02" "allow" "$(judge "echo 'git push しない'")"
  assert_eq "BG-T02" "allow" "$(judge 'ls # git commit はしない')"
  assert_eq "BG-T02" "allow" "$(judge $'cat <<EOF\ngit commit -m x\nEOF')"
  assert_eq "BG-T02" "allow" "$(judge 'echo "変更を push する前に確認する"')"
  assert_eq "BG-T02" "allow" "$(judge 'ls -la')"
}

# ---- BG-T03: コミットを生成しないサブコマンドは通る ----
case_pass_git() {
  local s
  for s in status log diff add fetch merge stash "show HEAD" "rev-parse HEAD" branch; do
    assert_eq "BG-T03" "allow" "$(judge "git $s")"
  done
}

# ---- BG-T04: $( ) の中も実行位置 ----
case_subshell() {
  assert_eq "BG-T04" "WF401" "$(judge 'echo "$(git commit -m x)"')"
  assert_eq "BG-T04" "WF402" "$(judge 'x=$(git push)')"
}

# ---- BG-T05: opaque は拒否側 ----
case_opaque() {
  assert_eq "BG-T05" "WF403" "$(judge 'eval "git commit"')"
  assert_eq "BG-T05" "WF403" "$(judge "bash -c 'git push'")"
  assert_eq "BG-T05" "WF403" "$(judge 'xargs git push')"
  assert_eq "BG-T05" "WF403" "$(judge 'find . -exec git commit ;')"
  # opaque でも対象語が無ければ通す
  assert_eq "BG-T05" "allow" "$(judge 'eval "ls -la"')"
}

# ---- BG-T06: 提供コマンドは拒否しない ----
case_provided() {
  assert_eq "BG-T06" "allow" "$(judge 'bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "docs: x" a.md')"
  assert_eq "BG-T06" "allow" "$(judge 'bash .claude/skills/20-common-step-commit-push/scripts/push.sh')"
}

# ---- BG-T07: 4096 文字超は縮退して語の共起で判定 ----
case_degraded() {
  local pad long
  pad="$(printf 'a%.0s' $(seq 1 4100))"
  long="echo $pad git commit"
  assert_eq "BG-T07" "WF403" "$(judge "$long")"
  long="echo $pad git push"
  assert_eq "BG-T07" "WF403" "$(judge "$long")"
  # 対象語が無ければ通る
  long="echo $pad"
  assert_eq "BG-T07" "allow" "$(judge "$long")"
  # git が無ければ通る
  long="echo $pad commit"
  assert_eq "BG-T07" "allow" "$(judge "$long")"
}

# ---- BG-T08 / BG-T09: PowerShell ----
case_powershell() {
  assert_eq "BG-T08" "WF401" "$(judge '& git commit' PowerShell)"
  assert_eq "BG-T08" "WF402" "$(judge 'git push; ls' PowerShell)"
  assert_eq "BG-T08" "WF401" "$(judge '.\git.exe commit' PowerShell)"
  assert_eq "BG-T09" "allow" "$(judge 'git status' PowerShell)"
  assert_eq "BG-T09" "allow" "$(judge 'git diff' PowerShell)"
  # 実行体をクォートで割っても、サブコマンドが読めれば拒否する（ヒアストリングを通す判断の負のコントロール）
  assert_eq "BG-T08" "WF401" "$(judge '& "git" commit' PowerShell)"
  assert_eq "BG-T08" "WF402" "$(judge '&"git" push' PowerShell)"
  assert_eq "BG-T08" "WF403" "$(judge 'git "commit"' PowerShell)"
  # PowerShell の eval 相当（Invoke-Expression / iex）は opaque として拒否側へ
  assert_eq "BG-T08" "WF403" "$(judge 'Invoke-Expression "git commit"' PowerShell)"
  assert_eq "BG-T08" "WF403" "$(judge 'iex "git push"' PowerShell)"
  assert_eq "BG-T09" "allow" "$(judge 'Invoke-Expression "ls"' PowerShell)"
  assert_eq "BG-T09" "allow" "$(judge $'@\'\ngit commit -m x\n\'@' PowerShell)"
}

# ---- BG-T10: コミットを生成するサブコマンドの全要素 ----
case_commit_makers() {
  assert_eq "BG-T10" "WF401" "$(judge 'git revert HEAD')"
  assert_eq "BG-T10" "WF401" "$(judge 'git cherry-pick abc')"
  assert_eq "BG-T10" "WF401" "$(judge 'git rebase --continue')"
  assert_eq "BG-T10" "WF401" "$(judge 'git am x.patch')"
  assert_eq "BG-T10" "WF401" "$(judge 'git commit-tree abc123')"
  # 明示的に対象外の 2 つ
  assert_eq "BG-T10" "allow" "$(judge 'git merge origin/main')"
  assert_eq "BG-T10" "allow" "$(judge 'git stash')"
}

# ---- BG-T11: 入力不正・停止中・記録 ----
case_input_and_record() {
  local out rc
  out="$(printf 'これは JSON ではない' | bash "$TMP_HOOK" 2>/dev/null)"; rc=$?
  case "$out" in *WF409*) pass "BG-T11" ;; *) fail "BG-T11" "入力不正で WF409 が出ない: $out" ;; esac
  assert_eq "BG-T11" "0" "$rc"
  out="$(printf '' | bash "$TMP_HOOK" 2>/dev/null)"
  case "$out" in *WF409*) pass "BG-T11" ;; *) fail "BG-T11" "空入力で WF409 が出ない: $out" ;; esac

  # 停止中は判定しない
  out="$(hook_payload PreToolUse Bash command='git commit -m x' | WORKFLOW_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "BG-T11" "" "$out"
  out="$(hook_payload PreToolUse Bash command='git commit -m x' | WORKFLOW_BLOCK_DIRECT_GIT_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "BG-T11" "" "$out"

  # 拒否だけを記録し、許可は記録しない
  local dec="$TMP_REPO/logs/hooks/decisions.jsonl" n1 n2
  rm -f "$dec"
  judge 'git status' > /dev/null
  n1=$([[ -f "$dec" ]] && wc -l < "$dec" || echo 0)
  judge 'git commit -m x' > /dev/null
  n2=$([[ -f "$dec" ]] && wc -l < "$dec" || echo 0)
  assert_eq "BG-T11" "0" "${n1// /}"
  assert_eq "BG-T11" "1" "${n2// /}"
  local body; body="$(cat "$dec")"
  [[ "$body" == *WF401* ]] && pass "BG-T11" || fail "BG-T11" "decisions.jsonl に WF401 が無い"
}

# ---- 外部プロセス: jq 1 回・git / date / sed / find を呼ばない ----
case_hotpath() {
  make_counting_path jq git date sed find awk grep cat tr cut head tail wc sort uniq
  local bash_bin; bash_bin="$(command -v bash)"
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" -c \
    "printf '%s' '$(hook_payload PreToolUse Bash command='git status')' | '$bash_bin' '$TMP_HOOK'"
  assert_eq "BG-T11" "1" "$(counted_calls jq)"
  assert_eq "BG-T11" "0" "$(counted_calls git)"
  assert_eq "BG-T11" "0" "$(counted_calls date)"
  assert_eq "BG-T11" "0" "$(counted_calls sed)"
  assert_eq "BG-T11" "0" "$(counted_calls find)"
}

case_deny
case_pass_text
case_pass_git
case_subshell
case_opaque
case_provided
case_degraded
case_powershell
case_commit_makers
case_input_and_record
case_hotpath
finish
