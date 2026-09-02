#!/usr/bin/env bash
# post-push-compact-prompt.sh — push の成功を検知して参照リンクを供給し、/compact を促す
# 仕様: .claude/docs/10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md（push 検知の正・識別子）
# 登録: PostToolUse / matcher `Bash|PowerShell`
# 出力: additionalContext（WF901 / WF902 / WF903）または無出力
set -euo pipefail

HOOK_DENY_ID="WF909"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__cp_dir="${BASH_SOURCE[0]%/*}"
case "$__cp_dir" in /*|[A-Za-z]:/*) ;; *) __cp_dir="$PWD/$__cp_dir" ;; esac
# shellcheck source=/dev/null
. "$__cp_dir/../lib/hook-common.sh"
# shellcheck source=/dev/null
. "$__cp_dir/../lib/cmdpos.sh"
# shellcheck source=/dev/null
. "$__cp_dir/../lib/push-detect.sh"

hook_init post-push-compact-prompt notify WF909

hook_read_input || hook_fail "入力を読めない"

# 制御方式 1: 停止中
hook_enforce_enabled || hook_disabled

# 前置判定（fork ゼロ）。push でなければ cmdpos も git も起動しない
[[ "${HOOK_COMMAND,,}" == *push* ]] || exit 0

__CP_STATE="$HOOK_WORKTREE/logs/push-state.json"

# 起点 sha は自分の状態から渡す。push_detect は状態ファイルを読まない（DDR i0009-24）
__cp_prev_of_branch() { # $1=ブランチ → REPLY（無ければ空）、__CP_PREV_COUNT
  REPLY=""; __CP_PREV_COUNT=0
  [[ -f "$__CP_STATE" ]] && command -v jq >/dev/null 2>&1 || return 0
  local -a pc=()
  mapfile -t pc < <(jq -r --arg b "$1" '(.[$b].sha // ""), ((.[$b].count // 0) | tostring)' "$__CP_STATE" 2>/dev/null | tr -d '\r' || true)
  REPLY="${pc[0]:-}"; __CP_PREV_COUNT="${pc[1]:-0}"
  [[ "$__CP_PREV_COUNT" =~ ^[0-9]+$ ]] || __CP_PREV_COUNT=0
  return 0
}

__cp_branch="$(git -C "$HOOK_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
__cp_branch="${__cp_branch//$'\r'/}"
__cp_prev_of_branch "$__cp_branch"
__cp_prev="$REPLY"

# 制御方式 2: push 検知。tool_response は渡さない —
# 仕様は「PostToolUse に届いた時点で成功とみなす」で、tool_response に終了コードのフィールドは
# 存在しない（DDR i0009-07）。push_detect 側に残る終了コードの検査は 0032 へ送る
if ! push_detect "$HOOK_COMMAND" "$__cp_prev" "" \
     "$([[ "$HOOK_TOOL" == PowerShell ]] && printf 'powershell' || printf 'bash')" "$HOOK_WORKTREE"; then
  log_debug "push ではない（$PD_REASON）"
  exit 0
fi

# 制御方式 3: ホスト判定と URL の正規化（リモートへは問い合わせない）
__cp_repo_url=""; __cp_host=""
__cp_origin="$(git -C "$HOOK_WORKTREE" remote get-url origin 2>/dev/null || true)"
__cp_origin="${__cp_origin//$'\r'/}"
if [[ -n "$__cp_origin" ]]; then
  __cp_url="$__cp_origin"
  # git@host:owner/repo.git → https://host/owner/repo
  if [[ "$__cp_url" =~ ^[A-Za-z0-9._-]+@([^:]+):(.+)$ ]]; then
    __cp_url="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
  __cp_url="${__cp_url%.git}"
  __cp_url="${__cp_url%/}"
  case "${__cp_url,,}" in
    *github.com*) __cp_host="github" ;;
    *gitlab*)     __cp_host="gitlab" ;;
    *)            __cp_host="" ;;
  esac
  [[ -n "$__cp_host" ]] && __cp_repo_url="$__cp_url"
fi

# default ブランチ（無ければ main）
__cp_default="$(git -C "$HOOK_WORKTREE" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
__cp_default="${__cp_default//$'\r'/}"; __cp_default="${__cp_default#origin/}"
[[ -n "$__cp_default" ]] || __cp_default="main"

# MR の記録（無ければ MR 依存のリンクを省く）
__cp_mr=""
if [[ -f "$HOOK_WORKTREE/logs/mr.json" ]] && command -v jq >/dev/null 2>&1; then
  # 正のキーは mr（00-workflow-issue-mr-driven 仕様の logs/mr.json）。number / iid は別実装からの受け皿
  __cp_mr="$(jq -r '(.mr // .number // .iid // empty) | tostring' "$HOOK_WORKTREE/logs/mr.json" 2>/dev/null | tr -d '\r' || true)"
  [[ "$__cp_mr" =~ ^[0-9]+$ ]] || __cp_mr=""
fi

# 制御方式 4: リンクの組み立て
__CP_MAX_FILES=15
__cp_lines=()
__cp_notes=()

if [[ -z "$__cp_repo_url" ]]; then
  __cp_notes+=("WF903: origin が GitHub / GitLab ではない（または取得できない）ためリンクを供給しない")
else
  if [[ -n "$__cp_mr" ]]; then
    case "$__cp_host" in
      github) __cp_lines+=("- MR: $__cp_repo_url/pull/$__cp_mr") ;;
      gitlab) __cp_lines+=("- MR: $__cp_repo_url/-/merge_requests/$__cp_mr") ;;
    esac
  else
    __cp_notes+=("WF903: MR が未記録（logs/mr.json 無し）のため MR に依存するリンクを省いた")
  fi
  case "$__cp_host" in
    github) __cp_lines+=("- default との差分: $__cp_repo_url/compare/$__cp_default...$PD_BRANCH") ;;
    gitlab) __cp_lines+=("- default との差分: $__cp_repo_url/-/compare/$__cp_default...$PD_BRANCH") ;;
  esac
  if [[ -n "$PD_PREV_SHA" ]]; then
    case "$__cp_host" in
      github) __cp_lines+=("- 前回 push からの差分: $__cp_repo_url/compare/$PD_PREV_SHA...$PD_HEAD") ;;
      gitlab) __cp_lines+=("- 前回 push からの差分: $__cp_repo_url/-/compare/$PD_PREV_SHA...$PD_HEAD") ;;
    esac
    if [[ -n "$__cp_mr" ]]; then
      case "$__cp_host" in
        github) __cp_lines+=("- MR のコメント一覧: $__cp_repo_url/pull/$__cp_mr") ;;
        gitlab) __cp_lines+=("- MR のコメント一覧: $__cp_repo_url/-/merge_requests/$__cp_mr#notes") ;;
      esac
    fi
  else
    __cp_notes+=("WF902: 前回 push の記録が無いので初回として扱った（前回 push からの差分とコメント一覧を省いた）")
  fi

  # 変更ファイル（上限 15 件。超過分は件数だけ）
  __cp_range="$__cp_default..$PD_HEAD"
  [[ -n "$PD_PREV_SHA" ]] && __cp_range="$PD_PREV_SHA..$PD_HEAD"
  __cp_files=()
  mapfile -t __cp_files < <(git -C "$HOOK_WORKTREE" diff --name-only "$__cp_range" 2>/dev/null | tr -d '\r' || true)
  if (( ${#__cp_files[@]} > 0 )); then
    __cp_lines+=("- 変更ファイル（${#__cp_files[@]} 件）:")
    __cp_i=0
    for __cp_f in "${__cp_files[@]}"; do
      [[ -n "$__cp_f" ]] || continue
      (( __cp_i >= __CP_MAX_FILES )) && break
      case "$__cp_host" in
        github) __cp_lines+=("  - $__cp_f: $__cp_repo_url/blob/$PD_HEAD/$__cp_f") ;;
        gitlab) __cp_lines+=("  - $__cp_f: $__cp_repo_url/-/blob/$PD_HEAD/$__cp_f") ;;
      esac
      __cp_i=$(( __cp_i + 1 ))
    done
    if (( ${#__cp_files[@]} > __CP_MAX_FILES )); then
      __cp_lines+=("  - （残り $(( ${#__cp_files[@]} - __CP_MAX_FILES )) 件は省略）")
    fi
  fi
fi

# 制御方式 5: push-state.json[b] を更新（このフック専用の状態。usage-report は読まない）
__cp_now=""
printf -v __cp_now '%(%Y-%m-%dT%H:%M:%S%z)T' -1
if command -v jq >/dev/null 2>&1; then
  # 既存の状態はファイルから直に読む。--slurpfile にプロセス置換（/dev/fd/63）を渡すと
  # Windows の jq が開けず、状態が 1 度も書かれないまま黙って終わる（実測で確認）
  __cp_cur="{}"
  if [[ -f "$__CP_STATE" ]]; then
    __cp_cur="$(jq -c 'if type == "object" then . else {} end' "$__CP_STATE" 2>/dev/null || printf '{}')"
    [[ -n "$__cp_cur" ]] || __cp_cur="{}"
  fi
  __cp_new="$(printf '%s' "$__cp_cur" | jq -c --arg b "$PD_BRANCH" --arg sha "$PD_HEAD" --arg at "$__cp_now" \
      --argjson c "$(( __CP_PREV_COUNT + 1 ))" \
      '.[$b] = {sha: $sha, at: $at, count: $c}' 2>/dev/null || true)"
  if [[ -n "$__cp_new" ]]; then
    hc_json_write "$__CP_STATE" "$__cp_new" || log_warn "push-state.json を更新できない"
  fi
fi

# 制御方式 6・7: 取得できた分だけ伝える。何も取れなければ無出力
if (( ${#__cp_lines[@]} == 0 && ${#__cp_notes[@]} == 0 )); then
  log_info "リンクを 1 件も組み立てられなかったので何も出さない"
  exit 0
fi

__cp_msg="push を検知した（ブランチ $PD_BRANCH / このブランチで $(( __CP_PREV_COUNT + 1 )) 回目）。参照リンク:"
for __cp_l in ${__cp_lines[@]+"${__cp_lines[@]}"}; do __cp_msg+=$'\n'"$__cp_l"; done
for __cp_l in ${__cp_notes[@]+"${__cp_notes[@]}"}; do __cp_msg+=$'\n'"- $__cp_l"; done
__cp_msg+=$'\n'"- レビュー依頼メッセージ（boundary.sh request の本文）にこれらのリンクを含めること"
__cp_msg+=$'\n'"- タスクの切れ目の処理（MR 本文更新・レビュー依頼）を終えたら、ユーザーに /compact の実行を促すこと。AskUserQuestion で待たない"

hook_notify PostToolUse WF901 "$__cp_msg" "$PD_BRANCH@$PD_HEAD"
exit 0
