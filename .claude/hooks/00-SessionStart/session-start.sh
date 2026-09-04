#!/usr/bin/env bash
# session-start.sh — セッションの開始・再開・クリア・compact のたびに現在地を注入する
# 仕様: .claude/docs/10_spec/hooks/00-SessionStart/session-start.md（注入の形式・識別子の正）
# 登録: SessionStart（matcher 無し。source は startup / resume / clear / compact のすべて）
# 出力: stdout の注入テキスト（WF701〜704）または無出力
#
# 現在地の判定そのものは `boundary.sh status --offline` に委ねる（独自の判定を持たない）。
# `boundary.sh` が不在・失敗のときは仕様の制御方式 3 のとおり「何も出さずに終了 0」に落ちる。
# 案内が消えるだけで作業は止まらない（偽の判定を置かない）。
set -euo pipefail

# 案内側なので判定不能でも通す。読み込み行の deny ポリシーは使わない
HOOK_DENY_ID="WF709"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__se_dir="${BASH_SOURCE[0]%/*}"
case "$__se_dir" in /*|[A-Za-z]:/*) ;; *) __se_dir="$PWD/$__se_dir" ;; esac
# shellcheck source=/dev/null
. "$__se_dir/../lib/hook-common.sh"

hook_init session-start notify WF709

# 入力（jq 1 回）。読めなくても案内側なので通す
hook_read_input || hook_fail "入力を読めない"


# 制御方式 1: 停止中は 1 行だけ出して記録する（現在地は出さない）
if ! hook_enforce_enabled; then
  printf '%s\n' "[WF701] 機構は停止中（WORKFLOW_ENFORCE=0 / WORKFLOW_SESSION_START_ENFORCE=0）"
  hook_disabled
fi

# 呼出条件: サブエージェントのセッションには注入しない。
# 判別できなければ出す（メインで欠けるほうが副作用が大きい）
if [[ -n "${HOOK_AGENT_ID:-}" || -n "${CLAUDE_AGENT_ID:-}" ]]; then
  hook_record skip "" "" "サブエージェントの開始（agent_id あり）"
  exit 0
fi

# 制御方式 2: logs/sessions/ の古いディレクトリを片付ける（失敗は無視）。
# frontmatter 索引の機構は未導入なので何もしない
__se_prune_sessions() {
  local base="$HOOK_WORKTREE/logs/sessions" d
  [[ -d "$base" ]] || return 0
  local ng=0
  shopt -q nullglob && ng=1
  shopt -s nullglob
  for d in "$base"/*/; do
    # 7 日 = 10080 分。find の -mmin なら stat の移植性に悩まなくて済む（hc_lock と同じ方針）
    if [[ -n "$(find "$d" -maxdepth 0 -mmin +10080 2>/dev/null)" ]]; then rm -rf "$d" 2>/dev/null || true; fi
  done
  (( ng )) || shopt -u nullglob
  return 0
}
__se_prune_sessions || true

# 制御方式 10: 進行状態ファイルの破損は boundary.sh を呼ぶ前に見る。
# boundary.sh status は壊れた記録を実態から再導出して**書き戻す**ので、呼んだ後では破損が見えない
__se_broken=()
if command -v jq >/dev/null 2>&1; then
  for __se_sf in mr.json review-state.json merge-state.json; do
    if [[ -f "$HOOK_WORKTREE/logs/$__se_sf" ]] && ! jq -e . "$HOOK_WORKTREE/logs/$__se_sf" >/dev/null 2>&1; then
      __se_broken+=("logs/$__se_sf")
    fi
  done
fi

# 制御方式 3: boundary.sh status --offline に判定を委ねる。
# 不在・失敗（jq / git 不在を含む）は何も出さずに終了 0
__se_boundary="$HOOK_WORKTREE/.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh"
if [[ ! -f "$__se_boundary" ]]; then
  log_info "boundary.sh が無いので現在地を導出しない（3/3 で実装）"
  hook_record skip "" "" "boundary.sh 不在（3/3 で実装）"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  log_info "jq が無いので現在地を導出しない"
  hook_record skip "" "" "jq 不在"
  exit 0
fi

__se_status=""
if ! __se_status="$(bash "$__se_boundary" status --offline 2>/dev/null)" || [[ -z "$__se_status" ]]; then
  log_info "boundary.sh status --offline が失敗したので何も出さない"
  hook_record skip "" "" "boundary.sh status --offline が失敗"
  exit 0
fi

# 制御方式 4〜11: 注入テキストの組み立て。判定は上の JSON がすべてで、ここでは整形だけを行う
# 空の値が潰れないよう 1 行 1 値で受ける（IFS 区切りの read は空フィールドを畳む）
__se_f=()
mapfile -t __se_f < <(printf '%s' "$__se_status" | jq -r '[
  (.mr // "" | tostring), (.host // ""), (.position // "none"),
  (.current // ""), (.next // ""), (.type // ""), (.skill // ""),
  (.last_task.task_type // ""), (.last_task.last_done // ""),
  ((.last_task.tickets // []) | join(" ")),
  (.review.state // "none"), (.review.requested_at // ""), (.review.via // "")
  ] | .[]' 2>/dev/null | tr -d '\r')
if [[ "${#__se_f[@]}" -lt 13 ]]; then
  log_warn "boundary.sh status の JSON を読めない"
  hook_record skip "" "" "status の JSON を読めない"
  exit 0
fi
__se_mr="${__se_f[0]}"; __se_host="${__se_f[1]}"; __se_pos="${__se_f[2]}"
__se_cur="${__se_f[3]}"; __se_next="${__se_f[4]}"; __se_next_type="${__se_f[5]}"; __se_skill="${__se_f[6]}"
__se_task_type="${__se_f[7]}"; __se_last_done="${__se_f[8]}"; __se_task_tickets="${__se_f[9]}"
__se_rstate="${__se_f[10]}"; __se_req_at="${__se_f[11]}"; __se_via="${__se_f[12]}"

__se_branch="$(git -C "$HOOK_WORKTREE" branch --show-current 2>/dev/null || true)"
__se_issue=""; __se_url=""
if [[ -f "$HOOK_WORKTREE/logs/mr.json" ]] && jq -e . "$HOOK_WORKTREE/logs/mr.json" >/dev/null 2>&1; then
  __se_issue="$(jq -r '.issue // "" | tostring' "$HOOK_WORKTREE/logs/mr.json" 2>/dev/null | tr -d '\r')"
  __se_url="$(jq -r '.url // ""' "$HOOK_WORKTREE/logs/mr.json" 2>/dev/null | tr -d '\r')"
fi
__se_merge=""; __se_merge_broken=0
if [[ -f "$HOOK_WORKTREE/logs/merge-state.json" ]]; then
  if jq -e . "$HOOK_WORKTREE/logs/merge-state.json" >/dev/null 2>&1; then
    __se_merge="$(jq -r '.state // ""' "$HOOK_WORKTREE/logs/merge-state.json" 2>/dev/null | tr -d '\r')"
  else
    __se_merge_broken=1
  fi
fi

# チケットは「番号-種類」で示す（status は番号だけを返す）
__se_name() { # $1=番号 $2=種類
  if [[ -z "$1" ]]; then printf '無し'; return 0; fi
  if [[ -z "$2" ]]; then printf '%s' "$1"; return 0; fi
  printf '%s-%s' "$1" "$2"
}
__se_range() { # 完了したタスクの範囲（先頭-末尾）
  local first last
  last="${__se_task_tickets%% *}"; first="${__se_task_tickets##* }"
  if [[ -z "$__se_task_tickets" ]]; then printf '無し'; return 0; fi
  if [[ "$first" == "$last" ]]; then printf '%s' "$first"; else printf '%s-%s' "$first" "$last"; fi
}
__se_has_skill() { [[ -n "$1" ]] && [[ -f "$HOOK_WORKTREE/.claude/skills/$1/SKILL.md" ]]; }

__se_has_ticket=0
[[ -n "$__se_cur" || -n "$__se_next" || -n "$__se_last_done" ]] && __se_has_ticket=1
__se_lines=()

# 制御方式 5: チケットも MR も無い（default ブランチでも同じ）
if [[ "$__se_has_ticket" -eq 0 && ( -z "$__se_mr" || "$__se_mr" == "null" ) ]]; then
  __se_lines+=("- 進行中の作業は無い。依頼ごとに \`CLAUDE.md\`「作業の振り分け」に従う")
else
  # ブランチと issue
  if [[ -n "$__se_issue" ]]; then
    __se_lines+=("- ブランチ: ${__se_branch:-不明}（issue #$__se_issue）")
  else
    __se_lines+=("- ブランチ: ${__se_branch:-不明}")
  fi

  # MR。制御方式 9（単独実行モード）と 8（WF703）をここで分ける
  __se_mark="#"; [[ "$__se_host" == "gitlab" ]] && __se_mark="!"
  if [[ -n "$__se_mr" && "$__se_mr" != "null" ]]; then
    __se_lines+=("- MR: ${__se_mark}${__se_mr} ${__se_url:-（URL 未記録）}（記録: logs/mr.json）")
  elif [[ "$__se_via" == "chat" ]]; then
    __se_lines+=("- MR: 無し（単独実行モード）")
  elif [[ "$__se_branch" =~ ^(feature|fix)-[0-9]+- ]]; then
    __se_lines+=("- MR: [WF703] 記録が無い。\`20-common-step-feature-mr\` の手順で既存 MR を紐づけ直す（\`boundary.sh status\` が CLI で再導出する）")
  else
    __se_lines+=("- MR: 無し")
  fi

  # チケット
  if [[ "$__se_has_ticket" -eq 1 ]]; then
    __se_lines+=("- チケット: 未着手の先頭 $(__se_name "$__se_next" "$__se_next_type") / 作業中 $(__se_name "$__se_cur" "$__se_next_type") / 完了の最後 $(__se_name "$__se_last_done" "$__se_task_type")")
  else
    __se_lines+=("- チケット: 無し")
  fi

  # 制御方式 7: チケットはあるが MR が無い（issue 確定前）。現在地と次のスキルを揃える
  __se_planning=0
  if [[ "$__se_has_ticket" -eq 1 && ( -z "$__se_mr" || "$__se_mr" == "null" ) && "$__se_via" != "chat" ]]; then __se_planning=1; fi

  # 現在地（制御方式 4 の対応表）。破損は WF702 をこの行に書き、残りの行は出す
  __se_here=""
  if [[ "$__se_planning" -eq 1 ]]; then __se_pos_label="planning"; else __se_pos_label="$__se_pos"; fi
  case "$__se_pos_label" in
    planning)       __se_here="全体計画の途中（issue 確定前）" ;;
    in_task)        __se_here="タスクの途中（$(__se_name "$__se_cur" "$__se_next_type")）" ;;
    before_request) __se_here="レビュー依頼前（${__se_task_type:-種類不明} $(__se_range)）" ;;
    requested)      __se_here="レビュー待ち（${__se_task_type:-種類不明} $(__se_range) を ${__se_req_at:-時刻不明} に依頼。レビュー結果は boundary.sh complete で取得する）" ;;
    completed)      __se_here="レビュー済み（指摘の扱いから再開）" ;;
    merge_prep)     __se_here="マージ前作業中（merge-state: ${__se_merge:-不明}。\`finalize.sh release\` を再実行）" ;;
    *)              __se_here="進行中の作業は無い" ;;
  esac
  if [[ "${#__se_broken[@]}" -gt 0 ]]; then
    __se_here="[WF702] 破損: ${__se_broken[*]}（提供コマンドの再導出に任せる。手で直さない）／ $__se_here"
  fi
  __se_lines+=("- 現在地: $__se_here")

  # 次に読み込むスキル
  __se_note=""
  case "$__se_pos" in
    requested) __se_note="（レビュー完了の連絡があるまで応答を終える）" ;;
    merge_prep) __se_note="（\`finalize.sh release\` の再実行から）" ;;
  esac
  if [[ "$__se_planning" -eq 1 ]]; then
    __se_lines+=("- 次に読み込むスキル: 10-task-overall-plan（全体計画の途中）")
  elif [[ -n "$__se_cur" || -n "$__se_next" ]]; then
    if [[ -n "$__se_skill" ]] && ! __se_has_skill "$__se_skill"; then
      __se_lines+=("- 次に読み込むスキル: 00-workflow-issue-mr-driven$__se_note ／ [WF704] $__se_skill に対応するスキルが無い")
    elif [[ -n "$__se_skill" ]]; then
      __se_lines+=("- 次に読み込むスキル: 00-workflow-issue-mr-driven$__se_note ／ タスクは $__se_skill")
    else
      __se_lines+=("- 次に読み込むスキル: 00-workflow-issue-mr-driven$__se_note")
    fi
  else
    __se_lines+=("- 次に読み込むスキル: 00-workflow-issue-mr-driven$__se_note")
  fi

  # マージ前作業
  if [[ "$__se_merge_broken" -eq 1 ]]; then
    __se_lines+=("- マージ前作業: [WF702] 破損: logs/merge-state.json")
  elif [[ -n "$__se_merge" ]]; then
    if [[ "$__se_merge" == "ready" ]]; then
      __se_lines+=("- マージ前作業: $__se_merge（draft 解除済み。マージは人間が行う）")
    else
      __se_lines+=("- マージ前作業: $__se_merge（draft 未解除。\`finalize.sh release\` を再実行する）")
    fi
  else
    __se_lines+=("- マージ前作業: 無し")
  fi
fi

__se_out="$(printf '[WF701] 現在地（機構が導出）\n'; printf '%s\n' "${__se_lines[@]}")"
# 制御方式 11: 8 KB を超えたら切り詰めずに警告行を先頭に足す
__se_bytes="$(printf '%s' "$__se_out" | wc -c | tr -d ' ')"
if [[ "$__se_bytes" -gt 8192 ]]; then
  __se_out="$(printf '[警告] 注入が 8 KB を超過（%s バイト）\n%s' "$__se_bytes" "$__se_out")"
fi
printf '%s\n' "$__se_out"
hook_record inject "WF701" "${__se_branch:-}" "mr=${__se_mr:-none} position=$__se_pos bytes=$__se_bytes"
exit 0
