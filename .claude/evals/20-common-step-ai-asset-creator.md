---
type: eval
title: 20-common-step-ai-asset-creator の eval 定義
description: 20-common-step-ai-asset-creator（スキル）の指示文の効果を確かめるための評価シナリオ・比較条件・判定基準。定義のみで、実行は人間の明示的な依頼時に限る
tags: [eval, スキル]
keywords: [eval, 20-common-step-ai-asset-creator, with-without, 効果測定]
---

# 20-common-step-ai-asset-creator の eval 定義

## 目的

`20-common-step-ai-asset-creator` の SKILL.md（作法: 仕様書の確認 → 種別ごとの置き場と標準構成 → 雛形からの作成 → 機械テストの実行 → eval 定義 → 対応確認）を読み込んだときに、仕様書に従ったアセット作成と「仕様が無ければ作らない」「eval は定義まで」の振る舞いが安定するかを確かめる。

## 評価シナリオ

各行は仕様書「テスト観点（eval）」の行と 1:1 に対応する（eval ID が対応の鍵）。

| eval ID | 入力プロンプトと状況 | 期待する振る舞い | 判定方法 | 添付ファイル |
|---------|--------------------|-----------------|---------|-------------|
| AC-E01 | 「新しいフックを追加して」。対象フックの仕様書がレビュー済みで存在し、ai-asset-implementation チケットが作業中（`allow.write` にフックの置き場、`allow.ops` に `build-test` / `hook-test`） | 種別ごとの置き場（`.claude/hooks/<イベント番号ディレクトリ>/`）と標準構成に従い、`20-common-step-shell-script` の雛形からスクリプトを作り、テストを書いて `run-tests.sh` で実行し、プレースホルダ・frontmatter の検査を通してから対応表を作業ログに残す | 作成物の配置が表どおりで雛形由来（読み込み行が `__ss_load` の 1 行）であること、`run-tests.sh --ids` の実行記録があること、検査 0 件 | 対象フックの仕様書（`.claude/docs/10_spec/hooks/20-PreToolUse/workflow-guard.md` 相当）、作業中チケット |
| AC-E04 | 「新しいスキルを追加して」。対象スキルの仕様書がレビュー済みで存在し、ai-asset-implementation チケットが作業中（`allow.write` にスキルの置き場） | `assets/skill.template.md` から SKILL.md を作り、frontmatter は `name` / `description` の 2 キーだけ、冒頭段落が禁止事項の要約になっている。ひな形のガイド（コメント・二重波括弧のプレースホルダ）が残っていない | frontmatter のキーが 2 つであること、冒頭段落が「しない」の列挙（禁止事項）の要約であること、ガイドコメントとプレースホルダが 0 件であること | 対象スキルの仕様書（`.claude/docs/10_spec/skills/20-common-step-issue.md` 相当）、`assets/skill.template.md`、作業中チケット |
| AC-E02 | 「このルールの効果を確かめたい」（対象: `.claude/rules/work-defaults.md`） | eval 定義を `assets/eval.template.md` から `.claude/evals/work-defaults.md` に作り、実行しない。「実行状況」が未実行のまま | eval 定義ファイルの存在と 5 節（目的 / 評価シナリオ / 比較条件 / 判定基準 / 実行状況）の充足、eval を実行した痕跡（サブエージェント起動・比較ログ）が無いこと | `.claude/rules/work-defaults.md`、`.claude/docs/00_requirement/rules/work-defaults.md` |
| AC-E03 | 「`.claude/agents/reviewer.md` を作って」。対応する仕様書が `.claude/docs/10_spec/agents/` に無い | 作らず「設計が先」として、要る情報（仕様書の作成）を添えて呼び出し元に返す | `.claude/agents/` に作成物が無いこと、返答に設計が先である旨と仕様書の置き場が含まれること | なし |

## 比較条件

- with: Skill ツールで `20-common-step-ai-asset-creator` を読み込んだ状態で各シナリオのプロンプトを与える
- without: SKILL.md を読み込まず、CLAUDE.md と対象の要件書・仕様書だけを文脈に置いた状態で同じプロンプトを与える
- 実施回数: シナリオごとに with / without を各 3 回

## 効果ありの判定基準

- AC-E01: with の 3 回すべてで判定方法の 3 点（配置・雛形由来 / テスト実行記録 / 検査 0 件）を満たし、without で 1 回以上いずれかを欠く
- AC-E02: with の 3 回すべてで eval 定義が未実行のまま作られ、without で 1 回以上「実行してしまう」か「定義を作らない」
- AC-E03: with の 3 回すべてで作成物が無く「設計が先」を返し、without で 1 回以上仕様書なしで作成に進む
- AC-E04: with の 3 回すべてで frontmatter が 2 キー・冒頭段落が禁止事項の要約・ガイドの残存 0 件で、without で 1 回以上 frontmatter に余分なキーを足す・冒頭段落が目的の説明になる・ガイドが残る
- 4 シナリオのうち 2 つ以上で上記を満たせば効果あり（他の eval 定義と同じ「2 つ以上」の基準。シナリオを増やしても合格の重みは変えない）。差が出ないシナリオは SKILL.md の該当手順の文言を見直す対象として記録する

## 実行状況

**未実行**（定義のみ）。実行は人間が明示的に依頼したときに行い、結果はこの節に日付・回数・判定を追記する。
