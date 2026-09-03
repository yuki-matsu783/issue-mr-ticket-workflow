---
type: ddr
title: i0009-39. cmdpos.sh に cmdpos_operands を足して削除対象を取り出せるようにする
description: 作業中・完了チケットの削除を塞ぐ判定に位置引数が要るが cmdpos.sh の出力は引数を生のまま返すだけだったため、オプションを除いた位置引数を返す補助関数を足した判断
tags: [ddr, hooks, cmdpos.sh, ライブラリ]
keywords: [cmdpos_operands, CP_ARGS, REPLY_OPERANDS, rm, git rm, mv, WF302, WF303, 位置引数]
---

# i0009-39. `cmdpos.sh` に `cmdpos_operands` を足して削除対象を取り出せるようにする

## 背景

`i0009-30` は「`rm` / `git rm` / `mv` / `git mv` の**元**（消える側）が `wip/10_tickets/10_doing/**` → WF302、`20_done/**` → WF303」と決めた。

`cmdpos.sh` の出力（§7-9）には `CP_ARGS[i]`（引数。区切りは RS）と `cmdpos_args <i>`（`REPLY_ARGS` 配列に展開）があるが、**オプションと位置引数を区別しない**。`rm -rf wip/10_tickets/20_done/0003.md` を渡すと `REPLY_ARGS` は `-rf` と パスの 2 要素になり、呼び手が自分で `-` 始まりを飛ばすことになる。同じ処理が `workflow-state-guard` と、将来 `workflow-guard` の WF205（コマンドによるファイル書き込み）でも要る。

## 決定

`cmdpos.sh` に補助関数 **`cmdpos_operands <i>`** を足す。

- `CP_ARGS[i]` から `-` で始まる語と `--` 以降の区切りを除いた**位置引数**を `REPLY_OPERANDS` 配列に展開する
- 例: `rm -rf a b` → `a b` / `mv -v src dst` → `src dst`
- **削除対象か宛先かの解釈は呼び手が行う**。`workflow-state-guard` は `rm` / `git rm` なら全部を「元」、`mv` なら最後を宛先・それ以外を元として扱う

## 理由

- **`i0009-17`（ライブラリは分類まで / 照合は呼び手）に沿う**。「オプションを除く」は入力の機械的な整形で、ライブラリの仕事。「最後が宛先か」はコマンドごとの意味論で、呼び手の仕事。線引きがこの規則どおりに引ける
- **同じ処理が 2 か所以上で要る**。`workflow-state-guard`（削除・移動の元）と `workflow-guard`（WF205 のコマンドによる書き込み対象）が同じ整形を必要とする。重複を避ける
- `cmdpos.sh` は既に純 bash・fork なしで動いており（HK-T05）、位置引数の抽出も同じ方針で書ける。ホットパスの fork 上限（`i0009-22`）に影響しない
- `CP_WRITE_TARGETS[i]` という似た出力が既にあるが、こちらは「書き込み対象」という**意味づけ済み**の集合で、削除の元は含まない。整形だけの `cmdpos_operands` とは役割が違う

## 却下した案

- **`workflow-state-guard` の中で `-` 始まりを飛ばす**: `workflow-guard` でも同じ処理が要るので重複する
- **`CP_WRITE_TARGETS` に削除の元を含める**: 「書き込み対象」の意味が広がりすぎる。`rm` の対象は書き込みではなく削除で、識別子も違う（WF205 と WF302 / WF303）
- **`cmdpos_operands` がコマンドごとに宛先を判定して返す**: ライブラリが `mv` / `cp` / `rm` の意味論を持つことになり、`i0009-17` の線引きに反する。新しいコマンドを足すたびにライブラリを触ることになる
- **オプションの厳密な解析（`-r` と `--recursive` と `-rf` の区別）まで行う**: 削除対象の抽出には不要。`-` 始まりを飛ばすだけで足りる（`rm -- -file` のようなケースは `--` 以降を位置引数として扱えば拾える）

## 影響

- `10_spec/フック共通仕様.md` §7-9（補助関数に `cmdpos_operands` を追加）
- `10_spec/hooks/20-PreToolUse/workflow-state-guard.md` 制御方式 3（元の判定で `cmdpos_operands` を使うことを明記）
- `10_spec/skills/20-common-step-shell-script.md`「ライブラリの責務の境界」（`cmdpos.sh` の行）
- **実装フェーズへ**: `HK-T05`（`cmdpos.sh` の lib 単体）に位置引数の抽出のケースを足す
- 関連: `i0009-30`（削除の遮断）・`i0009-17`（分類まで / 照合は呼び手）
