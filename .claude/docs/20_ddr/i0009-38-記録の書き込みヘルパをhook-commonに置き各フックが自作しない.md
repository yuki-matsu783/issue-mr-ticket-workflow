---
type: ddr
title: i0009-38. 記録の書き込みヘルパを hook-common.sh に置き、各フックが自作しない
description: 並行書き込みの 3 段階の規則を各フックが個別に実装すると守られないため、追記・原子的置換・ロックのヘルパを共有ライブラリに置くと決めた判断
tags: [ddr, hooks, hook-common.sh, 並行書き込み]
keywords: [hc_append_jsonl, hc_json_write, hc_lock, hc_unlock, mkdir ロック, 4KB, PIPE_BUF, 原子的]
---

# i0009-38. 記録の書き込みヘルパを `hook-common.sh` に置き、各フックが自作しない

## 背景

`i0009-23` は `logs/` への並行書き込みを 3 段階で規定した。

1. 追記だけのファイル（`*.jsonl` / `*.log`）: 1 行を 4 KB（`PIPE_BUF`）未満に保って `>>`
2. 読んで書き換えるファイル: 一時ファイル（`<name>.tmp.<pid>`）+ `mv`
3. read-modify-write が競合するもの（`usage/<branch>.json`）: `mkdir` ロックで直列化、取れなければ最大 2 秒で諦める

`decisions.jsonl` は**全フック**（11 本）が書き、`push-state.json` / `usage/<branch>.json` / `approvals.json` はそれぞれ別のフックが書く。規則を各フックが個別に実装すると、切り詰めの閾値・一時ファイルの命名・ロックのタイムアウトが 11 通りに分かれる。

## 決定

`hook-common.sh` に書き込みヘルパを置き、**各フックは自作しない**。

| 関数 | 役割 |
|---|---|
| `hc_append_jsonl <file> <line>` | 1 行を 4 KB 未満に切り詰めて（切り詰めたら末尾に `…`）`>>` で追記する |
| `hc_json_write <file> <content>` | 同じディレクトリの一時ファイル（`<name>.tmp.<pid>`）へ書いて `mv` で置き換える |
| `hc_lock <name>` / `hc_unlock <name>` | `mkdir <name>.lock` によるロック。取得できなければ最大 2 秒待って非 0 を返す。`trap` でも解放する（**打ち切りでは `trap` が効かないため、陳腐化したロックの強制解放を持つ — `i0009-60`**） |

§1 の `hook-common.sh` の説明にこの 4 つを載せ、lib 単体のテスト観点を `HK-T17` が受け持つ。

## 理由

- **規則を書いただけでは守られない**。切り詰めの閾値（4 KB / `note` と `target` で 1 KB）やロックのタイムアウト（2 秒）のような数値は、実装のたびに解釈がぶれる。関数に閉じれば 1 か所で決まる
- **`decisions.jsonl` は全フックが書く**ので、ここだけでも共通化の価値がある。11 本が同じ切り詰めロジックを持つのは重複の典型
- `redact`（§3）が既に同じ形で `hook-common.sh` にある。記録に載せる前に通す関数という点で性格が同じで、`hc_append_jsonl` の中で `redact` を呼ぶ形にできる
- **ロックの解放漏れが一番怖い**。`trap` の登録を関数の中に閉じれば、呼び手が `trap` を書き忘れてもロックが残らない

## 却下した案

- **各フックが直接 `>>` と `mv` を書く**: 上記のとおり数値と命名がぶれる。`trap` の書き忘れでロックが残る事故も起きる
- **`logger.sh` に相乗りさせる**: `logger.sh` は「ログ機構の失敗が本体を止めない」ために全関数を no-op にできる設計（`nop` ポリシー）で、記録（`decisions.jsonl`）とは失敗時の扱いが違う。`decisions.jsonl` は振り返りの材料なので、書けなかったことは分かる必要がある
- **別のライブラリ（`lib/record.sh`）に分ける**: `hook-common.sh` が既に「記録（`logs/`）」を担っており（§1 の説明）、分ける理由が無い。`source` が 1 本増えるコストの方が大きい

## 影響

- `10_spec/フック共通仕様.md` §1（`hook-common.sh` の説明に 4 関数を追加）・§11（`HK-T17` が lib 単体の観点も受け持つ）
- **実装フェーズへ**: `hc_append_jsonl` は内部で `redact` を通す。`hc_lock` は `trap` で解放を保証する
- 関連: `i0009-23`（並行書き込みの 3 段階の規則）
