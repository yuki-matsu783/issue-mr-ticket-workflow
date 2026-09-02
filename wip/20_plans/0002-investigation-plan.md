---
type: plan
title: 調査計画 — 置き場依存箇所と issue #20 の 5 論点の現状
description: apl/ 配下への置き場変更で影響を受ける記述の洗い出しと、issue #20 が挙げる 5 論点それぞれの現状を確かめるための調査の問い・読む場所・成果物の形を定める
tags: [plan, investigation, apl, design-docs]
keywords: [調査計画, 置き場, apl, src, docs, scope-limits, design-docs, 要件定義書, 仕様書, エラー識別子]
---

# 調査計画 — 置き場依存箇所と issue #20 の 5 論点の現状

## 対象

- issue: #20 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/20
- PR: #25 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/25
- チケット: 0002-investigation-plan（本計画）、0003-investigation（実施）

## この計画で何をするか

置き場を `apl/<アプリ名>/{src,docs}` に変えるにあたり、**どこを書き換えれば整合が保たれるか**を漏れなく把握する。あわせて issue #20 が挙げる 5 論点（アプリ向け節構成・置き場の一般化・識別子台帳・受け入れ条件の対応表・機械的検査）の現状を確かめ、フェーズ 2（AI アセット設計）が推測なしに設計を書ける材料をそろえる。

書き込みは `wip/**` のみ。ソース・設計文書・`.claude/` には触らない。

## 調査観点

| # | 問い | 効く判断点 / 受け入れ条件 |
|---|------|------------------------|
| Q1 | `src/**` / `docs/**` を前提にした記述は、ルール・スキル本体・設計文書・スクリプト・テスト・設定のどこに何件あるか | 条件 9・10。書き換え漏れの防止 |
| Q2 | `20-common-step-requirement` のどの記述が `.claude/docs/` 決め打ちか。置き場を引数化するとしたらどの単位か | 条件 2 |
| Q3 | `20-common-step-spec` の種別表と節構成はどこが正か。DDR `i0013-02` の 10 節をアプリ向けの型としてそのまま採用できるか | 条件 1 |
| Q4 | アプリのエラー識別子（`TB001`〜`TB007`）は現状どこに書かれ、機構の台帳（`フック共通仕様.md` §6）とどう役割が違うか | 条件 3 |
| Q5 | 要件定義書テンプレートの現在の章構成と、「issue の受け入れ条件との対応」を置ける位置・検査の形 | 条件 4 |
| Q6 | `docs/` 配下の設計文書への機械的検査は issue #24 の範囲とどこまで重なるか。今回入れるか寄せるか | 条件 5 |
| Q7 | `design-docs` と `ai-asset-design-docs` で重複している規定はどこか。適用範囲を `apl/**` に変えると食い違いが出る箇所はどこか | 条件 6・8 |
| Q8 | VS Code 拡張のビルド・テスト設定に `src/vscode-ticket-board` 前提のパスがあるか | 条件 10 |
| Q9 | 拡張が読む `wip/10_tickets` のパス解決は、拡張自身の移動で壊れないか | 条件 10 |

## 対象と方法

| 問い | 読む場所 | 確かめ方 |
|------|---------|---------|
| Q1 | リポジトリ全体 | `grep -rn` で `src/` `docs/` `src/\*\*` `docs/\*\*` を拾い、**置き場を指す用法**と**単なる語**を人手で仕分ける。件数とファイル一覧を表にする |
| Q2 | `.claude/skills/20-common-step-requirement/SKILL.md`、`.claude/docs/10_spec/skills/20-common-step-requirement.md` | 置き場を書いている箇所を行番号で特定し、`.claude/docs/` 固定 / 対象種別から導出 のどちらかに分類する |
| Q3 | `.claude/skills/20-common-step-spec/SKILL.md`、同仕様書、`docs/20_ddr/i0013-02-アプリ向け仕様書の節構成.md`、`docs/10_spec/vscode-ticket-board.md` | 種別表の現物と、実際に使われた 10 節を突き合わせ、過不足を挙げる |
| Q4 | `.claude/docs/10_spec/フック共通仕様.md` §6、`docs/10_spec/vscode-ticket-board.md` | 台帳の粒度（誰が採番し誰が衝突を防ぐか）を比較する |
| Q5 | `.claude/skills/20-common-step-requirement/assets/requirements.template.md`、`.claude/rules/ai-asset-design-docs.md`「要件書の形」 | 章順の規定と衝突しない挿入位置を特定する |
| Q6 | issue #24 の本文、`.claude/rules/design-docs.md`「テスト・機械的検査」 | 重複範囲を表にし、今回の判断（入れる / 寄せる）の材料を出す。issue の取得は GitHub MCP（読み取りのみ） |
| Q7 | `.claude/rules/design-docs.md`、`.claude/rules/ai-asset-design-docs.md` | 章ごとに規定を並べ、同一・差分・食い違いに分類する |
| Q8 | `src/vscode-ticket-board/{package.json,tsconfig.json,.gitignore,README.md}`、`test/` | パスを含む設定値を列挙する |
| Q9 | `src/vscode-ticket-board/src/{extension.ts,core/scan.ts}` | ワークスペースルートの解決方法を読む（リポジトリルート相対か、拡張からの相対か） |

外部技術調査（Web 検索）は行わない。すべてリポジトリ内の読み取りと issue の読み取りで足りる。

## 調査チケット

| 番号 | 種類 | 担当する問い | 先行 |
|------|------|------------|------|
| 0003 | investigation | Q1〜Q9（読み取りのみで、観点をまたぐ突き合わせが多いため 1 枚にまとめる） | 0002 |
| 0004 | ai-asset-design-plan | 次フェーズの計画 | 0003 |

## 成果物の形

結果レポート `wip/30_reports/0003-investigation.md` に次があれば、フェーズ 2 が設計を書ける。

- Q1: 書き換えが要る箇所の一覧（ファイル・行・現在の記述・置き場を指すか否か）
- Q2〜Q5・Q7: 問いごとの結論と根拠（ファイル + 行番号）
- Q6: 今回入れるか issue #24 に寄せるかの推奨と理由
- Q8・Q9: 移動で壊れる設定の一覧、または「壊れない」の根拠
- 設計フェーズに送る判断材料と、調査で決められなかったこと

## リスクと復旧

| リスク | 影響 | 対処 |
|--------|------|------|
| `grep` が語としての `docs` を大量に拾い、置き場を指す記述が埋もれる | 書き換え漏れ | 拡張子・パス区切りを含む形（`docs/`・`src/`・`"docs/**"`）に絞ってから広げる。件数を必ずレポートに残す |
| 拡張のワークスペース解決が実測しないと分からない | 移動後に拡張が動かない | 読み取りで判断できなければ「実装フェーズで実測」として保留に落とす（調査タスクは実行しない） |

## スコープ外

- 実際の書き換え（フェーズ 3・4）
- 既存の要件定義書の内容の見直し（issue #8 / #17）

## 保留した点

| 項目 | 決める時期 |
|------|-----------|
| 機械的検査を今回入れるか issue #24 に寄せるか | Q6 の結果を見てフェーズ 2 で決める |
| `apl/<アプリ名>/docs/90_glossary/` を最初から置くか | フェーズ 2 |
