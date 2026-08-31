---
type: ddr
title: i0004-04. default 上ではチケットの状態変更をコミットせず、feature ブランチの開始コミットに載せる
description: 全体計画チケットは feature ブランチ作成前（default 上）に作成・着手されるため、ticket.sh は default ブランチ上ではコミットを行わずファイルを未追跡のまま持ち越し、feature-mr の開始コミット（従来の空コミットの代わり）でまとめて載せる
tags: [ddr, workflow, ticket, branch]
keywords: [全体計画チケット, default ブランチ, コミット保留, 未追跡, 持ち越し, 開始コミット, 空コミット, feature-mr, ticket.sh]
---

# i0004-04. default 上ではチケットの状態変更をコミットせず、feature ブランチの開始コミットに載せる

## 背景

敵対的レビュー（仕様書 11 本）で、実行すると壊れる順序の矛盾が指摘された。ワークフローは最初に全体計画チケットを作成・着手してから全体計画タスクに入り（issue の確定はチケットの中で行う）、feature ブランチはその後に issue 番号が決まってから `origin/<default>` から切る。一方 `ticket.sh` の create / start は毎回コミットしていたため、チケットの 2 コミットは default ブランチのローカルに残り、feature ブランチには載らず、作業中チケットのファイルが作業ツリーから消えて直後の `complete` が失敗する。

## 決定

- `ticket.sh` の状態変更コミットは、**現在のブランチが default のときは行わない**（ファイルの作成・移動のみ行い、その旨を出力する）。該当するのは全体計画チケットの作成・着手だけ
- 未追跡のまま持ち越されたチケットファイルは、`20-common-step-feature-mr` がブランチ作成直後に行う**開始コミット**（`chore: #<N> <slug> の作業を開始`）で feature ブランチに載せる。載せるものが無い場合に限り従来どおり空コミットを作る
- feature-mr の未コミット検査は、`wip/` 配下の未追跡ファイル（持ち越し分）を除いた残りで判定する
- ブランチは従来どおり `origin/<default>` から切る（ローカル default にコミットを残さない）
- 機構のチケット判定（継続判定・宣言範囲の強制・現在地の導出）はファイルの存在で行い、git の追跡・コミットの有無を見ない。未追跡のまま持ち越したチケットも作業中として扱われる
- 開始コミットの前に、持ち越した作業中チケットの差分の基準点を作成元コミット（`origin/<default>`）に付け替える（差分検知の誤検知防止）

## 理由

- issue 番号が決まるまでブランチ名が定まらず、チケットは issue 確定より前に要る。順序は変えられないので、コミットのタイミングを feature ブランチ作成後まで遅らせるのが唯一の整合解
- 開始コミットに実体（チケット）が載ることで、MR 作成のためだけの空コミットがほぼ不要になる
- default ブランチにローカルコミットを作らない原則を保てる

## 却下した案

- **ブランチ作成をチケット作成より前に出す**: issue 番号が無いとブランチ名が決まらず、チケットなしで issue 確定を行うと「全体計画チケットの中で issue を確定する」設計と衝突する
- **ローカル default の HEAD から切る**: チケットのコミットは feature に載るが、default にローカルコミットが残り続ける
- **default 上でもコミットし、後で cherry-pick**: 履歴操作が増え、失敗時の状態が複雑になる

## 影響

- `10_spec/skills/20-common-step-ticket.md`（コミットの方式と default 上の例外）
- `10_spec/skills/20-common-step-feature-mr.md`・`00_requirement/skills/20-common-step-feature-mr.md`（開始コミット・未コミット検査の除外）
- `10_spec/skills/20-common-step-commit-push.md`（`--allow-empty` の位置づけ: 載せるものが無いときの予備）
- `hooks/10-UserPromptSubmit/workflow-entry.md`・`hooks/00-SessionStart/session-start.md`（判定がファイルの存在によることの明記、「チケットはあるが MR・ブランチが無い」状態を全体計画の途中として扱う）
