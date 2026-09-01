---
type: report
title: AI アセット設計 結果報告（チケット 0008〜0010・0012）
description: issue #6（実装 1/3）の AI アセット設計で更新した要件・仕様・DDR の一覧、受け入れ条件との対応、ヘッドレス実行での確認事項、想定と異なった点、残課題
tags: [report, ai-asset-design, issue-6]
---

# AI アセット設計 結果報告

- 対象 issue: #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6
- PR: #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 対象チケット: 0008（フック共通仕様・提供コマンド）、0009（shell-script・ticket・report-view）、0010（investigation・eval 表）、0012（敵対的レビュー F1〜F18 の反映）
- 計画: `wip/20_plans/0006-ai-asset-design-plan.md`
- 調査の入力: `wip/30_reports/0003-investigation.md`（D1〜D21、H1〜H6）

## 要約

調査で見つかった仕様と実環境の食い違い（D1〜D21）と、設計レビュー（opus 敵対的レビュー、18 件）の指摘をすべて要件・仕様に反映した。新しい設計判断は DDR i0006-01〜06 に残した。要件書に内部構造は書かず（`rules/logger.md` は使い方の要点だけに戻した）、判定順・スキーマ・パスは仕様側に置いた。実装（0011 以降）が読むべき正はすべて `.claude/docs/10_spec/` にある。

## 更新した文書

| 文書 | 主な変更 | 由来 |
|---|---|---|
| `10_spec/フック共通仕様.md` | §1 lib 5 本 + `frontmatter.sh` 依存、ラッパー `\|\|` の位置づけ / §2 共通フィールド（`permission_mode` 等）と PowerShell の `tool_input` / §3 deny 後は終了 0 / §6 台帳（TR・FR-T・eval 接頭辞、登録義務の範囲） / §7 `frontmatter.sh` の読み方 / §7-8 提供コマンドはルート相対表記の文字列一致だけ / §8 `*` は `/` を跨がない、`build-test` の定義、`web` / §9 `adversarial_review` を WF208 に / §11 HK-T09・T11・T12 / §12 T3・T5 を狭め T6 追加 | D2 D5 D7 D9 D12 D14 D17 D19 D21、F8 F9 F11 F15 F16 F17 F18 |
| `10_spec/hooks/12-PreToolUse/workflow-guard.md` | WF208 の対象に `adversarial_review`、WG-T09 | F4 |
| `10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md` | push 検知 2（`git push` の分岐）、PP-T08 | D8 |
| `10_spec/skills/20-common-step-shell-script.md` | 読み込み行（`<lib>` + 失敗時ポリシー、`LOGGER_ROOT`）/ 終了コード / `frontmatter.sh` / `run-tests.sh`（TR001〜006、`allow.ops` の検査）/ logger の時刻は `printf` を使わない / テスト方式（TR-T01〜05） | D1 D3 D4 D6 D10 D11、F3 F10 |
| `10_spec/skills/20-common-step-ticket.md` | `commit.sh -m "<件名>" <旧パス> <新パス>`、拒否時は作業ツリーを戻す、create は拒否でファイルを残さない、TICKET-T10・T11 | D13 D15、F1 F5 F13 |
| `10_spec/skills/20-common-step-commit-push.md` | push 検査 3 の対から `*-appendix-*.md` を除外 | F2 |
| `10_spec/skills/20-common-step-report-view.md` | 付録ファイル `-appendix-<記号>.md` の扱い | D16 |
| `10_spec/skills/10-task-investigation-plan.md` / `-exec.md` | 実行を伴う観点は `build-test` を宣言、`.claude/` 配下の一時変更を計画しない、要件との対応 +2 行 | D20 D21、F6 |
| `10_spec/skills/20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}.md` | eval 観点表（AC-E / FM-E / IS-E / RQ-E / SP-E） | Q6 |
| `10_spec/skills/20-common-step-spec.md` | eval 観点表を置く規則 | Q6 |
| `00_requirement/rules/logger.md` | 使い方を要点だけに（解決順・失敗ポリシーは仕様へ） | F14 |
| `00_requirement/skills/20-common-step-shell-script.md` | `frontmatter.sh`・`run-tests.sh` の受け入れ条件 | D3 D11 |
| `00_requirement/skills/10-task-investigation-{plan,exec}.md` | 実行を伴う調査と `.claude/` 配下の一時変更の受け入れ条件 | D20 D21 |
| `20_ddr/i0006-01〜06` | frontmatter.sh の置き場 / ticket.sh は commit.sh 経由 / data-required の格上げ / テスト方式 / 調査中の実行と一時変更 / 読み込み行 | — |

## 受け入れ条件との対応（設計の範囲）

| issue #6 の受け入れ条件 | 設計での対応 | 実装で確認する ID |
|---|---|---|
| ルール 14 本が要件どおり | 変更なし（0011 で 14 本 vs 4 本を判断 — 申し送り） | — |
| フック共通基盤（`lib/` 5 本・`config/` 2 本） | §1 の一覧・§7 の `frontmatter.sh` 依存・§8 の分類定義を確定 | HK-T01〜T12 |
| 共通ステップスキル 9 本と提供コマンド | ticket / commit-push / shell-script / report-view の仕様を実環境に合わせて確定 | TICKET-T01〜T11、TR-T01〜T05、SS-T01〜 |
| テストが `run-tests.sh` で通る | テスト方式（plain bash + test-lib）と ID 規約、`allow.ops` の検査 | TR-T05 |
| 要件・仕様・実装の整合 | 要件は外部的に、内部構造は仕様に。DDR に経緯 | RQ-E / SP-E |

## ヘッドレス実行で確認すること（2/3 以降）

- T5: PowerShell ツールのフック stdin 固有フィールドが Bash と同形か（登録直後の `decisions.jsonl`）
- T6: `permission_mode: auto` のときフックの deny が設定編集の分類器とどう重なるか
- `web` の宣言を強制するか（`WebFetch` / `WebSearch` を matcher に加えるか）

## 想定と異なった点

- 設計レビューの指摘が 18 件と多く、追加チケット 0012 で 1 回分の設計をやり直した。原因は 0008〜0010 を 3 チケットに分けたことで、文書間（共通仕様 ↔ 個別仕様 ↔ 要件）の突合を各チケット内で閉じられなかったこと。実装計画では「横断整合の確認」を独立チケットにせず、各チケットの DoD に「参照先の文言を再読して一致」を入れる
- `.claude/settings.json` を読む調査が分類器で止まり、T5 は文書と transcript から結論した（0003 の逸脱を引き継ぐ）

## 残課題（0011 への申し送り）

- F11: `web` の強制有無（matcher）
- F12: `subagent-stop-check` が読む `agent_type` の実物確認（サブエージェント実行時の stdin）
- ルール体系の 14 本（7 成果物 + 7 行動）と現状 4 本の差の扱い
- `.gitattributes` の新設を最初のステップに置く（CRLF 混入の防止）
