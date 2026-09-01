---
name: 20-common-step-ai-asset-creator
description: >
  レビュー済みの仕様書から AI アセット（スキル・フック・ルール・エージェント・settings.json）を種別ごとの置き場と
  標準構成で作成・変更し、機械実行できるものはテストを書いて実行し、機械検証できない指示文は eval 定義（実行しない）を
  作り、仕様の節と作成物の対応を確認してコミットする共通ステップ。アセットの中身の正は各仕様書で、このスキルは作法を固定する。
  Use when an ai-asset-implementation ticket is in progress and an asset must be created or changed from its reviewed
  spec ("スキルを作って", "フックを追加して", "ルールを直して", "settings.json に登録して"), or when an eval definition
  for a skill / rule / agent is needed ("このルールの効果を確かめたい").
---

# 20-common-step-ai-asset-creator — 仕様書どおりに作り、テストか eval で確かめる

仕様書が無い・未決のままのアセットは作らない。仕様に無い構造は発明せず、必要になったら仕様書への追記を呼び出し元に返す。テストの無効化・期待値の書き換えで合格にしない。eval は定義まで（実行は人間の明示的な依頼時のみ）。リファクタリングと仕様変更を 1 つの変更に混ぜない。

- 要件: `.claude/docs/00_requirement/skills/20-common-step-ai-asset-creator.md`
- 仕様（正。置き場と標準構成の表・OUT ひな形・eval ID AC-E01〜04）: `.claude/docs/10_spec/skills/20-common-step-ai-asset-creator.md`

## 手順

1. **仕様書を読む**: 対象の仕様書（`.claude/docs/10_spec/` 配下。ルールは要件書 `.claude/docs/00_requirement/rules/`）を読み、構成・名前・配置を確定する。無ければ「設計が先」として呼び出し元に返す。実装チケットの「やってよいこと」（`allow.write` / `allow.ops`）の範囲内で作業する
2. **種別と置き場を決める**（3 層の命名 prefix は `00-workflow-` / `10-task-` / `20-common-step-`）:

   | 種別 | 置き場 | 標準構成 |
   |------|--------|---------|
   | スキル | `.claude/skills/<3 層 prefix 付き名>/` | `SKILL.md` + `assets/`（テンプレート）+ `scripts/`（スクリプトと `scripts/tests/`）+ `references/`（必要時） |
   | フック | `.claude/hooks/<イベント番号ディレクトリ>/` | `<名前>.sh` + `tests/`。`.claude/settings.json` に登録 |
   | ルール | `.claude/rules/` | `<名前>.md` |
   | エージェント | `.claude/agents/` | `<名前>.md`（frontmatter + システムプロンプト） |
   | 設定 | `.claude/settings.json` | 変更項目のみの最小差分 |

3. **作成・変更する**: 仕様書の該当節（OUT ひな形 / Script 処理 / 定義ひな形）に正確に従う。SKILL.md は `assets/skill.template.md` をコピーして埋める（description は「何をするか + Use when 〜」。本文は 目的 / 手順 / 参照 / エラー時の対処。規約の中身は再掲せず参照にする）。既存アセットの変更は既存の構成・記法に合わせて差分を小さくする
4. **機械テストを書いて実行する**: sh の作成・変更は `20-common-step-shell-script` の手順（雛形・共通 logger・`test-lib.sh`・`run-tests.sh`・`bash -n`）で行う。仕様書のテスト観点のテスト ID ごとにケース（正常系・境界・異常系）を書き、失敗を先に確認してから実装し、既存テストの回帰とあわせて `run-tests.sh --ids` の結果を作業ログに残す。失敗は原因を直すか、仕様側の誤りとして呼び出し元に返す
5. **eval 定義を作る**: スキル・ルール・エージェントなど指示文の効果が機械検証できないものは、`cp .claude/skills/20-common-step-ai-asset-creator/assets/eval.template.md .claude/evals/<アセット名>.md` で作り、評価シナリオの各行を仕様書「テスト観点（eval）」表の行と 1:1（eval ID が鍵）で埋める。「実行状況」は **未実行** のまま残し、実行しない
6. **settings.json を変える場合**: 変更する項目だけを編集し、変更前の値と理由を作業ログに残す（一括書き換え・整形し直しをしない）
7. **対応を確認してコミットする**: 仕様書の節と作成ファイルの対応表（どの節をどのファイルが実現したか）を作業ログに書き、プレースホルダ（`{{ }}` / `TODO` / `TBD`。`assets/*.template.*` は対象外）と frontmatter を検査してから `20-common-step-commit-push` の `commit.sh` でコミットする（prefix は `ai-asset`。テストを持つスクリプト等は `feat` / `fix` / `test` の通常 prefix）。結果（作成物・テスト結果・eval 定義・対応表）を呼び出し元に返す

## 参照

- 雛形: `assets/skill.template.md`（SKILL.md）、`assets/eval.template.md`（eval 定義。評価シナリオ / 比較条件 / 判定基準 / 実行状況）
- アセットの中身の正: 対象の仕様書（`.claude/docs/10_spec/`）。仕様書・要件書の書き方: `20-common-step-spec` / `20-common-step-requirement`
- sh の作成手順・共通 logger・テストランナー: `20-common-step-shell-script`。bash 規約: `rules/`（bash-script ルール）。ログの規約: `.claude/rules/logger.md`
- eval は定義まで・機械テストは実施の方針: 要件書と DDR `i0001-20`
- コミット（prefix の使い分け）: `20-common-step-commit-push`
- 呼び出し元と完了検査（プレースホルダ・frontmatter・許可範囲）: `10-task-ai-asset-implementation-exec`

## エラー時の対処

| 状況 | 対処 |
|------|------|
| 対象の仕様書が無い / TBD のまま | 作らない。「設計が先」として、要る情報を添えて呼び出し元に返す |
| 仕様に無い構造・判断が必要になった | 発明しない。仕様書への追記案を呼び出し元に返す（実装チケットから `.claude/docs/` は書き換えない） |
| テストが失敗する | 無効化・期待値の書き換え・skip をしない。原因を直すか、仕様の誤りとして返す |
| 既存テストが回帰した / ワークフローを壊す振る舞いになる | 組み込まず、回帰した ID と原因を呼び出し元に報告する |
| 作成物が `allow.write` の外に出る | 作らず、許可範囲の見直し（計画側）を呼び出し元に返す |
| `run-tests.sh` が `TR006:` で止まる | 作業中チケットの `allow.ops` に `build-test` / `hook-test` が無い。チケットの frontmatter を手で直さず、計画側に返す |
| `commit.sh` が `CPxxx:` で拒否した | `20-common-step-commit-push` の表に従い解消して再実行する |
| eval の実行を求められた | 人間の明示的な依頼でなければ実行しない。定義ファイルの場所と実行手順（比較条件）を示す |
