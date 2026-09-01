---
type: eval
title: {{ASSET_NAME}} の eval 定義
description: {{ASSET_NAME}}（{{ASSET_KIND}}）の指示文の効果を確かめるための評価シナリオ・比較条件・判定基準。定義のみで、実行は人間の明示的な依頼時に限る
tags: [eval, {{ASSET_KIND}}]
keywords: [eval, {{ASSET_NAME}}, with-without, 効果測定]
---

# {{ASSET_NAME}} の eval 定義

## 目的

{{PURPOSE}}

## 評価シナリオ

各行は仕様書「テスト観点（eval）」の行と 1:1 に対応する（eval ID が対応の鍵）。

| eval ID | 入力プロンプトと状況 | 期待する振る舞い | 判定方法 | 添付ファイル |
|---------|--------------------|-----------------|---------|-------------|
{{SCENARIOS}}

## 比較条件

- with: {{WITH_CONDITION}}
- without: {{WITHOUT_CONDITION}}
- 実施回数: シナリオごとに with / without を各 {{RUNS}} 回

## 効果ありの判定基準

{{SUCCESS_CRITERIA}}

## 実行状況

**未実行**（定義のみ）。実行は人間が明示的に依頼したときに行い、結果はこの節に日付・回数・判定を追記する。
