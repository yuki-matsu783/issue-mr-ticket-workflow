---
type: report
title: AI アセット実装 結果報告（チケット 0013〜0021）
description: issue #6（実装 1/3）で作成した設定・ルール・共通ライブラリ・提供コマンド・共通ステップスキル・テストの一覧と仕様の節との対応、テスト結果（機械 / eval 未実行）、検査結果、仕様からの逸脱、想定と異なった点、残課題。実装チケットごとに節を追記し、0021 で集約する
tags: [report, ai-asset-implementation, issue-6]
---

# AI アセット実装 結果報告

- 対象 issue: #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6
- PR: #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 計画: `wip/20_plans/0011-ai-asset-implementation-plan.md`（0023 で修正）
- 対象チケット: 0013（S1）、0014（S2-1・S3-1）、0016（S2-3）、0017（S2-4）、0018（S2-5）、0015（S2-2。0024 の後）、0019（S4-1）、0020（S4-2）、0021（S4-3・S5-1）

## 要約

（0021 で集約）

## 確かめられなかったこと

（0021 で集約）

## 作成・更新したアセット（仕様の節との対応）

### 0013 S1: 設定・定義

| アセット | 仕様の節 | 備考 |
|---|---|---|
| `.gitattributes` | フック共通仕様 §8（`ai-asset-implementation.allow`） | `*.sh` `*.tsv` `*.json` `*.html` を `text eol=lf`。`*.md` は含めず既存ファイルの再正規化なし |
| `.claude/hooks/config/task-types.tsv` | `00-workflow-issue-mr-driven` 仕様 OUT ひな形（6 列）・対応表（15 行） | 1 行目は `#` 始まりのヘッダ（読み手はコメント行として飛ばせる）。対の相手は plan ↔ exec、メインエージェント担当 3 種は `-` |
| `.claude/hooks/config/scope-limits.json` | フック共通仕様 §8（構造・キー規則・初期値表） | `common` 5 キー、`types` 15 種すべてに `ops`。`commands.build-test` は空配列（外部ビルド・テストコマンドが無い。機構のテストは提供コマンド経路） |
| `.claude/rules/work-defaults.md` | 要件 `rules/work-defaults.md`「ルールが定める内容」 | 15 行の表。行動ルールなので 7 章スキーマの対象外。効くタイミングは frontmatter `applies_when` で宣言（`paths` に馴染まない行動ルールの宣言キー。`markdown-docs` ルール未作成のため暫定 — 逸脱欄参照） |

## テスト結果

### 0013

- 機械テスト: なし（HK-T02 は 0014 で `test-lib.sh` 完成後に書く）。代わりに次を手で確認: `jq . scope-limits.json` が通る / `types` のキー 15 個 = tsv の type 15 個 = work-defaults の表の type 15 個（`diff` で一致）/ `.gitattributes` 追加後の `git status` に既存ファイルの変更が出ない
- eval: なし

## 検査結果

### 0013

- プレースホルダ（`{{ }}` / `TODO` / `TBD`）: 0 件（対象 4 ファイル）
- frontmatter: `work-defaults.md` に `type` / `title` / `description` / `tags` / `keywords`
- 参照更新の再検索: 新規ファイルに旧名なし

## 仕様からの逸脱

| # | チケット | 内容 | 理由 | 反映先の候補 |
|---|---|---|---|---|
| D-1 | 0013 | 行動ルールの「効くタイミング」を frontmatter の `applies_when` キーで宣言した | 要件は「frontmatter で宣言する」とだけ定め、キー名を定める仕様（`markdown-docs` ルール・ルール体系の仕様）が未作成 | 0022 → `markdown-docs` ルールの要件、または `ルール体系.md` の仕様 |
| D-2 | 0013 | `task-types.tsv` の 1 行目をヘッダ（`#` 始まり）にした | 仕様は 6 列を定めるがヘッダの有無を定めない。`#` 始まりなら読み手がコメントとして飛ばせる | 0022（仕様に 1 行追記の候補） |

## 想定と異なった点

（各チケットで追記）

## 残課題

（0021 で集約）
