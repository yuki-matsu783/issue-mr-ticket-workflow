#!/usr/bin/env bash
# workflow-diff-check.sh — 操作のあとに作業中チケットの許可範囲外の差分を検知して復旧を促す
# 仕様: .claude/docs/10_spec/hooks/22-PostToolUse/workflow-diff-check.md（判定順・除外・WF60x）
# 登録: PostToolUse / matcher `Edit|Write|MultiEdit|NotebookEdit|Bash|PowerShell`
# 出力: additionalContext（WF601〜604）または無出力。`logs/sessions/<id>/approvals.json` への追記
#
# 案内側なので、判定できないときは黙って通す（拒否は workflow-guard の役目）。
# 許可範囲の判定規則は scope.sh に一本化し、このフックは独自の範囲を持たない。
set -euo pipefail

HOOK_DENY_ID="WF609"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__dc_dir="${BASH_SOURCE[0]%/*}"
case "$__dc_dir" in /*|[A-Za-z]:/*) ;; *) __dc_dir="$PWD/$__dc_dir" ;; esac
# shellcheck source=/dev/null
. "$__dc_dir/../lib/hook-common.sh"
# shellcheck source=/dev/null
. "$__dc_dir/../lib/cmdpos.sh"
# shellcheck source=/dev/null
. "$__dc_dir/../lib/scope.sh"

hook_init workflow-diff-check notify WF609

# 上限設定（scope-limits.json）も 1 回目の jq で読む
hook_read_input limits || hook_fail "入力を読めない"

__DC_US=$'\x1e'          # SC_TARGETS の区切り（フック共通仕様 §2 の副入力と同じバイト）
# 一覧の上限は subagent-stop-check（仕様に「20 を超えれば先頭 20 件 + 件数」と明記）に合わせる。
# 同じ性質の一覧で値を変える理由が無く、明記されている側が正
__DC_MAX_LIST=20

# ---- 制御方式 1: 抜ける条件 ----
hook_enforce_enabled || hook_disabled

hook_doing_ticket
__dc_name="$REPLY"
# 0 枚は通常の状態（チケット外の作業）。2 枚以上は判定不能（拒否は workflow-guard）
[[ -n "$__dc_name" ]] || exit 0
if (( HOOK_DOING_COUNT != 1 )); then
  log_debug "作業中チケットが $HOOK_DOING_COUNT 枚なので判定しない"
  exit 0
fi
__dc_rel="wip/10_tickets/10_doing/$__dc_name"
__dc_file="$HOOK_WORKTREE/$__dc_rel"

# チケットの宣言 → 上限設定 → 承認の記憶 の順に読む。どれかが欠けたら黙って抜ける
__dc_rc=0
scope_load_ticket "$__dc_file" || __dc_rc=$?
if (( __dc_rc != 0 )); then
  log_debug "チケットを読めないので判定しない: ${SC_ERROR:-}"
  exit 0
fi
__dc_rc=0
scope_load "$SC_TICKET_TYPE" || __dc_rc=$?
if (( __dc_rc != 0 )); then
  log_debug "上限設定を読めないので判定しない: ${SC_ERROR:-}"
  exit 0
fi
hook_read_state approvals || log_warn "承認の記憶を読めない（jq 不在）"
scope_load_approvals || log_warn "承認の記憶が壊れている（空として扱う）"

# ---- 出力の組み立て（制御方式 8: 複数の警告を 1 つの additionalContext にまとめる）----
__dc_ids=(); __dc_texts=(); __dc_targets_note=""

__dc_add_msg() { # $1=識別子 $2=本文
  __dc_ids+=("$1"); __dc_texts+=("$2")
}

__dc_emit() {
  local body="" i
  (( ${#__dc_ids[@]} > 0 )) || return 0
  body="${__dc_texts[0]}"
  for (( i = 1; i < ${#__dc_ids[@]}; i++ )); do
    body+=$'\n\n'"${__dc_ids[$i]}: ${__dc_texts[$i]}"
  done
  hook_notify PostToolUse "${__dc_ids[0]}" "$body" "$__dc_targets_note"
  return 0
}

# ---- 制御方式 2: 基準点なし ----
__dc_base=""
__dc_base="$(fm_get "$__dc_file" base_sha 2>/dev/null || true)"
__dc_base="${__dc_base//$'\r'/}"
__dc_base="${__dc_base//\"/}"
if [[ -z "$__dc_base" ]]; then
  __dc_add_msg WF604 "作業中チケット $__dc_name に base_sha（差分の基準点）が無いため、許可範囲外の差分の判定を行っていない。ticket.sh start で着手し直すことを検討する。"
  __dc_targets_note="$__dc_rel"
  __dc_emit
  exit 0
fi

# ---- 制御方式 3: 承認の記憶 ----
# 書き込み操作が PostToolUse に届いた = 人間が承認して実行された。未記載（WF202）だった範囲を
# セッション限りで覚え、以降の同じ範囲への操作と差分検知を通す
__dc_split_us() { # $1=US 区切りの文字列 → REPLY_LIST
  REPLY_LIST=()
  local s="${1:-}" x
  while [[ -n "$s" ]]; do
    if [[ "$s" == *"$__DC_US"* ]]; then x="${s%%"$__DC_US"*}"; s="${s#*"$__DC_US"}"; else x="$s"; s=""; fi
    [[ -n "$x" ]] && REPLY_LIST+=("$x")
  done
  return 0
}

__dc_op_targets=()
__dc_collect_targets() {
  local cls i
  cls="$(tool_class "$HOOK_TOOL" "$HOOK_SKILL")"
  case "$cls" in
    write)
      [[ -n "$HOOK_FILE_PATH" ]] && __dc_op_targets+=("$HOOK_FILE_PATH")
      ;;
    exec)
      [[ -n "$HOOK_COMMAND" ]] || return 0
      cmdpos_parse "$HOOK_COMMAND" "$([[ "$HOOK_TOOL" == PowerShell ]] && printf 'powershell' || printf 'bash')"
      # 縮退（bash 4.3 未満 / 長すぎる）では宛先を特定できない。承認は覚えない（範囲を広げないほうに倒す）
      (( ${CP_DEGRADED:-0} )) && return 0
      for (( i = 0; i < ${CP_COUNT:-0}; i++ )); do
        [[ "${CP_DATA[$i]:-0}" == 1 ]] && continue
        scope_classify "$i" >/dev/null
        [[ -n "$SC_TARGETS" ]] || continue
        __dc_split_us "$SC_TARGETS"
        __dc_op_targets+=("${REPLY_LIST[@]}")
      done
      ;;
  esac
  return 0
}
__dc_collect_targets

__dc_new_scopes=()
__dc_scope_known() { # $1=承認単位。既知（記憶済み or 今回の追加分）なら 0
  local s="$1" a
  for a in ${SC_APPROVED[@]+"${SC_APPROVED[@]}"}; do [[ "$a" == "$s" ]] && return 0; done
  for a in ${__dc_new_scopes[@]+"${__dc_new_scopes[@]}"}; do [[ "$a" == "$s" ]] && return 0; done
  return 1
}

# hook_rel_path はリポジトリの外のパスをそのまま返す（絶対パスのまま）。
# 許可範囲の判定はルート相対のパスにしか当たらないので、外のパスを承認単位にすると
# 意味のない記録が残るだけになる（実測で `C:/Users/.../Temp/outside` が入った）
__dc_in_repo() { # $1=hook_rel_path の結果。ルート相対なら 0
  local p="$1"
  [[ -n "$p" && "$p" != "." ]] || return 1
  case "$p" in
    /*|[A-Za-z]:/*) return 1 ;;      # 絶対パス = リポジトリの外
    ..|../*|*/../*) return 1 ;;      # 親をたどる形も外へ出得る
  esac
  return 0
}

for __dc_t in ${__dc_op_targets[@]+"${__dc_op_targets[@]}"}; do
  # 宛先が潰れている（cmdpos の `_`）ものは承認単位にできない
  [[ -n "$__dc_t" && "$__dc_t" != "_" ]] || continue
  hook_rel_path "$__dc_t" >/dev/null
  __dc_p="$REPLY"
  __dc_in_repo "$__dc_p" || continue
  scope_resolve "$__dc_p"
  # WF203（毎回確認）は記憶しない。WF202（未記載）だけを承認単位で覚える
  [[ "$SC_DECISION" == "ask" && "$SC_ID" == "WF202" ]] || continue
  [[ -n "$SC_ASK_SCOPE" && "$SC_ASK_SCOPE" != "." ]] || continue
  __dc_scope_known "$SC_ASK_SCOPE" && continue
  __dc_new_scopes+=("$SC_ASK_SCOPE")
done

if (( ${#__dc_new_scopes[@]} > 0 )); then
  if command -v jq >/dev/null 2>&1; then
    hook_session_dir
    __dc_appr="$REPLY/approvals.json"
    __dc_cur="[]"
    if [[ -f "$__dc_appr" ]]; then
      __dc_cur="$(jq -c 'if type == "array" then . else [] end' "$__dc_appr" 2>/dev/null || printf '[]')"
      [[ -n "$__dc_cur" ]] || __dc_cur="[]"
    fi
    printf -v __dc_now '%(%Y-%m-%dT%H:%M:%S%z)T' -1
    # ロックは取らない。ホットパス（フック共通仕様 §1）で hc_lock は使えないため、
    # hc_json_write の一時ファイル + mv による原子的な置き換えだけで守る
    __dc_next="$(printf '%s' "$__dc_cur" | jq -c --arg t "$__dc_name" --arg at "$__dc_now" \
      'reduce $ARGS.positional[] as $s (.; if any(.[]; .scope == $s) then . else . + [{scope: $s, ticket: $t, at: $at}] end)' \
      --args "${__dc_new_scopes[@]}" 2>/dev/null || printf '')"
    if [[ -n "$__dc_next" ]]; then
      hc_json_write "$__dc_appr" "$__dc_next" || log_warn "approvals.json を書けない"
      log_info "承認を記憶した count=${#__dc_new_scopes[@]}"
    else
      log_warn "approvals.json を組み立てられない"
    fi
  else
    log_warn "jq が無いので承認を記憶できない"
  fi
  # 今回承認された範囲は、この後の差分検知でも許可扱いにする（判定順 (6)）
  SC_APPROVED+=("${__dc_new_scopes[@]}")
fi

# ---- 制御方式 7: git が使えなければ黙って抜ける ----
command -v git >/dev/null 2>&1 || exit 0
git -C "$HOOK_WORKTREE" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# ---- 制御方式 4: 差分の検知 ----
declare -A __dc_kind=()
__dc_paths=()

__dc_after() { # $1=飛ばす語数 $2=レコード → REPLY（残り = パス）
  local n="$1" s="$2" i
  for (( i = 0; i < n; i++ )); do s="${s#* }"; done
  REPLY="$s"
  return 0
}

__dc_excluded() { # 機構自身の記録と作業領域は違反にしない
  case "$1" in
    logs|logs/*) return 0 ;;
    wip/00_overall_plan/*) return 0 ;;
    wip/tmp/*) return 0 ;;
  esac
  return 1
}

__dc_add_path() { # $1=ルート相対パス $2=種別
  local p="${1//\\//}"
  [[ -n "$p" ]] || return 0
  __dc_excluded "$p" && return 0
  [[ -n "${__dc_kind[$p]:-}" ]] && return 0
  __dc_kind[$p]="$2"
  __dc_paths+=("$p")
  return 0
}

# git status --porcelain=v2 -z（1 回）。レコードの語数は porcelain v2 の定義どおり。
# -uall を付けるのは、既定では未追跡がディレクトリ単位（`wip/`）に畳まれ、中身のパスで
# 許可範囲を判定できないため。畳まれた `wip/` は未記載として WF601 に化ける（実測で確認）
while IFS= read -r -d '' __dc_rec; do
  case "$__dc_rec" in
    '1 '*) __dc_after 8 "$__dc_rec";  __dc_add_path "$REPLY" 変更 ;;
    '2 '*) __dc_after 9 "$__dc_rec";  __dc_add_path "$REPLY" 移動先
           IFS= read -r -d '' __dc_orig_path || true ;;   # 移動元は次のフィールド。判定は移動先で行う
    'u '*) __dc_after 10 "$__dc_rec"; __dc_add_path "$REPLY" 変更 ;;
    '? '*) __dc_after 1 "$__dc_rec";  __dc_add_path "$REPLY" 未追跡 ;;
  esac
done < <(git -C "$HOOK_WORKTREE" status --porcelain=v2 -z -uall 2>/dev/null || true)

# 基準点が解決できないなら差分の取得に失敗したのと同じ（制御方式 7）。黙って抜ける。
# 続けると WF601 に「基準点は <解決できない値>」と書き、復旧指示の
# `git checkout <base> -- <path>` も動かない案内を出すことになる（実測で PLACEHOLDER がそのまま出た）
if ! git -C "$HOOK_WORKTREE" rev-parse --verify --quiet "$__dc_base^{commit}" >/dev/null 2>&1; then
  log_warn "基準点 $__dc_base を解決できないので差分を判定しない"
  exit 0
fi

# 基準点以降のコミット済みの差分
while IFS= read -r -d '' __dc_st; do
  IFS= read -r -d '' __dc_p1 || break
  case "$__dc_st" in
    R*|C*) IFS= read -r -d '' __dc_p2 || break
           __dc_add_path "$__dc_p2" 移動先 ;;
    *)     __dc_add_path "$__dc_p1" 変更 ;;
  esac
done < <(git -C "$HOOK_WORKTREE" diff --name-status -z "$__dc_base" 2>/dev/null || true)

__dc_bad=(); __dc_over=0
for __dc_p in ${__dc_paths[@]+"${__dc_paths[@]}"}; do
  scope_resolve "$__dc_p"
  case "$SC_DECISION" in
    deny|ask) ;;
    *) continue ;;
  esac
  if (( ${#__dc_bad[@]} >= __DC_MAX_LIST )); then __dc_over=$(( __dc_over + 1 )); continue; fi
  __dc_bad+=("- $__dc_p（${__dc_kind[$__dc_p]} / ${SC_ID:-WF202}）")
done

if (( ${#__dc_bad[@]} > 0 )); then
  __dc_body="作業中チケット $__dc_name（種類: $SC_TICKET_TYPE）の許可範囲外に差分がある。基準点は $__dc_base。"$'\n'
  __dc_body+="$(printf '%s\n' "${__dc_bad[@]}")"
  (( __dc_over > 0 )) && __dc_body+=$'\n'"- （他 $__dc_over 件）"
  __dc_body+=$'\n'"復旧: 追跡済みの変更は git checkout $__dc_base -- <path>、未追跡のファイルは削除して許可範囲内へ戻す。"
  __dc_body+="範囲を広げる必要があるなら、未着手チケットの見直しをユーザーに提案する（迂回しない）。巻き戻しはこのフックが行わないので AI が実施すること。"
  __dc_add_msg WF601 "$__dc_body"
  __dc_targets_note="${__dc_paths[0]}"
fi

# ---- 制御方式 5: 先行チケットの未完了 ----
__dc_pending=()
while IFS= read -r __dc_pre; do
  __dc_pre="${__dc_pre//$'\r'/}"
  [[ -n "$__dc_pre" ]] || continue
  __dc_ng=0
  shopt -q nullglob && __dc_ng=1
  shopt -s nullglob
  __dc_hits=("$HOOK_WORKTREE"/wip/10_tickets/20_done/"$__dc_pre"*.md)
  (( __dc_ng )) || shopt -u nullglob
  (( ${#__dc_hits[@]} > 0 )) || __dc_pending+=("$__dc_pre")
done < <(fm_list "$__dc_file" predecessors 2>/dev/null || true)

if (( ${#__dc_pending[@]} > 0 )); then
  __dc_add_msg WF602 "先行チケットが 20_done/ に無い: ${__dc_pending[*]}。先に完了させるか、全体計画を見直すこと。"
  [[ -n "$__dc_targets_note" ]] || __dc_targets_note="$__dc_rel"
fi

# ---- 制御方式 6: 種類の改変 ----
# 基準点にチケットが無い（未追跡のまま持ち越された全体計画チケット。DDR i0004-04）ときは検査しない
__dc_orig=""
if __dc_orig="$(git -C "$HOOK_WORKTREE" show "$__dc_base:$__dc_rel" 2>/dev/null)"; then
  __dc_fmc=0; __dc_was=""
  while IFS= read -r __dc_line; do
    __dc_line="${__dc_line//$'\r'/}"
    if [[ "$__dc_line" == "---" ]]; then
      __dc_fmc=$(( __dc_fmc + 1 ))
      (( __dc_fmc >= 2 )) && break
      continue
    fi
    if [[ "$__dc_line" == ticket_type:* ]]; then
      __dc_was="${__dc_line#ticket_type:}"
      __dc_was="${__dc_was#"${__dc_was%%[![:space:]]*}"}"
      __dc_was="${__dc_was%"${__dc_was##*[![:space:]]}"}"
      __dc_was="${__dc_was%\"}"; __dc_was="${__dc_was#\"}"
      __dc_was="${__dc_was%\'}"; __dc_was="${__dc_was#\'}"
      break
    fi
  done <<< "$__dc_orig"
  if [[ -n "$__dc_was" && "$__dc_was" != "$SC_TICKET_TYPE" ]]; then
    __dc_add_msg WF603 "チケットの種類が基準点から書き換えられている（元: $__dc_was / 現在: $SC_TICKET_TYPE）。許可範囲が変わるので元に戻すこと。"
    [[ -n "$__dc_targets_note" ]] || __dc_targets_note="$__dc_rel"
  fi
fi

__dc_emit
exit 0
