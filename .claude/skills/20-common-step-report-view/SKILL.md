---
name: 20-common-step-report-view
description: >
  計画書（wip/20_plans/）と結果レポート（wip/30_reports/）の HTML ビューを、テンプレートのコピーを Edit で
  埋めて作り、検査スクリプト check-html.sh（プレースホルダ・外部依存・id 重複・破断リンク・style 数・必須節・
  負のコントロール）に通す共通ステップ。正文は Markdown で、HTML はその視覚化。
  Use when a plan or report .md has been written or updated and its .html pair is needed ("HTML を作って",
  "HTML ビュー"), when push.sh reports an md/html pair mismatch (CP005 項目 3), or when check-html.sh fails (RV001〜008).
---

# 20-common-step-report-view — HTML はテンプレートのコピーを埋め、検査を通す

Markdown を正文とし、同じベース名の `.html` をテンプレートから作る。HTML にだけある情報を作らず、md を更新したら HTML も同じ変更で追随させる。全体計画書（`wip/00_overall_plan/`）には作らない。

- 要件: `.claude/docs/00_requirement/skills/20-common-step-report-view.md`
- 仕様（正。テンプレートの規約・検査 7 項目・エラー識別子 RV001〜008）: `.claude/docs/10_spec/skills/20-common-step-report-view.md`

## 手順

1. **対象を判定する**: `wip/30_reports/` の結果レポート・統括レポートと `wip/20_plans/` の計画書は必須。付録（`<連番>-<種類>-appendix-<記号>.md`）には作らない
2. **テンプレートをコピーする**: 用途に合わせて同じベース名で `cp`
   - レポート: `cp .claude/skills/20-common-step-report-view/assets/report.template.html wip/30_reports/<ベース名>.html`
   - 計画書: `cp .claude/skills/20-common-step-report-view/assets/plan.template.html wip/20_plans/<ベース名>.html`
3. **Edit で埋める**: `{{名前}}` のプレースホルダ（要素の内容として置いてある）をすべて md の内容に置き換える。テンプレートの節に対応しない内容は最も近い節へ収める。`data-required` 付きの必須節は削除せず、該当する内容が無いときも空にせず「無し」と 1 行書く（md 側も同じ）。空になる**任意**の節（`data-required` 無し）は節ごと削除してよく、目次からもその行を消す。それ以外の DOM 構造は変えない（構造の変更はテンプレートの改訂として AI アセットフェーズへ）
   - 視覚語彙: 結論の性質は 3 色 + 記号 + 文字（◎良 / △注意 / ✕問題）、レビューの重みは ◆特に見てほしい / ◇承認が欲しい / ・細かいレビュー不要。独自の色・記号を持ち込まない
   - レポートの章 ID は `f1, f2, …` の連番。目次・件数・未確認一覧・重点依頼から同じ ID を参照する
4. **検査する**: `bash .claude/skills/20-common-step-report-view/scripts/check-html.sh <file.html>`。失敗したら原因を直して再実行する（飛ばさない）。検査は全項目を実行して未充足を全件列挙する
5. **記録する**: 検査結果（`OK: 検査 7 項目すべて通過（id N 件 / リンク M 件…）`）を作業ログに残す
6. **同期する**: 以後 md を更新したら、同じ変更を HTML に反映して 4〜5 を繰り返す（追記だけで済ませない。md 側の差分が追加のみでなければ HTML も追加のみでは同期していない）

## 参照

- テンプレート: `assets/report.template.html`（レポート。`<body data-template="report">`）、`assets/plan.template.html`（計画書。`<body data-template="plan">`）。必須節の一覧はテンプレートの `data-required` だけが持つ
- 提供コマンド: `scripts/check-html.sh`
- md / html の対の存在検査: `20-common-step-commit-push`（push 前チェック項目 3）
- 検査結果の記録先: `20-common-step-ticket`（作業ログ）
- HTML ビューの対象と md 正文の原則: 要件書、DDR `i0001-05`

## エラー時の対処

| 状況 | 対処 |
|------|------|
| `RV001:` プレースホルダ残存 | 列挙された `{{名前}}` をすべて埋める（コメント内も数える。地の文で触れるときは表記を変える） |
| `RV002:` 外部リソース | `src` / `<link href>` / CSS `url()` / `@import` を除く。`<a href>` のハイパーリンクと `data:` URI は対象外なので、画像は data URI にする |
| `RV003:` id 重複 | 章をコピーしたら `f2, f3, …` に振り直す |
| `RV004:` 破断リンク | 目次・重点依頼・未確認一覧のリンク先 id を本文と揃える。任意節を削ったら目次の行も消す |
| `RV005:` `<style>` が 1 つでない | 追加した `<style>` を統合する（テンプレートの 1 つだけ） |
| `RV006:` 必須節が無い / テンプレートを特定できない | 削った必須節を戻す（無ければ「無し」と 1 行）。`<body data-template="report|plan">` を残す |
| `RV007:` id・リンク 0 件 | テンプレートから作っていない（白紙・スクリプト生成）。テンプレートのコピーからやり直す |
| `RV008:` 引数・ファイル不正（終了 2。検査には入っていない） | 存在する `.html` のパスを 1 つだけ渡す |
