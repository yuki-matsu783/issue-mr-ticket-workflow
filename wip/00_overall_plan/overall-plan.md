---
type: plan
title: 全体計画 — 設計文書スキルをアプリ（apl/ 配下）に対応させる
description: issue #20 の全体計画。アプリ本体の設計文書の型を機構側に置き、アプリの成果物の置き場を apl/<アプリ名>/{src,docs} に切り直すまでのフェーズ列・実行者・レビュー要否・許可範囲を定める
tags: [plan, overall, apl, design-docs]
keywords: [全体計画, apl, 設計文書, 置き場, scope-limits, design-docs, 20-common-step-requirement, 20-common-step-spec]
---

# 全体計画 — 設計文書スキルをアプリ（apl/ 配下）に対応させる

## 対象

- 対象 issue: #20 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/20
- PR: #25 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/25
- ブランチ: `claude/design-docs-app-support-6a9cyj`

## 種別

**AI アセット**。

主目的は機構側（`.claude/` のルール・共通ステップスキル・許可範囲設定）にアプリ向けの設計文書の型と置き場を定義することで、変更の重心は `.claude/**` にある。既存の `src/vscode-ticket-board/` と `docs/` の `apl/` 配下への移動はアプリ側のファイルを動かすが、中身の変更を伴わない移動と参照更新であり、新しい置き場の定義に従属する作業。よって種別は AI アセット 1 つとし、移動は実装・テストフェーズで扱う。

## フェーズ列

| # | フェーズ | 扱う範囲 |
|---|---------|---------|
| 1 | 調査 | 置き場（`src/**` / `docs/**`）に依存している記述の洗い出し（ルール・スキル本体・設計文書・スクリプト・テスト・`scope-limits.json`）、および #20 の 5 論点それぞれの現状 |
| 2 | AI アセット設計 | `.claude/docs/` の要件・仕様の更新。アプリ向け仕様書の節構成、要件定義書の置き場の一般化、アプリのエラー識別子台帳の方針、「issue の受け入れ条件との対応」表、`docs/` 配下の機械的検査の要否、`apl/<アプリ名>/{src,docs}` の置き場定義。置き場変更の DDR もここ |
| 3 | AI アセット実装・テスト | ルール本体（`design-docs`）・共通ステップスキル本体（`20-common-step-requirement` / `20-common-step-spec`）・テンプレート・`scope-limits.json` の更新とテスト |
| 4 | 実装・テスト | `src/vscode-ticket-board/` → `apl/vscode-ticket-board/src/`、`docs/` → `apl/vscode-ticket-board/docs/` の移動と参照更新、拡張のテスト実行 |
| 5 | フィードバック計画 | 3・4 の結果を見て、設計反映と全体まとめの要否を決める |
| 6 | 設計反映 | アプリ側 DDR（`i0013-01`）の frontmatter 更新と、移動後の文書内の置き場記述の追随 |
| 7 | 全体まとめ | 片付け・PR 本文の最終整形・draft 解除 |

テンプレート（AI アセットの標準: 調査 → AI アセット設計 → AI アセット実装 → 振り返り）との差分:

- **実装・テスト（4）を追加**: 既存ファイルの移動はアプリ側（`apl/**`）への書き込みで、AI アセット実装の許可範囲に入らない。フェーズを分けないと許可範囲を広げることになる
- **設計反映（6）を追加**: アプリ側の設計文書（DDR・要件・仕様）が移動と置き場変更の影響を受ける
- **順序の制約**: 3（`scope-limits.json` に `apl/**` を足す）が 4（`apl/**` への書き込み）より前でなければ、実装タスクが許可範囲外になる

## 受け入れ条件との対応

| # | issue #20 の受け入れ条件 | 満たすフェーズ |
|---|------------------------|--------------|
| 1 | `20-common-step-spec` の種別表にアプリの節構成が加わり、テンプレートまたは節の一覧がある | 2 → 3 |
| 2 | `20-common-step-requirement` の置き場の記述が `.claude/docs/` と アプリ側の双方を扱え、`design-docs` ルールと矛盾しない | 2 → 3 |
| 3 | アプリのエラー識別子の台帳の置き場が方針として書かれている | 2 |
| 4 | 要件定義書のテンプレートに「issue の受け入れ条件との対応」を書く場所があり、セルフレビューがその表と受け入れ基準の対応を検査する | 2 → 3 |
| 5 | アプリ配下の設計文書に対する機械的検査の要否が判断され、入れる場合は検査項目が定義されている | 1 → 2 |
| 6 | `ai-asset-design-docs` / `design-docs` ルールと相互に矛盾しない | 2 → 3 |
| 7 | 置き場が `apl/<アプリ名>/{src,docs}` と定義され、ルール・スキル・`scope-limits.json` の記述が一致する | 2 → 3 |
| 8 | `design-docs` ルールの適用範囲が `apl/**` になり、`ai-asset-design-docs` と矛盾しない | 2 → 3 |
| 9 | `scope-limits.json` の design / design-feedback / implementation の許可範囲が新しい置き場に追随し、旧前提の記述が残らない | 1 → 3 |
| 10 | 既存の `src/vscode-ticket-board/` と `docs/` が `apl/vscode-ticket-board/` 配下へ移動し、機構内の参照が更新される | 4 |
| 11 | 置き場の変更理由が DDR に残り、`i0013-01` は置き換え済みとして frontmatter だけ更新される | 2（新 DDR）・6（`i0013-01`） |

## 方針

基準は `.claude/rules/work-defaults.md`。**実行者の列は全種類で基準から一律に外す**（下記）。人間レビュー・敵対的レビューの要否は次表のとおり。

| type | 実行者 | 人間レビュー | 敵対的レビュー | 基準との差分 |
|---|---|---|---|---|
| overall-plan | メインエージェント | 要 | 不要 | 基準どおり |
| investigation-plan | メインエージェント | 不要 | 不要 | 実行者のみ差分 |
| investigation | メインエージェント | 要 | 不要 | 実行者のみ差分 |
| ai-asset-design-plan | メインエージェント | 不要 | 不要 | 実行者のみ差分 |
| ai-asset-design | メインエージェント | 要 | 要 | 実行者のみ差分。正史（`.claude/docs/`）の変更で差分が 1 文書に収まらない |
| ai-asset-implementation-plan | メインエージェント | 要 | 不要 | 実行者のみ差分。`scope-limits.json`（中核）を含むため人間レビューは維持 |
| ai-asset-implementation | メインエージェント | 要 | 要 | 実行者のみ差分。中核（`.claude/hooks/config/scope-limits.json`）を含む |
| implementation-plan | メインエージェント | 要 | 不要 | 実行者のみ差分 |
| implementation | メインエージェント | 要 | 不要 | 実行者と敵対的レビューが差分。中身を変えない移動と参照更新で、拡張の既存テストが全通過すれば振る舞いの変化は無い |
| feedback-plan | メインエージェント | 要 | 不要 | 基準どおり |
| design-feedback-plan | メインエージェント | 不要 | 不要 | 実行者のみ差分 |
| design-feedback | メインエージェント | 要 | 不要 | 実行者と敵対的レビューが差分。`i0013-01` の frontmatter 更新と置き場記述の追随のみで 50 行未満の見込み |
| overall-summary | メインエージェント | 要（最終確認） | 不要 | 基準どおり |

### 実行者を一律にメインエージェントへ倒す理由

`10-task-*` のスキル本体（`.claude/skills/10-task-*/`）が未作成で、issue #10 の範囲として残っている。サブエージェントに渡す手順書が存在しないため、各タスクの仕様書（`.claude/docs/10_spec/skills/10-task-*.md`）をメインエージェントが読んで実施する。

### 機構の未整備に伴うその他の運用差分

- `work-boundary.sh` / `merge-prep.sh` が未作成のため、ワーク境界のレビュー依頼・完了確認・マージ前作業はスクリプト経由で行えない。レビュー依頼は PR #25 へのコメント（GitHub MCP）で行い、レビュー完了はユーザーの連絡で判断する
- `gh` CLI がこの実行環境に無いため、GitHub 操作は GitHub MCP を使う（CLAUDE.md「環境と制約」に従う）
- フックは `settings.json` に未登録で許可範囲は機械的に強制されない。各チケットの `allow-write` は自己規律として記録する
- 敵対的レビューエージェント（`adversarial-reviewer`）の本体は未作成だが、**フェーズごとに 1 回、独立したサブエージェントによる敵対的レビューを実施する**。仕様書 `.claude/docs/10_spec/agents/adversarial-reviewer.md` を観点の正とする
- **人間レビューの代替**: 各フェーズの敵対的レビューの指摘に対応したことをもって、そのフェーズの人間レビュー（承認④）が済んだものとして扱う。ユーザーの明示的な委任（2026-09-02）による。全体まとめ（承認③⑤⑥）も同じ委任の下で進め、マージのみ人間が行う

### やってよいこと（許可範囲）

| type | 書き込んでよいパス |
|---|---|
| 各 plan タスク | `wip/**` のみ |
| investigation | `wip/**` のみ |
| ai-asset-design | `.claude/docs/**` |
| ai-asset-implementation | `.claude/skills/**`, `.claude/rules/**`, `.claude/hooks/config/scope-limits.json`, `CLAUDE.md` |
| implementation | `apl/**`（移動元の `src/**` / `docs/**` の削除を含む） |
| design-feedback | `apl/vscode-ticket-board/docs/**` |

## 保留した点

| 項目 | 決める時期 |
|------|-----------|
| アプリ配下の設計文書に対する機械的検査を今回入れるか、issue #24（設計文書検査の実装）に寄せるか | フェーズ 2（AI アセット設計）。調査の結果を見て決める |
| `apl/<アプリ名>/docs/` に `90_glossary/` を最初から置くか、必要になってから置くか | フェーズ 2 |
| `.gitignore` の `src/` 前提の記述の要否 | フェーズ 1（調査）で有無を確認し、あればフェーズ 3 で扱うか人間に委ねるかを決める |
| squash merge の可否・既定 | `gh` が無いため未確認。マージは人間が行うため、全体まとめの前にユーザーに確認する |

## 合意の記録

| 承認 | 内容 | 日時 |
|------|------|------|
| ① | issue #20 に追記して対応する | 2026-09-02 |
| ② | 追記案・ブランチ `claude/design-docs-app-support-6a9cyj`・PR タイトル `feat: 設計文書スキルをアプリ（apl/ 配下）に対応させる (#20)` | 2026-09-02 |
| ③ | 本計画（フェーズ列・実行者・レビュー要否・許可範囲）を承認 | 2026-09-02 |
| 委任 | フェーズごとの敵対的レビュー 1 回をもって人間レビューの代替とし、draft 解除まで進める（マージは人間） | 2026-09-02 |
