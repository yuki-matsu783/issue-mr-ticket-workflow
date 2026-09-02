---
type: plan
title: AI アセット実装計画 — ルール本体・スキル本体・許可範囲設定
description: レビュー済みの設計から、design-docs ルール本体・共通ステップスキル 2 本・要件書テンプレート・scope-limits.json・そのテスト・eval 定義を変更する範囲、テスト、ロックアウト対策を定める
tags: [plan, ai-asset-implementation, apl, scope-limits]
keywords: [実装計画, ルール本体, SKILL.md, requirements.template.md, scope-limits.json, test_scope.sh, ロックアウト, run-tests]
---

# AI アセット実装計画 — ルール本体・スキル本体・許可範囲設定

## 対象

- issue: #20 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/20
- PR: #25 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/25
- 起点: `.claude/docs/` の設計（チケット 0006〜0008・0010）
- チケット: 0009（本計画）、0011〜0012（実装）、0013（次の計画）

## この計画で何をするか

レビュー済みの設計文書のとおりに、AI アセット本体を変える。**中核（`.claude/hooks/config/scope-limits.json`）を含む**ため、ロックアウト（機構が自分自身を止める）が起きないことを実装前に確かめる手順を決める。

書き込みは `.claude/skills/**` `.claude/rules/**` `.claude/hooks/config/**` `.claude/evals/**` のみ。`.claude/docs/**`（設計文書）とアプリ配下には触らない。

## 変更するアセット

| # | アセット | 変更内容 | 正となる設計文書 |
|---|---------|---------|----------------|
| A1 | `.claude/rules/design-docs.md` | frontmatter の `paths` を `["apl/**"]` に。title / description / 冒頭説明 / 適用範囲 / 構造・配置をアプリルートの形に。書式・可読性に要件書の形（章順・EARS の節順と規約節の接頭辞・mermaid 15 ノード・自由記述 600 字・禁止節 3 つ・issue 対応の小節）を追加。堅牢性に「仕様書は要件書より先に変えない」、テスト・機械的検査に「要件との対応表の全件カバー」と処理フロー番号 14 を反映 | `00_requirement/rules/design-docs.md` |
| A2 | `.claude/rules/ai-asset-design-docs.md` | 冒頭の相互参照を `apl/**` に。テスト・機械的検査の「処理フロー 12」を 14 に | `00_requirement/rules/ai-asset-design-docs.md` |
| A3 | `.claude/skills/20-common-step-requirement/SKILL.md` | 置き場を `<設計文書ルート>` で一般化。処理フローに「設計文書ルートの決定」と「issue の受け入れ条件との対応」を挿入して 14 手順に。セルフレビューを 14 項目に | `10_spec/skills/20-common-step-requirement.md` |
| A4 | `.claude/skills/20-common-step-requirement/assets/requirements.template.md` | 概要章に小節「issue の受け入れ条件との対応」の骨格（表 + ガイドコメント）を追加 | 同上 処理フロー 4 |
| A5 | `.claude/skills/20-common-step-spec/SKILL.md` | 置き場を一般化。種別表にアプリの行（10 節固定）。アプリの識別子の採番規則 | `10_spec/skills/20-common-step-spec.md` |
| A6 | `.claude/hooks/config/scope-limits.json` | `common.protected` に `apl/*/.gitignore`、`common.file_granular` に 4 パターン、各 type の `allow` / `deny` / `confirm` を新しい形に | `10_spec/フック共通仕様.md`「初期値」 |
| A7 | `.claude/hooks/lib/tests/test_scope.sh` | A6 のフィクスチャとアサーションを追随させ、アプリルート直下・`apl/*/docs/**` の判定を足す | 同上 |
| A8 | `.claude/evals/design-docs.md` | 前提の `paths`（`docs/**`）を `apl/**` に | A1 |

## 方法とステップ

1. **A6 の前にロックアウト対策を確かめる**（下記「ロックアウト対策」）
2. A1・A2（ルール本体）→ A3・A4・A5（スキル本体とテンプレート）→ A8（eval）の順に、設計文書の該当節と 1:1 で対応させて書く
3. A6・A7 は最後にまとめて変え、`test_scope.sh` を先に落としてから `scope-limits.json` を直す（テストが変更を検出することを確かめる）
4. `run-tests.sh --ids` を実行し、既存テストの回帰が無いことを確かめる
5. 仕様の節と作成ファイルの対応表を作業ログに書く

## 検証

| 何を | どう確かめるか | テスト ID / 成果物 |
|------|--------------|------------------|
| 許可範囲の照合 | `test_scope.sh` の HK-T11（glob 照合）と HK-T15（判定順）に、アプリルート直下・`apl/*/docs/**` の期待値を足して実行 | HK-T11 / HK-T15 |
| 設定ファイルの整合 | `test_config_integrity.sh` が `scope-limits.json` の 15 type と `task-types.tsv` / `work-defaults.md` の行を照合 | HK-T02 |
| 既存テストの回帰 | `run-tests.sh --ids` を全件実行し、変更前と同じ結果になること | 全テスト ID |
| ルール・スキルの記述 | 設計文書の節と本体の節の対応表をセルフレビューで確認（機械検査は無い） | 作業ログの対応表 |
| eval 定義 | 実行しない。`design-docs.md` の前提の記述が A1 と一致すること | AD-E01〜（既存の eval ID） |

## ロックアウト対策

`scope-limits.json` は `common.confirm` に載る中核設定で、書き換えを誤ると以降のタスクが自分の許可範囲を失う。

| リスク | 影響 | 対処・巻き戻し |
|--------|------|--------------|
| `common.protected` に `apl/*/.gitignore` を足した結果、実装タスクが入れ子 `.gitignore` を作れない | フェーズ 4 の移動が止まる | 実装タスクの `allow` に `apl/*/.gitignore` を明示して判定順 (2) を通す（`.gitattributes` と同じ手当）。`test_scope.sh` に「implementation が `apl/a/.gitignore` を allow」のアサーションを足して固定する |
| 旧置き場（`src/**` `docs/**`）を全 type の deny から外した結果、計画・調査タスクが書けてしまう | 計画タスクがソースを触る | 計画・調査タスクの `deny` には残す（設計どおり）。`test_scope.sh` に「design-plan が `src/x.ts` を deny」のアサーションを残す |
| `apl/*/*` を implementation の allow に足した結果、意図しないファイルまで書ける | アプリルート直下の任意のファイルが無確認で書ける | `*` は `/` を跨がないので `src/` `docs/` の中には届かない。`test_scope.sh` で `apl/a/src/x.ts` が `apl/*/*` に一致しないことを固定する |
| フックが未登録のため、変更しても機構が実際に止まらず誤りに気づけない | 誤った設定がマージされる | `test_scope.sh` が `scope.sh` を直接叩いて判定を検査するので、フック登録の有無に関わらず検出できる。`run-tests.sh` の全通過を DoD にする |
| `scope-limits.json` の JSON が壊れる | すべての判定が WF210 で止まる | `jq . scope-limits.json` で構文を確かめてからコミットする。壊れたら `git checkout` で戻す（作業領域の変更なので巻き戻しは 1 コマンド） |

## チケット

| 番号 | 種類 | 担当 | 先行 |
|------|------|------|------|
| 0011 | ai-asset-implementation | A1・A2・A8（ルール本体と eval） | 0009 |
| 0012 | ai-asset-implementation | A3・A4・A5（スキル本体とテンプレート）+ A6・A7（許可範囲設定とテスト） | 0011 |
| 0013 | implementation-plan | フェーズ 4 の計画 | 0012 |

0011 と 0012 を分けたのは、ルール本体（宣言的な規約）とスキル本体・設定（手順と機械が読む値）でレビューの観点が違うため。0012 は中核を含むので `allow.ops` に `hook-test` と `build-test` を宣言する。

## スコープ外

- 既存の要件定義書 46 件への新しい形の適用（issue #8）
- 設計文書検査の実装（issue #24）
- アプリ配下のファイルの移動（フェーズ 4・6）
- フックの `settings.json` への登録（issue #9）

## 保留した点

| 項目 | 決める時期 |
|------|-----------|
| `test_scope.sh` のフィクスチャが `フック共通仕様.md` の初期値 JSON の写しで二重管理になっている件 | 本 issue の範囲外。フィードバック計画で別 issue の要否を判断する |
| 旧置き場の deny をいつ削除するか | フェーズ 6（移行完了後）。DDR `i0020-01` の影響に記載済み |
