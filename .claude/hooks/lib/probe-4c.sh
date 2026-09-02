#!/usr/bin/env bash
# probe-4c.sh — TBD 4c の実測プローブ（source 専用）。
#
# **一時の仕組み**。0031 で人間が `WORKFLOW_PROBE_4C=1` を設定した新しいセッションを起動して実測し、
# T1〜T4 / T9 の結論が出たら **この 1 ファイルと各フックの `probe_4c` の呼び出し 1 行を削除する**。
#
# なぜ要るか: `decisions.jsonl` は §5 で 10 キー固定なので `permission_mode` / `model` /
# `tool_response` / `agent_type` を入れる場所が無い。`systemMessage` を出す WF801 / WF803 は
# `subagent_type` が `task-executor`（`.claude/agents/` は空で実装が無い）で `executor` が main 以外の
# ときにしか発火しないので、そのままでは T9（systemMessage が届くか）が測れない。
#
# 既定（環境変数なし）では**一切の副作用が無い**（先頭の 1 行で戻る）。テストで固定する。
#
# 落とすもの:
#   (a) 値を落とす 7 フィールド（DoD で列挙したものに限る）:
#       tool_response.status / tool_response.agentId / agent_type / model /
#       permission_mode / source / tool_input.run_in_background
#   (b) それ以外のキーは**名前と型だけ**（値は落とさない）。`jq` の `paths(scalars)` で葉のパスを取る
#   文脈（ts / session_id / hook / event / tool）は `decisions.jsonl` が既に持つ項目と同じなので足す

__P4C_MAX_KEYS=2000   # キーの一覧が長すぎる入力で走査に時間をかけない

# probe_4c — 入力を読み込んだ直後・早期 return より前に呼ぶ。
# 早期 return の後ろに置くと、その経路（session-start が boundary.sh 不在で黙って抜ける等）の
# 記録が 1 行も残らず、測りたい `source` の値が取れない
probe_4c() {
  [[ "${WORKFLOW_PROBE_4C:-0}" == "1" ]] || return 0

  local keys="" line ts
  # キーの名前と型だけ（値は取らない）。プローブ時だけの jq なので、既定のホットパスの回数には影響しない
  if [[ -n "${HOOK_INPUT:-}" ]] && command -v jq >/dev/null 2>&1; then
    keys="$(printf '%s' "$HOOK_INPUT" \
      | jq -r --argjson max "$__P4C_MAX_KEYS" \
          '[paths(scalars) as $p | (($p | map(tostring) | join(".")) + ":" + (getpath($p) | type))]
           | sort | .[0:$max] | join(",")' 2>/dev/null)" || keys=""
  fi

  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  local -a kv=()
  __p4c_add() { __hc_json_str "${2:-}"; kv+=("\"$1\":\"$REPLY\""); }
  __p4c_add ts "$ts"
  __p4c_add session_id "${HOOK_SESSION_ID:-}"
  __p4c_add hook "${HOOK_NAME:-}"
  __p4c_add event "${HOOK_EVENT:-}"
  __p4c_add tool "${HOOK_TOOL:-}"
  # ---- 値を落とす 7 フィールド ----
  __p4c_add response_status "${HOOK_RESPONSE_STATUS:-}"
  __p4c_add response_agent_id "${HOOK_RESPONSE_AGENT_ID:-}"
  __p4c_add agent_type "${HOOK_AGENT_TYPE:-}"
  __p4c_add model "${HOOK_MODEL:-}"
  __p4c_add permission_mode "${HOOK_PERMISSION_MODE:-}"
  __p4c_add source "${HOOK_SOURCE:-}"
  __p4c_add run_in_background "${HOOK_RUN_IN_BACKGROUND:-}"
  # ---- それ以外は名前と型だけ ----
  __p4c_add keys "$keys"
  unset -f __p4c_add

  local IFS=','
  line="{${kv[*]}}"
  # hc_append_jsonl 経由にするのは redact と 4 KB の切り詰めを得るため。
  # 並列のフックが 4 KB を超える行を書くと JSONL が割れる
  hc_append_jsonl "$HOOK_WORKTREE/logs/hooks/probe-4c.jsonl" "$line" || true
  return 0
}

# probe_4c_enabled — 呼び手が「プローブ時だけの追加の振る舞い」を分けるための述語。
# subagent-start-check が Agent の呼び出しで無条件に systemMessage を 1 つ出す経路（DoD の (b)）に使う
probe_4c_enabled() { [[ "${WORKFLOW_PROBE_4C:-0}" == "1" ]]; }
