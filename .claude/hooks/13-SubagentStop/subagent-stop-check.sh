#!/usr/bin/env bash
# subagent-stop-check.sh — サブエージェントの終了後に作業領域の実態をメインエージェントへ伝える
# 仕様: .claude/docs/10_spec/hooks/13-SubagentStop/subagent-stop-check.md（検査・2 つの入口・WF81x）
# 登録: SubagentStop（matcher 無し）と PostToolUse / matcher `Agent`
# 出力: PostToolUse の additionalContext（WF811〜814・縮退時の WF801）または無出力
#
# 案内側。チケットの移動・完了も差分の巻き戻しもしない（異常と断定せず、実態として伝える）。
# SubagentStop の出力はメインエージェントに届かない（§12 T1）ので、そちらは記録だけを残す。
set -euo pipefail

HOOK_DENY_ID="WF819"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__sp_dir="${BASH_SOURCE[0]%/*}"
case "$__sp_dir" in /*|[A-Za-z]:/*) ;; *) __sp_dir="$PWD/$__sp_dir" ;; esac
# shellcheck source=/dev/null
. "$__sp_dir/../lib/hook-common.sh"
# shellcheck source=/dev/null
. "$__sp_dir/../lib/scope.sh"

hook_init subagent-stop-check notify WF819

hook_read_input limits || hook_fail "入力を読めない"

__SP_MAX_PATHS=20                    # WF812 / WF813 に並べるパスの上限
__SP_TASK_EXECUTOR="task-executor"

# 制御方式 1: 停止中
hook_enforce_enabled || hook_disabled

__SP_STATUS="${HOOK_RESPONSE_STATUS:-}"
# PostToolUse では tool_response.agentId（camelCase）。SubagentStop では agent_id（§2・DDR i0009-53）
if [[ "$HOOK_EVENT" == "SubagentStop" ]]; then
  __SP_AGENT="${HOOK_AGENT_ID:-}"
else
  __SP_AGENT="${HOOK_RESPONSE_AGENT_ID:-}"
fi
__SP_AGENT_SAFE="${__SP_AGENT//[^A-Za-z0-9._-]/-}"

__sp_ids=(); __sp_texts=()
__sp_add() { __sp_ids+=("$1"); __sp_texts+=("$2"); }

# ---- 対象チケット ----
__sp_doing_files=()
__sp_load_doing() {
  local ng=0
  shopt -q nullglob && ng=1
  shopt -s nullglob
  __sp_doing_files=("$HOOK_WORKTREE"/wip/10_tickets/10_doing/*.md)
  (( ng )) || shopt -u nullglob
  return 0
}

# ---- 制御方式 3: 検査 ----
__sp_inspect() {
  local f name type here line p st
  __sp_load_doing

  # WF811: 作業中のまま残ったチケット
  if (( ${#__sp_doing_files[@]} > 0 )); then
    local msg="作業中のまま残っているチケットがある:"
    for f in "${__sp_doing_files[@]}"; do
      name="${f##*/}"; name="${name%.md}"
      type=""
      type="$(fm_get "$f" ticket_type 2>/dev/null || true)"
      type="${type//$'\r'/}"
      here="無し"
      __sp_has_here "$f" && here="有り"
      msg+=$'\n'"- $name（種類: ${type:-不明} / 作業ログ「現在地」の記載: $here）"
    done
    msg+=$'\n'"対処: (1) サブエージェントの結果報告と突き合わせること。"
    msg+="(2) 完了していれば ticket.sh complete で完了の手続きを行うこと（サブエージェントが完了まで行う運用なら、作業中のまま残るのは異常）。"
    msg+="(3) 失敗・中断なら作業中のまま残ったチケットをユーザーに報告し、勝手に完了にしないこと。"
    __sp_add WF811 "$msg"
  fi

  # WF812 / WF813: 作業ツリーの差分
  command -v git >/dev/null 2>&1 || { log_info "git が無いので差分を見ない"; return 0; }
  git -C "$HOOK_WORKTREE" rev-parse --git-dir >/dev/null 2>&1 || { log_info "git リポジトリではない"; return 0; }

  local -a paths=()
  while IFS= read -r -d '' line; do
    st="${line:0:2}"
    p="${line:3}"
    case "$st" in
      R*|C*) IFS= read -r -d '' _ || true ;;   # 移動元は次のフィールド。判定は移動先で行う
    esac
    [[ -n "$p" ]] || continue
    case "$p" in
      logs|logs/*|wip/tmp/*) continue ;;
    esac
    paths+=("$p")
  done < <(git -C "$HOOK_WORKTREE" status --porcelain -z -uall 2>/dev/null || true)

  (( ${#paths[@]} > 0 )) || return 0

  __sp_add WF812 "未コミットの変更・未追跡が残っている:$(__sp_list "${paths[@]}")"$'\n'"対処: サブエージェントの結果報告と突き合わせ、必要なものは commit.sh でコミットし、不要なものは戻す。勝手に完了にしない。"

  # WF813: 作業中チケットの許可範囲外。
  # 2 枚以上あるとどのチケットの許可範囲で判定すべきか決まらないので範囲判定はしない
  # （workflow-diff-check が「2 枚以上は判定不能として黙って抜ける」のと揃える）。
  # WF811 / WF812 は枚数に依らず出す — 残っているチケットと差分の一覧は枚数と無関係に事実だから
  if (( ${#__sp_doing_files[@]} != 1 )); then
    log_debug "作業中チケットが ${#__sp_doing_files[@]} 枚なので範囲判定をしない"
    return 0
  fi
  local rc=0
  scope_load_ticket "${__sp_doing_files[0]}" || rc=$?
  (( rc == 0 )) || { log_debug "チケットを読めないので範囲判定をしない"; return 0; }
  rc=0
  scope_load "$SC_TICKET_TYPE" || rc=$?
  (( rc == 0 )) || { log_debug "上限設定を読めないので範囲判定をしない"; return 0; }
  hook_read_state approvals || true
  scope_load_approvals || true

  local -a bad=()
  for p in "${paths[@]}"; do
    scope_resolve "$p"
    case "$SC_DECISION" in
      deny|ask) bad+=("$p") ;;
    esac
  done
  (( ${#bad[@]} > 0 )) || return 0
  __sp_add WF813 "許可範囲外のパスに差分が残っている（作業中チケット ${__sp_doing_files[0]##*/} / 種類 $SC_TICKET_TYPE）:$(__sp_list "${bad[@]}")"$'\n'"復旧は workflow-diff-check の指示と同じ（基準点へ戻す。範囲を広げる必要があるならユーザーに提案する）。"
  return 0
}

# 作業ログ「現在地」に本文があるか
__sp_has_here() { # $1=チケット
  local line in=0 found=1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    if [[ "$line" == '### '* ]]; then
      if [[ "$line" == '### 現在地'* ]]; then in=1; else in=0; fi
      continue
    fi
    if (( in )) && [[ -n "${line//[[:space:]]/}" ]]; then found=0; break; fi
  done < "$1"
  return $found
}

__sp_list() { # $@=パス → 先頭 __SP_MAX_PATHS 件の箇条書き（超過分は件数）
  local out="" i=0 p
  for p in "$@"; do
    if (( i >= __SP_MAX_PATHS )); then
      out+=$'\n'"- （他 $(( $# - __SP_MAX_PATHS )) 件）"
      break
    fi
    out+=$'\n'"- $p"
    i=$(( i + 1 ))
  done
  printf '%s' "$out"
}

# ---- 記録（SubagentStop の経路）----
__sp_record_file() {
  hook_session_dir
  REPLY="$REPLY/subagent-${__SP_AGENT_SAFE:-unknown}.json"
  return 0
}

__sp_save() {
  local f at items="" i esc
  __sp_record_file; f="$REPLY"
  printf -v at '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  for i in "${!__sp_ids[@]}"; do
    __hc_json_str "${__sp_texts[$i]}"; esc="$REPLY"
    items+="${items:+,}{\"id\":\"${__sp_ids[$i]}\",\"text\":\"$esc\"}"
  done
  __hc_json_str "${__SP_AGENT:-}"
  hc_json_write "$f" "{\"checked_at\":\"$at\",\"agent_id\":\"$REPLY\",\"findings\":[$items]}" \
    || log_warn "検査結果を書けない"
  return 0
}

# 記録から読み戻す。戻り 1 = 記録が無い
__sp_load_saved() {
  local f n i id text
  __sp_record_file; f="$REPLY"
  [[ -f "$f" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  n="$(jq -r '(.findings // []) | length' "$f" 2>/dev/null | tr -d '' || true)"
  [[ "$n" =~ ^[0-9]+$ ]] || return 1
  __sp_ids=(); __sp_texts=()
  # 本文に改行が入るので行では分けられない。件数を取って 1 件ずつ引く（件数は高々 4）
  for (( i = 0; i < n; i++ )); do
    id="$(jq -r --argjson i "$i" '.findings[$i].id // ""' "$f" 2>/dev/null | tr -d '' || true)"
    text="$(jq -r --argjson i "$i" '.findings[$i].text // ""' "$f" 2>/dev/null || true)"
    [[ -n "$id" ]] || continue
    __sp_ids+=("$id"); __sp_texts+=("$text")
  done
  return 0
}

# ---- 制御方式 2: WF801 の縮退判定 ----
# subagent-start-check は通知しなかった場合も skip を残す（DDR i0009-52）。
# その記録が 1 件も無いときだけ、このフックが自分で判定する。
# 逸脱: PreToolUse `Agent` の時点では agentId がまだ発行されていないので、subagent-start-check は
# agentId を記録に載せられない。よって「同じ agentId の記録」ではなく
# 「このセッションの subagent-start-check の記録（agentId が載っていればそれも見る）」で引く（0032 へ書き戻す）
__sp_start_check_seen() {
  # 一次: subagent-start-check が判定のたびに置くセッション内の印。行数に依存しない
  hook_session_dir
  [[ -f "$REPLY/subagent-start-check.json" ]] && return 0
  # 二次: 印を置く前に始まったセッションのための後方互換。decisions.jsonl を頭から見る
  # （末尾 N 行だけを見ると、記録が育ったときに誤って縮退と判定して WF801 を二重に出す）
  local f="$HOOK_WORKTREE/logs/hooks/decisions.jsonl" line
  [[ -f "$f" ]] || return 1
  while IFS= read -r line; do
    [[ "$line" == *'"hook":"subagent-start-check"'* ]] || continue
    [[ "$line" == *"\"session_id\":\"$HOOK_SESSION_ID\""* ]] || continue
    return 0
  done < "$f"
  return 1
}

__sp_norm() { # $1=モデル名 → REPLY に族名。判定できなければ空で戻り 1
  local v="${1,,}" line fam al
  REPLY=""
  [[ -n "$v" ]] || return 1
  local f="$HOOK_ROOT/.claude/hooks/config/model-aliases.txt"
  [[ -f "$f" ]] || return 1
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

__sp_degraded_mismatch() {
  local t executor want got
  [[ "${HOOK_SUBAGENT_TYPE:-}" == "$__SP_TASK_EXECUTOR" ]] || return 0
  [[ -n "${HOOK_MODEL:-}" ]] || return 0
  __sp_start_check_seen && { log_debug "subagent-start-check の記録があるので再掲しない"; return 0; }
  __sp_load_doing
  (( ${#__sp_doing_files[@]} > 0 )) || return 0
  t="${__sp_doing_files[0]}"
  executor="$(fm_get "$t" executor 2>/dev/null || true)"
  executor="${executor//$'\r'/}"; executor="${executor//\"/}"
  [[ -n "$executor" && "${executor,,}" != "main" ]] || return 0
  want=""; got=""
  __sp_norm "$executor" && want="$REPLY"
  __sp_norm "$HOOK_MODEL" && got="$REPLY"
  [[ -n "$want" && -n "$got" ]] || return 0
  [[ "$want" != "$got" ]] || return 0
  __sp_add WF801 "実行者が違う（subagent-start-check の PreToolUse 経路が使えていないので、このフックが判定した）。チケット ${t##*/} の executor は $executor だが、起動したモデルは $HOOK_MODEL（$got）。チケットに従うなら $want で起動し直す。"
  return 0
}

# ---- 入口 1: SubagentStop（記録だけ。出力はメインに届かない）----
if [[ "$HOOK_EVENT" == "SubagentStop" ]]; then
  __sp_inspect
  __sp_save
  if (( ${#__sp_ids[@]} > 0 )); then
    hook_record notify "${__sp_ids[0]}" "${__SP_AGENT:-}" "SubagentStop で検査した（${#__sp_ids[@]} 件）"
  else
    hook_record skip "" "${__SP_AGENT:-}" "SubagentStop で検査し該当なし"
  fi
  exit 0
fi

# ---- 入口 2: PostToolUse `Agent` ----
if [[ "$__SP_STATUS" == "async_launched" ]]; then
  # まだ作業していないので作業後の検査をしない（作業前の作業領域を見てしまう）
  __sp_add WF814 "サブエージェントを background で起動した（tool_response.status が async_launched）ため、完了後の検査（WF811〜813）はメインエージェントに届かない。タスクの実施者は run_in_background: false で起動し直すか、完了を確かめてから自分で作業領域（10_doing/ と git status）を確認すること。"
elif __sp_load_saved; then
  # completed（foreground で走り終わった）: SubagentStop の記録があればそれを使う
  log_debug "SubagentStop の記録を読んだ agent=${__SP_AGENT:-}"
else
  __sp_ids=(); __sp_texts=()
  __sp_inspect
fi

# 縮退判定は status を問わず行う。記録の読み戻しは __sp_ids を入れ替えるので、その後に置く
__sp_degraded_mismatch

if (( ${#__sp_ids[@]} == 0 )); then
  hook_record skip "" "${__SP_AGENT:-}" "該当なし"
  exit 0
fi

__sp_body="${__sp_texts[0]}"
for __sp_i in "${!__sp_ids[@]}"; do
  (( __sp_i == 0 )) && continue
  __sp_body+=$'\n\n'"${__sp_ids[$__sp_i]}: ${__sp_texts[$__sp_i]}"
done
for __sp_i in "${!__sp_ids[@]}"; do
  (( __sp_i == 0 )) && continue
  hook_record notify "${__sp_ids[$__sp_i]}" "${__SP_AGENT:-}" "PostToolUse Agent で伝えた"
done
hook_notify PostToolUse "${__sp_ids[0]}" "$__sp_body" "${__SP_AGENT:-}"
exit 0
