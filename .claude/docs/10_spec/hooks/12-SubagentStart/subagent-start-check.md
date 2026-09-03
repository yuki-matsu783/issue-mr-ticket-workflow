---
type: spec
title: subagent-start-check フック 仕様
description: サブエージェント起動時に、対象チケット（作業中、無ければ未着手の先頭）の要点（名前・種類・やってよいこと・DoD）をサブエージェントのコンテキストに注入するフックの内部仕様。起動は妨げない。WF802 を定める
tags: [spec, hook, subagent-start-check]
keywords: [SubagentStart, 注入, additionalContext, 対象チケット, やってよいこと, DoD, WF802, hook_inject, 公開 API, 実行者, resolvedModel]
---

# subagent-start-check フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/12-SubagentStart/subagent-start-check.md](../../../00_requirement/hooks/12-SubagentStart/subagent-start-check.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)（§9 チケット frontmatter）。

案内側のフック。対象チケットは `10_doing/` の 1 枚、無ければ `00_todo/` の最小連番（チケットは 1 枚ずつ進むため次に実施されるもの — DDR i0001-23）。

**このフックが担うのは要点の注入（WF802）だけ**で、実行者の不一致（WF801）と background 起動（WF814）の通知は `subagent-stop-check` が PostToolUse `Agent` で**起動後に**行う。起動前に伝える経路は持たない: `systemMessage` は対話 UI でユーザーに表示されず、`additionalContext` はどのイベントでもツール結果の隣かそれ以降にしか入らない（共通仕様 §3）。一方 **PostToolUse `Agent` の `tool_response.resolvedModel` には実際に使われたモデルが載る**ので、起動時にモデルを明示しない呼び出し（`tool_input.model` が空になる）でも、実行者の比較は起動後なら行える。

禁止事項:

- 起動の拒否
- チケット本文の全文・他ファイルの注入
- チケットが読めないときの通知
- `hook-common` の private 関数（`__hc_*`）を直に呼ぶこと（出力の組み立ては公開 API を通す。§入出力）

## 呼出条件（イベント・matcher・登録）

- **SubagentStart（全サブエージェント。matcher なし）**: 対象チケットの要点の注入（WF802）。`adversarial-reviewer` の起動でも働くが、注入する内容は同じ（レビュー対象の範囲を知る材料になる）
- 登録はこの 1 行だけで、**PreToolUse `Agent` には登録しない**（共通仕様 §1 の登録表）

## 入出力

- 入力: `agent_id`・`agent_type`（`model` は**来ない**。公式は「`model` を受け取れるのは `SessionStart` だけ」と明記）。参照: 対象チケットの frontmatter（`ticket_type`、`allow`）と本文の DoD 節
- 出力: SubagentStart の additionalContext（`hook_inject`）。`systemMessage` は出さない
- **出力は `hook-common` の公開 API を通す**（`hook_inject` / `hook_notify` / `hook_record`）。`systemMessage` と `additionalContext` の **2 経路を同時に出す**必要が生じたときも、その 2 経路をまとめて出す**公開 API を `hook-common` に設けて**使う。マスク（`redact`）と JSON エスケープの規則をフック側に複製しないため、private 関数（`__hc_redact_to_reply` / `__hc_json_str`）をフックから直に呼ばない

## 制御方式

1. 停止中 → `disabled` を記録して何もしない
2. 対象チケットを決める。無ければ何もしない（`skip` を理由つきで記録する）
3. frontmatter が読めない → 何もしない（`skip`）
4. **注入**: `WF802` として、チケット名（`<連番>-<種類>`）/ タスクの種類 / やってよいこと（`allow.write` と `allow.ops` をそのまま）/ DoD（`- [ ]` 行だけ。根拠欄は除く）を注入する。合計 4 KB を超える DoD は件数と先頭 10 件にする
5. 入力が解釈できない → 何もしない（起動を止めない）

- **縮退（SubagentStart イベントが使えない版）**: 登録を外し、要点の注入は起動プロンプト（`00-workflow-issue-mr-driven` の `assets/subagent-prompt.template.md`）だけを経路とする

## エラー識別子とメッセージ

| ID | 種別 | 内容 |
|----|------|------|
| WF802 | 情報 | 対象チケットの要点の注入（チケット名 / タスクの種類 / やってよいこと / DoD） |

## 回復手順

- WF802 は情報で、回復手順を持たない。注入が働かない実行形態では起動プロンプトが唯一の経路になる（縮退）
- 実行者の不一致に気づいたときの回復（サブエージェントを止めて正しいモデルで起動し直す。`00-workflow-issue-mr-driven` 手順 2-3）は `subagent-stop-check` の WF801 が案内する。実行者を変えたいなら未着手チケットの見直しで `executor` を直す（作業中のチケットは `workflow-guard` が改変を拒否する）

## 記録（logs/）

- `decisions.jsonl`: `inject`（WF802。`note` に対象チケットと注入バイト数）/ `skip`（対象なし・チケットが読めない）/ `disabled`（停止中）
- 実行ログ: `logs/sh/hook-subagent-start-check.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| SA-T01 | 正常系 | 機械テスト。SubagentStart で作業中チケットの要点（チケット名・種類・やってよいこと・DoD）が additionalContext に注入される |
| SA-T03 | 正常系 | 作業中が無く未着手の先頭が対象になる。チケットが 1 枚も無ければ無出力 |
| SA-T04 | 正常系 | 機械テスト。SubagentStart の入力に `model` が来なくても注入だけを行い、実行者に関する通知を出さない |
| SA-T05 | 正常系 | frontmatter が壊れたチケットで無出力・終了 0 |
| SA-T06 | 境界 | DoD が 4 KB 超で件数と先頭 10 件に縮む。本文の作業ログは注入されない |
| SA-T08 | 正常系 | 機械テスト。注入したときは `decisions.jsonl` に `inject`、注入しなかったときも `skip` が理由つき（対象チケット無し / チケットが読めない）で残る |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: executor と起動モデルの比較・通知・記録 | `subagent-stop-check` 制御方式 2、WF801（このフックは行わない） |
| メイン: 起動前にユーザーへ / AI へは結果と同時（どちらも使えない版は事後の通知に縮退してよい） | 事後の通知に縮退している（概要）。起動前の経路は持たない |
| メイン: 起動を妨げない | 禁止事項 |
| メイン: 一致・対象なし・記載なしは通知しない | `subagent-stop-check` 制御方式 2 |
| メイン: タスクの実施者でないときは通知しない | `subagent-stop-check` 制御方式 2（`subagent_type` による絞り込み） |
| メイン: モデル不明は通知しない | `subagent-stop-check` 制御方式 2 |
| メイン: background 起動の通知（起動は妨げない） | `subagent-stop-check` の WF814 |
| メイン: 要点の注入（全文は注入しない） | 制御方式 4、WF802 |
| メイン: 対象なしは注入しない | 制御方式 2 |
| メイン: 記録・識別子 | 記録、エラー識別子 |
| 代替: 緊急停止 | 制御方式 1 |
| 例外: チケット不読・入力不正は通す | 制御方式 3・5 |
