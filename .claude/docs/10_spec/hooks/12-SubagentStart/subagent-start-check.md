---
type: spec
title: subagent-start-check フック 仕様
description: サブエージェント起動時に、対象チケット（作業中、無ければ未着手の先頭）の executor と起動モデルの不一致を通知し、チケットの要点（名前・種類・やってよいこと・DoD）を注入するフックの内部仕様。起動は妨げない。WF80x を定める
tags: [spec, hook, subagent-start-check]
keywords: [SubagentStart, 実行者, executor, model, 不一致, 通知, 注入, additionalContext, 対象チケット, やってよいこと, DoD, WF801, WF802]
---

# subagent-start-check フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/12-SubagentStart/subagent-start-check.md](../../../00_requirement/hooks/12-SubagentStart/subagent-start-check.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)（§9 チケット frontmatter）。

案内側のフック。対象チケットは `10_doing/` の 1 枚、無ければ `00_todo/` の最小連番（チケットは 1 枚ずつ進むため次に実施されるもの — DDR i0001-23）。

禁止事項:

- 起動の拒否
- チケット本文の全文・他ファイルの注入
- 起動モデルが特定できないときの通知（誤警告を出さない）
- チケットが読めないときの通知

## 呼出条件（イベント・matcher・登録）

- **SubagentStart（全サブエージェント）**: 対象チケットの要点の注入（WF802）。`adversarial-reviewer` の起動でも働くが、注入する内容は同じ（レビュー対象の範囲を知る材料になる）
- **PreToolUse、matcher `Agent`**: 実行者の不一致（WF801）の検知。同じスクリプトを 2 つのイベントに登録し、イベント名（`hook_event_name`）で処理を分ける。`SubagentStart` の入力に `model` は来ない（公式は「`model` を受け取れるのは `SessionStart` だけ」と明記）ため、比較の材料が取れるのは `Agent` ツールの `tool_input.model` を読める PreToolUse だけ（DDR i0009-06）
- この 2 行目の登録により、フック共通仕様 §1 の登録表は **17 行**になった（PreToolUse の 7 行目。0014 で確定）

## 入出力

- 入力: SubagentStart では `agent_id`・`agent_type`（`model` は**来ない**）。PreToolUse `Agent` では `tool_input.model`・`tool_input.subagent_type`（どちらも `hook_read_input` が `HOOK_MODEL` / `HOOK_SUBAGENT_TYPE` に入れる）。参照: 対象チケットの frontmatter（`executor`、`ticket_type`、`allow`）と本文の DoD 節
- 出力: SubagentStart の additionalContext（サブエージェントのコンテキストへ要点を注入）と、PreToolUse `Agent` の **`systemMessage` + `additionalContext` の 2 経路**（WF801）。**届く時点が違う**ことに注意する（DDR i0009-26）:
  - **`systemMessage`**（公式「Warning message shown to the user」）は**ユーザーにその場で表示**される。**サブエージェントが動き出す前に人間が気づける唯一の経路**で、ユーザーは中断して起動し直せる
  - **`additionalContext`** は公式が「PreToolUse … **next to the tool result**」「Claude reads the reminder on the next model request」と定めるとおり、**`Agent` ツールの結果の隣**に入る。つまりメインエージェントが読むのは**サブエージェントが走り終わった後**。PreToolUse に登録しても、メインエージェントへの到達は事後になる
  - PreToolUse の通知は起動を止めない（`permissionDecision` を出さない）。あわせて `decisions.jsonl` に `notify` で記録する

## 制御方式

1. 停止中 → `disabled` を記録して何もしない
2. 対象チケットを決める。無ければ何もしない
3. frontmatter が読めない・`executor` が解釈できない → 何もしない
4. **不一致（PreToolUse `Agent` のときだけ）**: `tool_input.subagent_type` が**タスク実施者**（`task-executor`）で、`executor` が `main` 以外で、`tool_input.model` が特定でき、正規化（`claude-sonnet-4-5-...` → `sonnet` のように族名で比較。対応表は `.claude/hooks/config/model-aliases.txt`。フックが読む外部データの置き場はフック共通仕様 §1）した値が異なる → **WF801** を **`systemMessage` と `additionalContext` の両方**に書き、`decisions.jsonl` に `notify` で記録（`note` にチケット・実行者・起動モデル・`subagent_type`）。**起動は止めない**（通知であり `permissionDecision` は出さない）
   - **`subagent_type` による絞り込み**: チケットの `executor` は**タスクの実施者**に対する指定であって、レビュアーや探索エージェントには当てはまらない。`adversarial-reviewer` / `Explore` などを別のモデルで起動するのは正当なので、`task-executor` 以外では判定しない（誤警告を出さない — 禁止事項。DDR i0009-32）
   - **限界 1**: `Agent` ツールの `model` は任意引数で、省略時は「エージェント定義のモデル」が使われる。省略された起動では `tool_input.model` が空になり**比較そのものができない**（何も出さない）。この限界は経路（PreToolUse / SubagentStart / PostToolUse）を変えても解消しない
   - **限界 2**: **メインエージェントに起動前に伝えることは Claude Code の仕様上できない**（`additionalContext` はどのイベントでもツール結果の隣かそれ以降にしか入らない）。起動前に届くのは `systemMessage` によるユーザーへの表示だけで、止めるかどうかは人間が決める。`permissionDecision: "ask"` にすれば起動を止められるが採らない（DDR i0009-26 の却下案）
   - SubagentStart のときは不一致の判定を行わない（`model` が来ないため）
5. **注入（SubagentStart のときだけ）**: `WF802` として、チケット名（`<連番>-<種類>`）/ タスクの種類 / やってよいこと（`allow.write` と `allow.ops` をそのまま）/ DoD（`- [ ]` 行だけ。根拠欄は除く）を注入する。合計 4 KB を超える DoD は件数と先頭 10 件にする
6. 入力が解釈できない → 何もしない（起動を止めない）

- **縮退（PreToolUse で `systemMessage` も `additionalContext` も届かない版）**: PreToolUse の登録を外し、実行者の不一致は `subagent-stop-check`（PostToolUse `Agent`）が事後に WF801 を通知する経路だけにする（ユーザーも起動前には気づけない。この場合 §1 は 16 行に戻る）。この縮退に落ちたときだけ、`subagent-stop-check` の再掲が唯一の通知経路になる（DDR i0009-31）
- **縮退（SubagentStart イベントが使えない版）**: SubagentStart の登録を外し、要点の注入は起動プロンプト（`00-workflow-issue-mr-driven` の `assets/subagent-prompt.template.md`）だけを経路とする。不一致の検知（PreToolUse `Agent`）はそのまま残る

## エラー識別子とメッセージ

| ID | 種別 | 内容 |
|----|------|------|
| WF801 | 通知 | 実行者の不一致: チケットの `executor` / 起動したモデル / 対象チケット。`systemMessage`（ユーザーへ即時）と `additionalContext`（メインエージェントへ、`Agent` の結果と同時）の 2 経路で出す。続けるか起動し直すかは、ユーザー（起動前）または AI（結果を見た後）がチケットに従って判断する |
| WF802 | 情報 | 対象チケットの要点の注入 |

## 回復手順

- WF801: メインエージェントがサブエージェントを止めて正しいモデルで起動し直す（`00-workflow-issue-mr-driven` 手順 2-3）。実行者を変えたいなら未着手チケットの見直しで `executor` を直す（作業中のチケットは `workflow-guard` が改変を拒否する）

## 記録（logs/）

- `decisions.jsonl`: `notify`（WF801）/ `inject`（WF802。`note` に対象チケットと注入バイト数）/ `skip`（対象なし・モデル不明・読めない）
- 実行ログ: `logs/sh/hook-subagent-start-check.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| SA-T01 | 正常系 | 機械テスト。作業中チケットの executor=sonnet で、PreToolUse `Agent` の `tool_input.model`=claude-sonnet-… なら通知なし。SubagentStart では要点が注入される |
| SA-T02 | 異常系 | 機械テスト。**PreToolUse `Agent`** で `subagent_type=task-executor`・executor=opus・`tool_input.model`=sonnet のとき WF801 が **`systemMessage` と `additionalContext` の両方**に出て記録に残る。起動は止まらない（`permissionDecision` を出さず終了 0） |
| SA-T07 | 正常系 | 機械テスト。`subagent_type` が `task-executor` 以外（`adversarial-reviewer` / `Explore`）のときは、executor とモデルが食い違っていても**通知しない**（誤警告を出さない。負のコントロールとして `task-executor` では出ることを同じテストで確かめる） |
| SA-T03 | 正常系 | 作業中が無く未着手の先頭が対象になる。チケットが 1 枚も無ければ無出力 |
| SA-T04 | 正常系 | 機械テスト。`tool_input.model` が無い（`Agent` の `model` を省略した）起動で通知なし。SubagentStart の入力（`model` が来ない）でも通知は出さず、要点の注入だけを行う |
| SA-T05 | 正常系 | frontmatter が壊れたチケットで無出力・終了 0 |
| SA-T06 | 境界 | DoD が 4 KB 超で件数と先頭 10 件に縮む。本文の作業ログは注入されない |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: executor と起動モデルの比較・通知・記録 | 制御方式 4、WF801 |
| メイン: 起動を妨げない | 禁止事項 |
| メイン: 一致・対象なし・記載なしは通知しない | 制御方式 2〜4 |
| メイン: モデル不明は通知しない | 制御方式 4 |
| メイン: 要点の注入（全文は注入しない） | 制御方式 5、WF802 |
| メイン: 対象なしは注入しない | 制御方式 2 |
| メイン: 記録・識別子 | 記録、エラー識別子 |
| 代替: 緊急停止 | 制御方式 1 |
| 例外: チケット不読・入力不正は通す | 制御方式 3・6 |
