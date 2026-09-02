#!/usr/bin/env bash
# test_cmdpos.sh — cmdpos.sh のテスト（仕様のテスト ID: HK-T05 / HK-T12）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*cmdpos*'
# テストは set -e を使わない（終了コードは run_cmd が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

# shellcheck disable=SC1091
. "$LOGGER_ROOT/.claude/hooks/lib/cmdpos.sh"

# 解析結果を 1 セグメント 1 行に整形して出力する: seg<i>: exe=<exe> sub=<sub> args=[..] redir=[..] write=[..] opaque=<n> provided=<p> gitlike=<g>
dump() { # $1=コマンド [$2=shell]
  local i us=$'\x1e'
  cmdpos_parse "$1" "${2:-bash}"
  printf 'count=%s degraded=%s\n' "$CP_COUNT" "$CP_DEGRADED"
  for ((i = 0; i < CP_COUNT; i++)); do
    printf 'seg%s: exe=%s sub=%s args=[%s] redir=[%s] write=[%s] opaque=%s provided=%s gitlike=%s\n' \
      "$i" "${CP_EXE[i]}" "${CP_SUBCMD[i]}" "${CP_ARGS[i]//$us/ }" "${CP_REDIRECTS[i]//$us/ }" "${CP_WRITE_TARGETS[i]//$us/ }" \
      "${CP_OPAQUE[i]}" "${CP_PROVIDED[i]}" "${CP_GITLIKE[i]}"
  done
}
has_git() { # $1=sub → yes/no
  if cmdpos_has_git_subcommand "$1"; then echo yes; else echo no; fi
}

# ---- HK-T05: 代表例（複合・ラッパー・パス付き・ヒアドキュメント・クォート・コメント・$( )・opaque・PowerShell・縮退）----
case_hk_t05_compound() {
  local c
  for c in 'git commit -m x' 'cd a && git commit' 'x; git commit' 'a | git commit' 'sudo git commit' 'if true; then git commit; fi' \
           '/usr/bin/git commit' './git commit' 'git.exe commit' 'git -C . commit' 'git -c user.name=x commit -m y' 'git --git-dir=.git commit' \
           'git --git-dir .git commit' 'VAR=1 git commit' 'time git commit' 'env X=1 git commit' 'nohup git commit &' 'timeout 10 git commit' \
           'sudo -u alice git commit' '{ git commit; }' '(git commit)' 'echo "$(git commit -m x)"' 'echo `git commit`' 'cd src && \
git commit'; do
    run_cmd dump "$c"
    assert_contains "HK-T05" "exe=git sub=commit"
  done
  run_cmd dump 'git push --force'
  assert_contains "HK-T05" "exe=git sub=push args=[push --force]"
  run_cmd dump 'cd a && git commit'
  assert_contains "HK-T05" "count=2"
  assert_contains "HK-T05" "seg0: exe=cd sub=a"
}

case_hk_t05_negative() {
  local c
  for c in $'cat <<EOF\ngit commit\nEOF' $'cat <<\'EOF\'\n  git commit\nEOF' $'cat <<-TAG\n\tgit commit\n\tTAG' "echo 'git commit'" 'echo "git commit"' \
           '# git commit' 'ls # git commit' 'grep "git commit" file.txt' 'echo コミットは git commit で' 'echo $((1<<2)); ls' 'git status' 'git log --oneline'; do
    run_cmd dump "$c"
    assert_not_contains "HK-T05" "sub=commit"
  done
  run_cmd dump 'echo $((1<<2)); git commit'
  assert_contains "HK-T05" "exe=git sub=commit"
  run_cmd dump 'foo#bar git status'
  assert_contains "HK-T05" "exe=foo#bar"
}

case_hk_t05_opaque() {
  run_cmd dump 'eval "git commit"'
  assert_contains "HK-T05" "exe=eval sub=_ args=[_] redir=[] write=[] opaque=1"
  run_cmd dump "bash -c 'git push'"
  assert_contains "HK-T05" "exe=bash sub=_ args=[-c _]"
  assert_contains "HK-T05" "opaque=1"
  # クォートで割った語（git 'commit'）は判定できない（既知の制約。サブコマンドは _ になる）
  run_cmd dump "git 'commit'"
  assert_contains "HK-T05" "exe=git sub=_"
  run_cmd dump 'xargs git push'
  assert_contains "HK-T05" "exe=xargs"
  assert_contains "HK-T05" "opaque=1"
  run_cmd dump 'find . -exec git commit \;'
  assert_contains "HK-T05" "exe=find"
  assert_contains "HK-T05" "opaque=1"
  run_cmd dump 'find . -name "*.sh"'
  assert_contains "HK-T05" "opaque=0"
  run_cmd dump 'bash -n .claude/skills/x/scripts/y.sh'
  assert_contains "HK-T05" "opaque=0"
  run_cmd dump 'powershell -Command "git push"'
  assert_contains "HK-T05" "exe=powershell"
  assert_contains "HK-T05" "opaque=1"
  run_cmd dump 'node -e "x"'
  assert_contains "HK-T05" "opaque=1"
  run_cmd dump 'python script.py'
  assert_contains "HK-T05" "opaque=0"
}

case_hk_t05_redirect_write() {
  run_cmd dump 'echo x > out.txt'
  assert_contains "HK-T05" "seg0: exe=echo sub=x args=[x] redir=[out.txt]"
  run_cmd dump 'cmd 2>&1'
  assert_contains "HK-T05" "count=1"
  assert_contains "HK-T05" "exe=cmd sub= args=[] redir=[]"
  run_cmd dump 'cmd >> app.log 2>&1'
  assert_contains "HK-T05" "redir=[app.log]"
  assert_contains "HK-T05" "count=1"
  run_cmd dump 'cmd &> all.log'
  assert_contains "HK-T05" "redir=[all.log]"
  run_cmd dump 'cmd > /dev/null'
  assert_contains "HK-T05" "redir=[]"
  run_cmd dump '> out.txt git commit'
  assert_contains "HK-T05" "exe=git sub=commit"
  assert_contains "HK-T05" "redir=[out.txt]"
  run_cmd dump 'cat < in.txt'
  assert_contains "HK-T05" "exe=cat sub= args=[] redir=[]"
  run_cmd dump 'cat <<< "data" | head'
  assert_contains "HK-T05" "count=2"
  assert_contains "HK-T05" "seg1: exe=head"
  run_cmd dump 'cp a b'
  assert_contains "HK-T05" "write=[b]"
  run_cmd dump 'mv -f a b c'
  assert_contains "HK-T05" "write=[c]"
  run_cmd dump 'tee -a out.log'
  assert_contains "HK-T05" "write=[out.log]"
  run_cmd dump 'touch x y'
  assert_contains "HK-T05" "write=[x y]"
  run_cmd dump 'mkdir -p d/e'
  assert_contains "HK-T05" "write=[d/e]"
  run_cmd dump 'rm -rf d'
  assert_contains "HK-T05" "write=[d]"
  run_cmd dump "sed -i 's/a/b/' f.txt"
  assert_contains "HK-T05" "write=[f.txt]"
  run_cmd dump "sed 's/a/b/' f.txt"
  assert_contains "HK-T05" "exe=sed"
  assert_contains "HK-T05" "write=[]"
  run_cmd dump "sed -i -e 's/a/b/' f g"
  assert_contains "HK-T05" "write=[f g]"
  run_cmd dump 'truncate -s 0 f'
  assert_contains "HK-T05" "write=[f]"
  run_cmd dump 'ln -s a b'
  assert_contains "HK-T05" "write=[b]"
}

case_hk_t05_powershell() {
  run_cmd dump '& git commit' powershell
  assert_contains "HK-T05" "exe=git sub=commit"
  run_cmd dump 'git push; ls' powershell
  assert_contains "HK-T05" "count=2"
  assert_contains "HK-T05" "exe=git sub=push"
  run_cmd dump '.\git.exe commit' powershell
  assert_contains "HK-T05" "exe=git sub=commit"
  run_cmd dump $'@\'\ngit commit\n\'@ | Out-File x' powershell
  assert_not_contains "HK-T05" "sub=commit"
  run_cmd dump $'$s = @"\ngit push\n"@' powershell
  assert_not_contains "HK-T05" "sub=push"
  run_cmd dump 'git status' powershell
  assert_contains "HK-T05" "exe=git sub=status"
  run_cmd dump 'git diff `
  --stat' powershell
  assert_contains "HK-T05" "exe=git sub=diff args=[diff --stat]"
  run_cmd dump '& "C:\Program Files\Git\git.exe" push' powershell
  assert_contains "HK-T05" "exe=_"
  assert_contains "HK-T05" "gitlike=1"
  run_cmd dump 'Get-ChildItem 2>&1' powershell
  assert_contains "HK-T05" "count=1"
  assert_contains "HK-T05" "exe=get-childitem"
}

case_hk_t05_degraded() {
  local long
  printf -v long 'echo %*s; git commit' 4090 ''
  run_cmd dump "$long"
  assert_contains "HK-T05" "count=0 degraded=1"
  cmdpos_parse "$long"
  assert_eq "HK-T05" "yes" "$(has_git commit)"
  assert_eq "HK-T05" "no" "$(has_git push)"
  cmdpos_parse 'git commit'
  assert_eq "HK-T05" "yes" "$(has_git commit)"
  cmdpos_parse 'echo "git commit"'
  assert_eq "HK-T05" "no" "$(has_git commit)"
  cmdpos_parse ''
  assert_eq "HK-T05" "0" "$CP_COUNT"
  # 変数代入だけ・空セグメント
  run_cmd dump 'FOO=bar; ; BAZ=1 ls'
  assert_contains "HK-T05" "exe=ls"
  run_cmd dump 'command -v jq'
  assert_contains "HK-T05" "exe=jq sub= args=[]"
}

# ---- HK-T12: 提供コマンドの識別はコマンド文字列上のルート相対表記だけ ----
# ---- HK-T05: 語彙表の全要素と負のケースの正の期待値 ----
case_hk_t05_vocab() {
  local w pair
  # ラッパー・予約語（§7-3）: どれを前置しても exe=git sub=commit
  for w in $_CP_PREFIX_WORDS; do
    case "$w" in
      timeout) run_cmd dump 'timeout 10 git commit' ;;
      sudo) run_cmd dump 'sudo -u alice git commit' ;;
      *) run_cmd dump "$w git commit" ;;
    esac
    assert_contains "HK-T05" "exe=git sub=commit"
  done
  # コード文字列を取る実行系（§7-5）: コード指定オプション付きは opaque、ファイル指定は opaque でない。無条件の語は常に opaque
  for w in $_CP_OPAQUE_WITH_OPT; do
    run_cmd dump "$w -c 'git push'"
    assert_contains "HK-T05" "exe=$w"
    assert_contains "HK-T05" "opaque=1"
    run_cmd dump "$w script.txt"
    assert_contains "HK-T05" "opaque=0"
  done
  for w in $_CP_OPAQUE_WORDS; do
    run_cmd dump "$w git push"
    assert_contains "HK-T05" "exe=$w"
    assert_contains "HK-T05" "opaque=1"
  done
  # 書き込み先を取るコマンド（§7）: write が空でない
  for pair in 'cp a b=b' 'mv a b=b' 'install a b=b' 'ln -s a b=b' 'sed -i s/x/y/ f.txt=f.txt' 'tee out.txt=out.txt' 'touch t.txt=t.txt' 'mkdir d=d' 'rm r.txt=r.txt'; do
    run_cmd dump "${pair%%=*}"
    assert_contains "HK-T05" "write=[${pair#*=}]"
  done
  run_cmd dump 'truncate -s 0 z'
  assert_not_contains "HK-T05" "write=[]"
  # 負のケースにも正の期待値: セグメントが消えたのではなく、別の exe として解析されている
  run_cmd dump 'grep "git commit" file.txt'
  assert_contains "HK-T05" "count=1"
  assert_contains "HK-T05" "seg0: exe=grep"
  run_cmd dump "echo 'git commit'"
  assert_contains "HK-T05" "seg0: exe=echo"
  run_cmd dump $'cat <<EOF\ngit commit\nEOF'
  assert_contains "HK-T05" "seg0: exe=cat"
  run_cmd dump 'ls # git commit'
  assert_contains "HK-T05" "count=1"
  assert_contains "HK-T05" "seg0: exe=ls"
  # gitlike: 実行体が不明（クォートで _ になった）でも、語としての git があるときだけ立つ
  run_cmd dump "'git' commit"
  assert_contains "HK-T05" "exe=_"
  assert_contains "HK-T05" "gitlike=1"
  run_cmd dump '"git.exe" push'
  assert_contains "HK-T05" "gitlike=1"
  for w in "'digit' x" "'legit' x" "'github' x" "'gitlab' x"; do
    run_cmd dump "$w"
    assert_contains "HK-T05" "exe=_"
    assert_contains "HK-T05" "gitlike=0"
  done
}

case_hk_t12() {
  run_cmd dump 'bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "docs: x" a.md'
  assert_contains "HK-T12" "provided=.claude/skills/20-common-step-commit-push/scripts/commit.sh"
  assert_contains "HK-T12" "args=[.claude/skills/20-common-step-commit-push/scripts/commit.sh -m _ a.md]"
  run_cmd dump 'bash .claude/hooks/20-PreToolUse/workflow-guard.sh'
  assert_contains "HK-T12" "provided=.claude/hooks/20-PreToolUse/workflow-guard.sh"
  run_cmd dump 'bash .claude/hooks/lib/tests/test_x.sh'
  assert_contains "HK-T12" "provided=.claude/hooks/lib/tests/test_x.sh"
  run_cmd dump 'sh .claude/skills/x/scripts/y.sh'
  assert_contains "HK-T12" "provided=.claude/skills/x/scripts/y.sh"
  cmdpos_parse 'cd wip && bash .claude/skills/20-common-step-commit-push/scripts/push.sh'
  assert_eq "HK-T12" "yes" "$(cmdpos_has_provided .claude/skills/20-common-step-commit-push/scripts/push.sh && echo yes || echo no)"
  local c
  for c in 'bash commit.sh' '/tmp/commit.sh' 'bash /tmp/commit.sh' 'bash /c/repo/.claude/skills/x/scripts/y.sh' 'bash ./.claude/skills/x/scripts/y.sh' \
           'bash "$DIR/commit.sh"' 'bash "$ROOT/.claude/skills/x/scripts/y.sh"' 'bash -n .claude/skills/x/scripts/y.sh' 'bash .claude/skills/x/scripts/sub/y.sh' \
           'bash .claude/skills/x/y.sh' 'bash ../.claude/skills/x/scripts/y.sh' 'bash .claude/skills/x/scripts/y.sh.bak' 'python .claude/skills/x/scripts/y.sh' \
           'bash -c ".claude/skills/x/scripts/y.sh"' '.claude/skills/x/scripts/y.sh'; do
    run_cmd dump "$c"
    assert_contains "HK-T12" "provided= "
    assert_not_contains "HK-T12" "provided=.claude"
  done
}

case_hk_t05_compound
case_hk_t05_negative
case_hk_t05_opaque
case_hk_t05_redirect_write
case_hk_t05_powershell
case_hk_t05_degraded
case_hk_t05_vocab
case_hk_t12
# ---- HK-T05: cmdpos_operands（位置引数の取り出し。DDR i0009-39）----
case_operands() {
  ops() { cmdpos_parse "$1"; cmdpos_operands 0; printf '%s\n' "${REPLY_OPERANDS[*]-}"; }
  assert_eq "HK-T05" "a b"                 "$(ops 'rm -rf a b')"
  assert_eq "HK-T05" "src dst"             "$(ops 'mv -v src dst')"
  assert_eq "HK-T05" "-weird"              "$(ops 'rm -- -weird')"
  assert_eq "HK-T05" "wip"                 "$(ops 'rm -rf wip')"
  assert_eq "HK-T05" "wip/10_tickets"      "$(ops 'rm -rf wip/10_tickets')"
  assert_eq "HK-T05" "wip/10_tickets/20_done" "$(ops 'rm -rf wip/10_tickets/20_done')"
  # git はサブコマンド自身を落とす
  assert_eq "HK-T05" "x y"                 "$(ops 'git rm -r --cached x y')"
  assert_eq "HK-T05" "a b"                 "$(ops 'git mv a b')"
  # 位置引数が無い
  assert_eq "HK-T05" ""                    "$(ops 'rm')"
  assert_eq "HK-T05" ""                    "$(ops 'rm -rf')"
}
case_operands

finish
