#!/usr/bin/env bash
# test_logger.sh — logger.sh のテスト（仕様のテスト ID: LG-T01〜05）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*logger*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

LIB="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts/logger.sh"
make_tmp_dir
ROOT="$TMP_DIR/root"
mkdir -p "$ROOT"

# logger を source して関数を呼ぶ小さなスクリプトを、指定の環境変数で実行する
# 使い方: runlog <name> <LOG_LEVEL or -> <ROOT> <bash のコマンド列>
runlog() {
  local name="$1" level="$2" root="$3" body="$4"
  local envs=(LOGGER_ROOT="$root" LOGGER_NAME="$name")
  [ "$level" != "-" ] && envs+=(LOG_LEVEL="$level")
  run_cmd env "${envs[@]}" bash -c "set -euo pipefail; source '$LIB'; $body"
}

# LG-T01 既定で INFO が書かれ DEBUG が書かれない
runlog t1 - "$ROOT" 'log_info "hello info"; log_debug "hello debug"'
assert_exit "LG-T01" 0
F="$ROOT/logs/sh/t1.log"
if [ -f "$F" ] && grep -q '\[INFO\] \[t1\] .*hello info' "$F" && ! grep -q 'hello debug' "$F"; then pass "LG-T01"; else fail "LG-T01" "log: $(cat "$F" 2>/dev/null)"; fi

# LG-T02 LOG_LEVEL=DEBUG で DEBUG も書かれ、行フォーマットが一致する
runlog t2 DEBUG "$ROOT" 'log_debug "dbg line"; log_warn "warn line"'
assert_exit "LG-T02" 0
F="$ROOT/logs/sh/t2.log"
line="$(grep 'dbg line' "$F" 2>/dev/null | head -1)"
if [[ "$line" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}\ \[DEBUG\]\ \[t2\]\ \[pid:[0-9]+\]\ dbg\ line$ ]]; then pass "LG-T02"; else fail "LG-T02" "format: '$line'"; fi
if grep -q '\[WARN\] \[t2\] .*warn line' "$F"; then pass "LG-T02"; else fail "LG-T02" "warn 行が無い"; fi

# LG-T03 logs/ が作成不能でも source と関数呼び出しが成功し、標準出力・標準エラーに何も出ない
BROKEN="$TMP_DIR/broken"
mkdir -p "$BROKEN"
: > "$BROKEN/logs"   # logs をファイルにして mkdir -p を失敗させる
runlog t3 - "$BROKEN" 'log_info "x"; log_error "y"; echo done'
assert_exit "LG-T03" 0
assert_eq "LG-T03" "done" "$R_OUT"
assert_eq "LG-T03" "" "$R_ERR"

# LG-T04 無効な LOG_LEVEL は INFO に正規化。改行入りメッセージが 1 行になる
runlog t4 bogus "$ROOT" 'log_debug "no"; log_info "$(printf "l1\nl2")"'
assert_exit "LG-T04" 0
F="$ROOT/logs/sh/t4.log"
n="$(grep -c '' "$F" 2>/dev/null || echo 0)"
assert_eq "LG-T04" "1" "$n"
if grep -q 'l1\\nl2' "$F" && ! grep -q '\[DEBUG\]' "$F"; then pass "LG-T04"; else fail "LG-T04" "log: $(cat "$F" 2>/dev/null)"; fi

# LG-T05 LOGGER_NAME による出どころの上書き（未指定なら $0 の basename）
runlog custom-name - "$ROOT" 'log_info "named"'
if [ -f "$ROOT/logs/sh/custom-name.log" ] && grep -q '\[custom-name\]' "$ROOT/logs/sh/custom-name.log"; then pass "LG-T05"; else fail "LG-T05" "custom-name.log が無い"; fi
printf '#!/usr/bin/env bash\nsource "%s"\nlog_info "from script"\n' "$LIB" > "$TMP_DIR/myscript.sh"
run_cmd env LOGGER_ROOT="$ROOT" bash "$TMP_DIR/myscript.sh"
if [ -f "$ROOT/logs/sh/myscript.log" ]; then pass "LG-T05"; else fail "LG-T05" "myscript.log が無い: $(ls "$ROOT/logs/sh" 2>/dev/null)"; fi

finish
