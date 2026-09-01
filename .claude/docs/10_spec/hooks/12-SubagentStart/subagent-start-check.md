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

- SubagentStart（全サブエージェント）。`adversarial-reviewer` の起動でも働くが、対象チケットの要点の注入は同じ（レビュー対象の範囲を知る材料になる）

## 入出力

- 入力: `agent_id`、`agent_type`、`model`（無い版では不一致の比較を行わない）。参照: 対象チケットの frontmatter（`executor`、`ticket_type`、`allow`）と本文の DoD 節
- 出力: SubagentStart の additionalContext（サブエージェントのコンテキストへ注入）。不一致はメインエージェントにも届く必要があるため、`decisions.jsonl` に記録し、`subagent-stop-check`（PostToolUse `Agent`）がその記録を拾って WF801 をメイン側に再掲する

## 制御方式

1. 停止中 → `disabled` を記録して何もしない
2. 対象チケットを決める。無ければ何もしない
3. frontmatter が読めない・`executor` が解釈できない → 何もしない
4. **不一致**: `executor` が `main` 以外で、入力の `model` が特定でき、正規化（`claude-sonnet-4-5-...` → `sonnet` のように族名で比較。対応表は `assets/model-aliases.txt`）した値が異なる → **WF801** を additionalContext の先頭に書き、`decisions.jsonl` に `notify` で記録（`note` にチケット・実行者・起動モデル）
5. **注入**: `WF802` として、チケット名（`<連番>-<種類>`）/ タスクの種類 / やってよいこと（`allow.write` と `allow.ops` をそのまま）/ DoD（`- [ ]` 行だけ。根拠欄は除く）を注入する。合計 4 KB を超える DoD は件数と先頭 10 件にする
6. 入力が解釈できない → 何もしない（起動を止めない）

- **縮退（SubagentStart イベントが使えない版）**: 登録を外し、要点の注入は起動プロンプト（`00-workflow-issue-mr-driven` の `assets/subagent-prompt.template.md`）だけを経路とする。実行者の不一致は `subagent-stop-check`（PostToolUse `Agent`）が `tool_input.model` と対象チケットの `executor` を比較して事後に WF801 を通知する（起動前には気づけないことを共通仕様 §12 T4 に記録）

## エラー識別子とメッセージ

| ID | 種別 | 内容 |
|----|------|------|
| WF801 | 通知 | 実行者の不一致: チケットの `executor` / 起動したモデル / 対象チケット。続けるか起動し直すかは AI がチケットに従って判断する |
| WF802 | 情報 | 対象チケットの要点の注入 |

## 回復手順

- WF801: メインエージェントがサブエージェントを止めて正しいモデルで起動し直す（`00-workflow-issue-mr-driven` 手順 2-3）。実行者を変えたいなら未着手チケットの見直しで `executor` を直す（作業中のチケットは `workflow-guard` が改変を拒否する）

## 記録（logs/）

- `decisions.jsonl`: `notify`（WF801）/ `inject`（WF802。`note` に対象チケットと注入バイト数）/ `skip`（対象なし・モデル不明・読めない）
- 実行ログ: `logs/sh/hook-subagent-start-check.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| SA-T01 | 正常系 | 作業中チケットの executor=sonnet、model=claude-sonnet-… で通知なし・要点が注入される |
| SA-T02 | 異常系 | executor=opus、model=sonnet で WF801 が注入の先頭に付き記録に残る。起動は止まらない（終了 0） |
| SA-T03 | 正常系 | 作業中が無く未着手の先頭が対象になる。チケットが 1 枚も無ければ無出力 |
| SA-T04 | 正常系 | `model` フィールドが無い入力で通知なし（注入はする） |
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
