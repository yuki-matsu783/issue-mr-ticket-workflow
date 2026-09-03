---
type: ddr
title: i0009-07. post-push の成功判定は PostToolUse に届いたことをもって成功とする
description: tool_response に終了コードのフィールドが存在せず PostToolUse が成功時にしか発火しないことが公式で確認されたため、post-push-* の成功判定から終了コード読みを外すと決めた判断
tags: [ddr, hooks, post-push-compact-prompt, post-push-usage-report]
keywords: [tool_response, exit_code, PostToolUse, PostToolUseFailure, 成功判定, T7, push-detect]
---

# i0009-07. post-push の成功判定は PostToolUse に届いたことをもって成功とする

## 背景

`post-push-compact-prompt` の制御方式 2 は「`tool_response` の終了コードが 0（フィールド名は `exit_code` / `exitCode` / `returnCode` / `code` の順に読み、どれも無ければ 0、`interrupted: true` は失敗）」で push の成功を判定していた。フィールド名が確定できず、共通仕様 §12 T7 が実測待ちの TBD として残っていた。

issue #9 の調査 0007 f4（2 巡目に `curl` で原本を読み直した結果）で次が確定した。

- 「`PostToolUse` hooks fire after a tool has already **executed successfully**.」（`hooks.md` L1930）。失敗は別イベント `PostToolUseFailure` に流れる
- 「`Bash` returns an object with `stdout`, `stderr`, `interrupted`, and `isImage` fields.」（L1990）。**終了コードのフィールドは無い**
- 失敗側（`PostToolUseFailure`）の入力は `error` / `is_interrupt` / `duration_ms` で、Bash / PowerShell なら `error` の 1 行目が `Exit code N`（L2066）

## 決定

- `post-push-compact-prompt` の成功判定を「**PostToolUse に届いた時点で成功**」に変える。`tool_response` の終了コードは読まない
- 上流が解決できないときの縮退も「PostToolUse に届いたこと自体をもって反映されたとみなす」に書き換える
- `post-push-usage-report` は検知を `push-detect` 経由で共有するので、要件との対応に同じ方針を注記する
- **`PostToolUseFailure` は登録しない**（`post-push-*` は成功時の案内が仕事で、失敗時に出すものが無い）
- 共通仕様 §12 T7 を「終了コードのフィールドは存在しない」で閉じるのは 0014 の担当

## 理由

- 読もうとしているフィールドが存在しないので、現行の「4 候補を順に読み、どれも無ければ 0」は**常に「無し → 0」に落ちる**。結果は正しいが、根拠にしているものが無い建て付けは仕様として誤り
- PostToolUse が成功時にしか発火しないなら、届いたこと自体が成功の証拠として十分で、追加の読み取りが要らない
- `PostToolUseFailure` を登録すると §1 の登録表がもう 1 行増えるが、失敗した push に対して案内すべきことが無い（AI は失敗を tool の結果として既に見ている）

## 却下した案

- **実測まで現行の 4 候補読みを残す**: 実測する対象（フィールド）が存在しないと分かった以上、実測は「無いことの確認」にしかならない。仕様を先に直す方が正直
- **`interrupted` を見て失敗を弾く**: `interrupted` は「中断された」で、PostToolUse に届く時点で成功しているなら現れない。判定に足しても意味が無い
- **`PostToolUseFailure` を登録して失敗も捕まえる**: 登録表が増える割に、出す案内が無い

## 影響

- `10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md` 入出力・制御方式 2・PP-T08
- `10_spec/hooks/22-PostToolUse/post-push-usage-report.md` 要件との対応
- **0014 へ**: 共通仕様 §12 T7 を閉じる。§1 に `PostToolUseFailure` は足さない
