#!/usr/bin/env bash
# workflow-entry.sh — 振り分けスキルの読み込み（宣言）をプロンプトごとに強制する
# 仕様: .claude/docs/10_spec/hooks/10-UserPromptSubmit/workflow-entry.md（宣言の記録・継続条件・WF10x）
# 登録: UserPromptSubmit（宣言のリセット）/ PreToolUse `Skill`（宣言の記録）/
#       PreToolUse 書き込み・実行・プランモード・起動・`mcp__.*`（未宣言の拒否）
# 出力: deny（WF101 / WF102 / WF109）または許可（無出力）
#
# 判定は「宣言があるか」だけ。範囲は workflow-guard、進行状態は workflow-state-guard の責務。
set -euo pipefail

HOOK_DENY_ID="WF109"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__we_dir="${BASH_SOURCE[0]%/*}"
case "$__we_dir" in /*|[A-Za-z]:/*) ;; *) __we_dir="$PWD/$__we_dir" ;; esac
# shellcheck source=/dev/null
. "$__we_dir/../lib/hook-common.sh"
# shellcheck source=/dev/null
. "$__we_dir/../lib/cmdpos.sh"

hook_init workflow-entry deny WF109

# 制御方式 1: 停止中なら何もしない（§4）
hook_enforce_enabled || hook_disabled

# 入力（jq 1 回目）
hook_read_input || hook_fail "入力を読めない"

__WE_HOWTO="Skill ツールで 00-workflow-issue-mr-driven（開発作業）または 00-workflow-quick-request（軽作業）を読み込んでから、元の操作をやり直すこと。判定基準は 00-workflow-quick-request の手順 0 の表。迂回（環境変数での無効化・別手段）はしないこと。"

# ---- 振り分けスキル名（config が正。コードに埋めない）----
__WE_SKILLS=()
__we_load_skills() {
  local f="$HOOK_ROOT/.claude/hooks/config/entry-skills.txt" line
  __WE_SKILLS=()
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] && __WE_SKILLS+=("$line")
  done < "$f"
  return 0
}
__we_load_skills

__we_is_entry_skill() { # $1=スキル名
  local s
  [[ -n "${1:-}" ]] || return 1
  for s in ${__WE_SKILLS[@]+"${__WE_SKILLS[@]}"}; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}

# ---- entry.json の読み書き ----
__we_field() { # $1=キー → REPLY（HC_ENTRY から取り出す。無ければ空）
  local s="${HC_ENTRY:-}" rec k
  REPLY=""
  while [[ -n "$s" ]]; do
    if [[ "$s" == *$'\x1e'* ]]; then rec="${s%%$'\x1e'*}"; s="${s#*$'\x1e'}"; else rec="$s"; s=""; fi
    [[ "$rec" == *$'\x1f'* ]] || continue
    k="${rec%%$'\x1f'*}"
    if [[ "$k" == "$1" ]]; then REPLY="${rec#*$'\x1f'}"; return 0; fi
  done
  return 1
}

__we_write_entry() { # $1=prompt_seq $2=declared_skill $3=continuation
  local at
  printf -v at '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  __hc_json_str "$2"; local sk="$REPLY"
  __hc_json_str "$3"; local co="$REPLY"
  hook_session_write entry.json \
    "{\"prompt_seq\":$1,\"declared_skill\":\"$sk\",\"declared_at\":\"$at\",\"continuation\":\"$co\"}" \
    || log_warn "entry.json を書けない"
  return 0
}

# ---- 入口 1: UserPromptSubmit（宣言のリセット。拒否はしない）----
if [[ "$HOOK_EVENT" == "UserPromptSubmit" ]]; then
  __we_seq=0
  if hook_read_state entry; then                      # jq 2 回目
    if __we_field prompt_seq; then
      [[ "$REPLY" =~ ^[0-9]+$ ]] && __we_seq="$REPLY"
    fi
  else
    log_warn "jq が無いので prompt_seq を引き継げない"
  fi
  __we_seq=$(( __we_seq + 1 ))

  # プロンプト 1 行目のスラッシュ起動は宣言として扱う（引数付き可）
  __we_declared=""
  __we_line="${HOOK_PROMPT:-}"
  __we_line="${__we_line#"${__we_line%%[![:space:]]*}"}"
  if [[ "$__we_line" == /* ]]; then
    __we_word="${__we_line#/}"
    __we_word="${__we_word%%[[:space:]]*}"
    __we_is_entry_skill "$__we_word" && __we_declared="$__we_word"
  fi
  __we_write_entry "$__we_seq" "$__we_declared" ""
  hook_record allow "" "" "prompt_seq=$__we_seq declared=${__we_declared:-none}"
  exit 0
fi

# ここから先は PreToolUse。判定不能は拒否側に倒す
hook_fail_closed

# ---- 入口 2: PreToolUse `Skill`（宣言の記録。Skill 自体は常に許可）----
if [[ "$HOOK_TOOL" == "Skill" ]]; then
  if __we_is_entry_skill "${HOOK_SKILL:-}"; then
    __we_seq=0
    if hook_read_state entry; then                    # jq 2 回目
      if __we_field prompt_seq; then
        [[ "$REPLY" =~ ^[0-9]+$ ]] && __we_seq="$REPLY"
      fi
    fi
    (( __we_seq > 0 )) || __we_seq=1
    __we_write_entry "$__we_seq" "$HOOK_SKILL" ""
    hook_record allow "" "$HOOK_SKILL" "declared $HOOK_SKILL"
    exit 0
  fi
  hook_allow
fi

# ---- 入口 3: PreToolUse（対象は書き込み / 実行 / プランモード / 起動 / MCP）----
__WE_CLASS="$(tool_class "$HOOK_TOOL" "${HOOK_SKILL:-}")"
case "$__WE_CLASS" in
  write|exec|plan|spawn) ;;
  *) [[ "$HOOK_TOOL" == mcp__* ]] || hook_allow ;;
esac

# 制御方式 2: 継続条件（宣言より先に評価する）
__we_has_tickets() {
  local ng=0 d
  shopt -q nullglob && ng=1
  shopt -s nullglob
  local -a files=()
  for d in 00_todo 10_doing 20_done; do
    files+=("$HOOK_WORKTREE/wip/10_tickets/$d"/*.md)
  done
  (( ng )) || shopt -u nullglob
  (( ${#files[@]} > 0 ))
}

if __we_has_tickets; then
  hook_record allow "" "" "continuation: tickets"
  exit 0
fi

# チケットが無いときだけ、レビュー状態・マージ前作業と宣言の記録を読む（jq 2 回目）
hook_read_state review merge entry || hook_fail "jq が見つからない（フックの依存）"

__we_state_of() { # $1=review|merge → REPLY に state
  local body k rec s
  case "$1" in
    review) body="${HC_REVIEW:-}" ;;
    merge)  body="${HC_MERGE:-}" ;;
    *) REPLY=""; return 1 ;;
  esac
  REPLY=""
  s="$body"
  while [[ -n "$s" ]]; do
    if [[ "$s" == *$'\x1e'* ]]; then rec="${s%%$'\x1e'*}"; s="${s#*$'\x1e'}"; else rec="$s"; s=""; fi
    [[ "$rec" == *$'\x1f'* ]] || continue
    k="${rec%%$'\x1f'*}"
    if [[ "$k" == "state" ]]; then REPLY="${rec#*$'\x1f'}"; return 0; fi
  done
  return 1
}

__we_state_of review || true
if [[ "$REPLY" == "requested" ]]; then
  hook_record allow "" "" "continuation: review"
  exit 0
fi

# マージ前作業中は「提供コマンドの再実行」だけを宣言なしで通す。
# それ以外はこの分岐で決めず、3〜4 の宣言の判定に進む（継続条件は緩和であって、宣言済みより厳しくしない）
__we_merge_ok=0
__we_state_of merge || true
case "$REPLY" in
  started|cleaned|pushed)
    if [[ "$__WE_CLASS" == exec && -n "${HOOK_COMMAND:-}" ]]; then
      cmdpos_parse "$HOOK_COMMAND" "$([[ "$HOOK_TOOL" == PowerShell ]] && printf 'powershell' || printf 'bash')"
      if (( CP_DEGRADED == 0 )); then
        for (( __we_i = 0; __we_i < CP_COUNT; __we_i++ )); do
          case "${CP_PROVIDED[$__we_i]:-}" in
            */finalize.sh|*/boundary.sh) __we_merge_ok=1 ;;
          esac
        done
      fi
    fi
    ;;
esac
if (( __we_merge_ok )); then
  hook_record allow "" "" "continuation: merge-prep（提供コマンドの再実行）"
  exit 0
fi

# 制御方式 3: 宣言の記録
if [[ "${HC_ENTRY_STATE:-missing}" != "ok" ]]; then
  hook_deny WF102 "このセッションの振り分けの記録（entry.json）が無い、または壊れているため未宣言として扱った。$__WE_HOWTO" "$HOOK_TOOL"
fi

__we_field declared_skill || REPLY=""
if [[ -z "$REPLY" ]]; then
  hook_deny WF101 "このプロンプトでは作業の振り分けが宣言されていない。$__WE_HOWTO マージ前作業の継続中なら finalize.sh release の再実行だけは宣言なしで通る。" "$HOOK_TOOL"
fi

# 制御方式 5: 宣言あり（他の判定は行わない）
hook_allow
