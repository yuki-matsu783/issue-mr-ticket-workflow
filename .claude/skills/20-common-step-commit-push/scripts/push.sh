#!/usr/bin/env bash
# push.sh — push 前チェック付きの push（提供コマンド）
# 仕様: .claude/docs/10_spec/skills/20-common-step-commit-push.md「push.sh」
# 使い方: bash .claude/skills/20-common-step-commit-push/scripts/push.sh
#   前チェック 4 項目を全件実施し、未充足を全件列挙して CP005 で止まる。`wip/push-check-skip.md` に
#   `- 項目 N: <理由>` と書かれた項目（1〜3）だけ飛ばす（項目 4 はスキップ不可）。
# 終了コード: 成功 0 / 前チェック未充足（CP005）・リモート拒否（CP006）1 / 引数や環境の誤り（CP007）2。最終行は `OK: ...` または `CP<番号>: ...`
set -euo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop
__ss_load frontmatter fatal

readonly SCRIPT_PREFIX="CP"
readonly SKIP_FILE="wip/push-check-skip.md"
readonly DOING_DIR="wip/10_tickets/10_doing"
readonly MERGE_STATE="logs/merge-state.json"
readonly ITEM_NAMES=("" "未コミットの変更が無い" "作業中のチケットが無い" "レポート・計画書の対が揃っている" "draft 解除後の作業領域が空")

usage() {
  cat <<'USAGE'
使い方: bash .claude/skills/20-common-step-commit-push/scripts/push.sh
  push 前チェック（1 未コミットなし / 2 作業中チケットなし / 3 md と html の対 / 4 draft 解除後の wip が空）を全件実施してから push する。
  意図的に飛ばす項目は wip/push-check-skip.md に `- 項目 N: <理由>` と書いてコミットする（項目 4 は飛ばせない。読むのはコミット済みの版だけ）。
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

# スキップ記録を読む: SKIP[n]=1（項目 1〜3 のみ）。項目 4 の指定は SKIP4_REQUESTED=1 として無視する
# 記録はコミット済みの版（HEAD）だけを読む。作業ツリーにしか無い記録では飛ばせない（記録は必ず MR の差分に載る）
declare -A SKIP=()
SKIP4_REQUESTED=0
read_skip_file() {
  local line content
  content="$(git show "HEAD:$SKIP_FILE" 2>/dev/null || true)"
  [ -n "$content" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [[ "$line" =~ ^[-*][[:space:]]*(項目[[:space:]]*)?([1-4])[[:space:]]*[:：] ]]; then
      if [ "${BASH_REMATCH[2]}" = "4" ]; then SKIP4_REQUESTED=1; else SKIP["${BASH_REMATCH[2]}"]=1; fi
    fi
  done <<<"$content"
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      *) result_ng 007 "引数は受け付けない: $1（push.sh は現在ブランチを push する）" 2 ;;
    esac
  done
  command -v git >/dev/null 2>&1 || result_ng 007 "git が無い（環境の誤り）" 2
  cd "$LOGGER_ROOT" || result_ng 007 "リポジトリルートに移動できない（環境の誤り）: $LOGGER_ROOT" 2
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ -n "$branch" ] && [ "$branch" != "HEAD" ] || result_ng 007 "現在ブランチを特定できない（detached HEAD。環境の誤り）" 2
  log_info "start branch=$branch"

  read_skip_file
  local unmet=() skipped=() lines=() detail

  # 1. 未コミットの変更が無い
  if [ -n "${SKIP[1]:-}" ]; then
    skipped+=("1"); lines+=("skip 項目 1: ${ITEM_NAMES[1]}（$SKIP_FILE）")
  else
    detail="$(git status --porcelain | tr -d '\r' | sed '/^$/d')"
    if [ -n "$detail" ]; then
      unmet+=("項目 1: 未コミットの変更が $(printf '%s\n' "$detail" | wc -l | tr -d ' ') 件（$(printf '%s\n' "$detail" | head -5 | sed 's/^...//' | tr '\n' ' ')）→ commit.sh でコミットする")
      lines+=("✗ 項目 1: ${ITEM_NAMES[1]}")
    else
      lines+=("✓ 項目 1: ${ITEM_NAMES[1]}")
    fi
  fi

  # 2. 作業中のチケットが無い（宣言に remote-write:push があれば通す）
  if [ -n "${SKIP[2]:-}" ]; then
    skipped+=("2"); lines+=("skip 項目 2: ${ITEM_NAMES[2]}（$SKIP_FILE）")
  else
    local doing=() ticket ops
    shopt -s nullglob
    doing=("$DOING_DIR"/*.md)
    shopt -u nullglob
    if [ "${#doing[@]}" -eq 0 ]; then
      lines+=("✓ 項目 2: ${ITEM_NAMES[2]}")
    else
      ticket="${doing[0]}"
      ops="$(fm_list "$ticket" allow.ops 2>/dev/null || true)"
      if grep -qx -- "remote-write:push" <<<"$ops"; then
        lines+=("✓ 項目 2: 作業中チケット ${ticket##*/} は push を宣言済み（remote-write:push）")
      else
        unmet+=("項目 2: 作業中のチケットがある（${ticket##*/}）→ 完了してから push する（宣言 remote-write:push が無い）")
        lines+=("✗ 項目 2: ${ITEM_NAMES[2]}")
      fi
    fi
  fi

  # 3. レポート・計画書の対（付録 *-appendix-*.md は対象外）
  if [ -n "${SKIP[3]:-}" ]; then
    skipped+=("3"); lines+=("skip 項目 3: ${ITEM_NAMES[3]}（$SKIP_FILE）")
  else
    local missing=() f base dir
    shopt -s nullglob
    for f in wip/30_reports/*.md wip/20_plans/*.md; do
      case "$f" in *-appendix-*.md) continue ;; esac
      base="${f%.md}"
      [ -f "$base.html" ] || missing+=("${f##*/} に .html が無い")
    done
    for f in wip/30_reports/*.html wip/20_plans/*.html; do
      base="${f%.html}"
      [ -f "$base.md" ] || missing+=("${f##*/} に .md が無い")
    done
    shopt -u nullglob
    if [ "${#missing[@]}" -gt 0 ]; then
      unmet+=("項目 3: レポート・計画書の対が不揃い（${missing[*]}）→ report-view の手順で HTML を作り check-html.sh を通す")
      lines+=("✗ 項目 3: ${ITEM_NAMES[3]}")
    else
      lines+=("✓ 項目 3: ${ITEM_NAMES[3]}")
    fi
  fi

  # 4. draft 解除後の作業領域が空（スキップ不可）
  local ready=0 state leftovers
  if [ -f "$MERGE_STATE" ]; then
    command -v jq >/dev/null 2>&1 || result_ng 007 "jq が無い（$MERGE_STATE の判定に要る。環境の誤り）" 2
    state="$(jq -r '.state // empty' "$MERGE_STATE" 2>/dev/null | tr -d '\r' || true)"
    [ "$state" = "ready" ] && ready=1
  fi
  if [ "$ready" -eq 1 ]; then
    leftovers="$(find wip -type f ! -name .gitkeep 2>/dev/null | head -20 | tr '\n' ' ')"
    if [ -n "$leftovers" ]; then
      unmet+=("項目 4: draft 解除後（merge-state ready）なのに wip/ に成果物が残っている（${leftovers}）→ finalize.sh の片付けで消す。この項目はスキップできない")
      lines+=("✗ 項目 4: ${ITEM_NAMES[4]}")
    else
      lines+=("✓ 項目 4: ${ITEM_NAMES[4]}")
    fi
  else
    lines+=("✓ 項目 4: ${ITEM_NAMES[4]}（draft 解除前のため対象外）")
  fi
  [ "$SKIP4_REQUESTED" -eq 1 ] && lines+=("注意: $SKIP_FILE の項目 4 の指定は無効（安全性の項目のためスキップできない）")

  printf '%s\n' "${lines[@]}"
  if [ "${#unmet[@]}" -gt 0 ]; then
    printf '%s\n' "${unmet[@]}"
    result_ng 005 "push できない。未充足 ${#unmet[@]} 件（上に列挙）。意図的に飛ばすなら $SKIP_FILE に「- 項目 N: 理由」を書いてコミットする（項目 4 は不可）" 1
  fi

  # push（上流未設定なら --set-upstream。force はしない）
  local upstream="" count out
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  if [ -n "$upstream" ]; then
    count="$(git rev-list --count "$upstream..HEAD" 2>/dev/null || echo '?')"
    if ! out="$(git push 2>&1)"; then
      printf '%s\n' "$out"
      result_ng 006 "リモートに拒否された（$branch → $upstream）。force はしない。状況を報告する" 1
    fi
  else
    count="$(git rev-list --count HEAD 2>/dev/null || echo '?')"
    if ! out="$(git push --set-upstream origin "$branch" 2>&1)"; then
      printf '%s\n' "$out"
      result_ng 006 "リモートに拒否された（$branch の初回 push）。force はしない。状況を報告する" 1
    fi
  fi
  log_info "pushed branch=$branch count=$count skipped=${skipped[*]:-none}"
  result_ok "push した（${branch}、${count} コミット）。スキップ: $([ "${#skipped[@]}" -eq 0 ] && printf 'なし' || printf '項目 %s' "${skipped[*]}")"
}

main "$@"
