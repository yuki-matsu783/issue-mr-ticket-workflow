---
type: report
title: 0024- AI アセット実装・テスト結果 — 機構の実体を作る
description: issue #10 の実装フェーズの結果報告。テンプレート実体 15 件・提供コマンド 2 本・フック 3 か所の追随・タスクスキル 15 本とエージェント 2 本・eval 定義 19 件・旧名 111 件の参照更新を、チケットごとの節で積み上げる
tags: [report, ai-asset-implementation, issue-10]
keywords: [AI アセット実装, テンプレート, boundary.sh, finalize.sh, 中核, ロックアウト対策, 機械テスト, eval, 参照更新, 旧名]
---

# 0024- AI アセット実装・テスト結果 — 機構の実体を作る

- 対象 issue: [#10](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/10)
- MR: [#35](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/35)（draft）
- ブランチ: `feature-10-task-skills-agents-finalize`
- チケット: 0024〜0032
- 作成日: 2026-09-04

## サマリ

実装フェーズの結果報告。0017 の計画が並べたステップ S1〜S9 を、チケット 0024〜0032 が同じレポートに節を積み上げる（実施タスクの共通手順 4）。

**0024（S1 設定・定義）**: 仕様の OUT ひな形が名前とパスで指定しているテンプレート **15 件**を作った。13 件は各スキルの `assets/`、2 件（レポート・計画書の md 共通の型）は `20-common-step-report-view` の `assets/`。仕様が参照する `*.template.md` は**全件が実体を持つ**状態になった。

- ◎良 1 件 / △注意 0 件 / ✕問題 0 件（節は e1 の 1 件。0024 まで）

### ◆特に見てほしい（判断に困っている）

- 無し

### ◇承認が欲しい（方針は決めた）

- **e1**: 計画書のテンプレート 8 件を「共通の型に足す節だけ」の形にした。共通の型を逐語で複製していないので、単体では完成した文書に見えない。節を 1 つ足すのに 15 か所を直す事態を避ける形（`20-common-step-report-view` 仕様「テンプレートの置き場」）だが、使う側が共通の型を必ずコピーする前提に依存する

### ・細かいレビューは不要（ほぼ確実）

- **e1**: `attachment-comment.template.md` は仕様の改訂で `summary-section.template.md` に置き換わっている（設計フェーズの残課題 R4）。0003 の a2 の表の名前ではなく、現行の仕様書の名前で作った

## 確かめられなかったこと

| 対象 | 確かめられなかった理由 | 引き取り先 |
|---|---|---|
| テンプレートが実際に使えるか（埋めた結果が仕様の OUT を満たすか） | このチケットで作ったのはひな形だけで、使う側の SKILL.md は S6（0029）で作る | S6 以降の実装チケット |
| `markdown-docs` ルールとの整合 | ルール自体が存在しない（`.claude/rules/` に無い）。2 つの設計文書ルールが参照しているが未作成 | 残課題 R1 |

## 実施した内容と結果

### e1. テンプレート実体 15 件を作った（S1） ◎良

仕様の OUT ひな形が名前とパスで指定しているテンプレートを作った。作成前の `.claude/skills/*/assets/` にあった `*.template.md` は 9 件（うち旧ワークフロー由来で仕様に無いものが 1 件）で、仕様が名前で参照する 20 種のうち **13 種が実体を持たなかった**。それに md の共通の型 2 件（設計フェーズの残課題 R6）を足して 15 件を作った。

**共通の型 2 件**（`20-common-step-report-view/assets/`）

| ファイル | 節 |
|---|---|
| `report.template.md` | サマリ（重点レビュー依頼 3 区分を含む）→ 確かめられなかったこと → 実施条件（任意）→ 実施した内容と結果 → 検証の結果（任意）→ 設計への反映 → 想定と異なった点 → 残課題 |
| `plan.template.md` | この計画で何をするか → 対象と範囲 → 方法とステップ → 検証 → チケット → リスクと復旧（任意）→ スコープ外（任意）→ 保留した点 / 対象なし |

節構成は同じ `assets/` の HTML ビューのテンプレートと 1 対 1 で対応させた。md が正文で HTML ビューだけがあった状態（0003 の a7）を解消した。

**種類ごとの型 9 件**

`10-task-overall-plan` の `overall-plan.template.md` だけは完成した 1 枚の文書として書いた（HTML ビューを作らない・1 画面程度という仕様のため）。残る 8 件は**共通の型に足す節だけ**を持つ形にした。

| スキル | ファイル | 足す節 |
|---|---|---|
| `10-task-investigation-plan` | `investigation-plan.template.md` | 調査観点 / 対象と方法 / 調査チケット / 成果物の形 |
| `10-task-design-plan` | `design-plan.template.md` | 判断点の結論方針 / 設計書の一覧 / 受け入れ条件との対応 / 設計チケット |
| `10-task-implementation-plan` | `implementation-plan.template.md` | 変更対象 / 許可範囲案 / テスト方針 / ステップ / 検証方法 / リスク / 設計差し戻し |
| `10-task-design-feedback-plan` | `design-feedback-plan.template.md` | 差分一覧 / 書き戻し方針 / 実装漏れ一覧 / 受け入れ条件の確認 / 設計反映チケット |
| `10-task-ai-asset-design-plan` | `ai-asset-design-plan.template.md` | 結論方針 / 文書一覧と骨子 / 横断整合 / ヘッドレス実行の帰結 / 受け入れ条件との対応 / 設計チケット |
| `10-task-ai-asset-implementation-plan` | `ai-asset-implementation-plan.template.md` | 変更対象 / 許可範囲案 / テスト方針 / ステップ / 参照更新一覧 / 依存するテスト / ロックアウト対策 / リスク / 設計差し戻し |
| `10-task-feedback-plan` | `feedback-plan.template.md` | 確認した記録の範囲 / 改善候補の一覧 / 合意 / 起票した issue / 後続フェーズの決定 |
| `10-task-overall-summary` | `summary-section.template.md` | MR 本文の `## 統括` 節（受け入れ条件との対応 / 残課題 / 別 issue / 成果物のリンク一覧の表） |

**ワークフロースキルの型 4 件**（`00-workflow-issue-mr-driven/assets/`）

| ファイル | 内容 |
|---|---|
| `subagent-prompt.template.md` | `task-executor` の起動プロンプト。issue・MR・**ブランチ名**・スキル名・対象・文脈のありか・禁止事項の要点・結果報告の形式 |
| `review-request.template.md` | 切れ目のレビュー依頼。対象タスクとチケット・差分範囲・見てほしい点・人間レビュー省略の有無・敵対的レビュー・次のタスク・確定してほしい判断 |
| `decision-note.template.md` | 承認・判断の書き写し。何を / 誰が / いつ / 内容 の 4 列 |
| `adversarial-review-prompt.template.md` | 敵対的レビュアーの起動プロンプト。patch のパス・対象ファイル・観点・進め方 5 段階・出力スキーマ |

**書き方で固定したこと**

- プレースホルダは二重波括弧で名前を囲む形式（HTML ビューと同じ規約）で、要素の内容として置く。冒頭の HTML コメントに「何を埋めるか」「どの節が必須か」「書き終わりにこのコメントを消すこと」を書いた
- `summary-section.template.md` の「成果物」の表は**骨格だけ**を置き、行を手で書かない。中身は `finalize.sh release` の段階 4 が埋める。空の表を `linked` と誤判定しないよう、判定には固定マーカーを使う（仕様の再導出の規定）
- `adversarial-review-prompt.template.md` には、起動前に差分を `wip/tmp/adversarial-<n>.patch` へ書き出すことと、実行者とモデルが一致したら差し替えることをコメントに書いた。レビュアー自身は `Bash` を持たないので差分を取れない

## 検証の結果

| 検証 | 結果 |
|---|---|
| 仕様が参照する `assets/*.template.md` | 20 種すべてに実体がある（`10_spec/` から抽出した名前を `find` と突合して MISSING 0 件） |
| 今回作った件数 | 15 件（種類ごと 9・ワークフロー 4・共通の型 2） |
| 名前の食い違い | 0 件。`attachment-comment.template.md` は現行仕様に無く、`summary-section.template.md` として作った |

## 設計への反映

| # | 反映すること | 引き取り先 |
|---|---|---|
| 1 | 種類ごとのテンプレートが「共通の型に足す節だけ」であることは、使う側の SKILL.md にも書く必要がある（テンプレートを 1 枚だけコピーして完成と誤解しないため） | S6（0029） |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| テンプレートは 0003 の a2 の表のパスにそのまま作れる | 9 番の `attachment-comment.template.md` は仕様の改訂で `summary-section.template.md` に置き換わっていた | 現行の仕様書の名前で作った（残課題 R4 の決着） |
| 種類ごとのテンプレートは共通の型を含む完成形で書く | 15 本が同じ節構成を逐語で持つと、節を 1 つ足すのに 15 か所を直すことになる（`report-view` 仕様が明示的に禁じている） | 足す節だけを持つ形にし、冒頭コメントで共通の型の場所を指した |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | `markdown-docs` ルールが存在しない。`design-docs` と `ai-asset-design-docs` の 2 本が frontmatter の規約の正として参照しているが `.claude/rules/` に無い。今回のテンプレートは既存文書の慣行（`type` / `title` / `description` / `tags` / `keywords`）に合わせた | フィードバック計画（0033） |
| R2 | 旧ワークフロー由来の `00-workflow-issue-mr-driven/assets/issue-addendum.template.md` と `issue-notify.template.md` が残っている（削除は S8） | S8（0031） |
