---
type: spec
title: 20-common-step-ai-asset-creator スキル 仕様
description: AI アセット（スキル・フック・ルール・エージェント・settings.json）作成の内部仕様。種別ごとの置き場と標準構成、SKILL.md と eval 定義のひな形、機械テストの実施手順、settings.json の最小差分の手順を定める
tags: [spec, skill, common-step]
keywords: [AI アセット, SKILL.md, フック, ルール, エージェント, settings.json, 標準構成, 機械テスト, eval 定義, 最小差分]
---

# 20-common-step-ai-asset-creator スキル 仕様

## 概要・禁止事項

AI アセット作成の共通ステップの内部仕様。対応する要件は [00_requirement/skills/20-common-step-ai-asset-creator.md](../../00_requirement/skills/20-common-step-ai-asset-creator.md)。

アセットの中身の正は各アセットの仕様書。この仕様は「どの種別を・どこに・どの構成で・どう検証して作るか」の作法を固定する。

禁止事項:

- 仕様書が無い・未決のままのアセット作成
- 仕様に無い構造の発明（必要になったら仕様書への追記を呼び出し元に返す）
- テストの無効化・期待値の書き換えによる合格
- eval の実行（定義の作成まで。実行は人間の明示的な依頼時のみ）
- settings.json の一括書き換え（変更する項目だけの最小差分）
- リファクタリングと仕様変更を 1 つの変更に混ぜること

## 呼出条件

- `10-task-ai-asset-implementation-exec` の実装チケットから、対象アセットの仕様書がレビュー済みの状態で読み込まれる

## IN / OUT

| IN | OUT |
|----|----|
| 対象アセットの仕様書、実装チケット（やってよいこと・DoD） | 作成・変更されたアセット一式、テストの実行結果、eval 定義（機械検証できないアセットの場合）、仕様との対応の確認結果 |

## IN / OUT サンプル

- スキル: `10_spec/skills/20-common-step-ticket.md` → `.claude/skills/20-common-step-ticket/{SKILL.md, assets/ticket.template.md, scripts/ticket.sh, scripts/tests/}`
- フック: `10_spec/hooks/20-PreToolUse/workflow-guard.md` → `.claude/hooks/20-PreToolUse/workflow-guard.sh` + テスト + `settings.json` への登録（最小差分）
- ルール: `00_requirement/rules/work-defaults.md` → `.claude/rules/work-defaults.md` + eval 定義

## 処理フロー

1. **仕様書を読む**: 対象の仕様書（ルールは要件書）を読み、構成・名前・配置を確定する。無ければ設計が先として呼び出し元に返す
2. **種別と置き場**:

| 種別 | 置き場 | 標準構成 |
|------|--------|---------|
| スキル | `.claude/skills/<3層prefix付き名>/` | `SKILL.md` + `assets/`（テンプレート）+ `scripts/`（スクリプトと `scripts/tests/`）+ `references/`（参照資料。必要時） |
| フック | `.claude/hooks/<イベント番号ディレクトリ>/` | `<名前>.sh` + テスト。`settings.json` に登録 |
| ルール | `.claude/rules/` | `<名前>.md` |
| エージェント | `.claude/agents/` | `<名前>.md`（frontmatter + システムプロンプト） |
| 設定 | `.claude/settings.json` | 変更項目のみの最小差分 |

3. **作成・変更**: 仕様書の該当節（OUT ひな形・Script 処理・定義ひな形）に正確に従う。既存アセットの変更は既存の構成・記法に合わせて差分を小さくする
4. **機械テスト**: sh の作成・変更は `20-common-step-shell-script` の手順（雛形・共通 logger・テスト・検査）で行う。スクリプト・フックはテスト（正常系・境界・異常系。仕様書のテスト観点のテスト ID に対応）を書いて実行し、既存テストの回帰とあわせて結果を作業ログに残す。失敗は原因を直すか仕様側の誤りとして返す
5. **eval 定義**: スキル・ルール・エージェントなど指示文の効果が機械検証できないものは、eval 定義を `.claude/evals/<アセット名>.md` に作成・更新する（実行しない）
6. **settings.json**: 変更する項目だけを編集し、変更前の値と理由を作業ログに残す
7. **対応確認**: 仕様書の節と作成ファイルの対応（仕様のどの節をどのファイルが実現したか）を確認し、コミット（prefix `ai-asset`。テストを持つスクリプト等は通常の prefix）して結果を呼び出し元に返す

## OUT ひな形

- `assets/skill.template.md`: SKILL.md のひな形。frontmatter（name / description — description は「何をするか + Use when 〜」の発火条件を含む）+ 本文（目的 / 手順 / 参照 / エラー時の対処）
- `assets/eval.template.md`: eval 定義のひな形。目的 / 評価シナリオ（eval ID・入力プロンプトと状況・期待する振る舞い・判定方法・添付ファイル）/ 比較条件（with / without、実施回数）/ 効果ありの判定基準 / 未実行の明記。評価シナリオの項目は参考実装の `evals/evals.json`（`skill_name`・`evals[{id, prompt, expected_output, files}]`）を Markdown の表に写したもので、各仕様書の「テスト観点（eval）」表の行と 1:1 に対応させる

## 参照ナレッジ

- 各アセットの中身の正: 対象の仕様書（`10_spec/` 配下）
- bash の書き方・フック登録の作法: `rules/`（bash-script ルール）
- sh の作成手順と共通 logger の実体: `20-common-step-shell-script`
- eval は定義まで・機械テストは実施の方針: 要件書と DDR `i0001-20`
- コミット: `20-common-step-commit-push`（prefix の使い分け）

## Script 処理

なし。テストの実行は各アセットの `scripts/tests/` が担い、frontmatter・プレースホルダの検査は実装タスクの完了検査（`10-task-ai-asset-implementation-exec` の仕様で定める）に含める。

### テスト観点（eval）

スクリプトを持たないため機械テストは無く、スキル本体（SKILL.md・ひな形）の効果は eval で定義する（実行は人間の判断。ID の規則は `フック共通仕様` §6）。

| eval ID | 入力（プロンプトと状況） | 期待する振る舞い | 判定方法 |
|---------|------------------------|-----------------|---------|
| AC-E01 | 「新しいフックを追加して」（仕様書あり・実装チケット作業中） | 種別ごとの置き場と標準構成に従い、`20-common-step-shell-script` の雛形からスクリプトを作り、テストを書いて実行し、frontmatter・プレースホルダの検査を通す | 作成物の配置と雛形由来であること、テスト実行の記録、検査 0 件 |
| AC-E02 | 「このルールの効果を確かめたい」 | eval 定義を `assets/eval.template.md` から `.claude/evals/<アセット名>.md` に作り、実行はしない | eval 定義の存在と項目の充足、実行していないこと |
| AC-E03 | 仕様書が無いアセットの作成依頼 | 作らず「設計が先」として呼び出し元に返す | 作成物が無いこと、返答の内容 |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 仕様書に正確に従う・構造を発明しない | 処理フロー 1・3、禁止事項 |
| メイン: 3 層の命名と標準構成 | 処理フロー 2 |
| メイン: 機械実行できるものはテストを書いて実行・記録 | 処理フロー 4 |
| メイン: 機械検証できないものは eval 定義（実行しない） | 処理フロー 5、OUT ひな形（eval.template） |
| メイン: settings.json は最小差分 + 変更前の値の記録 | 処理フロー 6 |
| メイン: 仕様との対応確認と報告 | 処理フロー 7 |
| 代替: 既存変更は差分小さく・リファクタと仕様変更を混ぜない | 処理フロー 3、禁止事項 |
| 代替: 仕様に無い判断は仕様書への追記を返す | 禁止事項 |
| 例外: 仕様が無ければ作らない | 処理フロー 1 |
| 例外: テスト失敗は無効化せず直すか仕様の誤りとして返す | 処理フロー 4、禁止事項 |
| 例外: ワークフローを壊す振る舞いは組み込まず報告 | 処理フロー 4（回帰の確認）+ 呼び出し元への報告 |
| 整合: コミットは commit-push・prefix は ai-asset | 処理フロー 7、参照ナレッジ |
| 整合: 手順の再掲禁止 | 参照ナレッジ（呼び出し元はこの仕様を参照） |
