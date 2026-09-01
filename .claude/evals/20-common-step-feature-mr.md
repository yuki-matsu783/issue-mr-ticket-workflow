---
type: eval
title: 20-common-step-feature-mr の eval 定義
description: 20-common-step-feature-mr（スキル）の指示文の効果を確かめるための評価シナリオ・比較条件・判定基準。定義のみで、実行は人間の明示的な依頼時に限る
tags: [eval, スキル]
keywords: [eval, 20-common-step-feature-mr, with-without, 効果測定]
---

# 20-common-step-feature-mr の eval 定義

## 目的

`20-common-step-feature-mr` の SKILL.md（default の最新化 → 同名ブランチの確認 → `feature-<N>-<slug>` の作成 → 開始コミットと push を提供コマンドで → 既存 MR の確認 → テンプレート本文の draft MR）を読み込んだときに、命名規約・draft・`Closes #N`・冪等性（作り直さない）・対象外ホストでの停止が安定するかを確かめる。

## 評価シナリオ

各行は仕様書「テスト観点（eval）」の行と 1:1 に対応する（eval ID が対応の鍵）。

| eval ID | 入力プロンプトと状況 | 期待する振る舞い | 判定方法 | 添付ファイル |
|---------|--------------------|-----------------|---------|-------------|
| FM-E01 | issue 連携モード。issue #12「ログイン検証の不備」が確定し、ブランチ名 `feature-12-login-validation` と MR タイトル `feat: ログイン検証の不備 (#12)` が承認済み。origin は GitHub、未コミットの変更なし | `git fetch origin` で default を最新化してから `origin/<default>` から `feature-12-login-validation` を切り、`commit.sh` で開始コミット（持ち越し分が無ければ `--allow-empty`）を積んで `push.sh` で push し、`assets/mr-body.template.md` 由来で `- Closes #12` を含む本文の **draft** MR を `gh pr create --draft` で作り、番号と URL を返す | ブランチ名が規約どおり、開始コミットの件名が `chore: #12 login-validation の作業を開始`、MR が draft で本文に `Closes #12`、`git commit` / `git push` の直接実行が無いこと | `assets/mr-body.template.md` |
| FM-E02 | FM-E01 と同じ入力で、`feature-12-login-validation` と open な draft MR #13 が既にある状態で再実行 | 同名ブランチがあれば作らず、現在ブランチの open な MR #13 の番号と URL を返して終える（二重作成しない） | ブランチ・MR が増えていないこと、報告に既存の #13 が含まれること | なし |
| FM-E03 | issue 連携モード。origin の URL が GitHub でも GitLab でもない（例: `https://git.example.internal/team/repo.git`） | ホストを判別できないため対象外として報告して停止する。推測で `gh` / `glab` を選ばず、ブランチも作らない | 停止していること、理由（ホスト判別不能）が返答にあること、ブランチが作られていないこと | なし |

## 比較条件

- with: Skill ツールで `20-common-step-feature-mr` を読み込んだ状態で各シナリオのプロンプトを与える（GitHub 操作は検証用リポジトリに対して行う）
- without: SKILL.md を読み込まず、CLAUDE.md と対象の要件書・仕様書だけを文脈に置いた状態で同じプロンプトを与える
- 実施回数: シナリオごとに with / without を各 3 回

## 効果ありの判定基準

- FM-E01: with の 3 回すべてで判定方法の 4 点（命名 / 開始コミット / draft と Closes / 直接実行なし）を満たし、without で 1 回以上いずれかを欠く（典型: draft でない MR、git push の直接実行）
- FM-E02: with の 3 回すべてで二重作成が無く、without で 1 回以上ブランチや MR を作り直す・別名で作る
- FM-E03: with の 3 回すべてで停止し、without で 1 回以上 gh を推測で使う
- 3 シナリオのうち 2 つ以上で上記を満たせば効果あり。差が出ないシナリオは SKILL.md の該当手順の文言を見直す対象として記録する

## 実行状況

**未実行**（定義のみ）。実行は人間が明示的に依頼したときに行い、結果はこの節に日付・回数・判定を追記する。
