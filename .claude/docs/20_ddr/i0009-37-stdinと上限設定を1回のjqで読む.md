---
type: ddr
title: i0009-37. hook_read_input は stdin と上限設定を 1 回の jq で読む
description: ホットパスの fork 上限を「jq 1 回」に決めたあと workflow-guard が scope-limits.json を読めなくなる問題を、jq の --slurpfile で副入力として渡すことで解いた判断
tags: [ddr, hooks, hook-common.sh, パフォーマンス]
keywords: [jq, --slurpfile, hook_read_input, scope-limits.json, fork 上限, ホットパス, workflow-guard]
---

# i0009-37. `hook_read_input` は stdin と上限設定を 1 回の `jq` で読む

## 背景

`i0009-22` はホットパスのフックが起動してよい外部プロセスを「**stdin を解析する `jq` の 1 回だけ**」と決めた。0019 の結果報告はこれを ✕問題 として出し、**実装可能性が未確認**であることを申し送った。

問題は `workflow-guard` である。このフックは判定に 2 つの JSON を要する。

- stdin のフック入力（`tool_name` / `tool_input` / `session_id` / `permission_mode` …）
- **`.claude/hooks/config/scope-limits.json`**（`common.*` と `types[t].*`）

素直に書けば `jq` が 2 回になり、上限を超える。チケットの frontmatter は `frontmatter.sh`（純 bash）で読むので問題にならず、**残るのは上限設定だけ**だった。

## 決定

`hook-common.sh` の **`hook_read_input`** が、**stdin と `scope-limits.json` を 1 回の `jq` 呼び出しで読む**。

- `jq` の **`--slurpfile`**（ファイルを副入力として変数に読み込むオプション）で設定を渡す。stdin は通常の入力として解析する
- 1 回の呼び出しで、フック入力の共通フィールドと `tool_input` の必要な値、および `common.*` / `types[t].*` の必要な値をまとめて取り出し、呼び出し元のシェル変数・配列に置く
- §1 の lib の説明にこの形を明記する

## 理由

- **`jq` は複数の入力を 1 回で扱える**。`--slurpfile` / `--argjson` / `--rawfile` はまさにこのためのオプションで、追加のプロセスを起こさずに副入力を渡せる。上限を緩めずに要求を満たせる
- **上限を緩める方が高くつく**。「`jq` 2 回」に緩めると、次に別の設定ファイルが要ったときに 3 回になる。上限は「fork をこれ以上増やさない」という設計の圧力として働くべきもので、要求のたびに緩めると意味が無い（`i0009-22` の趣旨）
- **読み取りが 1 か所に集まる**利点もある。`hook_read_input` が入力と設定の両方を返せば、各フックが設定の読み方を自作しない（`i0009-17`「ライブラリは分類まで」と同じく、共通化できるものは共通化する）
- 案内側フック（`post-push-*` / `session-start` など）はホットパスではないので、必要なら別途 `jq` を呼んでよい。この決定はホットパスの 5 本に対する制約

## 却下した案

- **ホットパスの上限を「`jq` 2 回」に緩める**: 上限が要求に押されて動くなら制約として機能しない。しかも 5 本が並列に走るので、1 回の増加が 5 プロセスの増加になる
- **`scope-limits.json` を TSV や `key=value` の平文に変える**: 純 bash で読めるようになるが、`common.allow` のような配列と `types[t]` の入れ子を平文で表すと読みにくくなる。**ユーザーが管理する設定**（`workflow-guard` 仕様が形式の正）なので、可読性を落とす変更は避けたい
- **`scope-limits.json` を起動時に 1 回だけ読んでキャッシュする**: フックは毎ツール呼び出しで新しいプロセスとして起動するので、「起動時」がそのまま「毎回」になる。キャッシュファイルを持つと今度はその読み書きと陳腐化の管理が要る
- **設定の読み取りを `frontmatter.sh` のような純 bash パーサで書く**: JSON の入れ子とエスケープを純 bash で正しく扱うのは壊れやすい（`frontmatter.sh` が汎用 YAML パーサではないと断っているのと同じ理由）

## 影響

- `10_spec/フック共通仕様.md` §1（`hook-common.sh` の説明に `--slurpfile` の形を明記）
- **実装フェーズへ**: `hook_read_input` の引数に上限設定のパスを取る（省略時は読まない）。ホットパス 5 本のテストに `make_counting_path` による `jq` の回数検査（1 回）を入れる
- 0019 の f2（✕問題）として残した実装可能性の疑いは**これで解消**する
- 関連: `i0009-22`（fork 上限）・`i0009-21`（並列実行で 5 倍になること）
