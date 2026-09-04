---
type: plan
title: 全体計画 — git worktree による作業ツリー分離と同一フェーズのチケット並列実施
description: issue #50 の全体計画。種別・フェーズ列・受け入れ条件との対応・タスクの種類ごとの実行者とレビュー要否を定める
tags: [plan, overall-plan, issue-50]
keywords: [worktree, 並列実施, WIPリミット, 作業ツリー分離, 宣言範囲, 差分の基準点, フック, 提供コマンド, DDR]
---

# 全体計画 — git worktree による作業ツリー分離と同一フェーズのチケット並列実施

## 対象

- 対象 issue: [#50](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/50)
- MR: [#51](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/51)（draft）
- ブランチ: `feature-50-worktree-parallel-tickets`

## 種別

AI アセット。変更対象は `.claude/` 配下のフック（`workflow-guard` / `workflow-diff-check` / `subagent-start-check`）・共通ライブラリ（`scope.sh`）・提供コマンド（`ticket.sh` / `push.sh` / `boundary.sh`）・スキル・エージェント定義とその要件定義書・仕様書であり、`apl/` 配下のアプリには一切触れない。

## フェーズ列

AI アセットの標準列をそのまま採用する。省略するフェーズは無い。

| # | フェーズ | 採否 | 標準列との差分と理由 |
|---|---|---|---|
| 1 | 全体計画 | 採用 | 標準どおり |
| 2 | 調査 | 採用 | 標準どおり。worktree 上での機構の挙動が実測でしか分からず、並列の採否がその結果に依存する |
| 3 | AI アセット設計 | 採用 | 標準どおり |
| 4 | AI アセット実装・テスト | 採用 | 標準どおり |
| 5 | フィードバック計画 | 採用 | 標準どおり |
| 6 | 追加の AI アセット設計 / 実装 | 未定 | フィードバック計画で要否を決める |
| 7 | 全体まとめ | 採用 | 標準どおり |

## 受け入れ条件との対応

| # | 受け入れ条件 | 満たすフェーズ |
|---|---|---|
| A1 | worktree 上で機構（フック・提供コマンド・`boundary.sh`）が健全に動くことが実測で確かめられ、動かない箇所があれば直っている | 調査 / AI アセット実装・テスト |
| A2 | issue-MR 駆動を開始するときに worktree を切るかどうかの既定と手順が要件・仕様に定まっている | AI アセット設計 |
| A3 | 並行作業の手段（worktree / 別 clone）が CLAUDE.md か振り分けスキルから 1 ホップで辿れる | AI アセット設計 / AI アセット実装・テスト |
| A4 | 1 issue の中で同じフェーズの依存しないチケットを並列に実施する方式について、採否と理由が新しい DDR に残っている | AI アセット設計 |
| A5 | 並列を採用する場合、宣言範囲の強制・差分の基準点・実行者照合が worktree ごとに一意に決まることが仕様に明記され、機械テストで確認されている | AI アセット設計 / AI アセット実装・テスト |
| A6 | 並列を採用する場合、並列作業の成果を feature ブランチへ合流させる手順（チケットファイルの衝突の扱いを含む）が定まっている | AI アセット設計 |

## 方針

`.claude/rules/work-defaults.md` を基準にする。差分は 3 件。

| type | 実行者 | 人間レビュー | 敵対的レビュー | 基準との差分 |
|---|---|---|---|---|
| overall-plan | メインエージェント | 要（承認①②③で実施済み） | 不要 | 基準どおり |
| investigation-plan | サブエージェント（opus） | 不要 | 不要 | 基準どおり |
| investigation | サブエージェント（opus） | 不要 | 要（fable / 1 回） | **実行者を opus へ**（差分 1）/ **人間レビューを不要へ・敵対的レビューを要へ**（差分 3） |
| ai-asset-design-plan | サブエージェント（opus） | 不要 | 不要 | 基準どおり |
| ai-asset-design | サブエージェント（opus） | 不要 | 要（fable / 1 回） | **人間レビューを不要へ**（差分 3） |
| ai-asset-implementation-plan | サブエージェント（opus） | 不要 | 要（fable / 1 回） | **人間レビューを不要へ・敵対的レビューを要へ**（差分 3） |
| ai-asset-implementation | サブエージェント（opus） | 不要 | 要（fable / 1 回） | **人間レビューを不要へ**（差分 3） |
| feedback-plan | メインエージェント | 不要 | 不要 | **人間レビューを不要へ**（差分 3）。改善候補の対応先の合意は対話で行う |
| overall-summary | メインエージェント | 不要 | 要（fable / 1 回） | **人間レビューを不要へ・敵対的レビューを要へ**（差分 3） |

### 差分 1: 調査の実行者を opus に上げる

調査対象が `scope.sh` の分類ロジック・`workflow-guard` の判定順・提供コマンドと `logs/` 配下の状態ファイルの相互作用であり、いずれも読み違えると設計全体の前提が狂う。`work-defaults.md` の investigation 行に実行者の調整条件は書かれていないため、基準に無い調整として合意する。

### 差分 2: 実測が要る git 操作は人間が実行する

`scope.sh` の git 分類に `checkout` / `switch` / `worktree` が無く、どの `allow.ops` を宣言しても AI からは実行できない（本全体計画の実施中に 3 回踏んだ）。調査フェーズで worktree を実際に作る実測は、AI が手順とコマンドを用意し、ユーザーが実行して結果を返す形で行う。この制約は A1 の解消（実装フェーズ）まで続く。

### 差分 3: 人間レビューを敵対的レビューに置き換える

ユーザーの明示指示により、全体計画より後のフェーズでは切れ目ごとの人間レビューで停止せず、draft 解除まで通しで進める。代わりに**フェーズごとに 1 回、`claude-fable-5-1` の `adversarial-reviewer` による敵対的レビューを必ず挟む**。基準では敵対的レビューが不要とされている `investigation` / `ai-asset-implementation-plan` / `overall-summary` にも入れる。

- 敵対的レビュアーのモデルは `work-defaults.md` の既定どおり `claude-fable-5-1`。実行者は opus とメインエージェントなので、実行者と同一モデルになる状況は生じない
- 既定のモデルで起動できないときは、実行者と別のモデルに差し替えたうえで実施回数を消費したものとして数える
- 実施回数の上限はフェーズごとに 1 回。上限に達した後の指摘は追加チケットにせず、切れ目のコメントに転記する
- 切れ目では `boundary.sh skip --reason` でレビュー省略を記録し、MR 本文の該当行に省略の理由を添える

### やってよいこと

| type | 書き込んでよい範囲 | 実行してよい操作 |
|---|---|---|
| investigation-plan | `wip/**` | `read` / `remote-read` |
| investigation | `wip/**` | `read` / `remote-read` / `build-test`（既存テストの実行のみ） |
| ai-asset-design-plan | `wip/**` | `read` / `remote-read` |
| ai-asset-design | `wip/**` / `.claude/docs/**` | `read` / `remote-read` |
| ai-asset-implementation-plan | `wip/**` | `read` / `remote-read` |
| ai-asset-implementation | `wip/**` / `.claude/**` | `read` / `remote-read` / `build-test` / `hook-test` |

`.claude/hooks/config/**` と `.claude/settings.json` は毎回確認の対象（`scope-limits.json` の `common.confirm`）。

## 保留した点

| # | 保留した点 | 決める時期・場所 |
|---|---|---|
| P1 | 1 issue 内の並列実施を採用するか見送るか | 調査の実測結果を受けて AI アセット設計計画で決める |
| P2 | 本全体計画の実施中に見つかった機構の不具合 4 件（`ticket.sh cancel` の default 上コミット / `logs/` の進行状態が issue をまたいで残る / push 失敗時の push 検知の誤報 / `mr.json` の `issue` が誰にも書かれない）の切り出し先 | 全体まとめで別 issue として起票する |
| P3 | 調査で必要な実測を、ユーザー実行で回すか、先に git 分類の穴を直してから回すか | 調査計画 |

## 合意の記録

| # | 日付 | 相手 | 内容 |
|---|---|---|---|
| ① | 2026-09-04 | ユーザー | 該当する既存 issue が無いため新規に起票する。(A) 同一フェーズの並列実行と (B) 開始時の worktree 分離を 1 issue で扱う。DDR i0001-23 は調査で費用対効果を測ってから採否を決める |
| ② | 2026-09-04 | ユーザー | issue #50 の本文・ブランチ名 `feature-50-worktree-parallel-tickets`・MR タイトルを案のまま承認 |
| ③ | 2026-09-04 | ユーザー | フェーズ列・実行者・レビュー要否・やってよいことを案のまま承認（差分 1・差分 2 を含む） |
| ④ | 2026-09-04 | ユーザー | フェーズごとに `claude-fable-5-1` で敵対的レビューを 1 回ずつ入れ、切れ目の人間レビューでは停止せず draft 解除まで通しで進める（差分 3） |
