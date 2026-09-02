---
type: ddr
title: i0009-53. tool_response のフィールド名は camelCase で、イベント入力側とは違う
description: tool_response の識別子が agentId（camelCase）でイベント共通入力の agent_id（snake_case）と別物であることを確認し、両者を取り違えない書き方を仕様に定めた判断
tags: [ddr, hooks, subagent-stop-check, 命名]
keywords: [tool_response, agentId, agent_id, camelCase, snake_case, status, resolvedModel, 取り違え]
---

# i0009-53. `tool_response` のフィールド名は camelCase で、イベント入力側とは違う

## 背景

`subagent-stop-check` の仕様は、PostToolUse `Agent` で「直近の記録（`tool_response` の **`agent_id`** に対応するもの）を読む」と書いていた。公式を読み直すと、`tool_response` が持つのは **`agentId`**（camelCase）である。

- `hooks.md:1702`（`Agent` の `tool_response` の表）: 「`agentId` | string | Identifier for the subagent run」。同じ表に `status` / `content` / `resolvedModel` / `modelsUsed` / `totalTokens` / `totalDurationMs` / `totalToolUseCount` / `usage` が並ぶ（すべて camelCase）
- 一方、イベントの共通入力フィールドは snake_case（`session_id` / `transcript_path` / `hook_event_name`）で、SubagentStop の追加フィールドも `agent_id` / `agent_type` / `agent_transcript_path` / `last_assistant_message`（`hooks.md:2325`）

つまり**同じ「サブエージェントの識別子」を指す名前が、経路によって `agentId` と `agent_id` に分かれている**。`i0009-52` で `subagent-stop-check` の縮退判定が `agentId` による記録の引き当てに依存するようになったため、取り違えると**記録が常に見つからず、毎回「縮退」と判定して WF801 を重複して出す**。

## 決定

- 共通仕様 §2 に「**`tool_response` のフィールド名は camelCase**（`status` / `agentId` / `content` / `resolvedModel` / `totalTokens` / `usage` …）。イベントの共通入力フィールド側は snake_case（`agent_id` / `agent_transcript_path`）で、**同じものを指す名前が経路によって違う**」と書く
- `subagent-stop-check` の概要・呼出条件・入出力の `agent_id` を、PostToolUse 経路については `tool_response.agentId` に直す（SubagentStop 経路の `agent_id` はそのまま）
- `SP-T08` に「`tool_response.agentId`（camelCase）で記録を引くこと — `agent_id` では引けない」を書く

## 理由

- **失敗が静かに起きる**。存在しないキーを `jq` で引けば `null` が返るだけで、エラーにならない。「記録が無い」＝「縮退」と解釈されるので、**常に縮退として振る舞う**という一貫した誤りになり、テストを書かない限り気づけない
- **命名の不統一は公式の仕様なので、こちらが合わせるしかない**。`tool_response` はツールが返す値をそのまま渡す枠で、ツール側の命名（camelCase）が出る。共通入力フィールドはフックの枠組みが決める（snake_case）
- **1 か所に書いておけば他のフックにも効く**。`post-push-*` が `tool_response.stdout` を読む（§12 T7）ように、`tool_response` を読むフックは他にもある

## 却下した案

- **`hook-common.sh` で `tool_response` のキーを snake_case に正規化する**: 公式の名前と仕様書の名前が食い違い、原本と突き合わせるときに毎回変換が要る。`i0009-46` で `hook_read_input` に寄せた読み取りの中で、キー名は公式のまま扱う
- **`agent_id`（イベント入力側）で記録を引く**: SubagentStop の記録は `agent_id` で書かれるので一見合うが、PostToolUse `Agent` のイベント入力には `agent_id` が無い（`Agent` を呼んだのはメインエージェントで、そのイベント自身はサブエージェントのものではない）。引く手段が `tool_response` しかない
- **両方のキーを試す（`agentId // agent_id`）**: 動くが、どちらが正かを仕様が決めていない状態を実装で埋めることになる。将来どちらかが変わったときに気づけない

## 影響

- `10_spec/フック共通仕様.md` §2（命名の違い）
- `10_spec/hooks/13-SubagentStop/subagent-stop-check.md` 概要・呼出条件・入出力・`SP-T08`
- **実装フェーズへ**: `tool_response` を読む他のフック（`post-push-*`）も公式の名前をそのまま使う
- 関連: `i0009-52`（縮退判定が `agentId` に依存する）・`i0009-50`（`status` も同じ表のフィールド）
