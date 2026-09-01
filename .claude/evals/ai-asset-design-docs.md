---
type: eval
title: ai-asset-design-docs の eval 定義
description: ai-asset-design-docs（ルール）の指示文の効果を確かめるための評価シナリオ・比較条件・判定基準。定義のみで、実行は人間の明示的な依頼時に限る
tags: [eval, ルール]
keywords: [eval, ai-asset-design-docs, with-without, 効果測定, .claude/docs, 正史, DDR, 台帳]
---

# ai-asset-design-docs の eval 定義

## 目的

`.claude/rules/ai-asset-design-docs.md`（`.claude/docs/**` の AI アセット設計文書の規約）が `paths` の一致で読み込まれているときに、フック・スキル・ルールの要件定義書と仕様書を正史だけで書き、エラー識別子・テスト ID を台帳と各仕様で管理し、DDR に経緯を残し、用語辞書と食い違わせない振る舞いが安定するかを確かめる。

## 評価シナリオ

各行は仕様書「テスト観点（eval）」の行と 1:1 に対応する（eval ID が対応の鍵）。

| eval ID | 入力プロンプトと状況 | 期待する振る舞い | 判定方法 | 添付ファイル |
|---------|--------------------|-----------------|---------|-------------|
| AD-E01 | AI アセット設計タスクで「commit.sh に『git commit 自体が失敗した』ときの識別子を足して」 | 仕様書の Script 処理に条件と識別子を追加し、あわせてフック共通仕様の台帳（§6）に同じ識別子を登録する。番号は既存と衝突しないものを選ぶ | 仕様書と台帳の両方に同じ識別子があり、既存番号と重複していないこと | `.claude/rules/ai-asset-design-docs.md`、`.claude/docs/10_spec/skills/20-common-step-commit-push.md`、`.claude/docs/10_spec/フック共通仕様.md` |
| AD-E02 | 「仕様書に、なぜ判定順をこうしたかの理由と却下した案を書いておいて」 | 仕様書には現在の判定順だけを書き、理由と却下案は DDR（`.claude/docs/20_ddr/`）に書いて仕様書から参照しない（DDR 側から仕様を参照する） | 仕様書の差分に理由・却下案が無く、DDR が 1 件増えていること | `.claude/rules/ai-asset-design-docs.md`、DDR の既存例 |
| AD-E03 | 「このスキルの要件定義書で『提供コマンド』を『補助スクリプト』と呼び替えて」 | 用語辞書（`90_glossary/`）の定義語を勝手に置き換えず、用語を変えるなら辞書の更新を先に提案し、他の文書との食い違いを指摘する | 要件定義書の差分で定義語が置き換わっておらず、用語辞書の更新が提案されていること | `.claude/rules/ai-asset-design-docs.md`、`.claude/docs/90_glossary/` の該当語 |

## 比較条件

- with: `.claude/rules/ai-asset-design-docs.md` が `paths`（`.claude/docs/**`）の一致で読み込まれている状態で各シナリオのプロンプトを与える
- without: `ai-asset-design-docs.md` を読み込まない状態で、CLAUDE.md と requirement / spec の共通ステップ仕様だけを文脈に置いて同じプロンプトを与える
- 実施回数: シナリオごとに with / without を各 3 回

## 効果ありの判定基準

- AD-E01: with の 3 回すべてで仕様書と台帳の両方に登録され、without で 1 回以上台帳への登録が漏れる
- AD-E02: with の 3 回すべてで理由・却下案が DDR に分かれ、without で 1 回以上仕様書に理由を書く
- AD-E03: with の 3 回すべてで定義語を置き換えず辞書の更新を提案し、without で 1 回以上そのまま置き換える
- 3 シナリオのうち 2 つ以上で上記を満たせば効果あり。差が出ないシナリオはルールの該当章の文言を見直す対象として記録する

## 実行状況

**未実行**（定義のみ）。実行は人間が明示的に依頼したときに行い、結果はこの節に日付・回数・判定を追記する。
