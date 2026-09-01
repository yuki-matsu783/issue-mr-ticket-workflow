#!/usr/bin/env bash
# run-tests.sh — テストランナー（提供コマンド）
# 仕様: .claude/docs/10_spec/skills/20-common-step-shell-script.md「run-tests.sh」
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh [--filter <glob>] [--ids] [--timeout <秒>]
# 終了コード: 全 PASS 0 / FAIL・TIMEOUT・0 本・宣言不足 1 / 引数や環境の誤り 2。最終行は `OK: ...` または `TR<番号>: ...`
set -euo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop
__ss_load frontmatter fatal

readonly SCRIPT_PREFIX="TR"
readonly DEFAULT_TIMEOUT=120
readonly DOING_DIR="wip/10_tickets/10_doing"

usage() {
  cat <<'USAGE'
使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh [--filter <glob>] [--ids] [--timeout <秒>]
  --filter <glob>  テストファイルのパス（リポジトリルート相対）を glob で絞る
  --ids            PASS / FAIL した テスト ID の一覧と重複 ID を出す
  --timeout <秒>   1 テストの上限秒数（既定 120）
USAGE
}

result_ok() { # $1=メッセージ
  log_info "OK: $1"
  printf 'OK: %s\n' "$1"
  exit 0
}
result_ng() { # $1=番号 $2=メッセージ $3=終了コード
  log_warn "${SCRIPT_PREFIX}$1: $2"
  printf '%s%s: %s\n' "$SCRIPT_PREFIX" "$1" "$2"
  exit "$3"
}

main() {
  local filter="" show_ids=0 limit="$DEFAULT_TIMEOUT"
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --filter)
        [ $# -ge 2 ] || result_ng 004 "--filter には glob を指定する" 2
        filter="$2"; shift ;;
      --ids) show_ids=1 ;;
      --timeout)
        [ $# -ge 2 ] || result_ng 004 "--timeout には秒数を指定する" 2
        [[ "$2" =~ ^[0-9]+$ ]] || result_ng 004 "--timeout は整数（秒）: $2" 2
        limit="$2"; shift ;;
      *) result_ng 004 "不明な引数: $1（--filter <glob> / --ids / --timeout <秒>）" 2 ;;
    esac
    shift
  done

  # 実行環境
  local missing=""
  command -v timeout >/dev/null 2>&1 || missing+=" timeout"
  command -v jq >/dev/null 2>&1 || missing+=" jq"
  [ -z "$missing" ] || result_ng 005 "実行環境の不備: 次のコマンドが無い —${missing}" 2

  cd "$LOGGER_ROOT" || result_ng 005 "リポジトリルートに移動できない: $LOGGER_ROOT" 2
  log_info "start filter=${filter:-*} ids=$show_ids timeout=$limit root=$LOGGER_ROOT"

  # 2. テストの列挙（2 つの置き場）
  shopt -s globstar nullglob
  local all=() files=() f
  all=(.claude/hooks/**/tests/test_*.sh .claude/skills/*/scripts/tests/test_*.sh)
  shopt -u globstar nullglob
  for f in "${all[@]}"; do
    # shellcheck disable=SC2053
    if [ -n "$filter" ] && [[ "$f" != $filter ]]; then continue; fi
    files+=("$f")
  done
  local includes_hooks=0
  for f in "${files[@]}"; do
    case "$f" in .claude/hooks/*) includes_hooks=1 ;; esac
  done

  # 1. 作業中チケットの宣言検査（提供コマンドは分類を問わずフックが許可するため、ここで検査する）
  local doing=() ticket ops need="" lacking=""
  shopt -s nullglob
  doing=("$DOING_DIR"/*.md)
  shopt -u nullglob
  if [ "${#doing[@]}" -gt 0 ]; then
    ticket="${doing[0]}"
    ops="$(fm_list "$ticket" allow.ops 2>/dev/null || true)"
    need="build-test"
    [ "$includes_hooks" -eq 1 ] && need="build-test hook-test"
    local n
    for n in $need; do
      grep -qx -- "$n" <<<"$ops" || lacking+=" $n"
    done
    if [ -n "$lacking" ]; then
      result_ng 006 "作業中チケット ${ticket##*/} の allow.ops に無い分類:${lacking}（宣言は ${ops//$'\n'/ }）。計画で宣言してから実行する" 1
    fi
  fi

  [ "${#files[@]}" -gt 0 ] || result_ng 001 "対象のテストが 0 本（filter=${filter:-*}。置き場: .claude/hooks/**/tests/test_*.sh, .claude/skills/*/scripts/tests/test_*.sh）" 1

  # 3. 実行と集計
  local out code status line id last
  local -a rows=() fail_files=() timeout_files=() pass_ids=() fail_ids=() id_files=()
  for f in "${files[@]}"; do
    if out="$(timeout "$limit" bash "$f" 2>&1)"; then code=0; else code=$?; fi
    status="PASS"
    local file_fail=0
    while IFS= read -r line; do
      line="${line%$'\r'}"
      if [[ "$line" =~ ^(PASS|FAIL)\ ([A-Z]{2,6}-[TE][0-9]{2}[a-z]?) ]]; then
        id="${BASH_REMATCH[2]}"
        id_files+=("$id"$'\t'"$f")
        if [ "${BASH_REMATCH[1]}" = "PASS" ]; then pass_ids+=("$id"); else fail_ids+=("$id"); file_fail=1; fi
      fi
    done <<<"$out"
    last="${out##*$'\n'}"
    if [ "$code" -eq 124 ]; then
      status="TIMEOUT"; timeout_files+=("$f")
    elif [ "$code" -ne 0 ] || [ "$file_fail" -eq 1 ]; then
      status="FAIL"; fail_files+=("$f")
    fi
    rows+=("| $f | $status | exit $code | ${last:-（出力なし）} |")
    log_info "test $f status=$status exit=$code last=${last:-}"
  done

  # 4. 出力
  printf '| テスト | 結果 | 終了コード | 最終行 |\n|---|---|---|---|\n'
  printf '%s\n' "${rows[@]}"
  if [ "$show_ids" -eq 1 ]; then
    printf '\nPASS ID: %s\n' "$(printf '%s\n' "${pass_ids[@]:-}" | sort -u | tr '\n' ' ')"
    printf 'FAIL ID: %s\n' "$(printf '%s\n' "${fail_ids[@]:-}" | sort -u | tr '\n' ' ')"
    # 重複: 同じ ID が複数のファイルに現れる
    local dup
    dup="$(printf '%s\n' "${id_files[@]:-}" | awk -F'\t' 'NF==2 { if (!($1 in seen) || seen[$1] != $2) { count[$1]++; seen[$1]=$2; files[$1]=files[$1] (files[$1]==""?"":", ") $2 } } END { for (k in count) if (count[k] > 1) print k " (" files[k] ")" }' | sort)"
    if [ -n "$dup" ]; then printf '重複 ID:\n%s\n' "$dup"; else printf '重複 ID: なし\n'; fi
  fi
  printf '\n'

  # 5. 判定
  local distinct
  distinct="$(printf '%s\n' "${pass_ids[@]:-}" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')"
  if [ "${#fail_files[@]}" -eq 0 ] && [ "${#timeout_files[@]}" -eq 0 ]; then
    result_ok "${#files[@]} 本 / ${distinct} 件"
  fi
  if [ "${#timeout_files[@]}" -gt 0 ]; then
    log_warn "TR003: ${timeout_files[*]}"
    printf 'TR003: タイムアウト（%s 秒）: %s\n' "$limit" "${timeout_files[*]}"
  fi
  if [ "${#fail_files[@]}" -gt 0 ]; then
    log_warn "TR002: ${fail_files[*]}"
    printf 'TR002: FAIL したテスト: %s / FAIL した ID: %s\n' "${fail_files[*]}" "$(printf '%s\n' "${fail_ids[@]:-}" | sort -u | tr '\n' ' ')"
  fi
  exit 1
}

main "$@"
