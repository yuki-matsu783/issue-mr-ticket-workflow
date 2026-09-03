#!/usr/bin/env bash
# workflow-state-guard.sh — 進行状態ファイル・チケットの置き場・draft 解除への直接操作を拒否する
# 仕様: .claude/docs/10_spec/hooks/20-PreToolUse/workflow-state-guard.md（保護対象・判定・WF30x）
# 登録: PreToolUse / matcher 書き込み・実行・`mcp__.*`
# 出力: deny（WF301〜304 / WF309）または許可（無出力）
#
# workflow-guard と独立に常時働く。遷移の前提条件は判定しない（提供コマンドの責務）。
# 設定（scope-limits.json）が壊れていても**拒否に倒さない** — 倒すと WF210 の復旧経路が潰れて
# 設定 1 ファイルの破損が完全なロックアウトになる（DDR i0009-29）。
set -euo pipefail

HOOK_DENY_ID="WF309"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__sg_dir="${BASH_SOURCE[0]%/*}"
case "$__sg_dir" in /*|[A-Za-z]:/*) ;; *) __sg_dir="$PWD/$__sg_dir" ;; esac
# shellcheck source=/dev/null
. "$__sg_dir/../lib/hook-common.sh"
# shellcheck source=/dev/null
. "$__sg_dir/../lib/cmdpos.sh"
# shellcheck source=/dev/null
. "$__sg_dir/../lib/scope.sh"

hook_init workflow-state-guard deny WF309
hook_fail_closed

# 制御方式 1: 停止中なら何もしない（§4）。制御方式 0 より先に評価する（§3）
hook_enforce_enabled || hook_disabled

# 入力（jq 1 回。副入力として scope-limits.json を読む）
hook_read_input limits || hook_fail "入力を読めない"

__SG_DOING="wip/10_tickets/10_doing"
__SG_DONE="wip/10_tickets/20_done"

__SG_HOWTO_STATE="進行状態は提供コマンドでのみ遷移する（bash .claude/hooks/boundary.sh … / bash .claude/hooks/finalize.sh …）。前提が満たせないならユーザーに報告し、ファイルを作って状態を作らないこと。"
__SG_HOWTO_START="着手は bash .claude/skills/20-common-step-ticket/scripts/ticket.sh start <番号>。取り消しは ticket.sh cancel。"
__SG_HOWTO_DONE="完了は bash .claude/skills/20-common-step-ticket/scripts/ticket.sh complete <番号>（全体まとめは finalize.sh release）。完了済みのチケットは触らない。"
__SG_HOWTO_READY="draft の解除は bash .claude/hooks/finalize.sh release 経由でのみ行う（MCP 経由でも同じ）。"
__SG_NO_BYPASS="コマンドの分割・別の実行系・権限設定の変更・フックの登録解除で迂回しないこと。"

# ---- 制御方式 0: 設定が読めないときは既定値へフォールバックし、拒否に倒さない ----
__SG_STATE_FILES=()
__sg_load_state_files() {
  local rc=0
  scope_load || rc=$?
  if (( rc == 0 )) && (( ${#SC_COMMON_STATE_FILES[@]} > 0 )); then
    __SG_STATE_FILES=("${SC_COMMON_STATE_FILES[@]}")
    return 0
  fi
  # 既定値（仕様の制御方式 0）。設定 1 ファイルの破損でロックアウトしないための例外
  __SG_STATE_FILES=(logs/mr.json logs/review-state.json logs/review-history.jsonl logs/merge-state.json)
  hook_record notify "" "" "scope-limits.json を読めないので common.state_files の既定値にフォールバックした（HC_LIMITS_STATE=${HC_LIMITS_STATE:-missing}）"
  return 0
}
__sg_load_state_files

# ---- パスの補助 ----
__sg_rel() { # $1=パス → REPLY にルート相対（外のパスは絶対のまま）。末尾の / を落とす
  hook_rel_path "$1" >/dev/null
  REPLY="${REPLY%/}"
  return 0
}

__sg_is_state_file() { # $1=ルート相対パス
  local p="$1" g
  [[ -n "$p" ]] || return 1
  for g in ${__SG_STATE_FILES[@]+"${__SG_STATE_FILES[@]}"}; do
    scope_match "$g" "$p" && return 0
  done
  return 1
}

__sg_in_dir() { # $1=パス $2=置き場。置き場自身かその中なら 0（宛先の判定に使う）
  local p="${1%/}" d="$2"
  [[ -n "$p" ]] || return 1
  [[ "$p" == "$d" || "$p" == "$d/"* ]]
}

__sg_hits_dir() { # $1=パス $2=置き場。置き場自身・その中・**その祖先**なら 0（元＝消える側の判定に使う）
  local p="${1%/}" d="$2"
  [[ -n "$p" ]] || return 1
  [[ "$p" == "." ]] && return 0                 # ルートごと消す形
  __sg_in_dir "$p" "$d" && return 0
  # `**` の glob はパターン自身の親に一致しないので、祖先は別に見る（DDR i0009-59）
  [[ "$d/" == "$p/"* ]] && return 0
  return 1
}

# ---- 制御方式 4: MCP ツール ----
if [[ "$HOOK_TOOL" == mcp__* ]]; then
  case "${HOOK_TOOL,,}" in
    *pull_request*|*merge_request*)
      if [[ "${HOOK_DRAFT:-}" == "false" ]]; then
        hook_deny WF304 "MCP 経由の draft 解除（draft:false）は行わない。$__SG_HOWTO_READY $__SG_NO_BYPASS" "$HOOK_TOOL"
      fi
      ;;
  esac
  # 進行状態ファイル・置き場・draft 解除の 3 つ以外は守備範囲外（外部委任モードを潰さない。DDR i0009-28）
  hook_allow
fi

__SG_CLASS="$(tool_class "$HOOK_TOOL" "$HOOK_SKILL")"

# ---- 制御方式 2: 書き込みツール ----
if [[ "$__SG_CLASS" == write ]]; then
  if [[ -z "${HOOK_FILE_PATH:-}" ]]; then
    hook_deny WF309 "書き込みの対象パスを読み取れないため、保護対象に関わるか判断できない。$__SG_NO_BYPASS" "$HOOK_TOOL"
  fi
  __sg_rel "$HOOK_FILE_PATH"; __SG_P="$REPLY"
  if __sg_is_state_file "$__SG_P"; then
    hook_deny WF301 "$__SG_P は進行状態ファイルなので、ツールから直接書き換えない。$__SG_HOWTO_STATE $__SG_NO_BYPASS" "$__SG_P"
  fi
  if __sg_in_dir "$__SG_P" "$__SG_DONE"; then
    hook_deny WF303 "$__SG_P は完了の置き場にある。$__SG_HOWTO_DONE $__SG_NO_BYPASS" "$__SG_P"
  fi
  if __sg_in_dir "$__SG_P" "$__SG_DOING"; then
    # 既存チケット本文の更新（作業ログ）は許可。新規作成だけを拒否する
    if [[ ! -e "$HOOK_WORKTREE/$__SG_P" ]]; then
      hook_deny WF302 "$__SG_P を作業中の置き場に直接作らない。$__SG_HOWTO_START $__SG_NO_BYPASS" "$__SG_P"
    fi
  fi
  hook_allow
fi

# 実行以外（読み取り・計画・起動・宣言）は保護対象に関わらない
[[ "$__SG_CLASS" == exec ]] || hook_allow

# ---- 制御方式 3: 実行ツール ----
__SG_CMD="${HOOK_COMMAND:-}"
[[ -n "$__SG_CMD" ]] && : || hook_allow

__sg_target() { printf '%s' "${__SG_CMD:0:80}"; }

# opaque / 縮退で拒否側に倒す対象語（state_files の basename と置き場・draft 解除の語）
__SG_WORDS=(10_doing 20_done ready draft)
__sg_add_basenames() {
  local g b
  for g in ${__SG_STATE_FILES[@]+"${__SG_STATE_FILES[@]}"}; do
    b="${g##*/}"
    [[ -n "$b" && "$b" != '*'* ]] && __SG_WORDS+=("${b,,}")
  done
  return 0
}
__sg_add_basenames

__sg_has_word() { # コマンド文字列に対象語があるか
  local w
  for w in "${__SG_WORDS[@]}"; do
    [[ "$CP_LOWER" == *"$w"* ]] && return 0
  done
  return 1
}

cmdpos_parse "$__SG_CMD" "$([[ "$HOOK_TOOL" == PowerShell ]] && printf 'powershell' || printf 'bash')"

if (( CP_DEGRADED )); then
  if __sg_has_word; then
    hook_deny WF309 "コマンドが長すぎる（または bash が古い）ため位置を判定できず、進行状態・置き場・draft 解除に関わる語があるので拒否側に倒した。$__SG_HOWTO_STATE $__SG_NO_BYPASS" "$(__sg_target)"
  fi
  hook_allow
fi

# 宛先（リダイレクト先・書き込みコマンドの対象）と元（消える側）を分けて集める
__sg_split_us() { # $1=US 区切り → REPLY_LIST
  REPLY_LIST=()
  local s="${1:-}" x
  while [[ -n "$s" ]]; do
    if [[ "$s" == *$'\x1e'* ]]; then x="${s%%$'\x1e'*}"; s="${s#*$'\x1e'}"; else x="$s"; s=""; fi
    [[ -n "$x" ]] && REPLY_LIST+=("$x")
  done
  return 0
}

__sg_deny_dest() { # $1=宛先パス（生）
  local p
  [[ -n "$1" && "$1" != "_" ]] || return 0
  __sg_rel "$1"; p="$REPLY"
  if __sg_is_state_file "$p"; then
    hook_deny WF301 "$p は進行状態ファイルで、書き込みを伴う位置に現れている。$__SG_HOWTO_STATE $__SG_NO_BYPASS" "$(__sg_target)"
  fi
  if __sg_in_dir "$p" "$__SG_DONE"; then
    hook_deny WF303 "完了の置き場（$p）へ直接書き込まない。$__SG_HOWTO_DONE $__SG_NO_BYPASS" "$(__sg_target)"
  fi
  if __sg_in_dir "$p" "$__SG_DOING"; then
    hook_deny WF302 "作業中の置き場（$p）へ直接書き込まない。$__SG_HOWTO_START $__SG_NO_BYPASS" "$(__sg_target)"
  fi
  return 0
}

__sg_deny_src() { # $1=元パス（生）。消える側なので置き場の祖先も見る
  local p
  [[ -n "$1" && "$1" != "_" ]] || return 0
  __sg_rel "$1"; p="$REPLY"
  if __sg_is_state_file "$p"; then
    hook_deny WF301 "$p は進行状態ファイルで、消える側に指定されている。$__SG_HOWTO_STATE $__SG_NO_BYPASS" "$(__sg_target)"
  fi
  # 作業中を先に見る。両方の祖先（wip / wip/10_tickets）を消す形は WF302 に倒す（仕様 SG-T11）
  if __sg_hits_dir "$p" "$__SG_DOING"; then
    hook_deny WF302 "作業中の置き場（$__SG_DOING）が $p の削除・移動で失われる。$__SG_HOWTO_START $__SG_NO_BYPASS" "$(__sg_target)"
  fi
  if __sg_hits_dir "$p" "$__SG_DONE"; then
    hook_deny WF303 "完了の置き場（$__SG_DONE）が $p の削除・移動で失われる。$__SG_HOWTO_DONE $__SG_NO_BYPASS" "$(__sg_target)"
  fi
  return 0
}

__sg_deny_ready() { # $1=セグメント番号。gh / glab の draft 解除
  local i="$1" exe="${CP_EXE[$1]:-}" a0 a1 t method=0 hasdraft=0
  [[ "$exe" == gh || "$exe" == glab ]] || return 0
  cmdpos_args "$i"
  a0="${REPLY_ARGS[0]:-}"; a1="${REPLY_ARGS[1]:-}"
  if [[ "$a0" == pr || "$a0" == mr ]]; then
    [[ "$a1" == ready ]] && hook_deny WF304 "draft の解除を直接実行しない。$__SG_HOWTO_READY $__SG_NO_BYPASS" "$(__sg_target)"
    for t in "${REPLY_ARGS[@]}"; do
      [[ "${t,,}" == "--ready" ]] && hook_deny WF304 "draft の解除（--ready）を直接実行しない。$__SG_HOWTO_READY $__SG_NO_BYPASS" "$(__sg_target)"
    done
  fi
  if [[ "$a0" == api ]]; then
    for t in "${REPLY_ARGS[@]}"; do
      case "${t,,}" in
        *draft=false*) hook_deny WF304 "API 経由の draft 解除を直接実行しない。$__SG_HOWTO_READY $__SG_NO_BYPASS" "$(__sg_target)" ;;
        put|-x|--method) method=1 ;;
        *draft*) hasdraft=1 ;;
      esac
    done
    (( method && hasdraft )) && hook_deny WF304 "API 経由の draft の書き換えを直接実行しない。$__SG_HOWTO_READY $__SG_NO_BYPASS" "$(__sg_target)"
  fi
  return 0
}

__sg_i=0
for (( __sg_i = 0; __sg_i < CP_COUNT; __sg_i++ )); do
  # データだけの段（ヒアドキュメント本文・コメント）は実行位置ではない
  [[ "${CP_DATA[$__sg_i]:-0}" == 1 ]] && continue
  # 提供コマンド（§7-8）が唯一の書き換え経路。内部処理は見えない
  [[ -n "${CP_PROVIDED[$__sg_i]:-}" ]] && continue

  if [[ "${CP_OPAQUE[$__sg_i]:-0}" == 1 ]]; then
    if __sg_has_word; then
      hook_deny WF309 "文字列をコードとして受け取る実行系の中に、進行状態・置き場・draft 解除に関わる語がある。中身を判定できないので拒否側に倒した。$__SG_HOWTO_STATE $__SG_NO_BYPASS" "$(__sg_target)"
    fi
    continue
  fi

  __sg_exe="${CP_EXE[$__sg_i]:-}"
  __sg_sub="${CP_SUBCMD[$__sg_i]:-}"

  # 宛先: リダイレクト先と、書き込みコマンドの対象（rm は「元」として別に見る）
  __sg_split_us "${CP_REDIRECTS[$__sg_i]:-}"
  for __sg_t in ${REPLY_LIST[@]+"${REPLY_LIST[@]}"}; do __sg_deny_dest "$__sg_t"; done
  if [[ "$__sg_exe" != rm ]]; then
    __sg_split_us "${CP_WRITE_TARGETS[$__sg_i]:-}"
    for __sg_t in ${REPLY_LIST[@]+"${REPLY_LIST[@]}"}; do __sg_deny_dest "$__sg_t"; done
  fi

  # 元（消える側）: rm / git rm は全部、mv / git mv は最後を宛先としてそれ以外
  __sg_srcs=()
  case "$__sg_exe" in
    rm) cmdpos_operands "$__sg_i"; __sg_srcs=(${REPLY_OPERANDS[@]+"${REPLY_OPERANDS[@]}"}) ;;
    mv)
      cmdpos_operands "$__sg_i"
      if (( ${#REPLY_OPERANDS[@]} >= 2 )); then
        __sg_srcs=("${REPLY_OPERANDS[@]:0:${#REPLY_OPERANDS[@]}-1}")
      fi ;;
    git)
      case "$__sg_sub" in
        rm) cmdpos_operands "$__sg_i"; __sg_srcs=(${REPLY_OPERANDS[@]+"${REPLY_OPERANDS[@]}"}) ;;
        mv)
          cmdpos_operands "$__sg_i"
          if (( ${#REPLY_OPERANDS[@]} >= 2 )); then
            __sg_srcs=("${REPLY_OPERANDS[@]:0:${#REPLY_OPERANDS[@]}-1}")
            __sg_deny_dest "${REPLY_OPERANDS[-1]}"
          fi ;;
        checkout|restore)
          # 状態ファイルの復元（上書き）。置き場は対象にしない
          cmdpos_operands "$__sg_i"
          for __sg_t in ${REPLY_OPERANDS[@]+"${REPLY_OPERANDS[@]}"}; do
            __sg_rel "$__sg_t"
            if __sg_is_state_file "$REPLY"; then
              hook_deny WF301 "$REPLY は進行状態ファイルで、git $__sg_sub で上書きしようとしている。$__SG_HOWTO_STATE $__SG_NO_BYPASS" "$(__sg_target)"
            fi
          done ;;
      esac ;;
  esac
  for __sg_t in ${__sg_srcs[@]+"${__sg_srcs[@]}"}; do __sg_deny_src "$__sg_t"; done

  # draft 解除
  __sg_deny_ready "$__sg_i"
done

hook_allow
