#!/usr/bin/env bash
# subagent-start-check.sh — サブエージェントの起動時に実行者の不一致を通知し、対象チケットの要点を注入する
# 仕様: .claude/docs/10_spec/hooks/12-SubagentStart/subagent-start-check.md（判定・2 経路の出力・WF80x）
# 登録: SubagentStart（matcher 無し）と PreToolUse / matcher `Agent`
# 出力: systemMessage + additionalContext（WF801 / WF803）、additionalContext（WF802）または無出力
#
# 案内側なので起動を止めない（permissionDecision を出さない）。同じスクリプトを 2 つのイベントに
# 登録し、hook_event_name で処理を分ける（SubagentStart には model が来ないので比較できない）。
set -euo pipefail

HOOK_DENY_ID="WF809"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop
__ss_load frontmatter nop

__sa_dir="${BASH_SOURCE[0]%/*}"
case "$__sa_dir" in /*|[A-Za-z]:/*) ;; *) __sa_dir="$PWD/$__sa_dir" ;; esac
# shellcheck source=/dev/null
. "$__sa_dir/../lib/hook-common.sh"

hook_init subagent-start-check notify WF809

hook_read_input || hook_fail "入力を読めない"

__SA_TASK_EXECUTOR="task-executor"   # チケットの executor が当てはまる subagent_type（それ以外では判定しない）
__SA_DOD_MAX=4096                    # 注入する DoD の上限（バイト）
__SA_DOD_HEAD=10                     # 上限を超えたときに残す件数

# 制御方式 1: 停止中
hook_enforce_enabled || hook_disabled

# ---- 制御方式 2: 対象チケット（作業中の 1 枚。無ければ未着手の最小連番）----
__sa_target() {
  local ng=0 f
  REPLY=""
  shopt -q nullglob && ng=1
  shopt -s nullglob
  local -a doing=("$HOOK_WORKTREE"/wip/10_tickets/10_doing/*.md)
  local -a todo=("$HOOK_WORKTREE"/wip/10_tickets/00_todo/*.md)
  (( ng )) || shopt -u nullglob
  if (( ${#doing[@]} > 0 )); then REPLY="${doing[0]}"; return 0; fi
  # チケットは 1 枚ずつ進むので、未着手の最小連番が次に実施されるもの（DDR i0001-23）。
  # glob の展開は名前順なので先頭がそれに当たる
  if (( ${#todo[@]} > 0 )); then REPLY="${todo[0]}"; return 0; fi
  return 1
}

# 2 経路の出力（systemMessage = ユーザーへ即時 / additionalContext = ツール結果の隣）。
# hook-common に 2 経路をまとめて出す公開 API が無いため、ここで組み立てる（0032 へ書き戻す）
__sa_emit2() { # $1=イベント $2=systemMessage $3=additionalContext
  local sm ac
  __hc_redact_to_reply "$2"; __hc_json_str "$REPLY"; sm="$REPLY"
  __hc_redact_to_reply "$3"; __hc_json_str "$REPLY"; ac="$REPLY"
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
    "$sm" "$1" "$ac"
  return 0
}

# ---- モデル名の正規化（.claude/hooks/config/model-aliases.txt）----
__sa_norm() { # $1=モデル名 → REPLY に族名。判定できなければ空で戻り 1
  local v="${1,,}" line fam al
  REPLY=""
  [[ -n "$v" ]] || return 1
  local f="$HOOK_ROOT/.claude/hooks/config/model-aliases.txt"
  [[ -f "$f" ]] || { log_warn "model-aliases.txt が無いのでモデルを正規化できない"; return 1; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    line="${line%%#*}"
    [[ "$line" == *$'\t'* ]] || continue
    fam="${line%%$'\t'*}"; al="${line#*$'\t'}"
    fam="${fam//[[:space:]]/}"; al="${al//[[:space:]]/}"
    [[ -n "$fam" && -n "$al" ]] || continue
    if [[ "$v" == "$al"* ]]; then REPLY="$fam"; return 0; fi
  done < "$f"
  return 1
}

# ---- 対象チケットの読み取り ----
__sa_file=""
if ! __sa_target; then
  hook_record skip "" "" "対象チケットが無い"
  exit 0
fi
__sa_file="$REPLY"
__sa_name="${__sa_file##*/}"; __sa_name="${__sa_name%.md}"

__sa_type=""; __sa_executor=""
__sa_type="$(fm_get "$__sa_file" ticket_type 2>/dev/null || true)"
__sa_type="${__sa_type//$'\r'/}"
if [[ -z "$__sa_type" ]]; then
  # 制御方式 3・7: frontmatter が読めないときは何もしない（起動を止めない）
  hook_record skip "" "$__sa_name" "チケットの frontmatter を読めない"
  exit 0
fi
__sa_executor="$(fm_get "$__sa_file" executor 2>/dev/null || true)"
__sa_executor="${__sa_executor//$'\r'/}"
__sa_executor="${__sa_executor//\"/}"

# ---- SubagentStart: 要点の注入（制御方式 6）----
if [[ "$HOOK_EVENT" == "SubagentStart" ]]; then
  __sa_w=""; __sa_o=""
  while IFS= read -r __sa_v; do
    __sa_v="${__sa_v//$'\r'/}"
    [[ -n "$__sa_v" ]] && __sa_w+="${__sa_w:+, }$__sa_v"
  done < <(fm_list "$__sa_file" allow.write 2>/dev/null || true)
  while IFS= read -r __sa_v; do
    __sa_v="${__sa_v//$'\r'/}"
    [[ -n "$__sa_v" ]] && __sa_o+="${__sa_o:+, }$__sa_v"
  done < <(fm_list "$__sa_file" allow.ops 2>/dev/null || true)

  # DoD は `- [ ]` 行だけ。根拠欄（（根拠: …））は落とす
  __sa_dod=()
  __sa_in=0
  while IFS= read -r __sa_line || [[ -n "$__sa_line" ]]; do
    __sa_line="${__sa_line//$'\r'/}"
    if [[ "$__sa_line" == '## '* ]]; then
      if [[ "$__sa_line" == '## DoD'* ]]; then __sa_in=1; else __sa_in=0; fi
      continue
    fi
    (( __sa_in )) || continue
    case "$__sa_line" in
      '- [ ]'*|'- [x]'*|'- [X]'*) ;;
      *) continue ;;
    esac
    __sa_line="${__sa_line%（根拠:*}"
    __sa_line="${__sa_line%"${__sa_line##*[![:space:]]}"}"
    __sa_dod+=("$__sa_line")
  done < "$__sa_file"

  __sa_dod_text=""
  for __sa_line in ${__sa_dod[@]+"${__sa_dod[@]}"}; do __sa_dod_text+="$__sa_line"$'\n'; done
  __hc_bytelen "$__sa_dod_text"
  if (( REPLY > __SA_DOD_MAX )); then
    __sa_dod_text=""
    for (( __sa_i = 0; __sa_i < ${#__sa_dod[@]} && __sa_i < __SA_DOD_HEAD; __sa_i++ )); do
      __sa_dod_text+="${__sa_dod[$__sa_i]}"$'\n'
    done
    __sa_dod_text+="（DoD は全 ${#__sa_dod[@]} 件。長いので先頭 $__SA_DOD_HEAD 件だけを載せた。全文はチケットを読む）"$'\n'
  fi

  __sa_msg="WF802: 対象チケット $__sa_name の要点"$'\n'
  __sa_msg+="- タスクの種類: $__sa_type"$'\n'
  __sa_msg+="- やってよいこと（書き込み）: ${__sa_w:-（記載なし）}"$'\n'
  __sa_msg+="- やってよいこと（操作）: ${__sa_o:-（記載なし）}"$'\n'
  __sa_msg+="- DoD:"$'\n'"${__sa_dod_text:-（記載なし）}"
  hook_inject SubagentStart WF802 "$__sa_msg"
  exit 0
fi

# ---- PreToolUse `Agent`: 実行者の不一致（WF801）と background 起動（WF803）----
# ここまで来た = PreToolUse `Agent` の経路が生きている。その事実をセッション内に印として残す。
# subagent-stop-check は縮退（この登録行が外れている）かどうかをこの印で判定する。
# decisions.jsonl の走査で代えると、記録が育つほど誤って縮退と判定しやすくなる（DDR i0009-52 の実装）
__sa_mark() {
  local at
  printf -v at '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  hook_session_write subagent-start-check.json \
    "{\"at\":\"$at\",\"event\":\"PreToolUse\",\"tool\":\"Agent\"}" || log_warn "経路の印を書けない"
  return 0
}
__sa_mark

__sa_ids=(); __sa_lines=()

if [[ "${HOOK_SUBAGENT_TYPE:-}" != "$__SA_TASK_EXECUTOR" ]]; then
  # チケットの executor はタスクの実施者に対する指定。レビュアーや探索エージェントには当てはまらない
  hook_record skip "" "$__sa_name" "subagent_type が対象外（${HOOK_SUBAGENT_TYPE:-未指定}）"
  exit 0
fi

# 制御方式 5: サブエージェントは既定で background で走り、そのとき subagent-stop-check の
# 検査（WF811〜813）がメインエージェントに届かない（DDR i0009-50）
if [[ "${HOOK_RUN_IN_BACKGROUND:-}" != "false" ]]; then
  __sa_ids+=("WF803")
  __sa_lines+=("WF803: タスク実施者を background で起動しようとしている（run_in_background が明示的に false でない）。完了後の検査（WF811〜813）がメインエージェントに届かない。run_in_background: false で起動し直すと結果を受け取れる。起動は止めていない。")
fi

# 制御方式 4: 不一致の判定
__sa_reason=""
if [[ -z "$__sa_executor" ]]; then
  __sa_reason="executor の記載が無い"
elif [[ "${__sa_executor,,}" == "main" ]]; then
  __sa_reason="実行者がメインエージェント（比較対象外）"
elif [[ -z "${HOOK_MODEL:-}" ]]; then
  __sa_reason="model が特定できない（Agent の model 省略）"
else
  __sa_want=""; __sa_got=""
  __sa_norm "$__sa_executor" && __sa_want="$REPLY"
  __sa_norm "$HOOK_MODEL" && __sa_got="$REPLY"
  if [[ -z "$__sa_want" || -z "$__sa_got" ]]; then
    __sa_reason="model が特定できない（正規化できない値）"
  elif [[ "$__sa_want" == "$__sa_got" ]]; then
    __sa_reason="一致（$__sa_want）"
  else
    __sa_ids+=("WF801")
    __sa_lines+=("WF801: 実行者が違う。チケット $__sa_name の executor は $__sa_executor だが、起動しようとしているモデルは $HOOK_MODEL（$__sa_got）。チケットに従うなら止めて $__sa_want で起動し直す。実行者を変えたいなら未着手チケットの見直しで executor を直す。起動は止めていない。")
  fi
fi
[[ -n "$__sa_reason" ]] && hook_record skip "" "$__sa_name" "$__sa_reason"

if (( ${#__sa_ids[@]} > 0 )); then
  __sa_body=""
  for __sa_i in "${!__sa_lines[@]}"; do
    __sa_body+="${__sa_body:+$'\n\n'}${__sa_lines[$__sa_i]}"
  done
  for __sa_i in "${!__sa_ids[@]}"; do
    hook_record notify "${__sa_ids[$__sa_i]}" "$__sa_name" \
      "executor=$__sa_executor model=${HOOK_MODEL:-} subagent_type=${HOOK_SUBAGENT_TYPE:-} background=${HOOK_RUN_IN_BACKGROUND:-未指定}"
  done
  __sa_emit2 PreToolUse "$__sa_body" "$__sa_body"
  exit 0
fi

exit 0
