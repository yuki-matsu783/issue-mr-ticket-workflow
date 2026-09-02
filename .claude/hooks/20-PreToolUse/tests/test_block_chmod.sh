#!/usr/bin/env bash
# test_block_chmod.sh — block-chmod.sh のテスト（仕様のテスト ID: BC-T01〜BC-T06）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*block_chmod*'
# テストは set -e を使わない（終了コードは run_cmd が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

HOOK="$LOGGER_ROOT/.claude/hooks/20-PreToolUse/block-chmod.sh"
CFG_DIR="$LOGGER_ROOT/.claude/hooks/config"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/config" "$TMP_REPO/.claude/hooks/20-PreToolUse" "$TMP_REPO/.claude/hooks/lib" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts"
cp "$HOOK" "$TMP_REPO/.claude/hooks/20-PreToolUse/"
cp "$LOGGER_ROOT/.claude/hooks/lib/hook-common.sh" "$LOGGER_ROOT/.claude/hooks/lib/cmdpos.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts/logger.sh" \
   "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/" 2>/dev/null || true
cp "$CFG_DIR/blocked-commands.txt" "$TMP_REPO/.claude/hooks/config/"
TMP_HOOK="$TMP_REPO/.claude/hooks/20-PreToolUse/block-chmod.sh"

# 判定を 1 語にする: WF501 / WF509 / allow
judge() { # $1=コマンド文字列
  local out
  out="$(hook_payload PreToolUse Bash command="$1" | bash "$TMP_HOOK" 2>/dev/null)"; local rc=$?
  case "$out" in
    *WF501*) printf 'WF501\n' ;;
    *WF509*) printf 'WF509\n' ;;
    # 無出力でも終了コードが 0 でなければ許可ではない（PreToolUse の終了 2 は拒否）
    "")      if (( rc == 0 )); then printf 'allow\n'; else printf 'exit%d\n' "$rc"; fi ;;
    *)       printf 'other:%s\n' "$out" ;;
  esac
}

# ---- BC-T01: 複合・ラッパー・パス付きの chmod を拒否する ----
case_block() {
  assert_eq "BC-T01" "WF501" "$(judge 'chmod +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge 'ls && chmod +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge 'sudo chmod 755 a')"
  assert_eq "BC-T01" "WF501" "$(judge '/usr/bin/chmod +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'cd x; chmod 644 y')"
  assert_eq "BC-T01" "WF501" "$(judge 'env FOO=1 chmod +x a')"
  # クォート・エスケープで実行体を割っても拒否する（正規化では chmod に戻らない形を含む）
  assert_eq "BC-T01" "WF501" "$(judge 'c\hmod +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge 'ch""mod +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge "ch''mod +x a.sh")"
  # 実行体が変数展開なら何が走るか分からないので拒否側に倒す
  assert_eq "BC-T01" "WF501" "$(judge 'CMD=chmod; $CMD +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge 'eval "chmod +x a"')"
  # 中身の見えない展開を挟んで実行体を割る形。bash はいずれも chmod として実行する
  # （`bash -c 'chmod$@ --version'` が chmod のバージョンを出すことを実測で確認した）
  assert_eq "BC-T01" "WF501" "$(judge 'chmod$() +x a')"
  assert_eq "BC-T01" "WF501" "$(judge "chmod\$'' +x a")"
  assert_eq "BC-T01" "WF501" "$(judge 'chmod$(true) +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'chmod${x} +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'chmod$@ +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'chmod$* +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'ch$()mod +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'chmod`` +x a')"
  # 中身のあるクォートで実行体を割る形。bash は結合して chmod を起動する
  # （`bash -c '"chmod" --version'` が chmod (GNU coreutils) を出すことを実測で確認した）。
  # クォートの中身を復元する方針では表記を列挙し切れないので、
  # 実行位置に難読化の痕跡があれば「実行体を特定できない」として拒否側に倒す
  assert_eq "BC-T01" "WF501" "$(judge '"chmod" +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge "'chmod' +x a.sh")"
  assert_eq "BC-T01" "WF501" "$(judge 'c"h"mod +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge 'ch"m"od +x a.sh')"
  assert_eq "BC-T01" "WF501" "$(judge '"/usr/bin/chmod" +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'sudo "chmod" 755 a')"
  # 中身が空でない展開を挟んで実行体を割る形。展開結果は空なので chmod が起動する
  assert_eq "BC-T01" "WF501" "$(judge 'ch$( )mod +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'ch$( : )mod +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'ch$(echo)mod +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'ch${x:-}mod +x a')"
  assert_eq "BC-T01" "WF501" "$(judge 'c${x}hmod +x a')"
  # 難読化除去は文字単位の走査なので長さの上限（4096 バイト）で縮退し、複製が空になる。
  # そのとき前置判定を通すのは「記号と空白を落とした複製」だけなので、空白の除去を外すと
  # 長いコマンドに隠した `ch$( )mod` が前置判定で落ちて素通りする
  # （前置判定を通れば cmdpos も縮退しているので制御方式 4 が拒否する）
  local pad
  pad="$(printf 'a%.0s' $(seq 1 5000))"
  assert_eq "BC-T01" "WF501" "$(judge "ch\$( )mod +x a # $pad")"
  # ヒアドキュメント本文を実行位置から外しても、本文の「外」にある実行位置は拒否のまま。
  # 上の BC-T02 と同数の対照を置く（片側だけ見ると取りこぼしと過剰拒否を往復する）
  local hdx
  for hdx in $'cat > o.py <<PY\nx\nPY\nchmod +x a' \
             $'chmod +x a\ncat > o.py <<PY\nx\nPY' \
             $'chmod +x a <<PY\nx\nPY' \
             $'bash -c "chmod +x a" <<PY\nx\nPY' \
             $'cat > o.py <<PY\nx\nPY\nls | xargs chmod +x'; do
    assert_eq "BC-T01" "WF501" "$(judge "$hdx")"
  done
}

# ---- BC-T02: クォート・検索語・地の文の chmod は通る ----
case_pass() {
  assert_eq "BC-T02" "allow" "$(judge 'grep chmod README.md')"
  assert_eq "BC-T02" "allow" "$(judge 'echo "chmod"')"
  assert_eq "BC-T02" "allow" "$(judge "grep -n 'chmod' .claude/docs/x.md")"
  assert_eq "BC-T02" "allow" "$(judge 'ls -la')"
  # 別の段のデータとして現れただけの語では拒否しない（opaque な段の中身に無いのに全体を見ると過剰拒否になる）
  assert_eq "BC-T02" "allow" "$(judge 'grep chmod f | xargs echo')"
  assert_eq "BC-T02" "allow" "$(judge 'cat notes.md | grep chmod')"
  # 引用符の中に区切り文字と禁止語が並ぶ形。難読化の除去でクォートを構文ごと落とすと、
  # 文字列の中の `;` `|` `(` `)` が本物の区切りに昇格して、これらが軒並み拒否になる。
  # このプロジェクトはコミットメッセージや文書で chmod に言及するので現実に踏む
  assert_eq "BC-T02" "allow" "$(judge 'git commit -m "fix: 権限は触らない; chmod は使わない"')"
  assert_eq "BC-T02" "allow" "$(judge 'echo "NG: cd x; chmod +x a" >> wip/tmp/note.md')"
  assert_eq "BC-T02" "allow" "$(judge 'grep -n "a | chmod" doc.md')"
  assert_eq "BC-T02" "allow" "$(judge 'echo "使うな: (chmod)"')"
  assert_eq "BC-T02" "allow" "$(judge 'printf "%s" "a; chmod 600 f" >> notes.md')"
  # 実行体が難読化されていないのに、コマンドが禁止語に言及するだけの形。
  # 「難読化の痕跡があれば拒否」の代償（過剰拒否）がここに出るので、拒否側と同数の対照を置く。
  # 実行体に元から `_` を含むもの（`my_tool.sh`）が潰れたクォート由来と誤判定されないことも見る
  assert_eq "BC-T02" "allow" "$(judge 'bash script.sh -m "chmod の話"')"
  assert_eq "BC-T02" "allow" "$(judge './my_tool.sh --note "chmod"')"
  assert_eq "BC-T02" "allow" "$(judge 'python3 tools/check_mode.py --word chmod')"
  assert_eq "BC-T02" "allow" "$(judge 'rg "chmod" -n .claude/')"
  assert_eq "BC-T02" "allow" "$(judge 'git log --grep "chmod" --oneline')"
  assert_eq "BC-T02" "allow" "$(judge './a_b_c.sh --mode "chmod"')"
  assert_eq "BC-T02" "allow" "$(judge 'touch modules/x.txt')"
  assert_eq "BC-T02" "allow" "$(judge 'wc -l notes.md')"
  assert_eq "BC-T02" "allow" "$(judge 'sed -n "1,5p" chmod-notes.md')"
  assert_eq "BC-T02" "allow" "$(judge 'ls chmod_backup/')"
  assert_eq "BC-T02" "allow" "$(judge 'diff a.md b.md')"
  # ヒアドキュメントの本文は実行位置ではない（bash は決して実行しない）。
  # cmdpos は「クォート・コメント・ヒアドキュメント本文」を同じ `_` に潰すので、
  # 実行体が `_` = 難読化と読むと、本文に禁止語を書いただけで拒否側に倒れる。
  # 0028 の実測で、登録から 3 回目の Bash 呼び出しがこれで止まった
  local hd
  for hd in $'cat > o.py <<\'PY\'\nE = ["chmod --version"]\nPY' \
            $'cat > o.py <<PY\nE = ["chmod --version"]\nPY' \
            $'cat > o.py <<-PY\n\tE = ["chmod --version"]\n\tPY' \
            $'cat > o.py << PY\nE = ["chmod --version"]\nPY'; do
    assert_eq "BC-T02" "allow" "$(judge "$hd")"
  done
  # 0028 の切り分けで対照に使った形（ヒアドキュメント無しで禁止語 + クォート + 変数展開）。
  # 0036 が「代償」として想定していたのはこの形だが、実際には通る。
  # 過剰拒否の原因がヒアドキュメントだけだったことを、この対照が固定する
  assert_eq "BC-T02" "allow" "$(judge 'echo "chmod" "${HOME}"')"
  assert_eq "BC-T02" "allow" "$(judge 'echo "chmod --version" > note.md')"
  assert_eq "BC-T02" "allow" "$(judge 'echo "${HOME}/chmod"')"
  # コメントだけの行に禁止語がある形も通る（コメントも実行されない）
  assert_eq "BC-T02" "allow" "$(judge $'ls -la\n# chmod は使わない\necho b')"
}

# ---- BC-T03: bash -c / xargs 経由でも拒否する ----
case_wrapper() {
  assert_eq "BC-T03" "WF501" "$(judge 'bash -c "chmod +x a"')"
  assert_eq "BC-T03" "WF501" "$(judge 'ls | xargs chmod +x')"
}

# ---- BC-T04: 一覧に足すと拒否され、外すと通る（一覧をコードに埋めていない） ----
case_list() {
  local f="$TMP_REPO/.claude/hooks/config/blocked-commands.txt"
  assert_eq "BC-T04" "allow" "$(judge 'chown user a')"
  printf '# c\nchmod\nchown\n' > "$f"
  assert_eq "BC-T04" "WF501" "$(judge 'chown user a')"
  assert_eq "BC-T04" "WF501" "$(judge 'chmod +x a')"
  printf '# c\nchown\n' > "$f"
  assert_eq "BC-T04" "allow" "$(judge 'chmod +x a')"
  assert_eq "BC-T04" "WF501" "$(judge 'chown user a')"
  # 空の一覧なら何も拒否しない
  printf '# コメントだけ\n\n' > "$f"
  assert_eq "BC-T04" "allow" "$(judge 'chmod +x a')"
  printf '# c\nchmod\n' > "$f"
}

# ---- BC-T05: 一覧の語を含まないコマンドは cmdpos.sh を読み込まずに通る（高速前置判定） ----
# 「壊しても通る」を主張するなら実際に壊して確かめる。cp で退避して戻すだけでは何も検査していない
case_fastpath() {
  local lib="$TMP_REPO/.claude/hooks/lib/cmdpos.sh" bak="$TMP_REPO/cmdpos.sh.bak"
  cp "$lib" "$bak"
  # 構文エラーを仕込む。読み込んでいれば source した時点で落ちる
  printf '%s\n' 'if ( then fi' > "$lib"
  assert_eq "BC-T05" "allow" "$(judge 'ls -la')"
  assert_eq "BC-T05" "allow" "$(judge 'git status')"
  assert_eq "BC-T05" "allow" "$(judge 'cat README.md')"
  # 一覧の語を含むコマンドは cmdpos.sh が要るので、壊れていれば拒否側に倒れる（無出力・終了 0 の許可にはならない）。
  # source 時の構文エラーは bash が即座に落とすので EXIT トラップが走らず、stdout の deny JSON ではなく
  # 終了コード 2（PreToolUse では拒否）で止まる。どちらの形でも「許可ではない」ことを見る
  local out rc
  out="$(hook_payload PreToolUse Bash command='chmod +x a' | bash "$TMP_HOOK" 2>/dev/null)"; rc=$?
  if [[ -n "$out" ]] || (( rc != 0 )); then pass "BC-T05"; else fail "BC-T05" "cmdpos.sh が壊れているのに chmod が許可された"; fi
  cp "$bak" "$lib"
  # 前置判定そのものを消すと、一覧の語を含まないコマンドでも cmdpos.sh を読むようになる（= この検査に検出力がある）
  assert_eq "BC-T05" "allow" "$(judge 'ls -la')"
  # 前置判定は大文字小文字を問わない
  assert_eq "BC-T05" "WF501" "$(judge 'CHMOD +x a')"
}

# ---- BC-T06: 入力不正で WF509 ----
case_bad_input() {
  local out
  out="$(printf '%s' 'not json' | bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_contains_out() { [[ "$out" == *"$1"* ]] && pass "BC-T06" || fail "BC-T06" "出力に '$1' が無い: $out"; }
  assert_contains_out "WF509"
  assert_contains_out '"permissionDecision":"deny"'
  out="$(printf '%s' '' | bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_contains_out "WF509"
}

# ---- 付随: ホットパスの外部プロセス（HK-T19）: jq は 1 回、git / date / sed / find は呼ばない ----
case_hotpath() {
  local bash_bin; bash_bin="$(command -v bash)"
  make_counting_path jq git date sed find awk grep cat tr cut head tail wc sort uniq
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" -c     "printf '%s' '$(hook_payload PreToolUse Bash command='chmod +x a')' | '$bash_bin' '$TMP_HOOK'"
  assert_eq "BC-T05" "1" "$(counted_calls jq)"
  assert_eq "BC-T05" "0" "$(counted_calls git)"
  assert_eq "BC-T05" "0" "$(counted_calls date)"
  assert_eq "BC-T05" "0" "$(counted_calls sed)"
  assert_eq "BC-T05" "0" "$(counted_calls find)"
}

# ---- 付随: 緊急停止（§4）では何も出さない ----
case_enforce() {
  local out
  out="$(hook_payload PreToolUse Bash command='chmod +x a' | WORKFLOW_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "BC-T01" "" "$out"
  out="$(hook_payload PreToolUse Bash command='chmod +x a' | WORKFLOW_BLOCK_CHMOD_ENFORCE=0 bash "$TMP_HOOK" 2>/dev/null)" || true
  assert_eq "BC-T01" "" "$out"
}

# ---- 付随: 拒否は decisions.jsonl に残り、許可は残らない ----
case_record() {
  local dec="$TMP_REPO/logs/hooks/decisions.jsonl" n1 n2
  rm -f "$dec"
  judge 'ls -la' > /dev/null
  n1=$([[ -f "$dec" ]] && wc -l < "$dec" || echo 0)
  judge 'chmod +x a' > /dev/null
  n2=$([[ -f "$dec" ]] && wc -l < "$dec" || echo 0)
  assert_eq "BC-T01" "0" "${n1// /}"
  assert_eq "BC-T01" "1" "${n2// /}"
  local body; body="$(cat "$dec")"
  [[ "$body" == *WF501* ]] && pass "BC-T01" || fail "BC-T01" "decisions.jsonl に WF501 が無い"
}

case_block
case_pass
case_wrapper
case_list
case_fastpath
case_bad_input
case_hotpath
case_enforce
case_record
finish
