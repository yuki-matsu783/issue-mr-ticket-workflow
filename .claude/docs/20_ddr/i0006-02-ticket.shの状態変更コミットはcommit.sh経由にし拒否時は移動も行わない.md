---
type: ddr
title: i0006-02. ticket.sh の状態変更コミットは commit.sh 経由にし、拒否時は移動も行わない
description: チケットの作成・着手・完了・取り消しに伴うコミットを、ticket.sh が git を直接叩くのではなく commit.sh を内部から呼ぶ形に統一し、commit.sh が拒否したときはチケットの移動も行わない判断。仕様間の矛盾（commit-push 仕様と ticket 仕様）の解消
tags: [ddr, ticket, commit, 提供コマンド]
keywords: [ticket.sh, commit.sh, 状態変更のコミット, 規約検査, 除外パターン, 仕様内矛盾, 移動とコミットの分離, overall-plan 非コミット]
---

# i0006-02. ticket.sh の状態変更コミットは commit.sh 経由にし、拒否時は移動も行わない

## 背景

`20-common-step-commit-push` 仕様の呼出条件は「`ticket.sh` は状態変更のコミットに内部から `commit.sh` を使う」と書き、`20-common-step-ticket` 仕様の Script 処理は「各サブコマンドが内部で `git` を直接実行する」と書いていた。調査（issue #6 チケット 0003、付録 B §3-4）で仕様内の矛盾として検出された。

## 決定

- `ticket.sh` の create / start / complete / cancel は、状態変更のコミットを `commit.sh -m "<件名>" <パス>...`（移動なら旧パスと新パス。`commit-push` 仕様のインターフェースどおり `--` は使わない）で行う
- `commit.sh` が拒否した（メッセージ規約・除外パターン・差分なし）ときは、その最終行をそのまま `ticket.sh` の失敗として返し、作業ツリーを実行前の状態に戻す（移動・作成・記載事項の変更だけが済んだ状態を残さない）
- `overall-plan` の create / start がコミットしない規定（DDR i0004-04）は維持する

## 理由

- メッセージ規約の検査・除外パターンの突合・除外一覧の出力が `commit.sh` の 1 箇所に集まり、`ticket.sh` は件名と対象パスを渡すだけになる
- 移動だけ済んでコミットされていない中間状態を作らない（フックの継続判定はファイルの存在を見るため、中間状態は「作業中なのに履歴に無い」チケットを生む）
- 参考実装にも同じ構図がある（`cleanup-task.sh` は自前コミットを避け、コミットを呼び出し側の責務にしている）

## 却下した案

- **`git` 直実行のまま commit-push 仕様を直す**: 規約検査が 2 箇所に散り、除外パターンの突合が `ticket.sh` に無い状態が残る
- **移動してからコミットし、拒否されたら移動を戻す**: 戻し忘れ・途中失敗で中間状態が残る

## 影響

- `10_spec/skills/20-common-step-ticket.md`（Script 処理 冒頭・create 4・参照ナレッジ・TICKET-T10）
- `10_spec/skills/20-common-step-commit-push.md`（変更なし。呼出条件が正になった。引数形は同仕様の `commit.sh -m "<メッセージ>" <ファイル>...` に従う）
