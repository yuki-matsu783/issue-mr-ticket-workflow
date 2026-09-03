---
type: ddr
title: i0009-57. 出力先の取り出しは cmdpos_args の走査で行う
description: cmdpos_operands ではオプション本体が落ちて URL と出力先を区別できないため、引数列を先頭から走査してオプションの次の語を取る形に定めた判断
tags: [ddr, hooks, cmdpos.sh, scope.sh, web]
keywords: [cmdpos_operands, cmdpos_args, REPLY_ARGS, curl, -o, --output, -O, URL, 出力先]
---

# i0009-57. 出力先の取り出しは `cmdpos_args` の走査で行う

## 背景

`i0009-41` の影響と 0022 の申し送りは、`curl` / `wget` の出力先オプションの照合に **`cmdpos_operands`**（`i0009-39`）が使えると書いた。

`cmdpos_operands` の定義は「`CP_ARGS[i]` から `-` で始まる語と `--` 以降の区切りを除いた**位置引数**を `REPLY_OPERANDS` に展開する」である。これを `curl` に当てると、**オプション本体（`-o`）が落ちて、残った語のうちどれが URL でどれが出力先かを区別できない**。

```
curl https://x/y -o wip/tmp/a   → REPLY_OPERANDS = [https://x/y, wip/tmp/a]
curl -o wip/tmp/a https://x/y   → REPLY_OPERANDS = [wip/tmp/a, https://x/y]
curl https://x/y                → REPLY_OPERANDS = [https://x/y]     ← 出力先は無い
```

この結果に §8 の判定を当てると、出力先を持たない `curl <url>` でも URL がパスとして正規化されて WF205 / WF202 に落ちかねず、`WG-T15` が固定した「`curl https://example.com/x` は `web` を宣言した investigation で**通る**」と食い違う。

## 決定

- 出力先の取り出しは **`cmdpos_args`（`REPLY_ARGS`）で得た引数列を先頭から走査する**
  - `curl` の `-o` / `--output` / `--output-dir`、`wget` の `-O` を見つけたら、**その次の語**を出力先とする（`--output=<path>` の等号形は前方一致で拾う）
  - `curl` の `-O` / `--remote-name` と `wget` の**既定動作**は出力先の語を取らない。**URL の basename を作業ツリー基準のカレントに作る**ものとして扱う
  - **`://` を含む語は URL とみなし、出力先として扱わない**
- `i0009-41` の影響と 0022 の申し送りから `cmdpos_operands` の記述を外す
- `WG-T17` に「出力先と URL の取り違えをしない」ケース（URL が先 / 出力先が先 / 出力先なし）を置く

## 理由

- **`cmdpos_operands` は「オプションを機械的に落とす」関数で、オプションと値の対応を保たない**（`i0009-39` がそう定義した）。`rm` / `git rm` のように**位置引数だけが意味を持つ**コマンドには合うが、`curl` のように**オプションが値を取る**コマンドには合わない。関数が悪いのではなく、当てる先を間違えていた
- **`i0009-39` の線引き（ライブラリは整形まで / 意味論は呼び手）が守られる**。「`-o` の次が出力先」というのは `curl` の意味論なので、`scope.sh`（呼び手）が持つ。`cmdpos.sh` に `curl` の知識を入れない
- **`://` による URL の判定で足りる**。`curl` に渡す URL はスキームを持つのが通常で、スキームを省いた形（`curl example.com`）は出力先として扱われても実害が小さい（`example.com` というパスへの書き込みは WF202 の確認になるだけ）
- **`-O` と `wget` の既定を「カレントに作る」と扱う**のは、そこが作業ツリーのルートであれば `wip/tmp/**` に当たらず WF205 になるため、安全側に倒れる

## 却下した案

- **`cmdpos.sh` に `cmdpos_option_value <i> <opt>` を足す**: 汎用のオプション値の取得はコマンドごとの記法（等号形・結合形 `-ofile`）に踏み込むことになり、`i0009-39` が「オプションの厳密な解析まで行わない」として退けた範囲に入る。今回必要なのは `curl` / `wget` の数個だけ
- **出力先を持つかどうかを見ず、`web` の分類では常に書き込みの判定を当てる**: `curl <url>`（標準出力）が毎回 URL をパスとして判定され、`WG-T15` と矛盾する
- **`REPLY_OPERANDS` の最後の語を出力先とみなす**: `curl -o out <url>` では URL が最後になる。順序に依存する当て推量で、決定的でない

## 影響

- `10_spec/フック共通仕様.md` §8（出力先の取り出し方）
- `10_spec/hooks/20-PreToolUse/workflow-guard.md` `WG-T17`
- `20_ddr/i0009-41`（影響から `cmdpos_operands` を外す）
- `wip/30_reports/0022-ai-asset-design.md`「設計への反映」2 の申し送り（0025 の結果報告で訂正する）
- 関連: `i0009-39`（`cmdpos_operands` の定義）・`i0009-56`（判定順）
