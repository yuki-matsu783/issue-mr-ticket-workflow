---
type: ddr
title: i0009-10. フックが読む外部データは .claude/hooks/config/ に集約し assets/ を作らない
description: entry-skills.txt と model-aliases.txt の基準ディレクトリが未定だったため、フックが読む外部データの置き場を既存の config/ に一本化し、フック側に assets/ を作らないと決めた判断
tags: [ddr, hooks, 置き場, config]
keywords: [entry-skills.txt, model-aliases.txt, blocked-commands.txt, scope-limits.json, task-types.tsv, assets, config, common.confirm, WF203]
---

# i0009-10. フックが読む外部データは `.claude/hooks/config/` に集約し `assets/` を作らない

## 背景

issue #9 の調査 0005 f4 で、フックが読む外部データファイルのうち 3 本が未作成であることが分かった。

| ファイル | 読み手 | 置き場 |
|---|---|---|
| `blocked-commands.txt` | `block-chmod` | `.claude/hooks/config/`（仕様が確定済み） |
| `entry-skills.txt` | `workflow-entry` | **未定**（仕様は `assets/entry-skills.txt` と相対で書いていた） |
| `model-aliases.txt` | `subagent-start-check` | **未定**（同上。0013 は「基準ディレクトリは 0014 が確定するまで暫定」と明記して先送りした） |

`assets/` はスキルの規約（`20-common-step-*` のテンプレート置き場）から借りた書き方で、フックにはそもそも `assets/` の慣行が無い。一方 `.claude/hooks/config/` は既に `scope-limits.json` と `task-types.tsv` が置かれており、`scope-limits.json` の `common.confirm` にも `.claude/hooks/config/**` として登録されている。

## 決定

- **フックが読む外部データはすべて `.claude/hooks/config/` に置く**。1 ファイル 1 用途。現時点の 5 本は `scope-limits.json` / `task-types.tsv` / `blocked-commands.txt` / `entry-skills.txt` / `model-aliases.txt`
- **フックのディレクトリ配下に `assets/` を作らない**。`assets/` はスキル配下のテンプレート等に限る
- 共通仕様 §1 に置き場の行を足し、`workflow-entry` 仕様（呼出条件・WE-T07）と `subagent-start-check` 仕様（制御方式 4）のパスを絶対の形（`.claude/hooks/config/...`）に書き換える
- `config/` 配下は `common.confirm` に当たるため、**新規作成時に毎回 WF203 の確認が入る**ことを共通仕様に明記する（実装フェーズで驚かないため）

## 理由

- 置き場が 1 か所なら、`scope-limits.json` の `common.confirm` の 1 行（`.claude/hooks/config/**`）だけで全部が保護される。`assets/` を作ると保護パターンを増やすか、保護から漏れるかのどちらかになる
- `blocked-commands.txt` が既に `config/` に決まっているので、同じ性格（フックが読む・ユーザーが編集し得る・コードではない）のファイルを別のディレクトリに分けると、読み手が「どちらを見るか」を毎回考えることになる
- 相対パス（`assets/...`）は「何からの相対か」が仕様上あいまいで、フック本体（`.claude/hooks/<NN-Event>/`）からの相対なのかフックのルートからなのかが読み取れない。絶対の形にすれば `cd` の位置に依存しない
- 拡張子が `.json` / `.tsv` / `.txt` と混在するのは許容する。用途ごとに素直な形式を選ぶ方が、統一のために不自然な形式へ寄せるより読みやすい

## 却下した案

- **`.claude/hooks/assets/` を作る**: スキルの `assets/` と名前が同じで役割が違う（スキルの `assets/` は AI が読むテンプレート、フックのそれは実行時にスクリプトが読むデータ）。同名で違う意味の慣行を 2 つ持つのは避けたい
- **各フックのディレクトリ配下（`.claude/hooks/20-PreToolUse/config/`）に置く**: 共有されるファイル（`model-aliases.txt` は将来 `subagent-stop-check` も読み得る）の置き場が決まらない。イベント名のディレクトリに設定が散る
- **`.claude/config/` に置く**: フック以外（スキル・エージェント）も読む場所と誤解される。今のところ読み手はフックだけなので、`hooks/` の下に閉じておく方が範囲が明確

## 影響

- `10_spec/フック共通仕様.md` §1（置き場の行を追加）
- `10_spec/hooks/10-UserPromptSubmit/workflow-entry.md` 呼出条件・WE-T07
- `10_spec/hooks/12-SubagentStart/subagent-start-check.md` 制御方式 4（暫定の注記を外す）
- `20_ddr/i0009-03`（影響欄の「0014 で確定するまで暫定」を確定済みに書き換え）
- **実装フェーズへ**: `entry-skills.txt` と `model-aliases.txt` の 2 本を新規作成する。作成時に WF203 の確認が出る
