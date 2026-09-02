#!/usr/bin/env bash
# post-push-usage-report.sh — 前回 push からの対応工数を集計してレポート本文を用意する
# 仕様: .claude/docs/10_spec/hooks/22-PostToolUse/post-push-usage-report.md（集計項目・本文の形・WF91x）
# 登録: PostToolUse / matcher `Bash|PowerShell`（既定）と Stop / SubagentStop（`--accumulate`）
# 出力: additionalContext（WF911）または無出力。logs/usage/<branch>.json と report-<branch>-<count>.md
#
# 1 つのスクリプトを 2 つの契機で使う:
#   --accumulate  応答完了ごとに transcript の未処理分を logs/usage/<branch>.json へ加算する
#   （既定）      push 成功時に合算してレポート本文を組み立てる
# 投稿はしない（boundary.sh request / note の責務）。リセットもしない（投稿の成否は boundary.sh が書く）。
set -euo pipefail

HOOK_DENY_ID="WF919"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__ur_dir="${BASH_SOURCE[0]%/*}"
case "$__ur_dir" in /*|[A-Za-z]:/*) ;; *) __ur_dir="$PWD/$__ur_dir" ;; esac
# shellcheck source=/dev/null
. "$__ur_dir/../lib/hook-common.sh"
# shellcheck source=/dev/null
. "$__ur_dir/../lib/cmdpos.sh"
# shellcheck source=/dev/null
. "$__ur_dir/../lib/push-detect.sh"
# shellcheck source=/dev/null
. "$__ur_dir/../lib/transcript.sh"

hook_init post-push-usage-report notify WF919

__UR_MODE="default"
[[ "${1:-}" == "--accumulate" ]] && __UR_MODE="accumulate"

__UR_IDLE_GAP=600        # 秒。これを超える間隔は実作業時間に数えない（席を外した時間）

hook_read_input || hook_fail "入力を読めない"

# 制御方式 1（両モード共通）: 停止中。蓄積側は記録も残さない（Stop のたびに 1 行増えるため）
if ! hook_enforce_enabled; then
  [[ "$__UR_MODE" == "accumulate" ]] && exit 0
  hook_disabled
fi

# ---- 状態ファイル ----
__UR_BR="$(git -C "$HOOK_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
__UR_BR="${__UR_BR//$'\r'/}"
[[ -n "$__UR_BR" && "$__UR_BR" != "HEAD" ]] || __UR_BR="detached"
__UR_SAFE="${__UR_BR//[^A-Za-z0-9._-]/-}"      # ファイル名にできる形（feature/x → feature-x）
__UR_FILE="$HOOK_WORKTREE/logs/usage/$__UR_SAFE.json"

__UR_STATE=""; __UR_BROKEN=0

__ur_now_iso() { printf -v REPLY '%(%Y-%m-%dT%H:%M:%S%z)T' -1; }

__ur_new_state() {
  local at
  __ur_now_iso; at="$REPLY"
  printf '{"since_sha":"","since_at":"%s","last_push_sha":"","push_count":0,"sessions":{},"subagents":{},"posted":false}' "$at"
}

# 状態を読む。壊れていれば __UR_BROKEN=1 で空にする（呼び手が作り直して注記する。制御方式 6）
__ur_state_read() {
  __UR_STATE=""; __UR_BROKEN=0
  [[ -f "$__UR_FILE" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  __UR_STATE="$(jq -c 'if type == "object" then . else empty end' "$__UR_FILE" 2>/dev/null || true)"
  if [[ -z "$__UR_STATE" ]]; then
    __UR_BROKEN=1
    log_warn "usage の状態が壊れているので作り直す"
  fi
  return 0
}

# ---- 蓄積（制御方式 --accumulate 2〜5）----
# $1=transcript のパス $2=sessions|subagents $3=キー。戻り 1 = 蓄積しなかった
__ur_accumulate() {
  local tp="${1:-}" kind="$2" key="$3" off agg cur next
  local -a v=()
  [[ -n "$key" ]] || return 1
  if [[ -z "$tp" || ! -f "$tp" ]]; then
    log_info "transcript が無いので蓄積しない kind=$kind"
    return 1
  fi
  command -v jq >/dev/null 2>&1 || return 1
  if ! hc_lock "usage-$__UR_SAFE"; then
    log_warn "usage-$__UR_SAFE のロックを取れないので今回の蓄積を諦めた"
    return 1
  fi
  __ur_state_read
  cur="$__UR_STATE"
  [[ -n "$cur" ]] || cur="$(__ur_new_state)"
  off="$(printf '%s' "$cur" | jq -r --arg d "$kind" --arg k "$key" '(.[$d][$k].last_offset // 0) | tostring' 2>/dev/null || printf '0')"
  [[ "$off" =~ ^[0-9]+$ ]] || off=0

  agg="$(transcript_aggregate "$tp" "$off" || true)"
  # 実作業時間: 隣り合う記録の間隔を足す。ユーザー入力（u）の直前と、席を外した間隔は数えない
  mapfile -t v < <(printf '%s' "$agg" | jq -r --argjson gap "$__UR_IDLE_GAP" '
    . as $r | ($r.timestamps // []) as $ts
    | (reduce range(0; (($ts | length) - 1)) as $i (0;
        (($ts[$i + 1][0] - $ts[$i][0]) as $g
         | if $g <= 0 or $g > $gap or $ts[$i + 1][1] == "u" then . else . + $g end))) as $act
    | ($r.input // 0), ($r.output // 0), ($r.cache_read // 0), ($r.cache_write // 0),
      ($r.tool_calls // 0), ($r.responses // 0), $act, ($r.parse_errors // 0), ($r.new_offset // 0)
  ' 2>/dev/null | tr -d '\r' || true)
  if (( ${#v[@]} < 9 )); then
    log_warn "transcript を解釈できないので蓄積しない kind=$kind"
    hc_unlock "usage-$__UR_SAFE"
    return 1
  fi

  next="$(printf '%s' "$cur" | jq -c --arg d "$kind" --arg k "$key" \
    --argjson i "${v[0]}" --argjson o "${v[1]}" --argjson cr "${v[2]}" --argjson cw "${v[3]}" \
    --argjson tc "${v[4]}" --argjson rs "${v[5]}" --argjson ac "${v[6]}" --argjson pe "${v[7]}" \
    --argjson no "${v[8]}" '
    .[$d] = ((.[$d] // {})
      | .[$k] = ((.[$k] // {input: 0, output: 0, cache_read: 0, cache_write: 0, tool_calls: 0,
                            responses: 0, active_seconds: 0, parse_errors: 0, last_offset: 0})
        | .input += $i | .output += $o | .cache_read += $cr | .cache_write += $cw
        | .tool_calls += $tc | .responses += $rs | .active_seconds += $ac
        | .parse_errors += $pe | .last_offset = $no))
  ' 2>/dev/null || true)"
  if [[ -n "$next" ]]; then
    hc_json_write "$__UR_FILE" "$next" || log_warn "usage の状態を書けない"
    __UR_STATE="$next"
    log_info "蓄積した kind=$kind offset=$off→${v[8]} parse_errors=${v[7]}"
  else
    log_warn "usage の状態を組み立てられない kind=$kind"
  fi
  hc_unlock "usage-$__UR_SAFE"
  return 0
}

# 今の入力から蓄積対象（transcript とキー）を決める。
# SubagentStop は agent_transcript_path を読む。transcript_path はメインのものなので、
# 読むとメイン分が subagents[] に二重計上される（仕様の入出力）
__ur_accumulate_current() {
  if [[ "$HOOK_EVENT" == "SubagentStop" ]]; then
    __ur_accumulate "${HOOK_AGENT_TRANSCRIPT_PATH:-}" subagents "${HOOK_AGENT_ID:-}"
    return $?
  fi
  __ur_accumulate "${HOOK_TRANSCRIPT_PATH:-}" sessions "${HOOK_SESSION_ID:-}"
  return $?
}

if [[ "$__UR_MODE" == "accumulate" ]]; then
  __ur_accumulate_current || true
  exit 0
fi

# ---- 既定（push 成功時）----
# 前置判定（fork ゼロ）
[[ "${HOOK_COMMAND,,}" == *push* ]] || exit 0

command -v jq >/dev/null 2>&1 || { log_warn "jq が無いので集計しない"; exit 0; }

__ur_state_read
__UR_WAS_BROKEN="$__UR_BROKEN"
[[ -n "$__UR_STATE" ]] || __UR_STATE="$(__ur_new_state)"

__ur_prev="$(printf '%s' "$__UR_STATE" | jq -r '.last_push_sha // ""' 2>/dev/null || true)"
__ur_prev="${__ur_prev//$'\r'/}"

# 制御方式 1: 起点は自分の状態から渡す。push-state.json は読まない（DDR i0009-24）
if ! push_detect "$HOOK_COMMAND" "$__ur_prev" "" \
     "$([[ "$HOOK_TOOL" == PowerShell ]] && printf 'powershell' || printf 'bash')" "$HOOK_WORKTREE"; then
  log_debug "push ではない（$PD_REASON）"
  exit 0
fi

# 制御方式 2: ターン途中の push でも漏らさないよう、現在セッションの未蓄積分を先に取り込む
__ur_accumulate_current || true
__ur_state_read
[[ -n "$__UR_STATE" ]] || __UR_STATE="$(__ur_new_state)"

# 制御方式 8: transcript がまったく読めず集計が空のままなら記録だけして抜ける
__ur_has="$(printf '%s' "$__UR_STATE" | jq -r '[(.sessions // {}), (.subagents // {})] | map(length) | add' 2>/dev/null || printf '0')"
if [[ -z "$__ur_has" || "$__ur_has" == "0" ]]; then
  hook_record skip WF912 "$__UR_SAFE" "集計できる記録が無い（transcript 不読）"
  log_info "集計対象が無いのでレポートを作らない"
  exit 0
fi

# ---- 合算 ----
mapfile -t __UR_SUM < <(printf '%s' "$__UR_STATE" | jq -r '
  def acc: [ (. // {}) | .[] ];
  ((.sessions | acc) + (.subagents | acc)) as $all
  | (($all | map(.input // 0) | add) // 0),
    (($all | map(.output // 0) | add) // 0),
    (($all | map(.cache_read // 0) | add) // 0),
    (($all | map(.cache_write // 0) | add) // 0),
    (($all | map(.tool_calls // 0) | add) // 0),
    (($all | map(.responses // 0) | add) // 0),
    (($all | map(.active_seconds // 0) | add) // 0),
    (($all | map(.parse_errors // 0) | add) // 0),
    ((.subagents // {}) | length),
    (.since_sha // ""), (.since_at // ""), ((.push_count // 0) | tostring), ((.posted // false) | tostring)
' 2>/dev/null | tr -d '\r' || true)
if (( ${#__UR_SUM[@]} < 13 )); then
  hook_record skip WF912 "$__UR_SAFE" "蓄積を合算できない"
  log_warn "蓄積を合算できないのでレポートを作らない"
  exit 0
fi

__ur_since_sha="${__UR_SUM[9]}"
__ur_since_at="${__UR_SUM[10]}"
__ur_count=$(( ${__UR_SUM[11]} + 1 ))
__ur_posted="${__UR_SUM[12]}"

# ---- 整形 ----
__ur_comma() { # $1=整数 → REPLY に 3 桁区切り
  local n="${1:-0}" out=""
  [[ "$n" =~ ^[0-9]+$ ]] || { REPLY="$n"; return 0; }
  while (( ${#n} > 3 )); do
    out=",${n:${#n}-3:3}$out"
    n="${n:0:${#n}-3}"
  done
  REPLY="$n$out"
  return 0
}

__ur_hm() { # $1=秒 → REPLY に「H 時間 M 分」（1 時間未満は「M 分」）
  local s="${1:-0}" h m
  [[ "$s" =~ ^[0-9]+$ ]] || s=0
  h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
  if (( h > 0 )); then REPLY="$h 時間 $m 分"; else REPLY="$m 分"; fi
  return 0
}

__ur_short() { # $1=sha → REPLY に短縮形（空なら «記録なし»）
  local s="${1:-}"
  if [[ -z "$s" ]]; then REPLY="（記録なし）"; else REPLY="${s:0:7}"; fi
  return 0
}

# ---- 注記 ----
__ur_notes=()
(( __UR_WAS_BROKEN )) && __ur_notes+=("蓄積の記録が壊れていたため、今回の push を起点に作り直した")
[[ -z "$__ur_since_sha" ]] && __ur_notes+=("集計期間の起点が未記録のため、蓄積を開始した時点からの合計")
[[ "$__ur_posted" == "false" && "${__UR_SUM[11]}" != "0" ]] && __ur_notes+=("前回の投稿が完了していないため、前回分を繰り越して集計している")
(( ${__UR_SUM[7]} > 0 )) && __ur_notes+=("読み取れなかった記録が ${__UR_SUM[7]} 行あり、その分は集計に含まれない")

# MR の有無（単独実行モード）
__UR_MR="$HOOK_WORKTREE/logs/mr.json"
__ur_mr_num=""
if [[ -f "$__UR_MR" ]]; then
  __ur_mr_num="$(jq -r '(.mr // empty) | tostring' "$__UR_MR" 2>/dev/null | tr -d '\r' || true)"
fi
[[ -n "$__ur_mr_num" ]] || __ur_notes+=("MR が未記録のため投稿先が無い（記録だけ残す）")

# ---- 本文 ----
__ur_now_iso; __ur_now="$REPLY"
__ur_short "$__ur_since_sha"; __ur_from="$REPLY"
__ur_short "$PD_HEAD"; __ur_to="$REPLY"
__ur_comma "${__UR_SUM[0]}"; __ur_in="$REPLY"
__ur_comma "${__UR_SUM[1]}"; __ur_out="$REPLY"
__ur_comma "${__UR_SUM[2]}"; __ur_cr="$REPLY"
__ur_comma "${__UR_SUM[3]}"; __ur_cw="$REPLY"
__ur_comma "${__UR_SUM[4]}"; __ur_tc="$REPLY"
__ur_comma "${__UR_SUM[5]}"; __ur_rs="$REPLY"
__ur_hm "${__UR_SUM[6]}"; __ur_act="$REPLY"

__ur_body="## 対応工数（AI 集計）"$'\n'
__ur_body+="- 集計期間: $__ur_from（${__ur_since_at:-（記録なし）}）→ $__ur_to（$__ur_now） / ブランチ $__UR_BR / このブランチで $__ur_count 回目の push"$'\n'
__ur_body+="- トークン: 入力 $__ur_in / 出力 $__ur_out / キャッシュ読取 $__ur_cr / キャッシュ書込 $__ur_cw"$'\n'
__ur_body+="- ツール実行: $__ur_tc 回 / 応答: $__ur_rs 回 / 実作業時間: $__ur_act"$'\n'
if (( ${__UR_SUM[8]} > 0 )); then
  __ur_body+="- サブエージェント: ${__UR_SUM[8]} 体分を含む"$'\n'
else
  __ur_body+="- サブエージェント: 含まれるものは無し"$'\n'
fi
if (( ${#__ur_notes[@]} > 0 )); then
  # IFS で連結すると区切りに使えるのは 1 バイトだけで、多バイト文字が壊れる。自分でつなぐ
  __ur_note_str=""
  for __ur_n in "${__ur_notes[@]}"; do __ur_note_str+="${__ur_note_str:+ / }$__ur_n"; done
  __ur_body+="- 注記: $__ur_note_str"$'\n'
fi
__ur_body+="— この集計は Claude Code のセッション記録から機構が機械的に算出したものです"

# ---- 制御方式 4: 状態の更新とレポートの保存 ----
__ur_report="logs/usage/report-$__UR_SAFE-$__ur_count.md"
mkdir -p "$HOOK_WORKTREE/logs/usage" 2>/dev/null || true
printf '%s\n' "$__ur_body" > "$HOOK_WORKTREE/$__ur_report" 2>/dev/null \
  || log_warn "レポートを書けない: $__ur_report"

if hc_lock "usage-$__UR_SAFE"; then
  __ur_state_read
  [[ -n "$__UR_STATE" ]] || __UR_STATE="$(__ur_new_state)"
  # 起点（since_sha / since_at）は書かない。投稿に成功したときだけ boundary.sh が進める（既定 5）。
  # ここで初回 push の HEAD を入れると、集計値には push 前の分が入っているのに集計期間の起点だけが
  # 後ろへずれ、表示と数値が食い違う
  __ur_next="$(printf '%s' "$__UR_STATE" | jq -c --arg h "$PD_HEAD" --argjson c "$__ur_count" '
    .last_push_sha = $h | .push_count = $c
  ' 2>/dev/null || true)"
  [[ -n "$__ur_next" ]] && { hc_json_write "$__UR_FILE" "$__ur_next" || log_warn "usage の状態を書けない"; }
  hc_unlock "usage-$__UR_SAFE"
else
  log_warn "usage-$__UR_SAFE のロックを取れないので状態を更新しなかった"
fi

# ---- 制御方式 6・4: 通知 ----
# 識別子は hook_inject が付けないので本文の先頭に自分で置く（hook_deny / hook_notify は付ける）
__ur_id=WF911
(( __UR_WAS_BROKEN )) && __ur_id=WF913
__ur_msg="$__ur_id: 前回 push からの対応工数を集計した。以下が MR に添える本文。"$'\n\n'
__ur_msg+="$__ur_body"$'\n\n'
__ur_msg+="この本文は $__ur_report に保存した。MR へは boundary.sh request / note が通常コメントとして投稿する（--usage-report $__ur_report を渡す）。フックは投稿しない。"
# 記録は inject（仕様の「記録」節）。note は本文の先頭 200 字（集計値の要約）になる
hook_inject PostToolUse "$__ur_id" "$__ur_msg"
exit 0
