#!/usr/bin/env bash
# test_check_html.sh — check-html.sh とテンプレート 2 本のテスト（仕様のテスト ID: RV-T01〜07）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*check_html*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SKILL="$LOGGER_ROOT/.claude/skills/20-common-step-report-view"
CHECK="$SKILL/scripts/check-html.sh"
make_tmp_dir
# 一時ファイルはリポジトリ内の wip/tmp に置く（check-html.sh はリポジトリルートに cd するため相対で渡す）
WORK="wip/tmp/test-check-html-$$"
mkdir -p "$LOGGER_ROOT/$WORK"
trap 'rm -rf "$LOGGER_ROOT/$WORK"' EXIT
cd "$LOGGER_ROOT" || exit 2

# テンプレートの {{名前}} をすべて埋める（正しく埋めた HTML）
fill() { # $1=template $2=out
  sed -E 's/\{\{[a-z0-9_]+\}\}/埋めた内容/g' "$1" > "$2"
}
R="$WORK/report.html"; P="$WORK/plan.html"
fill "$SKILL/assets/report.template.html" "$R"
fill "$SKILL/assets/plan.template.html" "$P"

# RV-T01 テンプレートを正しく埋めた HTML が OK（件数付き）
run_cmd bash "$CHECK" "$R"
assert_exit "RV-T01" 0
assert_contains "RV-T01" "OK: 検査 7 項目すべて通過（id "
assert_contains "RV-T01" "テンプレート: report"
run_cmd bash "$CHECK" "$P"
assert_exit "RV-T01" 0
assert_contains "RV-T01" "テンプレート: plan"
# テンプレート自身はプレースホルダを持つので RV001（雛形は合格しない）
run_cmd bash "$CHECK" "$SKILL/assets/report.template.html"
assert_exit "RV-T01" 1
assert_contains "RV-T01" "RV001:"
# 引数不正
run_cmd bash "$CHECK"
assert_exit "RV-T01" 2
run_cmd bash "$CHECK" "$WORK/nosuch.html"
assert_exit "RV-T01" 2

# RV-T02 プレースホルダ残存・外部参照・重複 id・破断リンク・style 2 つがそれぞれの RV で全件列挙
B="$WORK/bad.html"
sed -e 's|<p class="lead">埋めた内容</p>|<p class="lead">{{summary}} と {{summary}} と {{todo}}</p>|' \
    -e 's|<h3 id="f1">|<h3 id="f1"><img src="https://example.com/x.png"><img src="pic.png"><script src="a.js"></script>|' \
    -e 's|<section id="todo" data-required>|<link rel="stylesheet" href="https://example.com/x.css"><section id="todo" data-required>|' \
    -e 's|<h2>残課題</h2>|<h2 id="f1">残課題</h2><a href="#nowhere">x</a><a href="#f9">y</a><style>@import url(https://example.com/a.css);</style>|' \
    "$R" > "$B"
run_cmd bash "$CHECK" "$B"
assert_exit "RV-T02" 1
assert_contains "RV-T02" "RV001: プレースホルダが残っている: {{summary}}×2 {{todo}}×1"
assert_contains "RV-T02" "RV002: 外部リソースの読み込みがある（5 件）"
assert_contains "RV-T02" "RV003: id が重複している: f1"
assert_contains "RV-T02" "RV004: 参照先の無いページ内リンク: f9 nowhere"
assert_contains "RV-T02" "RV005: <style> 要素が 2 個"
assert_not_contains "RV-T02" "RV006:"
assert_not_contains "RV-T02" "RV007:"
assert_eq "RV-T02" "RV005" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
# 単一引用符の属性（src='…' / href='…'）も外部リソースとして数える。id='…' も id として読む
B3="$WORK/sq.html"
sed -e "s|<p class=\"lead\">埋めた内容</p>|<p class=\"lead\"><img src='https://evil.example.com/t.gif'><script src='https://evil.example.com/x.js'></script><span id='sq1'>s</span><a href='#sq1'>a</a></p>|" "$R" > "$B3"
run_cmd bash "$CHECK" "$B3"
assert_exit "RV-T02" 1
assert_contains "RV-T02" "RV002: 外部リソースの読み込みがある（2 件）"
assert_not_contains "RV-T02" "RV004:"

# RV-T03 必須節を丸ごと削った HTML が RV006（任意節を削っても通る）
B="$WORK/missing.html"
awk '/<section id="next" data-required>/{skip=1} skip && /<\/section>/{skip=0; next} !skip' "$R" | sed '/<li><a href="#next">/d' > "$B"
run_cmd bash "$CHECK" "$B"
assert_exit "RV-T03" 1
assert_contains "RV-T03" "RV006: テンプレート（report）の必須節が無い: next"
B2="$WORK/optional-removed.html"
awk '/<section id="conditions">/{skip=1} skip && /<\/section>/{skip=0; next} !skip' "$R" | sed '/<li><a href="#conditions">/d' > "$B2"
run_cmd bash "$CHECK" "$B2"
assert_exit "RV-T03" 0
# 計画書の必須節（tickets / pending）も同様
B3="$WORK/plan-missing.html"
awk '/<section id="pending" data-required>/{skip=1} skip && /<\/section>/{skip=0; next} !skip' "$P" | sed '/<li><a href="#pending">/d' > "$B3"
run_cmd bash "$CHECK" "$B3"
assert_exit "RV-T03" 1
assert_contains "RV-T03" "必須節が無い: pending"

# RV-T04 空に近い HTML（id / リンク 0 件）が RV007（出力なし＝合格にしない）
E="$WORK/empty.html"
printf '<!DOCTYPE html><html><head><style>body{}</style></head><body data-template="report"><p>x</p></body></html>\n' > "$E"
run_cmd bash "$CHECK" "$E"
assert_exit "RV-T04" 1
assert_contains "RV-T04" "RV007: id 0 件 / ページ内リンク 0 件"
assert_contains "RV-T04" "RV006:"
# テンプレートを特定できない置き場・属性なし
E2="$WORK/unknown.html"
printf '<!DOCTYPE html><html><head><style>body{}</style></head><body><h1 id="a">x</h1><a href="#a">a</a></body></html>\n' > "$E2"
run_cmd bash "$CHECK" "$E2"
assert_exit "RV-T04" 1
assert_contains "RV-T04" "RV006: テンプレートを特定できない"

# RV-T05 ページ内アンカー・data: URI・<a href> の外部リンクは外部リソースと数えない
B="$WORK/ok-links.html"
sed -e 's|<p class="lead">埋めた内容</p>|<p class="lead"><a href="https://github.com/x/y/issues/6">issue #6</a> <a href="#findings">章</a> <img src="data:image/png;base64,AAAA" alt=""> <span style="background:url(data:image/svg+xml;utf8,x)">s</span></p>|' "$R" > "$B"
run_cmd bash "$CHECK" "$B"
assert_exit "RV-T05" 0
assert_not_contains "RV-T05" "RV002"
# コメントの中の src / <style> は数えない
B2="$WORK/comment.html"
sed -e 's|<p class="lead">埋めた内容</p>|<p class="lead">x</p><!-- <img src="https://e.com/a.png"> <style></style> <a href="#zzz">z</a> -->|' "$R" > "$B2"
run_cmd bash "$CHECK" "$B2"
assert_exit "RV-T05" 0

# RV-T06 data-required が <section> 以外（サイドバーの dl・h1）に付いていても検査 6 が拾い、削られていれば RV006
B="$WORK/no-meta.html"
sed -e '/<dl class="meta" id="meta" data-required>/,/<\/dl>/d' -e 's|<h1 id="title" data-required>埋めた内容</h1>|<p>no title</p>|' "$R" > "$B"
run_cmd bash "$CHECK" "$B"
assert_exit "RV-T06" 1
assert_contains "RV-T06" "RV006:"
assert_contains "RV-T06" " title"
assert_contains "RV-T06" " meta"
# data-required を外しただけ（要素と id は残る）なら存在検査は通る
B2="$WORK/attr-removed.html"
sed -e 's|<dl class="meta" id="meta" data-required>|<dl class="meta" id="meta">|' "$R" > "$B2"
run_cmd bash "$CHECK" "$B2"
assert_exit "RV-T06" 0

# RV-T07 引数・ファイル不正は検査に入る前に RV008・終了 2（最終行が RV008:）。導出元テンプレート不明は検査 6 の不合格 RV006・終了 1（RV008 ではない）
run_cmd bash "$CHECK"
assert_exit "RV-T07" 2
assert_eq "RV-T07" "RV008" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
run_cmd bash "$CHECK" "$R" "$P"
assert_exit "RV-T07" 2
assert_contains "RV-T07" "RV008: 引数は HTML ファイル 1 つ"
run_cmd bash "$CHECK" "$WORK/nosuch.html"
assert_exit "RV-T07" 2
assert_eq "RV-T07" "RV008: ファイルが無い: $WORK/nosuch.html" "${R_OUT##*$'\n'}"
printf 'plain\n' > "$WORK/not-html.txt"
run_cmd bash "$CHECK" "$WORK/not-html.txt"
assert_exit "RV-T07" 2
assert_eq "RV-T07" "RV008: .html 以外は検査しない: $WORK/not-html.txt" "${R_OUT##*$'\n'}"
assert_not_contains "RV-T07" "RV001"
# 読めないファイル（権限を落とせる環境でだけ検査する。Windows の NTFS では chmod が効かないことがある）
cp "$R" "$WORK/noperm.html"
chmod 000 "$WORK/noperm.html" 2>/dev/null || true
if [ ! -r "$WORK/noperm.html" ]; then
  run_cmd bash "$CHECK" "$WORK/noperm.html"
  assert_exit "RV-T07" 2
  assert_eq "RV-T07" "RV008" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
  assert_contains "RV-T07" "読めない"
fi
chmod 644 "$WORK/noperm.html" 2>/dev/null || true
# 負のケースの正の期待値: data-template 無し + 置き場外は RV006 で終了 1（引数・ファイルは正しいので RV008 を出さない）
run_cmd bash "$CHECK" "$E2"
assert_exit "RV-T07" 1
assert_contains "RV-T07" "RV006: テンプレートを特定できない"
assert_not_contains "RV-T07" "RV008"

finish
