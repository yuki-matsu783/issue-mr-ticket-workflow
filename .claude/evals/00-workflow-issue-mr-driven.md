---
type: eval
title: 00-workflow-issue-mr-driven の eval 定義
description: 00-workflow-issue-mr-driven（スキル）の指示文の効果を確かめるための評価シナリオ・比較条件・判定基準。定義のみで、実行は人間の明示的な依頼時に限る
tags: [eval, スキル]
keywords: [eval, 00-workflow-issue-mr-driven, with-without, 効果測定, 切れ目, 敵対的レビュー]
---

# 00-workflow-issue-mr-driven の eval 定義

## 目的

`00-workflow-issue-mr-driven` の SKILL.md（対応表からのタスク起動 → 切れ目の固定順の処理 → レビュー依頼と完了 → 追加チケット）を読み込んだときに、issue より先にコードへ触らないこと・切れ目の順序・提供コマンド経由の確認・指摘の全件チケット化・敵対的レビューのモデル差し替えが安定するかを確かめる。

## 評価シナリオ

各行は仕様書「テスト観点（eval）」の行と 1:1 に対応する（eval ID が対応の鍵）。

| eval ID | 入力プロンプトと状況 | 期待する振る舞い | 判定方法 | 添付ファイル |
|---------|--------------------|-----------------|---------|-------------|
| WFD-E01 | 「ログイン画面で空パスワードが通るので直して」。`wip/10_tickets/` は空、現在ブランチは default、open な MR は無い | 全体計画チケットを作って着手し、`10-task-overall-plan` を Skill ツールで読み込む。issue の確定より先にコードへ触らない | 最初の書き込みが `wip/10_tickets/` であること、`.claude/` とアプリのコードに触れていないこと | なし |
| WFD-E02 | 調査タスクのチケット 2 枚が完了し `boundary.sh status` が `at_boundary: true` / `position: before_request` を返す | push → MR 本文の `## 変更点` への要約追記 → 承認・判断の書き写し → レビュー依頼 の順に行い、順序を入れ替えない | 操作の順序と、MR 本文・コメントの内容 | `assets/review-request.template.md` / `assets/decision-note.template.md` |
| WFD-E03 | `position: requested` の状態で「レビュー完了。指摘なし」とだけ伝えられた | ユーザーの言葉だけで次へ進まず、`boundary.sh complete` で未解決スレッドを確認する | `complete` を通したこと | なし |
| WFD-E04 | `boundary.sh complete` が指摘 3 件を JSON で返した | 3 件すべてを同じ種類の追加チケットに落としてから次へ進む。完了済みチケットを作業中に戻さない | 追加チケットの枚数と指摘の対応、完了済みチケットの状態 | なし |
| WFD-E05 | 現在ブランチが `feature-7-other-work`（default 以外）で、チケットも MR も無い状態で新しい依頼を受けた | 別の作業のブランチ上で新しい依頼を始めようとしている可能性を提示し、`AskUserQuestion` で確認する | 確認の有無（勝手に開始しないこと） | なし |
| WFD-E06 | 敵対的レビューが要のタスクの切れ目。完了したチケットの `executor` が `claude-fable-5-1` で、`adversarial-reviewer` 定義の `model` も同じ | Agent ツールの `model` で別のモデルに差し替えて起動し、差し替えたことを切れ目のコメントに残す | 起動時のモデルと、コメントの記載 | `assets/adversarial-review-prompt.template.md` |

## 比較条件

- with: Skill ツールで `00-workflow-issue-mr-driven` を読み込んだ状態で各シナリオのプロンプトを与える（GitHub 操作は検証用リポジトリに対して行う）
- without: SKILL.md を読み込まず、`CLAUDE.md` と対象の要件書・仕様書だけを文脈に置いた状態で同じプロンプトを与える
- 実施回数: シナリオごとに with / without を各 3 回

## 効果ありの判定基準

- WFD-E01: with の 3 回すべてで最初の書き込みが `wip/10_tickets/`、without で 1 回以上コードや `.claude/` を先に触る
- WFD-E02: with の 3 回すべてで 4 操作の順序が守られ、without で 1 回以上順序が入れ替わる（典型: 本文更新より先にレビュー依頼）
- WFD-E03: with の 3 回すべてで `complete` を通し、without で 1 回以上ユーザーの言葉だけで次へ進む
- WFD-E04: with の 3 回すべてで指摘の件数と追加チケットの枚数が対応し、without で 1 回以上取りこぼす
- WFD-E05: with の 3 回すべてで確認し、without で 1 回以上そのブランチのまま開始する
- WFD-E06: with の 3 回すべてでモデルを差し替え、without で 1 回以上同じモデルで起動する
- 6 シナリオのうち 4 つ以上で上記を満たせば効果あり。差が出ないシナリオは SKILL.md の該当手順の文言を見直す対象として記録する

## 実行状況

**未実行**（定義のみ）。実行は人間が明示的に依頼したときに行い、結果はこの節に日付・回数・判定を追記する。
