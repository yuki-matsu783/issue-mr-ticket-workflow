---
type: ddr
title: i0009-08. session-start のテスト ID の接頭辞を SS-H から SE-T に変える
description: SS-H* が run-tests.sh の ID 抽出正規表現に一致せず --ids の一覧にも重複検出にも現れないため、接頭辞を SE-T に変えると決めた判断
tags: [ddr, hooks, session-start, テスト]
keywords: [SS-H, SE-T, run-tests.sh, 正規表現, --ids, テスト ID, 重複検出, 受け入れ条件 2]
---

# i0009-08. session-start のテスト ID の接頭辞を SS-H から SE-T に変える

## 背景

`run-tests.sh:110` は結果行から ID を抜き出すのに `^(PASS|FAIL) ([A-Z]{2,6}-[TE][0-9]{2}[a-z]?)` を使う。3 文字目以降が `T` か `E` に限られるため、`session-start` の `SS-H01`〜`SS-H09` は**一致しない**。結果として `--ids` の一覧にも重複検出にも現れず、issue #9 の受け入れ条件 2（登録後に `run-tests.sh --ids` の全件が通る）を満たせない（調査 0005 f3）。

`SS-H` という接頭辞になっていたのは、`SS-T` を `20-common-step-shell-script` の既存テスト（SS-T00〜T04）が使っているため。

## 決定

- `session-start` のテスト ID の接頭辞を **`SE-T`** に変える（`SE-T01`〜`SE-T09`）
- `run-tests.sh` 側の正規表現は変えない（`20-common-step-shell-script` の仕様。0015 が制約を明記する）

## 理由

- 影響がフック 1 本のテストに閉じる。正規表現を広げる案は `20-common-step-shell-script` の仕様と TR 系テストが連動し、他のアセットの ID 命名にも影響する
- `SE` は既存・新規のどの接頭辞とも衝突しない（既存: AA / BB / CC / CP / FR / HK / LG / RV / SS / TR / TICKET、新規: WE / SG / BC / BG / WG / DC / PP / UR / SA / SP）
- `BG-T09b` のような枝番は正規表現の `[a-z]?` に合うので現状維持でよい

## 却下した案

- **`run-tests.sh` の正規表現を `[A-Z]` に広げる**: `20-common-step-shell-script` 仕様と TR 系テストの変更が要り、影響範囲が広い。ID の 3 文字目に意味（T = テスト / E = eval）を持たせている設計も崩れる
- **`SS-T05` 以降を使う**: 既存の `SS-T00`〜`T04` と連番が続いてしまい、別のアセットのテストが同じ接頭辞を共有する状態が続く

## 影響

- `10_spec/hooks/00-SessionStart/session-start.md` テスト観点の表と要件との対応
- **0015 へ**: `run-tests.sh` の ID 抽出の制約（`[A-Z]{2,6}-[TE][0-9]{2}[a-z]?`）を `20-common-step-shell-script` 仕様に明記する
