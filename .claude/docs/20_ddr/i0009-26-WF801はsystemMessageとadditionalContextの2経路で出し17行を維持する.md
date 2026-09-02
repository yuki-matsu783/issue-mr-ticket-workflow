---
type: ddr
title: i0009-26. WF801 は systemMessage と additionalContext の 2 経路で出し、登録表 17 行を維持する
description: PreToolUse の additionalContext がツール結果の隣にしか届かず「起動前にメインへ伝える」が実現できないと分かったため、ユーザー向けの systemMessage を併用して 17 行目の登録を正当化した判断
tags: [ddr, hooks, subagent-start-check, WF801]
keywords: [WF801, systemMessage, additionalContext, next to the tool result, PreToolUse, Agent, 17 行, ask]
---

# i0009-26. WF801 は `systemMessage` と `additionalContext` の 2 経路で出し、登録表 17 行を維持する

## 背景

`i0009-06` は「`SubagentStart` に `model` が来ないので、実行者の不一致（WF801）は `Agent` ツールの `tool_input.model` を読める **PreToolUse** で判定する」と決め、これにより §1 の登録表が 16 行 → **17 行**になった。決定の根拠は「**起動前に伝えれば、メインエージェントは止めて正しいモデルで起動し直せる**」だった。

設計ワークの境界レビュー（付録 A の S1）が、この根拠を否定する公式の記述を見つけた。

> `additionalContext` … Where the reminder appears depends on the event:
> * **PreToolUse**, PostToolUse, PostToolUseFailure, and PostToolBatch: **next to the tool result**

> Claude reads the reminder on **the next model request**, but it doesn't appear as a chat message in the interface.

つまり PreToolUse に登録しても、`additionalContext` が入るのは **`Agent` ツールの結果の隣**で、メインエージェントが読むのは**サブエージェントが走り終わった後**。`i0009-06` が却下案 (a)（事後通知に一本化）に付けた欠点「走り終わってから分かる」は、採用した案 (c) にもそのまま当てはまっていた。

一方で、同じ JSON 出力の**トップレベル `systemMessage`** は公式が「**Warning message shown to the user**」と定めており、ほぼ全イベントで有効で、AI ではなく**ユーザーにその場で表示される**。

## 決定

- **登録表 17 行を維持する**（PreToolUse `Agent` の登録を残す）
- WF801 を **2 経路**で出す:
  - **`systemMessage`**: ユーザーに即時表示。**サブエージェントが動き出す前に人間が気づける唯一の経路**で、中断して起動し直せる
  - **`additionalContext`**: メインエージェントへ。届くのは `Agent` の結果と同時（事後）
- 仕様に「**メインエージェントに起動前に伝えることは Claude Code の仕様上できない**」を限界 2 として明記する
- 要件を精密化する: 「**サブエージェントが動き出す前にユーザーへ**伝え、**AI へは遅くとも結果と同時に**伝える。AI に起動前に伝えることは実行基盤の仕組み上できないため、これを求めない」
- **`permissionDecision: "ask"` は採らない**（下記）

## 理由

- **`systemMessage` は事後通知では代替できない**。`subagent-stop-check`（PostToolUse `Agent`）でも `systemMessage` は出せるが、それはサブエージェントが走り終わった後。ユーザーが**止められる**のは PreToolUse だけで、ここに 17 行目の価値が残る
- `additionalContext` を併せて出すのは、ユーザーが席を外しているときに AI が結果を見て気づけるようにするため。2 経路は重複ではなく、受け手（人間 / AI）と時点（起動前 / 事後）が違う
- 要件が「実現できないこと」を求めたまま残るのが一番まずい。**達成できる形に要件を直す**方が、達成できないまま仕様で言い訳するより誠実

## 却下した案

- **案 (a) に戻す（事後通知に一本化・16 行）**: `systemMessage` によるユーザーへの即時警告が失われる。人間が止める機会がゼロになり、`i0009-06` が案 (a) を却下した理由（半分しか果たさない）が今度こそ当たる
- **`permissionDecision: "ask"` にして起動を止める**: 「動き出す前に伝える」を最も強く満たすが、(1) 判定はモデル名の正規化に依存する推定で誤警告の余地がある、(2) ヘッドレスでは `ask` が `deny` に化けるので（§10）、誤警告がそのままサブエージェントの起動不能になる、(3) WF801 は「通知」として設計されており（要件「起動を妨げてはならない」）、`ask` にすると識別子の種別・拒否側の登録数・ラッパーの扱いがすべて変わる
- **`continue: false` で止める**: セッション全体が止まる。過剰
- **要件を「起動の直後に伝える」に緩めて 16 行に戻す**: 人間が止める機会を捨てることになる。`systemMessage` という手段がある以上、捨てる理由が無い

## 影響

- `10_spec/hooks/12-SubagentStart/subagent-start-check.md` 入出力・制御方式 4・限界 2・縮退・WF801 の説明・SA-T02
- `00_requirement/hooks/12-SubagentStart/subagent-start-check.md` メインフロー（到達の時点）
- `10_spec/フック共通仕様.md` §3（`systemMessage` の行を追加・PreToolUse の到達時点の注記）
- §1 の登録表は **17 行のまま**（`i0009-06` の結論を維持）
