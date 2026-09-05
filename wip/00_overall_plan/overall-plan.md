---
type: plan
title: 全体計画 — hook機構（Claude Code Ticket Guard）設計文書の §1〜§5 を取り込む
description: issue #52 の全体計画。種別・フェーズ列・受け入れ条件との対応・タスクの種類ごとの実行者とレビュー要否を定める
tags: [plan, overall-plan, issue-52]
keywords: [hook機構, Ticket Guard, 設計文書, 生写し, 要件定義書, PreToolUse, 権限判定, Confluence, 取り込み]
---

# 全体計画 — hook機構（Claude Code Ticket Guard）設計文書の §1〜§5 を取り込む

## 対象

- 対象 issue: [#52](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/52)
- MR: [#53](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/53)（draft）
- ブランチ: `claude/hook-mechanism-hx89wi`

## 種別

AI アセット。変更対象は `.claude/docs/00_requirement/hook機構.md` の 1 ファイルだけで、`apl/` 配下には触れない。

## フェーズ列

AI アセットの標準列をそのまま採る。AI アセット実装・テストは、今回の変更先が `.claude/docs/` に限られ `scope-limits.json` 上 `ai-asset-implementation` の書き込み対象（スキル・フック・ルール・エージェント）に該当が無いため、計画チケットの「対象なし」で即完了する見込みである（省略はしない）。

| # | フェーズ | 採否 | 標準列との差分と理由 |
|---|---|---|---|
| 1 | 全体計画 | 採用 | 標準どおり |
| 2 | 調査（計画 → 実施） | 採用 | 標準どおり。既存文書の章構成・欠落範囲・前方参照先を確定する |
| 3 | AI アセット設計（計画 → 実施） | 採用 | 標準どおり。今回の主作業。取り込みそのものがこのフェーズで行われる |
| 4 | AI アセット実装・テスト（計画 → 実施） | 採用 | 標準どおり。ただし「対象なし」で即完了する見込み（変更先が `.claude/docs/` のみ） |
| 5 | フィードバック計画 | 採用 | 標準どおり |
| 6 | 全体まとめ | 採用 | 標準どおり |

## 受け入れ条件との対応

| # | 受け入れ条件 | 満たすフェーズ |
|---|---|---|
| A1 | `hook機構.md` が §0 概要表から始まり、§1〜§5 が §6 の前に入っている | AI アセット設計 |
| A2 | 提供された表・コードブロック・図が行の欠落なく Markdown として再現されている | AI アセット設計 |
| A3 | 章番号が §0〜§12.2 で連続し、重複や飛びが無い | 調査（現状の章番号の確定）→ AI アセット設計 |
| A4 | 未提供の節（§13〜§23）と、本文からそれらへの参照が残ることが文書内に明記されている | 調査（前方参照先の洗い出し）→ AI アセット設計 |

## 方針

`.claude/rules/work-defaults.md` を基準とする。差分は 2 行のみ。

| type | 実行者 | 人間レビュー | 敵対的レビュー | 基準との差分 |
|---|---|---|---|---|
| overall-plan | メインエージェント | 要 | 不要 | 基準どおり |
| investigation-plan | サブエージェント（opus） | 不要 | 不要 | 基準どおり |
| investigation | サブエージェント（sonnet） | 不要 | 不要 | **人間レビューを要 → 不要へ**。既存 1 ファイルを読むだけの調査で、観点も章構成と前方参照の 2 点に収まる。基準の「読むだけの小さな調査（1 観点・1 チケット）は不要に下げてよい」に当たる |
| ai-asset-design-plan | サブエージェント（opus） | 不要 | 不要 | 基準どおり |
| ai-asset-design | サブエージェント（opus） | 要 | 要 | 基準どおり。追記量が 1 文書・300 行超で「50 行未満なら省略」に当たらない |
| ai-asset-implementation-plan | サブエージェント（opus） | 要 | 不要 | 基準どおり |
| ai-asset-implementation | サブエージェント（opus） | 要 | 要 | 基準どおり（対象なしで即完了する見込み） |
| feedback-plan | メインエージェント | 要 | 不要 | 基準どおり |
| overall-summary | メインエージェント | 要（最終確認） | 不要 | 基準どおり |

### 文書の型についての差分（承認②で合意）

`20-common-step-requirement` は要件定義書の章順・EARS・mermaid を固めているが、今回は Confluence 原本との照合可能性を優先して**生写しの形式を保つ**。したがって AI アセット設計実施タスクは、`.claude/docs/00_requirement/hook機構.md` への追記だけを行い、章順の組み替え・EARS への書き換え・mermaid 図の追加・1:1 の仕様書の作成を行わない。型への変換は別 issue とする。

### やってよいこと

| type | 書き込んでよい範囲 | 実行してよい操作 |
|---|---|---|
| 計画タスク（`*-plan`） | `wip/**` | `read` / `remote-read` |
| investigation | `wip/**` | `read` / `remote-read` |
| ai-asset-design | `wip/**`、`.claude/docs/00_requirement/hook機構.md` | `read` / `remote-read` |
| ai-asset-implementation | `wip/**` | `read` / `remote-read` / `hook-test` |
| overall-summary | `wip/**` | `read` / `remote-read` / `remote-write:*`（正規名で宣言する） |

チケットの `allow.ops` は `scope-limits.json` の正規名（`read` / `remote-read` / `remote-write:push` など）で書く。日本語ラベルで書くと `push.sh` の項目 2 が読み取れない。

## 保留した点

| # | 保留した点 | 決める時期・場所 |
|---|---|---|
| P1 | squash merge の可否と既定を確認できていない（`gh` が未導入で `gh repo view` が使えず、MCP 側に該当ツールが無い） | 全体まとめの前に人間が確認する |
| P2 | 未提供の §13〜§23 をいつ取り込むか | フィードバック計画（別 issue にする想定） |
| P3 | 生写しの文書を `20-common-step-requirement` の型へ変換するか | フィードバック計画（別 issue にする想定） |
| P4 | 取り込んだ設計と既存 `.claude/hooks/` の実装との差分（何が既にあり何が無いか） | フィードバック計画（別 issue にする想定） |
| P5 | `boundary.sh` が MR を検出できない（`gh` 未導入のため `logs/mr.json` が空）。切れ目は外部委任モード（`--external`）で通す | 各タスクの切れ目 |

## 合意の記録

| # | 日付 | 相手 | 内容 |
|---|---|---|---|
| ① | 2026-09-05 | ユーザー | 該当する既存 issue が無いため新規起票。スコープは「文書の取り込みのみ」（実装・差分分析は行わない） |
| ② | 2026-09-05 | ユーザー | issue #52 の本文、ブランチ `claude/hook-mechanism-hx89wi`（既存ブランチをそのまま使う）、MR タイトル。形式は生写しを保つ |
| ③ | 2026-09-05 | ユーザー | 上の「フェーズ列」「方針」の表のとおりで進めることに合意。調査の人間レビューを不要へ下げる差分も含めて承認 |
