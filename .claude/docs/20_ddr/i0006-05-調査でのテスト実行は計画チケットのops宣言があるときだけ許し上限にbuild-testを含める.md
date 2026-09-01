---
type: ddr
title: i0006-05. 調査でのテスト実行は計画チケットの ops 宣言があるときだけ許し、上限に build-test を含める
description: 調査計画仕様が「動かして確かめる」を計画できる一方で調査実施仕様と許可範囲の上限がテスト実行を禁じていた矛盾を、調査チケットの allow.ops に build-test が宣言されたときだけ実行を許す形で解消する判断。あわせて .claude 配下の一時変更を調査で計画しない規定
tags: [ddr, investigation, ops, build-test, scope-limits]
keywords: [調査, テスト実行, build-test, web, allow.ops, 宣言, 上限, investigation-exec, investigation-plan, 一時変更, settings.json, 仕様間矛盾]
---

# i0006-05. 調査でのテスト実行は計画チケットの ops 宣言があるときだけ許し、上限に build-test を含める

## 背景

issue #6 の調査で、調査計画 0002 は参考実装のテスト 1 本の実行を「確かめ方」として計画したが、`10-task-investigation-exec` の禁止事項は「ビルドやテストの実行」を禁じ、フック共通仕様 §8 初期値の `investigation.ops` は `read, remote-read` だけだった（敵対的レビュー F2）。実施側はさらに 32 本まで実行範囲を広げ、チケットの `ops` に `build-test` を自分で宣言していた（宣言は上限を絞る役なので通らないはずの形）。同じ調査計画は `.claude/settings.json` への一時フック登録も計画していたが、これは §8 の `investigation`（deny `.claude/**`）と `common.confirm` のどちらでも通らない経路だった。

## 決定

- 調査でのテスト実行（既存テストの実行）は、調査計画が該当する調査チケットの `allow.ops` に `build-test` を宣言したときだけ許す。§8 初期値の `investigation.ops` は `read, remote-read, build-test, web` とし、`build-test` と `web` は上限に含めるだけで宣言が無ければ使えない（`d.ops` に無い分類は拒否）
- 調査実施仕様の禁止事項は「宣言の無いビルド・テストの実行」に改める。宣言があるときも書き込みは一時ディレクトリに限る
- 調査計画は `.claude/**` への一時変更（settings.json の一時登録等）を計画しない。機構の挙動を確かめる必要があるときは既存の記録（transcript・logs）で代えるか、AI アセット実装フェーズの検証に回す

## 理由

- 参考テストを実際に動かした結果が、テスト方式の結論（DDR i0006-04）の根拠になった。全面禁止にするとこの種の調査ができない
- 宣言必須にすることで「計画が実行を意図した」ことが機械可読になり、実施側が勝手に範囲を広げられない（外部技術調査の `web` と同じ型）
- `.claude/**` の一時変更は、上限の設計（自己改変を AI の裁量で行わせない）と正面から衝突する。調査で必要になった時点で計画の誤り

## 却下した案

- **全面禁止のまま（計画仕様側を「実行は計画しない」に直す）**: 動かして確かめる調査ができず、既存の記録が無いときに判断材料を失う
- **上限に `build-test` を含めず、宣言だけで通す**: §8 の「宣言は上限の内側で絞る」規則に反する
- **実施側の裁量で実行を認める**: 今回のように範囲が広がる。宣言が無い実行は拒否されるべき

## 影響

- `10_spec/フック共通仕様.md` §8 初期値表（`investigation` 行）
- `10_spec/skills/10-task-investigation-exec.md`（禁止事項・固有手順）と `00_requirement/skills/10-task-investigation-exec.md`
- `10_spec/skills/10-task-investigation-plan.md`（固有手順: 宣言と一時変更の禁止）と `00_requirement/skills/10-task-investigation-plan.md`
