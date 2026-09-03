---
type: ddr
title: i0009-50. サブエージェントは既定で background という前提で設計する
description: 公式が「subagents run in the background by default」と定め PostToolUse Agent が起動直後に発火することが分かり、WF801 には有利・WF811〜813 には不利という前提を仕様に据えた判断
tags: [ddr, hooks, subagent, PostToolUse]
keywords: [background, async_launched, completed, run_in_background, PostToolUse, Agent, WF801, WF811, WF803, i0009-26]
---

# i0009-50. サブエージェントは既定で background という前提で設計する

## 背景

`i0009-06` は「`SubagentStart` に `model` が来ない」ことから実行者の比較を PreToolUse `Agent` に移し、`i0009-26` は「`additionalContext` は `Agent` の結果の隣＝**サブエージェントが走り終わった後**に届く」という理解のもとで WF801 の到達を 2 経路（`systemMessage` + `additionalContext`）にした。`subagent-stop-check` も PostToolUse `Agent` を「サブエージェントが走り終わった後」の経路として使い、そこで WF811〜813（作業中のまま残ったチケット・未コミット差分・範囲外の差分）を伝える設計だった。

ワーク境界の 2 巡目レビューで、この前提が公式と食い違うことが分かった。

- `hooks.md:1701`（`Agent` の `tool_response` の表）: 「`"completed"` for foreground subagents, `"async_launched"` for background subagents. **As of v2.1.198, subagents run in the background by default**, so an omitted `run_in_background` also produces `"async_launched"`」
- `hooks.md:1711`: 「For background subagents, the tool returns when the task moves to the background … a background launch **returns immediately**」
- `hooks.md:1699`: 「When a **foreground** Agent call completes, your PostToolUse hook receives the subagent's final text and run telemetry in `tool_response`」（foreground に限定されている）

つまり**既定では PostToolUse `Agent` は「走り終わった後」ではなく「起動した直後」に発火する**。`.claude/docs/` に background への言及は 1 件も無かった。

## 決定

**サブエージェントは既定で background で走る**という前提を共通仕様 §2 に据える。そのうえで、この違いが 2 つの用途で逆に効くことを明記する。

| 用途 | 起動直後に発火することの意味 |
|---|---|
| **起動の事実に関する通知**（WF801 = 実行者の不一致） | **有利**。サブエージェントがほとんど動かないうちにメインエージェントが気づける。`i0009-26` が「AI へは遅くとも結果と同時に」とした想定より早い |
| **作業後の検査**（WF811〜813） | **成立しない**。起動直後では作業前の作業領域を見ることになる |

- 作業後の検査は `tool_response.status` で分岐する（`i0009-51`）
- **`Agent` の `tool_input` に `run_in_background` は公式の表に無い**（表は `prompt` / `description` / `subagent_type` / `model`）。省略時が background なので、**`tool_input.run_in_background` が明示的に `false` でなければ background として扱う**。この判定は PreToolUse `Agent` で行える
- `subagent-start-check` は、タスクの実施者（`subagent_type = task-executor`）を background で起動しようとしたときに **WF803** を通知する（起動は止めない）。要件にも「完了を待たない形で起動されるとき、その旨と検査が届かないことを伝える」を足す

## 理由

- **前提が違えば設計の帰結が変わる**。WF811〜813 は「サブエージェントが作業を終えた作業領域」を見る設計で、起動直後に見ると常に「該当なし」になる。気づかないまま実装すると、テストは通るのに実運用で何も検知しないフックができる
- **止めるのではなく伝える**。`run_in_background` の既定は Claude Code 側の仕様で、機構が変えられるものではない。タスクの実施者については foreground を促し、それでも background で起動されたら「検査が届かない」ことを伝えるのが、案内側フックとして釣り合う
- **`i0009-26` の結論（17 行維持）は強まる**。`additionalContext` が想定より早く届くので、WF801 の到達はむしろ良くなる。この DDR は `i0009-26` を覆さない
- **判定材料が揃っている**。`tool_response.status` は PostToolUse で、`tool_input.run_in_background` は PreToolUse で読めるので、どちらも追加の入力を要さない

## 却下した案

- **タスクの実施者を background で起動することを禁じる（deny）**: `subagent-start-check` は案内側のフックで、起動を止める設計になっていない。止めるなら `workflow-guard` の制御方式 8（起動は許可）を変えることになり、`i0009-27` の「MCP の種別を強制しない」と同じく、機構が守る対象（作業領域外への書き込み・コミット / push・進行状態）から外れる
- **`subagent-stop-check` の PostToolUse 登録を外し、SubagentStop だけにする**: SubagentStop の出力はメインエージェントに届かない（§12 T1）ので、検査の結果が誰にも見えなくなる
- **background でも検査し、`agent_transcript_path` の完了を待つ**: フックはツール呼び出しごとに起動して終わるプロセスで、待つ手段が無い。待てば `timeout`（fail-open）に落ちる
- **`.claude/agents/` の定義側で foreground を既定にする**: エージェント定義に `run_in_background` の既定を書ける保証が公式に無い。実体の作成は 3/3 の範囲でもある

## 影響

- `10_spec/フック共通仕様.md` §2（background 既定・`tool_response` の名前・`run_in_background` の判定）・§6（WF803 / WF814 を台帳に）・§1 の登録表 7 行目の説明
- `10_spec/hooks/12-SubagentStart/subagent-start-check.md` 制御方式 5（WF803）・限界 2・`SA-T09`
- `10_spec/hooks/13-SubagentStop/subagent-stop-check.md` 概要・呼出条件・`SP-T07`
- `00_requirement/hooks/12-SubagentStart/subagent-start-check.md` メインフロー（background 起動の通知）
- `20_ddr/i0009-26`（`additionalContext` の到達が想定より早いことを追記）
- **フェーズ 4c へ**: `tool_response.status` が実際に `async_launched` になるかを見る
- 関連: `i0009-51`（`status` による分岐）・`i0009-53`（camelCase）
