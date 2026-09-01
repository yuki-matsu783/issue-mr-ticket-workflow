---
type: ddr
title: i0006-01. チケット frontmatter の読み取りは純 bash の frontmatter.sh に集約し、shell-script スキル配下に置く
description: 入れ子（allow.write）とインラインマップ（human_review）を含むチケット frontmatter を、フック（hooks/lib）と提供コマンド（ticket.sh）の両方が同じ純 bash ライブラリで読む判断。置き場を 20-common-step-shell-script の scripts/ にし依存の向きを logger と揃える
tags: [ddr, frontmatter, ticket, hooks, shell-script]
keywords: [frontmatter.sh, 入れ子, インラインマップ, allow.write, human_review, 純 bash, yq, フラット化, 置き場, 依存の向き, 規則の複製禁止]
---

# i0006-01. チケット frontmatter の読み取りは純 bash の frontmatter.sh に集約し、shell-script スキル配下に置く

## 背景

調査（issue #6 チケット 0003）で、参考実装の frontmatter パーサ（`extract-frontmatter.sh`）がトップレベルのキーしか読めず、フック共通仕様 §9 の入れ子 `allow: {write, ops}` を黙って捨て、インラインマップ `human_review: {required, reason}` を文字列にすることが分かった。`yq` は実行環境に無い。読み手は `scope.sh`（hooks/lib、毎ツール呼び出しで起動）と `ticket.sh`（提供コマンド）の 2 箇所あり、別々に書くと解釈がずれる。

## 決定

- 読み取りライブラリ `frontmatter.sh`（`source` 専用・純 bash・外部プロセスなし）を `.claude/skills/20-common-step-shell-script/scripts/` に置き、hooks/lib と `ticket.sh` の両方がこれを `source` する
- 対象は §9 のチケット形式（スカラー・フロー配列・入れ子マッピング・インラインマップ）に限り、汎用 YAML パーサにしない。ブロック配列と複数行スカラーは対象外（空 + 戻り値 1）
- 利用側は `fm_get` / `fm_list` だけを通し、`sed` / `grep` による自前の切り出しを持たない（規則の複製禁止）
- 依存の向きは logger と同じ「フック → スキル配下のライブラリ」

## 理由

- 判定に使う値（`allow` / `human_review` / `predecessors`）の解釈が 1 箇所に決まり、フックと提供コマンドで食い違わない
- フックは fork コスト（Git Bash で約 95 ms/回）を負うため、jq / yq を起動するパーサは使えない。純 bash なら両方で使える
- 置き場を shell-script スキルにすると、既に同じ向きで参照している logger と揃い、`hook-test` の許可 glob にも影響しない

## 却下した案

- **hooks/lib に置き、skills 側から hooks/lib を `source` する**: 依存の向きが logger と逆になり、提供コマンドがフックの内部に依存する
- **yq に委ねる**: 実行環境に無く、導入先プロジェクトにも依存を要求することになる
- **frontmatter をフラット化する仕様変更**（`human_review_required` / `allow_write` 等）: `sed` 1 行で読める利点はあるが、可読性を落とし §8・§9・WF208 の記述とテンプレートを書き換える必要がある。パーサの拡張は局所的で済む
- **フックと ticket.sh で別々に実装する**: 解釈のずれが判定の抜け道になる

## 影響

- `10_spec/skills/20-common-step-shell-script.md`（frontmatter.sh の関数・テスト観点 FR-T01〜05・読み込み行）
- `10_spec/フック共通仕様.md` §7（参照）・§9（読み取りの統一）
- `10_spec/skills/20-common-step-ticket.md`（参照ナレッジ）
- `00_requirement/skills/20-common-step-shell-script.md`（共通ライブラリの提供と重複禁止）
