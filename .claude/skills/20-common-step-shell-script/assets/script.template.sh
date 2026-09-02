#!/usr/bin/env bash
# {{NAME}}.sh — {{PURPOSE}}
# 仕様: {{SPEC_PATH}}（インターフェース・判定順・エラー識別子の正）
# 使い方: bash {{INVOKE_PATH}} <subcommand> [options]
# 終了コード: 成功 0 / 検査・前提未充足 1 / 引数や環境の誤り 2。最終行は `OK: ...` または `{{PREFIX}}<番号>: ...`
set -euo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# <lib> = logger | frontmatter | test-lib、<policy> = nop | fatal | deny。フックの deny は HOOK_DENY_ID（例 WF209）を先に設定する。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop
# frontmatter を読む提供コマンドは次の行も使う（不要なら削除）: __ss_load frontmatter fatal

readonly SCRIPT_PREFIX="{{PREFIX}}"

usage() {
  cat <<'USAGE'
使い方: bash {{INVOKE_PATH}} <subcommand> [options]
  subcommand: {{SUBCOMMANDS}}
  options:    {{OPTIONS}}
USAGE
}

# 結果出力の型。最終行に OK: / <PREFIX><番号>: を出して終了する
result_ok() { # $1=メッセージ
  log_info "OK: $1"
  printf 'OK: %s\n' "$1"
  exit 0
}
result_ng() { # $1=番号(3 桁) $2=メッセージ $3=終了コード(1 or 2)
  log_warn "${SCRIPT_PREFIX}$1: $2"
  printf '%s%s: %s\n' "$SCRIPT_PREFIX" "$1" "$2"
  exit "$3"
}

main() {
  local subcommand="" positional=()
  # オプションは順不同で受け付ける
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --*) result_ng "{{ARG_ERROR_NO}}" "不明なオプション: $1" 2 ;;
      *) if [ -z "$subcommand" ]; then subcommand="$1"; else positional+=("$1"); fi ;;
    esac
    shift
  done
  log_info "start subcommand=${subcommand:-} args=${positional[*]:-}"
  case "$subcommand" in
    "") result_ok "{{NAME}} 実行" ;;
    *) result_ng "{{ARG_ERROR_NO}}" "不明なサブコマンド: $subcommand" 2 ;;
  esac
}

main "$@"
