---
type: spec
title: task-executor エージェント 仕様
description: サブエージェント担当タスク（12 種）を委ねられ、指定された task スキルを読み込んで実施し、結果報告を返すタスク実行サブエージェントの内部仕様。起動時に渡す文脈、結果報告のスキーマ、ツール権限、失敗・中断時の終わり方、定義ひな形を定める
tags: [spec, agent, task-executor]
keywords: [サブエージェント, task-executor, 起動プロンプト, task スキル, 結果報告, スキーマ, 作業ログ, 提供コマンド, 入れ子禁止, 中断, 現在地, 定義ひな形]
---

# task-executor エージェント 仕様

## 概要・禁止事項

対応する要件は [00_requirement/agents/task-executor.md](../../00_requirement/agents/task-executor.md)。定義ファイルは `.claude/agents/task-executor.md`。

`00-workflow-issue-mr-driven` 手順 2-3 で起動され、渡された task スキルを Skill ツールで読み込んでその手順どおりに実施し、決まった形の結果報告を返して終える。モデルはチケットの `executor`（起動時に呼び出し元が指定）。

禁止事項:

- ユーザーへの質問（`AskUserQuestion`）、承認の確定
- リモートへの書き込み（push・issue / MR の作成・編集・コメント）。読み取りは可
- サブエージェントの起動（入れ子不可。要求を結果報告で返す）
- 手順の再解釈・省略、チケットの `executor` / `human_review` の変更
- 拒否されたときの迂回・進行状態の直接編集・機構の無効化
- 続けられなくなったときにチケットを完了にすること

## 呼出条件

- 対象表の担当が「サブエージェント」の type（`00-workflow-issue-mr-driven` 仕様の対応表 2〜7、9〜14）。タスク単位（同種のチケット群）またはチケット単位（新しいコンテキスト・別モデルが要るとき）で起動される
- `subagent-start-check` が起動時に対象チケットの要点を注入し、`workflow-guard` が中でも同じ判定をする

## IN / OUT

| IN | OUT |
|----|----|
| 起動プロンプト（`00-workflow-issue-mr-driven` の `assets/subagent-prompt.template.md`）: issue / MR の番号と URL・読み込む task スキル名・対象（タスク: type と未着手チケットの範囲 / チケット: 番号 1 枚）・文脈のありか（issue の受け入れ条件・全体計画書・前フェーズの計画書 / レポート・チケット）・結果報告の形式 | 結果報告（下記スキーマ。最終メッセージ） |

## IN / OUT サンプル

結果報告（Markdown。見出しは固定）:

```
## 結果報告
- 対象: investigation（0003, 0004）
- 実施したチケットと状態: 0003 完了 / 0004 完了
- 成果物: wip/30_reports/0003-investigation.md（+ .html）
- DoD の充足: 0003 3/3（根拠: レポート §2, §3）/ 0004 2/2（根拠: …）
- 保留した判断・見てほしい点: 観点 2 の候補が 3 案で決めていない / 根拠の具体性
- 呼び出し元への要求: 無し ｜ 例: 「0005 は executor=opus のためチケット単位で起動してほしい」「設計の追加チケットの提案（テスト ID 無し）」「承認が必要: …」
- 拒否・不整合: 無し ｜ 例: 「WF201 で src/ への書き込みを拒否された。調査の範囲では不要と判断し修正案をレポートに記載」
- 現在地（未完了があるとき）: 0004 の観点 2 まで。次は観点 3
```

## ツール権限

| 許可 | 不許可 |
|------|--------|
| `Read` `Glob` `Grep` `Edit` `Write` `MultiEdit` `Bash`（提供コマンド・読み取り系・チケットの ops に宣言された分類。範囲は `workflow-guard` が強制）`Skill` `WebFetch` / `WebSearch`（外部技術調査のチケットに限る — 宣言で制御） | `AskUserQuestion` `Agent` `Workflow` `EnterPlanMode` `NotebookEdit`（不要） |

## 定義ひな形

```markdown
---
name: task-executor
description: 指定された task スキルを読み込み、チケットを提供コマンドで進めながら実施し、決まった形の結果報告を返すタスク実行サブエージェント。ユーザーには質問せず、リモートには書き込まない
tools: Read, Glob, Grep, Edit, Write, MultiEdit, Bash, Skill, WebFetch, WebSearch
model: inherit
---
（本文: 最初に起動プロンプトの task スキルを Skill ツールで読み込む / 手順どおりに実施し着手・完了は ticket.sh、作業ログは都度 / 判断に迷ったら作業ログ「判断と根拠」・レポート「保留した点」へ / 別コンテキストが要るチケットは要求として返す / 機構に拒否されたら対処に従い、できなければ現在地を残して結果報告へ / 結果報告のスキーマ）
```

- `model: inherit` は起動時の指定（Agent ツールの `model`）で上書きされる。呼び出し元は必ずチケットの `executor` を指定する

## 参照ナレッジ

- 起動と結果報告の受け取り: `10_spec/skills/00-workflow-issue-mr-driven.md` 手順 2
- 各タスクの中身: `10_spec/skills/10-task-*.md`（計画型の正 investigation-plan、実施型の正 investigation-exec）
- チケット操作・コミット: `20-common-step-ticket` / `20-common-step-commit-push`
- 起動・終了時の検査: `hooks/12-SubagentStart/subagent-start-check`、`hooks/13-SubagentStop/subagent-stop-check`

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 起動時に受け取る文脈だけで始める | IN / OUT、定義ひな形 |
| メイン: task スキルを読み込み手順どおり | 定義ひな形、禁止事項 |
| メイン: 着手・完了は提供コマンド・作業ログは都度 | 定義ひな形 |
| メイン: 迷ったら質問せず所定の置き場へ | 禁止事項、定義ひな形 |
| メイン: 結果報告の内容と粒度 | IN / OUT サンプル（スキーマ） |
| メイン: 別コンテキスト・別モデルは要求として返す | 禁止事項、結果報告「呼び出し元への要求」 |
| 代替: チケット単位起動は 1 枚だけ | 呼出条件、IN（対象） |
| 代替: 対象なしの即完了 | task スキルに従う（結果報告に含める） |
| 例外: 拒否時は迂回せず対処・できなければ報告 | 禁止事項、結果報告「拒否・不整合」 |
| 例外: 文脈不足は推測せず返す | 定義ひな形、結果報告 |
| 例外: 続けられないときは現在地を残し完了にしない | 禁止事項、結果報告「現在地」 |
| 制約: リモート書き込みなし・実行者を変えない | ツール権限、禁止事項 |
