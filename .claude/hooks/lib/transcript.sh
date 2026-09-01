#!/usr/bin/env bash
# transcript.sh — transcript（JSONL）の解析（source 専用）。使用量の集計を 1 関数に閉じる
# 仕様: .claude/docs/10_spec/hooks/22-PostToolUse/post-push-usage-report.md `--accumulate` 2・5（正）、フック共通仕様 §11 HK-T14
# 提供: transcript_aggregate <transcript のパス> [カーソル（処理済み行数。既定 0）] → JSON を 1 行出力
#   {"input","output","cache_read","cache_write","tool_calls","responses","timestamps":[[epoch,"a|r|u"],...],"parse_errors","new_offset"}
#   - カーソル以降の行だけを 1 回の jq で集計し、new_offset（総行数）を次のカーソルにする（二重計上防止）
#   - 壊れた行（JSON でない・usage の無い assistant 行）は飛ばして parse_errors に数える
#   - timestamps は assistant（a）/ tool_result を含む user（r）/ それ以外の user（u）のエポック秒。実作業時間の計算は呼び出し側
#   - ファイル不在・空ファイル・jq 不在は 0 の結果を出して終了 0（jq 不在は戻り 1）
# 注意: transcript の中身をシェル変数や引数に載せない（Windows のコマンドライン長上限）。jq にはファイルパスを渡す

# 直接実行されたら何もしない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi

_tr_zero() { # $1=new_offset
  printf '{"input":0,"output":0,"cache_read":0,"cache_write":0,"tool_calls":0,"responses":0,"timestamps":[],"parse_errors":0,"new_offset":%s}\n' "$1"
}

transcript_aggregate() {
  local p="${1:-}" off="${2:-0}" out
  [[ "$off" =~ ^[0-9]+$ ]] || off=0
  if [[ -z "$p" || ! -f "$p" || ! -s "$p" ]]; then _tr_zero "$off"; return 0; fi
  command -v jq >/dev/null 2>&1 || { _tr_zero "$off"; return 1; }
  out="$(jq -R -n -c --argjson offset "$off" '
    # ISO 8601 → エポック秒。strptime に依存しない（Windows の jq 1.6 では strptime が使えない）。末尾のオフセット（+09:00 等）は差し引く
    def days_from_civil($y; $m; $d):
      (if $m <= 2 then $y - 1 else $y end) as $ya
      | ($ya / 400 | floor) as $era
      | ($ya - $era * 400) as $yoe
      | ((153 * ($m + (if $m > 2 then -3 else 9 end)) + 2) / 5 | floor) as $doy
      | ($yoe * 365 + ($yoe / 4 | floor) - ($yoe / 100 | floor) + $doy + $d - 1) as $doe
      | ($era * 146097 + $doe - 719468);
    def ts_epoch: . as $s
      | try (
          (days_from_civil($s[0:4] | tonumber; $s[5:7] | tonumber; $s[8:10] | tonumber) * 86400
           + ($s[11:13] | tonumber) * 3600 + ($s[14:16] | tonumber) * 60 + ($s[17:19] | tonumber))
          - (if ($s | test("[+-][0-9]{2}:?[0-9]{2}$"))
             then ($s | capture("(?<sg>[+-])(?<hh>[0-9]{2}):?(?<mm>[0-9]{2})$") | ((.hh | tonumber) * 3600 + (.mm | tonumber) * 60) * (if .sg == "-" then -1 else 1 end))
             else 0 end)
        ) catch null;
    def blocks: if type == "array" then .[] else empty end;
    [inputs] as $all
    | ($all | length) as $total
    | ($all[$offset:] | map(sub("\r$"; "")) | map(select(length > 0))) as $lines
    | reduce $lines[] as $l (
        {input: 0, output: 0, cache_read: 0, cache_write: 0, tool_calls: 0, responses: 0, timestamps: [], parse_errors: 0};
        ($l | try fromjson catch null) as $e
        | if $e == null or ($e | type) != "object" then .parse_errors += 1
          elif $e.type == "assistant" then
            .responses += 1
            | (if ($e.message.usage | type) == "object" then
                .input += ($e.message.usage.input_tokens // 0)
                | .output += ($e.message.usage.output_tokens // 0)
                | .cache_read += ($e.message.usage.cache_read_input_tokens // 0)
                | .cache_write += ($e.message.usage.cache_creation_input_tokens // 0)
              else .parse_errors += 1 end)
            | .tool_calls += ([ ($e.message.content // []) | blocks | select(.type == "tool_use") ] | length)
            | (if ($e.timestamp | type) == "string" then .timestamps += [[($e.timestamp | ts_epoch), "a"]] else . end)
          elif $e.type == "user" then
            ([ ($e.message.content // []) | blocks | select(.type == "tool_result") ] | length) as $tr
            | (if ($e.timestamp | type) == "string" then .timestamps += [[($e.timestamp | ts_epoch), (if $tr > 0 then "r" else "u" end)]] else . end)
          else . end)
    | .timestamps |= map(select(.[0] != null))
    | . + {new_offset: $total}
  ' "$p" 2>/dev/null)" || { _tr_zero "$off"; return 0; }
  out="${out//$'\r'/}"
  [[ -n "$out" ]] || { _tr_zero "$off"; return 0; }
  printf '%s\n' "$out"
  return 0
}
