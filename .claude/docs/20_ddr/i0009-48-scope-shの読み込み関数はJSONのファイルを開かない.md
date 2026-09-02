---
type: ddr
title: i0009-48. scope.sh の読み込み関数は JSON のファイルを開かない
description: scope_load がパスを引数に取る形だとホットパスの jq 回数の上限を関数の側から破れてしまうため、hook-common が取り出した値を受け取る形に変えた判断
tags: [ddr, hooks, scope.sh, hook-common.sh, ライブラリ]
keywords: [scope_load, scope_load_approvals, scope_load_ticket, HC_, jq 回数, 責務の境界, i0009-46]
---

# i0009-48. `scope.sh` の読み込み関数は JSON のファイルを開かない

## 背景

`i0009-33` が定めた `scope.sh` の「出力の形」では、読み込み関数がファイルのパスを引数に取っていた。

```
scope_load <scope-limits.json> [type]
scope_load_ticket <ticket.md>
scope_load_approvals <approvals.json>
```

一方 `i0009-37` / `i0009-46` は「JSON を読むのは `hook-common.sh` の `hook_read_input` / `hook_read_state` で、ホットパスの `jq` は最大 2 回」と決めた。両者を並べると実装者が困る。

- `scope_load` が自分でパスを開いて `jq` を呼ぶなら、`hook_read_input` の 1 回に加えて 2 回目・3 回目が生まれ、上限を破る
- `scope_load` が開かないなら、引数のパスは何のためにあるのか分からない

`approvals.json` は `workflow-guard` の判定順 (6) で必ず参照するので、この曖昧さは主要な経路にそのまま乗る。

## 決定

- **`scope_load` と `scope_load_approvals` はパスを引数に取らない**。`hook-common.sh` が既に取り出した `HC_*` を読んで `SC_*` に詰め替えるだけにする（`scope_load` は `type` だけを任意引数に取る）
- 副入力が読めなかったことは `HC_<名前>_STATE` から分かるので、`SC_ERROR` と戻り値 2（`frontmatter.sh` 不在と同じ「ライブラリ・依存が使えない」の側）に写す
- **例外は `scope_load_ticket <ticket.md>`**。チケットの frontmatter は `frontmatter.sh`（純 bash）が読み、`jq` を使わないので上限に関わらない。パスを引数に取り続ける
- §8 の「出力の形」の表と、その下の説明に明記する

## 理由

- **上限を関数の側から破れないようにする**。「`jq` を呼ぶのは `hook-common.sh` だけ」と決めれば、回数の検査（`HK-T19`）が意味を持つ。ライブラリが自分で読める形を残すと、実装者が善意で読んでしまい、テストが通らなくなってから気づく
- **`scope.sh` を `source` する 4 本のフックが「自分が何回 `jq` を呼ぶか」を数えられる**。読み込みが呼び出し側の 2 行に集まるので、目で追える
- **`i0009-17`（ライブラリは分類まで / 照合は呼び手）と同じ線引き**。`scope.sh` の仕事は「上限と宣言を突き合わせて判定する」ことで、「ファイルを開いて JSON を解釈する」ことではない
- **`frontmatter.sh` だけ扱いが違うことに理由がある**。純 bash で fork しないので、どこから呼んでも上限に影響しない。「`jq` を使うかどうか」が境界であって「ファイルを開くかどうか」ではない

## 却下した案

- **`scope_load` が生の JSON 文字列を引数に取る**: 呼び手が `hook-common.sh` から文字列を取り出して渡すことになり、間に 1 段増える。しかも `scope.sh` の中でその文字列を解釈するには結局 `jq` が要る
- **`scope_load` がパスを取り、内部で「既に読まれていればそれを使う」キャッシュを持つ**: 「読まれているか」の判定が暗黙で、テストで固定しにくい。呼び手から見て `jq` が走るかどうかが分からない
- **`hook-common.sh` に `SC_*` まで詰めさせて `scope.sh` の読み込み関数を廃止する**: `hook-common.sh` が `scope.sh` の変数名を知ることになり、依存が逆向きになる（`scope.sh` が `hook-common.sh` を使う関係が崩れる）
- **`scope_load_ticket` も引数を取らない形に揃える**: 揃うが、`workflow-guard` は作業中チケットのパスを自分で決めており（`10_doing/*.md` の 1 枚目）、それを `hook-common.sh` に渡してから受け取り直すのは遠回り

## 影響

- `10_spec/フック共通仕様.md` §8（「出力の形」の表から 2 関数のパス引数を外し、開かないことと例外を明記）
- **実装フェーズへ**: `scope.sh` に `jq` の呼び出しが 1 つも無いことを `HK-T19` の付随として確かめる
- 関連: `i0009-33`（出力の形）・`i0009-46`（`jq` の回数）・`i0009-17`（ライブラリの責務の境界）
