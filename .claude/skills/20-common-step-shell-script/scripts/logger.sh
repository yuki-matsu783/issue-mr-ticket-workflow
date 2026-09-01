#!/usr/bin/env bash
# logger.sh — 共通 logger（source 専用）
# 仕様: .claude/docs/10_spec/skills/20-common-step-shell-script.md「logger.sh」、ルール: .claude/rules/logger.md
# 提供: log_debug / log_info / log_warn / log_error（各 1 引数。複数引数はスペース連結）
# 出力先: <LOGGER_ROOT>/logs/sh/<出どころ>.log。標準出力・標準エラーには何も出さない。失敗はすべて握りつぶす

# 直接実行されたら何もしない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi

# 1. 初期化: リポジトリルート（読み込み行が LOGGER_ROOT に置く。無ければ git に聞く）
__lg_root="${LOGGER_ROOT:-}"
if [[ -z "$__lg_root" ]]; then
  __lg_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
LOGGER_DIR=""
if [[ -n "$__lg_root" ]]; then
  LOGGER_DIR="$__lg_root/logs/sh"
  mkdir -p "$LOGGER_DIR" 2>/dev/null || LOGGER_DIR=""
fi

# 出どころ: LOGGER_NAME があればそれ、無ければ $0 の basename（拡張子なし）
if [[ -n "${LOGGER_NAME:-}" ]]; then
  __lg_name="$LOGGER_NAME"
else
  __lg_name="${0##*/}"
  __lg_name="${__lg_name%.sh}"
fi
case "$__lg_name" in ""|bash|-bash|sh|-sh) __lg_name="sh" ;; esac
LOGGER_SOURCE="$__lg_name"
LOGGER_FILE=""
[[ -n "$LOGGER_DIR" ]] && LOGGER_FILE="$LOGGER_DIR/$LOGGER_SOURCE.log"

# レベル: DEBUG(10) < INFO(20) < WARN(30) < ERROR(40)。未設定・無効値は INFO
__lg_lv="${LOG_LEVEL:-INFO}"
__lg_lv="${__lg_lv^^}"
case "$__lg_lv" in
  DEBUG) LOGGER_LEVEL_NUM=10 ;;
  INFO)  LOGGER_LEVEL_NUM=20 ;;
  WARN)  LOGGER_LEVEL_NUM=30 ;;
  ERROR) LOGGER_LEVEL_NUM=40 ;;
  *)     LOGGER_LEVEL_NUM=20 ;;
esac
unset __lg_root __lg_name __lg_lv

# 書き込み本体。常に 0 を返す（set -e の利用側を巻き込まない）
__lg_write() { # $1=レベル番号 $2=レベル名 $3..=メッセージ
  local num="$1" lvl="$2" msg ts
  shift 2
  if (( num < LOGGER_LEVEL_NUM )); then return 0; fi
  msg="$*"
  msg="${msg//$'\r'/}"
  msg="${msg//$'\n'/\\n}"
  # 時刻は bash 組み込みで取り（date を fork しない）、+0900 にコロンを挿して +09:00 にする
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  ts="${ts:0:22}:${ts:22}"
  if [[ -n "$LOGGER_FILE" ]]; then
    printf '%s [%s] [%s] [pid:%s] %s\n' "$ts" "$lvl" "$LOGGER_SOURCE" "$$" "$msg" >> "$LOGGER_FILE" 2>/dev/null || true
  fi
  return 0
}

log_debug() { __lg_write 10 DEBUG "$@"; }
log_info()  { __lg_write 20 INFO  "$@"; }
log_warn()  { __lg_write 30 WARN  "$@"; }
log_error() { __lg_write 40 ERROR "$@"; }
