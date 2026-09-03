---
type: ddr
title: i0009-47. 副入力は --rawfile と fromjson? で読み、破損で判定ごと落とさない
description: jq の --slurpfile が副入力の破損・不在で呼び出しごと失敗し stdout を空にすることが実測で分かり、--rawfile + fromjson? に変えて設定の破損がロックアウトにならないようにした判断
tags: [ddr, hooks, hook-common.sh, フェイルクローズド, ロックアウト]
keywords: [jq, --slurpfile, --rawfile, fromjson, --argjson, WF210, i0009-29, i0009-37, ロックアウト, 副入力]
---

# i0009-47. 副入力は `--rawfile` と `fromjson?` で読み、破損で判定ごと落とさない

## 背景

`i0009-37` は `hook_read_input` が `jq --slurpfile lim <scope-limits.json>` で設定を副入力として渡す形を決めた。ワーク境界の 2 巡目レビューで、この形が**設定 1 ファイルの破損を完全なロックアウトに変える**ことが分かった。

```
$ printf '{"bad"' > bad.json
$ echo '{"a":1}' | jq --slurpfile lim bad.json '.a'
jq: Bad JSON in --slurpfile lim bad.json: Unfinished JSON term at EOF at line 1, column 6
exit=2      # stdout は空

$ echo '{"a":1}' | jq --slurpfile lim missing.json '.a'
jq: Bad JSON in --slurpfile lim missing.json: Could not open missing.json: …
exit=2      # stdout は空
```

`--slurpfile` は副入力をパースしてから本体を評価するので、副入力が壊れていれば**呼び出し全体が失敗し、stdin の解析結果すら得られない**。ところが機構は次の 2 つを要求している。

- `workflow-guard` 制御方式 3: 設定が壊れたら **WF210** とし、復旧経路（提供コマンドの実行・`wip/10_tickets/**` への書き込み・`scope-limits.json` 自身への ask 付きの書き込み）は通す
- `workflow-state-guard` 制御方式 0（`i0009-29`）: 設定が読めなくても**既定値で判定を続ける**（拒否に倒さない）

どちらも「`tool_name` と対象パスが分かっていること」が前提で、`--slurpfile` に相乗りさせると前提ごと失われる。**`i0009-29` が塞いだロックアウト経路を `i0009-37` が別の形で開け直していた**。

## 決定

副入力の渡し方を変える。`--slurpfile` は使わない。

- **存在するファイルだけを `--rawfile <名前> <パス>` で文字列として渡し、`jq` の中で `fromjson? // null` に通す**
- 存在しないファイルは **`--argjson <名前> null`** に差し替える。存在の確認は `[ -f ]`（bash の組み込みなので fork しない）
- 副入力が読めなかったことは **`HC_<名前>_STATE`**（`ok` / `missing` / `broken`）で呼び手に伝える。**どう扱うかは各フックの制御方式が決める**（`workflow-guard` は WF210、`workflow-state-guard` は既定値で続行）
- `HK-T18` で固定する: 設定を壊した状態・消した状態のそれぞれで `hook_read_input` が終了 0 で戻り、`tool_name` / `tool_input` / `session_id` が取れること。`--slurpfile` 版が stdout 空・終了 2 になることを負のコントロールとして添える

実測（同じ環境）:

```
$ echo '{"a":1}' | jq -r --rawfile lim bad.json '{a:.a, lim:(($lim|fromjson?) // null)} | @json'
{"a":1,"lim":null}
exit=0
```

## 理由

- **拒否側フックが「判定できない」と「入力すら読めない」を区別できなければ、縮退の設計が成立しない**。`--rawfile` なら壊れた副入力は `null` になるだけで、stdin の解析は生きる。制御方式 3 と 0 がそのまま実装できる
- **ロックアウトは機構が最も避けるべき失敗**。0019（相対パス登録）・0020（設定破損時の拒否）に続く 3 つ目の経路で、いずれも「機構自身が自分を止めて回復手段を奪う」形をしている。実測で塞げるものは塞ぐ
- **`[ -f ]` の追加コストは 0**。bash の組み込みで fork しないので、`i0009-46` の上限に影響しない
- **`fromjson?` は失敗を握るだけで隠さない**。`// null` の結果を `HC_*_STATE` に写すので、「壊れていた」ことは呼び手に届く。黙って既定値にすり替えるのとは違う

## 却下した案

- **`--slurpfile` のまま、呼び出し前に `jq -e . <file> >/dev/null` で検証する**: `jq` の呼び出しが 1 回増え、`i0009-46` の上限を破る。しかも検証と本番の間にファイルが壊れる余地が残る
- **`--slurpfile` のまま、失敗したら stdin だけの `jq` を呼び直す**: 破損時に `jq` が 2 回になる。壊れているときこそ速く確実に答えたいのに、遅くなる方に倒れる
- **副入力を `$(cat <file>)` でシェル変数に読んで `--arg` で渡す**: `cat` が fork なので `i0009-22`（`jq` 以外の外部プロセスを起こさない）に反する。bash の `$(< file)` なら fork しないが、大きなファイルをシェル変数に載せる形になり、`scope-limits.json` が育つと引数の長さ制限に当たる
- **設定の読み取りを各フックに任せる**: `i0009-37` が共通化した利点（読み方が 1 か所）を捨てることになる
- **設定が壊れていたら常に deny に倒す（`workflow-state-guard` も含めて）**: `i0009-29` が「設定 1 ファイルの破損が全操作の拒否になり、直す手段まで奪う」として退けた案そのもの

## 影響

- `10_spec/フック共通仕様.md` §1（`hook-common.sh` の副入力の渡し方・`HC_<名前>_STATE`）・§11（`HK-T18` を新設）
- `10_spec/hooks/20-PreToolUse/workflow-guard.md` 制御方式 3（`HC_LIMITS_STATE` を判定の材料に）・テスト観点（`WG-T16` を新設）
- `10_spec/hooks/20-PreToolUse/workflow-state-guard.md` 制御方式 0（この分岐に**到達できる**ことを明記）
- `10_spec/hooks/10-UserPromptSubmit/workflow-entry.md` 手順 3（`HC_ENTRY_STATE`）
- `20_ddr/i0009-37`（渡し方をこの DDR に委ねる）
- 関連: `i0009-29`（設定破損で拒否に倒さない）・`i0009-20`（相対パス登録によるロックアウト）
