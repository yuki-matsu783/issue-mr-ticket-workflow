---
type: ddr
title: i0009-13. permissionDecision の defer は採用しない
description: ask の代わりに使える第 4 の値 defer が対話セッションでは無視される仕様であることが公式で確認されたため、採用せずヘッドレスは deny 置換のままとすると決めた判断
tags: [ddr, hooks, permissionDecision, ヘッドレス]
keywords: [defer, ask, deny, allow, permissionDecision, ヘッドレス, claude -p, WORKFLOW_HEADLESS, T3]
---

# i0009-13. `permissionDecision` の `defer` は採用しない

## 背景

共通仕様 §3 は `permissionDecision` に `deny` / `ask` / `allow` の 3 値を使い、ヘッドレス（§10）では `ask` を `deny` に置き換えると定めている。`ask` は非対話モードでは応答が得られないため拒否として扱われる、というのがその根拠だった。

issue #9 の調査 0007 f3 で、公式の hooks リファレンスに**第 4 の値 `defer`** が存在することが分かった。§12 T3 には「`"defer"` という値がある」とだけ書かれ、採用の可否が保留になっていた。

2 巡目に `curl` で原本（`hooks.md` L1781 付近）を読み直したところ、次の記載が確認できた。

> Claude Code honors this value only in non-interactive mode with the `-p` flag. In interactive sessions it logs a warning and ignores the hook result.

`defer` は `claude -p` をサブプロセスとして動かす統合（親プロセスに判断を委ねる形）のための値である。

## 決定

- **`defer` は採用しない**。共通仕様 §3 の制御方式は `deny` / `ask` / `allow` の 3 値のままとする
- ヘッドレスでの `ask` の扱いは現行どおり **`deny` への置き換え**（§10）を維持する
- §12 T3 のうち `defer` に関する部分をこの決定で閉じる。**「`claude -p` を入力から判別できるか」は閉じない**（フェーズ 4c の実測項目として残す）

## 理由

- この機構は**対話セッションで動くことを前提**にしている（承認ポイント・レビュー依頼・`AskUserQuestion` がワークフローの骨格になっている）。対話セッションで無視される値を制御の選択肢に加えても、実際に効く場面が無い
- 効かないうえに**警告がログに出る**。使うたびにノイズが増える
- `defer` が効く場面（`claude -p` をサブプロセスとして動かす統合）は、この機構が守ろうとしている場面ではない。ヘッドレスで守りたいのは「人間が応答できないので確認を通してしまう」ことで、それは `deny` 置換で既に達成している
- 採用すると「対話なら ask、ヘッドレスなら defer」の分岐が全フックに入り、判定の分岐が 1 段深くなる。得るものが無いのに複雑さだけが増える

## 却下した案

- **ヘッドレスで `ask` の代わりに `defer` を返す**: `claude -p` でしか効かず、`CI` 環境変数だけで判定しているケース（対話セッションで `CI=1` を立てた場合など）では警告になる。`deny` 置換の方が「必ず止まる」ぶん安全
- **`defer` を採用しつつ対話セッションでは `ask` にフォールバックする**: 分岐が増える割に、`defer` が効く経路をこの機構は持っていない
- **T3 全体を保留のまま残す**: `defer` の側は原本の記載で判断できるので、実測を待つ理由が無い。実測が要るのは「`claude -p` を入力から判別できるか」だけで、そこは残す

## 影響

- `10_spec/フック共通仕様.md` §12 T3（`defer` の部分を閉じ、判別の部分は残す）
- `10_spec/フック共通仕様.md` §3・§10（変更なし。現行の 3 値と `deny` 置換を維持することの確認）
- **フェーズ 4c へ**: 「`claude -p` を入力から判別できるか」の実測は残る
