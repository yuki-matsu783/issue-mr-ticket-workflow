---
type: ddr
title: i0009-06. WF801 は PreToolUse の Agent で起動前に判定し、登録表を 17 行にする
description: SubagentStart の入力に model が来ないことが公式で確認されたため、実行者の不一致の検知を PreToolUse Agent の tool_input.model に移し、フック共通仕様 §1 の登録表を 16 行から 17 行にすると決めた判断
tags: [ddr, hooks, subagent-start-check, subagent-stop-check]
keywords: [WF801, model, SubagentStart, PreToolUse, Agent, tool_input.model, additionalContext, 登録表, 17 行, HK-T01]
---

# i0009-06. WF801 は PreToolUse の Agent で起動前に判定し、登録表を 17 行にする

## 背景

`subagent-start-check` の制御方式 4 は、SubagentStart の入力の `model` とチケットの `executor` を比較して WF801（実行者の不一致）を通知する設計だった。issue #9 の調査 0007 f2 で、公式 hooks リファレンス（`hooks.md` L743）が「Only `SessionStart` hooks can receive a `model` field, and Claude Code doesn't always include it.」と明記していることが分かり、**SubagentStart では `model` が構造的に来ない**ことが確定した。

比較の材料になるのは `Agent` ツールの `tool_input.model` で、これを読めるのは PreToolUse（起動前）と PostToolUse（起動後）。`hook_read_input` は既に `.tool_input.model // .model` を読んで `HOOK_MODEL` に入れる。PreToolUse で `additionalContext` を返せることは公式（`hooks.md` L1747）で確認済み。

## 決定

- **WF801 の本線は PreToolUse、matcher `Agent`**。`subagent-start-check` を SubagentStart と PreToolUse `Agent` の 2 か所に登録し、イベント名で処理を分ける（SubagentStart = 要点の注入 WF802、PreToolUse = 不一致の通知 WF801）
- これにより **フック共通仕様 §1 の登録表は 16 行 → 17 行**になる。確定と HK-T01・段階登録の割り当ての組み直しは 0014・0016 が行う
- `subagent-stop-check`（PostToolUse `Agent`）の WF801 の再掲は**事後の保険**として残す。PreToolUse の経路が使えない縮退のときだけ唯一の通知経路になる
- **どの経路でも共通の限界**を仕様に明記する: `Agent` ツールの `model` は任意引数で、省略時はエージェント定義のモデルが使われる。省略された起動では `tool_input.model` が空になり比較そのものができない

## 理由

- WF801 の目的は「間違ったモデルで作業が進むのを防ぐ」ことで、起動後に伝えても作業は終わっている。起動前に伝えれば、メインエージェントは止めて正しいモデルで起動し直せる
- 登録が 1 行増える代償は小さい。フックのスクリプトは 1 本のままで、`workflow-entry` が既に 3 か所に登録されている前例がある
- SubagentStart の登録を残すのは要点の注入（WF802）のためで、こちらは `model` を必要としない

## 却下した案

- **(a) 事後通知に一本化する（`subagent-stop-check` だけ）**: §1 を増やさずに済むが、サブエージェントが走り終わってから不一致が分かる。WF801 の目的を半分しか果たさない
- **(b) SubagentStart で `model` があれば使い、無ければ通知しない（現行の既定）**: 公式が「来ない」と明記している以上、この分岐は永久に成立しない死んだコードになる
- **`workflow-guard` の PreToolUse `Agent` の判定に相乗りする**: `workflow-guard` は拒否側で、案内（additionalContext）を出す経路を持たない。§3 の側の分離が崩れる

## 影響

- `10_spec/hooks/12-SubagentStart/subagent-start-check.md` 呼出条件・入出力・制御方式 4・5・縮退・SA-T01/T02/T04
- `00_requirement/hooks/12-SubagentStart/subagent-start-check.md` 受け入れ基準（起動前に伝える・モデルを特定できない場合）
- `10_spec/hooks/13-SubagentStop/subagent-stop-check.md` 概要（WF801 の再掲は保険）
- **0014 へ**: フック共通仕様 §1 の登録表（17 行）・§2（`model` は SessionStart のみ）・§3（PreToolUse の通知経路）・§6 台帳の WF801 の持ち主・§12 T4
- **0016 へ**: 段階登録の割り当て（① 記録・案内側の行数が 1 増える）と HK-T01 の期待値
