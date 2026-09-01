#!/usr/bin/env bash
# push-detect.sh — push の検知（source 専用）
# 仕様: .claude/docs/10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md「push 検知」1〜3（正）、フック共通仕様 §11 HK-T13
# 提供: push_detect <コマンド文字列> [tool_response の JSON] [bash|powershell] [リポジトリルート]
#   戻り 0 = push が成功し HEAD が進んだ（PD_BRANCH / PD_HEAD / PD_PREV_SHA / PD_COUNT を置く）、1 = 対象外（PD_REASON に理由）
# 判定: (1) fork ゼロの前置フィルタ（文字列に push を含まなければ外部コマンドを 1 つも起動せずに偽）
#       (2) コマンド列に提供コマンド push.sh か実行位置の git push（cmdpos.sh。縮退時は部分一致）
#       (3) tool_response の終了コードが 0（無ければ 0 とみなす。interrupted は失敗）
#       (4) HEAD == @{upstream}。無ければ origin/<b>、それも無ければ終了コード 0 で反映されたとみなす（縮退）
#       (5) push-state.json[b].sha != HEAD（前回 push 時点から進んでいる。記録が無ければ初回として真）
# 依存: cmdpos.sh（同じディレクトリ。未読み込みなら読む）、jq（tool_response と push-state.json の読み取り。無ければ縮退）

# 直接実行されたら何もしない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi

if ! declare -F cmdpos_parse >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/cmdpos.sh"
fi

PD_PUSH_SH=".claude/skills/20-common-step-commit-push/scripts/push.sh"
PD_BRANCH=""; PD_HEAD=""; PD_PREV_SHA=""; PD_COUNT=0; PD_REASON=""

push_detect() {
  local cmd="${1:-}" resp="${2:-}" shell="${3:-bash}" root="${4:-${HOOK_ROOT:-$PWD}}" lc="${1,,}"
  local code="0" head branch up state prev count
  PD_BRANCH=""; PD_HEAD=""; PD_PREV_SHA=""; PD_COUNT=0; PD_REASON=""
  # (1) 前置フィルタ（fork ゼロ）
  [[ "$lc" == *push* ]] || { PD_REASON="no-push-word"; return 1; }
  # (2) コマンド位置
  cmdpos_parse "$cmd" "$shell"
  if (( CP_DEGRADED )); then
    [[ "$lc" =~ git[[:space:]]+push || "$lc" == *push.sh* ]] || { PD_REASON="degraded-no-push"; return 1; }
  else
    cmdpos_has_provided "$PD_PUSH_SH" || cmdpos_has_git_subcommand push || { PD_REASON="not-a-push"; return 1; }
  fi
  # (3) 終了コード
  if [[ -n "$resp" ]]; then
    if command -v jq >/dev/null 2>&1; then
      code="$(printf '%s' "$resp" | jq -r 'if type == "object" then ((.exit_code // .exitCode // .returnCode // .code // (if .interrupted == true then 1 else 0 end)) | tostring) else "0" end' 2>/dev/null | tr -d '\r')" || code="0"
      [[ "$code" =~ ^[0-9]+$ ]] || code="0"
    else
      [[ "$resp" == *'"interrupted":true'* || "$resp" == *'"interrupted": true'* ]] && code="1"
    fi
  fi
  [[ "$code" == "0" ]] || { PD_REASON="exit-$code"; return 1; }
  # (4) HEAD がリモートに反映されたか
  head="$(git -C "$root" rev-parse HEAD 2>/dev/null)" || { PD_REASON="no-head"; return 1; }
  head="${head//$'\r'/}"
  branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch=""
  branch="${branch//$'\r'/}"
  if up="$(git -C "$root" rev-parse '@{upstream}' 2>/dev/null)"; then
    [[ "${up//$'\r'/}" == "$head" ]] || { PD_REASON="head-not-on-upstream"; return 1; }
  elif [[ -n "$branch" ]] && up="$(git -C "$root" rev-parse "origin/$branch" 2>/dev/null)"; then
    [[ "${up//$'\r'/}" == "$head" ]] || { PD_REASON="head-not-on-origin-branch"; return 1; }
  else
    PD_REASON="degraded-exit-code"   # 上流も origin/<b> も無い: 終了コード 0 で反映されたとみなす（縮退）
  fi
  # (5) 前回 push 時点から進んでいるか
  state="$root/logs/push-state.json"; prev=""; count=0
  if [[ -f "$state" ]] && command -v jq >/dev/null 2>&1; then
    local -a pc=()
    mapfile -t pc < <(jq -r --arg b "$branch" '(.[$b].sha // ""), ((.[$b].count // 0) | tostring)' "$state" 2>/dev/null | tr -d '\r' || true)
    prev="${pc[0]:-}"; count="${pc[1]:-0}"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
  fi
  [[ -n "$prev" && "$prev" == "$head" ]] && { PD_REASON="not-advanced"; return 1; }
  PD_BRANCH="$branch"; PD_HEAD="$head"; PD_PREV_SHA="$prev"; PD_COUNT="$count"
  [[ -z "$PD_REASON" ]] && PD_REASON="pushed"
  return 0
}
