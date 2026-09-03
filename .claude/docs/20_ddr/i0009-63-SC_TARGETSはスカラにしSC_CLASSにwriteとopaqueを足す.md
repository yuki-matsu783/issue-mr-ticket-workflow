---
type: ddr
title: i0009-63. SC_TARGETS はスカラにし、SC_CLASS に write と opaque を足す
description: フック共通仕様 §8 の公開変数の表が既存実装と食い違っていたため、配列表記と値集合の不足を実装の側に合わせて仕様を直すと決めた判断
tags: [ddr, hooks, scope, 仕様の書き戻し]
keywords: [SC_TARGETS, SC_CLASS, scope.sh, scope_match, SC_BUILD_TEST, 0x1E, write, opaque]
---

# i0009-63. `SC_TARGETS` はスカラにし、`SC_CLASS` に `write` と `opaque` を足す

## 背景

フック共通仕様 §8 は `scope.sh` の公開変数を表で定めている。この表と実体が 4 点で食い違っていた。

| 仕様 §8 の表 | 実体（`scope.sh`） |
|---|---|
| `SC_TARGETS[]`（配列） | US（0x1E）区切りのスカラ文字列 |
| `SC_CLASS` の値集合に `write` / `opaque` / `remote-write:upload` / `web` が無い | 4 つとも返る |
| `scope_match <path> <pattern>` | `scope_match <glob> <path>`（引数順が逆） |
| `SC_BUILD_TEST[]` | `SC_BUILD_TEST_CMDS` |

0027 で `scope_classify` に web の 3 段判定を足したとき、`write` 分岐が既にスカラで `SC_TARGETS` を組み立てていたので、新しい分岐もそれに合わせた。引数順と名前のずれは 0027 以前からある既存のもので、0027 の変更ではない。

## 決定

- **仕様の側を実装に合わせる**。4 点とも §8 の表を直す
- `SC_TARGETS` は US（0x1E）区切りのスカラ文字列とする（表から `[]` を外す）。取り出しは呼び手が同じ区切りで割る
- `SC_CLASS` の値集合に `write` / `opaque` / `remote-write:upload` / `web` を足し、実体が返しうる値をすべて列挙する
- `scope_match` の引数順は `<glob> <path>`、ビルドテストの変数名は `SC_BUILD_TEST_CMDS` と書く
- `scope_load` / `scope_load_approvals` の戻り値のずれ（仕様は 2、実装は 1）も同じ §8 の中にあるが、あちらは HK-T16 が実装側を固定しているので**別の判断として扱う**（この DDR は表の 4 点だけを扱う）

## 理由

- **配列にする実利が無い**。`cmdpos.sh` の公開変数（`CP_ARGS` / `CP_REDIRECTS` / `CP_WRITE_TARGETS`）が既に同じ 0x1E 区切りのスカラなので、揃えたほうが呼び手が覚える割り方が 1 つで済む
- **bash の配列は関数の境界を越えにくい**。配列で返すなら `declare -g -a` で書くか `cmdpos_args` のような展開関数を SC 側にも用意することになり、得るものは「仕様の文字どおり」だけ
- **値集合が実体より狭いと危険**。読んだ人が「`write` は返らない」と信じて分岐を落とす。列挙は漏れた時点で誤読の原因になる
- **呼び手が既にスカラ前提**。`workflow-guard` / `workflow-diff-check` / `workflow-state-guard` が同じ形で読んでおり、HK-T11 / HK-T15 が実装の側を固定している
- 引数順と名前は**実体が正しく動いている**もので、仕様の写し間違いに実装を合わせる理由が無い

## 却下した案

- **実装を配列に直す**: 呼び手 5 本を同時に直すことになる。変更の量に対して得るものが無い
- **`SC_TARGETS` を NUL 区切りにする**: bash の変数に NUL バイトは入らない
- **値集合を仕様から消し「実装が返すもの」とだけ書く**: 網羅性が検査できなくなる。呼び手が全分岐を書けたかを仕様から確かめられなくなる
- **`scope_match` の引数順を仕様に合わせて実装を直す**: 呼び出し箇所すべてを同時に直す必要があり、引数がどちらも文字列なので取り違えても静かに誤判定する。ずれの解消に見合うリスクではない

## 影響

- `10_spec/フック共通仕様.md` §8（`SC_TARGETS` のスカラ化・`SC_CLASS` の値集合・`scope_match` の引数順・`SC_BUILD_TEST_CMDS` の名前）
- 実装は変更しない（0027 の実体がそのまま正）
- 関連: `i0009-56`（web の判定順は送信側と出力先を先に見る）・`i0009-57`（出力先の取り出しは `cmdpos_args` の走査）・`i0009-72`（区切りバイトの割り当て）・`i0009-48`（`scope.sh` の読み込み関数は JSON のファイルを開かない）
