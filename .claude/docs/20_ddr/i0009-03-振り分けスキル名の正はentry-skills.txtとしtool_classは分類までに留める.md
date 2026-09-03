---
type: ddr
title: i0009-03. 振り分けスキル名の正は entry-skills.txt とし、tool_class は分類までに留める
description: hook-common.sh の tool_class が持つ 00-workflow-* の接頭辞判定と、workflow-entry が読む entry-skills.txt の列挙が二重定義になる問題に対し、名前の照合をフック側に一本化すると決めた判断
tags: [ddr, hooks, workflow-entry, hook-common]
keywords: [tool_class, entry-skills.txt, 00-workflow-, 二重定義, declare, WE-T07, CLAUDE.md]
---

# i0009-03. 振り分けスキル名の正は entry-skills.txt とし、tool_class は分類までに留める

## 背景

`hook-common.sh:156-165` の `tool_class` は `Skill` ツールのとき `case "${2:-}" in 00-workflow-*) printf 'declare\n' ;; *) printf 'read\n' ;; esac` と、`00-workflow-` の接頭辞をコードに持っている。一方 `workflow-entry` 仕様は、振り分けスキル名の正を `assets/entry-skills.txt`（`00-workflow-issue-mr-driven` / `00-workflow-quick-request`）に置き、WE-T07 で `CLAUDE.md` の表との一致を検査すると定める。「振り分けスキルかどうか」の判定が lib（接頭辞）とファイル（列挙）の 2 か所にある（issue #9 の調査 0006 f2）。

## 決定

- **振り分けスキル名の正は `.claude/hooks/config/entry-skills.txt`** とし、名前の照合は `workflow-entry` が行う
- `tool_class` は「ツールの種類の分類」に徹する。`Skill` に対する戻り値の意味は「宣言の候補になり得るツール」であり、スキル名の照合の根拠には使わない
- この役割分担を `workflow-entry` 仕様の呼出条件に明記する。`hook-common` 側の記述（`20-common-step-shell-script` 仕様）の更新は 0015 が行う

## 理由

- 将来 `00-workflow-` で始まる別のスキル（例: `00-workflow-hotfix`）が増えると、`tool_class` は `declare` を返すが `entry-skills.txt` には無い、という食い違いが起こる。ファイルを正にすれば追加はファイルの 1 行で済む
- `CLAUDE.md` の表との一致を検査する WE-T07 が既にあり、ファイル側に正を置く前提で書かれている
- `tool_class` を変えると HK-T03 系の既存テストに影響する可能性がある。**接頭辞判定をすぐ消すのではなく「照合には使わない」と役割を定める**方が、この issue の範囲で安全に閉じられる

## 却下した案

- **`tool_class` から接頭辞判定を消す**: HK-T03 系のテストの期待値に影響し、`20-common-step-shell-script` の仕様変更（0015 の担当）と同時でないと壊れる。役割の定義だけ先に決め、実体の整理は 0015 に渡す
- **`entry-skills.txt` をやめて接頭辞判定に一本化する**: `CLAUDE.md` の表と機械的に照合できなくなる（WE-T07 が成立しない）
- **両方で確かめる（二重に照合する）**: 食い違ったときにどちらが正か決まらない

## 影響

- `10_spec/hooks/10-UserPromptSubmit/workflow-entry.md` 呼出条件（`Skill` の行）
- `10_spec/skills/20-common-step-shell-script.md`（`tool_class` の責務。0015 が書く）
- `entry-skills.txt` の基準ディレクトリは 0014（フック共通仕様 §1）で `.claude/hooks/config/` に確定した（DDR i0009-10）。この DDR の決定（名前の正を外部ファイルに置く）自体は置き場に依存しない
