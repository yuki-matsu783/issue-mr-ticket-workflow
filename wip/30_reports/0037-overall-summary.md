---
type: report
title: 統括レポート — issue #6 自己改善ワークフロー機構の実装 1/3（基盤）
description: issue #6（PR #7）の全体まとめ。受け入れ条件 1〜7 との対応（チケット・テスト ID）、各ワークのレビュー結果（承認④による opus 代替の記録）、フィードバック計画の対応、別 issue 一覧、衝突確認、残課題、全体まとめチケット 0037 の DoD × 根拠
tags: [report, overall-summary, issue-6]
---

# 統括レポート — issue #6 自己改善ワークフロー機構の実装 1/3（基盤）

- 対象 issue: #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6
- PR: #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7（`feature-6-workflow-foundation` → `main`）
- 全体計画: `wip/00_overall_plan/overall-plan.md`（フェーズ列: 全体計画 → 調査 → AI アセット設計 → AI アセット実装 → フィードバック計画 → AI アセット設計（2 回目）→ AI アセット実装（2 回目）→ 全体まとめ）
- チケット: 0001〜0038 のうち完了 38 枚（取り消し 0）。全体まとめは 0037
- 片付け前のコミット（作業領域の恒久リンク）: PR #7 の `## 統括` 節と HTML 添付コメントに記した SHA 固定のリンク（片付けコミットの親）

## 要約

issue #6 の成果物 — ルール 4 本、`hooks/lib/` 5 本と `config/` 2 本、共通ステップスキル 9 本（SKILL.md・assets）と提供コマンド 4 本（`ticket.sh` / `commit.sh` / `push.sh` / `check-html.sh`）、それらのテスト 14 本 / 59 ID — はすべて作成・検証済み。受け入れ条件 1〜7 はいずれも満たした（下表）。各ワークの切れ目のレビューは、全体計画の人間レビュー（承認④）以降、opus の敵対的自己レビューで代替し、確度 0.5 以上の指摘は同種の追加チケット（0007 / 0012 / 0023 / 0025 / 0027 / 0032 / 0038 / 0039）で反映した。

仕様と実装の食い違いはフィードバック計画 0022 で棚卸しし（候補 54 件）、この MR で 27 件を仕様・要件・DDR（`i0006-01〜12`）と実装に反映した。残る 16 件と、2 回目の設計・実装で新たに出た申し送りは、別 issue #9・#10・#11 に起票した（本文はユーザー承認済み）。

## 確かめられなかったこと

- `shellcheck` は本環境（Windows / Git Bash）に無く、静的検査は `bash -n` のみ。CI（Linux）での実行は 2/3 の issue に方針決定として送った
- フック本体は未実装・未登録（2/3 の範囲）のため、`hooks/lib/` と提供コマンドの「フックからの呼ばれ方」（`WORKFLOW_ENTRY_ENFORCE`・WF 系の deny）は実機では未確認。lib のテストと `settings.json` 未登録での手作業運用で代替した
- 全体まとめの提供コマンド `finalize.sh` / `boundary.sh` は 3/3 の範囲で未作成。0037 は仕様の処理フロー 2〜9 を手作業で代替した（下記「全体まとめの手作業代替」）
- eval 定義（SC-E / AC-E / IS-E / FM-E / RQ-E など）は定義のみで未実行（要件どおり）

## 受け入れ条件との対応

| # | 受け入れ条件 | 満たしたワーク・チケット | 根拠（テスト ID・検査） |
|---|---|---|---|
| 1 | ルール 4 本（`ai-asset-design-docs` / `design-docs` / `logger` / `work-defaults`）が要件どおり `.claude/rules/` にある | 0013（`work-defaults`）、0021（`logger` / `design-docs` / `ai-asset-design-docs`）、0025（F-23(b) 例外フロー）、0030（`ルール体系` 要件の category / applies_when と整合） | 実装計画 0011 の要件対応表、実装結果報告 0013 の対応表、`test_config_integrity.sh`（`work-defaults` × tsv × json の整合） |
| 2 | `hooks/lib/` 5 本がフック共通仕様どおりに動き、テストが失敗ケースを含めて通る | 0015（5 本）、0024（HK-T13 / T14 の付番）、0025（語彙表の全要素ループ・計数・負のケース）、0035（HK-T15 の付番、`--session`） | HK-T03〜T15（`test_hook_common.sh` 108 / `test_cmdpos.sh` 237 / `test_scope.sh` 246 / `test_push_detect.sh` 31 / `test_transcript.sh` 23 assert）全 PASS |
| 3 | `task-types.tsv` / `scope-limits.json` が種別表（15 種別）・既定値と一致し、3 データの整合テストが通る | 0013、0025 | `test_config_integrity.sh`（HK-T02、8 assert）全 PASS |
| 4 | 共通ステップスキル 9 本の SKILL.md と assets が仕様の処理フロー / OUT ひな形 / 参照ナレッジと 1:1（識別子表・処理フロー・OUT ひな形の範囲。本文構成の `## 目的` はひな形だけが持ち既存 9 本は未対応 — 実装結果報告の訂正 5、対応は 3/3） | 0019（4 本）、0020（5 本 + assets 6 + eval 5）、0033（テンプレート 2 本）、0036（7 本の識別子表・test-lib 一覧・eval ID） | 各チケットの作業ログの対応表（0036 は仕様の行 × SKILL.md の行）、プレースホルダ・frontmatter 検査 0 件 |
| 5 | 提供コマンド 4 本が Script 処理どおりに動き TICKET-T\* / CP-T\* / RV-T\* が失敗ケース含めて通る | 0016 / 0017 / 0018、0025、0033（CP007 / CP008）、0034（TK008・`yaml_escape`・見出し重複）、0035（RV008） | TICKET-T01〜T12（117）/ CP-T01〜T08（68 + 44）/ RV-T01〜T07（51）全 PASS。ロックアウト対策の実機確認（変更後の自分のコマンドで自分をコミット・完了） |
| 6 | すべての sh が `20-common-step-shell-script` の規約（`logs/sh/`・エラー ID・終了コード・`redact`）に従う | 0014（test-lib / logger / frontmatter / run-tests / 雛形）、0025、0035 | SS-T01〜T04（38）/ TR-T01〜T05（41）/ FR-T01〜T05（41）/ LG-T\*（13）/ HK-T10（redact）全 PASS。`bash -n` 全 sh OK |
| 7 | 仕様との食い違いは仕様書へ書き戻し DDR に残す。T5 の結果を仕様に反映 | 0005（T5 の検証）→ 0008（§12 T5 反映）、0008〜0010 / 0012（DDR `i0006-01〜06`）、0028〜0030 / 0032（DDR `i0006-07〜12`）。実装 2 回目の逸脱 D2-1〜D2-7 と訂正 6 件は 3/3 の issue へ | `.claude/docs/` の DDR 12 件、設計結果報告 0008 / 0028 |

注記: issue #6 の受け入れ条件 1 は「ルール 4 本」だが、要件 `ルール体系` は 15 本を要求する。差分 11 本は個別の要件書が無く参考実装が取り込み元のため、本 issue では扱わず別 issue（[#11](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/11)）に切り出した。

## 各ワークのレビュー結果

承認④（2026-09-01、ユーザー: 「人間のレビュー代わりに opus でエージェント起動して自己レビューして MR の draft 解消まで進めていいよ」）により、全体計画以降の人間レビューは opus の敵対的自己レビューで代替した。指摘の全文は `wip/tmp/review-*-findings.md`（gitignore 対象。要点は各追加チケットの DoD と PR コメントに写した）。

| ワーク | チケット | レビュー | 指摘 | 反映 |
|---|---|---|---|---|
| 全体計画 | 0001 | 人間（チャット） | 指摘なし（「オッケー」）。同時に承認④ | — |
| 調査計画 | 0002 | 省略（既定: 不要） | — | — |
| 調査 | 0003〜0005 | opus | F1〜F11（11 件、すべて 0.5 以上） | 追加チケット 0007 で全反映（1 件は誤指摘: 参考実装に eval 資産はある） |
| AI アセット設計計画 | 0006 | 省略（既定: 不要） | — | — |
| AI アセット設計 | 0008〜0010 | opus | F1〜F18（18 件） | 追加チケット 0012 で全反映 |
| AI アセット実装計画 | 0011 | opus | R1〜R17（17 件） | 追加チケット 0023 で全採用、設計差し戻し 0024（HK-T13 / T14） |
| AI アセット実装 | 0013〜0021 | opus | 25 件（0.5 以上 19） | 追加チケット 0025 で 20 件修正（14 + 低確度 6）、残りは 0022 の候補へ |
| フィードバック計画 | 0022 | opus | 1〜12（12 件） | 追加チケット 0027 で全反映 |
| AI アセット設計計画（2 回目） | 0026 | 省略（既定: 不要） | — | — |
| AI アセット設計（2 回目） | 0028〜0030 | opus | G-1〜G-21（0.5 以上 15） | 追加チケット 0032 で反映（G-18 / G-19 は最小対応） |
| AI アセット実装計画（2 回目） | 0031 | opus | P-1〜P-23（0.5 以上 20） | 追加チケット 0038 で反映 |
| AI アセット実装（2 回目） | 0033〜0036 | opus | I2-1〜I2-28（0.5 以上 22） | 追加チケット 0039 で反映（往復の不具合・契約違反・識別力の無いテスト・訂正 6 件）。3/3 へ 7 件・別 issue へ 1 件 |
| 全体まとめ | 0037 | 人間（承認③: 片付け〜draft 解除） | — | — |

## フィードバック計画の対応

フィードバック計画 0022（+ 0027）の候補 54 件（A 11 / B 9 / C 4 / D 6 / E 5 / F 1 / G 12 / H 6）の対応先:

| 対応先 | 件数 | 実施 |
|---|---|---|
| この MR | 27 | AI アセット設計（2 回目）0028〜0030 / 0032 と AI アセット実装（2 回目）0033〜0036 で反映 |
| 別 issue（2/3） | 8（D1〜D6・G7・G8） | [#9](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9) の本文に記載 |
| 別 issue（3/3） | 6（B7・E1〜E5） | [#10](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/10) の本文に記載 |
| 別 issue（ルール 11 本） | 1（F1） | [#11](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/11) |
| 別 issue（小改善） | 1（G9） | 0035 で `check-html.sh` の `strip_comments` を awk 化（1 検査 7.0 → 3.1 秒）。残り（fork 約 20 回）は 3/3 の issue に小改善として記載 |
| 対応しない・問題なし | 11 | 0022 計画書の対応表のとおり（理由つき） |

## 別 issue 一覧

| issue | 内容 | 由来 |
|---|---|---|
| [#9](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9) 実装 2/3 | フック本体 11 本、`settings.json` への登録（人間の操作）、§12 TBD T1〜T4 の検証、`HOOK_DENY_ID` の既定、作業中チケット 2 枚以上の扱い、`tool_response` / `agent_type` / `web` / `defer` の実物確認、`shellcheck` の CI 方針 | 0022 の D1〜D6・G7・G8（8 件） |
| [#10](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/10) 実装 3/3 | タスクスキル 15 本・ワークフロースキル 2 本・エージェント 2 本、`finalize.sh` / `boundary.sh`、参照更新（旧名の置換）、および #6 の設計・実装から仕様へ書き戻す申し送り 20 件超 | 0022 の B7・E1〜E5（6 件）+ 0026〜0039 の「AI アセットに反映すべき内容」と逸脱 D2-2 / D2-4 / I2-19 / I2-21 / I2-22 / I2-25 / I2-27 / I2-28 |
| [#11](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/11) ルール 11 本 | `ルール体系` が要求する 15 本のうち未作成の 11 本（成果物 5・行動 6）の要件書・本体・eval | 0022 の F1（1 件）。issue #6 の受け入れ条件は「4 本」 |

小改善（G9 の残り・I2-26: `check-html.sh` の所要 1 検査 2.5〜3 秒、`run-tests.sh` の全件 5 分、`test_ticket.sh` が 117 assert で 60 秒台）は独立の issue を立てず、#10 の本文に「スコープ外・必要になったら別 issue」として記載した。

2 回目の設計・実装で新たに出た申し送り（0026・0028〜0036・0038 の作業ログ「AI アセットに反映すべき内容」と実装結果報告 0033 の残課題）は、上の 2/3・3/3 の本文に取り込んだ。

## 衝突確認

`git fetch origin` の後、`origin/main` は `09a5e6b`（このブランチの分岐元）のままで進んでおらず、衝突は無い。

- `git merge-base HEAD origin/main` = `09a5e6b`（= `origin/main` の先端）
- `git rev-list --count HEAD..origin/main` = 0（取り込むものが無い）／`origin/main..HEAD` = 106
- `git merge-tree` の衝突マーカー 0 件

したがって取り込み（`git merge origin/main`）は行っていない。draft 解除の直前に同じ検査をもう一度行う。

## 全体まとめの手作業代替

`finalize.sh` / `boundary.sh` が無いため、`10-task-overall-summary` 仕様の処理フロー 2〜9 を次のとおり手作業で代替した:

| 手順 | 仕様 | 代替 |
|---|---|---|
| 2 別 issue 起票 | `20-common-step-issue` で起票 | 本文案 3 件を AskUserQuestion で提示し、承認後に `gh issue create --body-file` |
| 3 衝突解消 | `git fetch origin` | 同左（結果は上） |
| 4 統括レポート | md + HTML | このレポート（`check-html.sh` OK） |
| 5 MR 本文の最終化 | `## 統括` 節 | `gh pr edit 7 --body-file` |
| 6 HTML 添付 | 非公式エンドポイントでアップロードしコメント 1 件 | アップロードは失敗（HTTP 422 / `content_type is not included in the list of allowed content types`・`.html != text/html`）。仕様の代替フローに従い再試行せず、**片付け前のコミットに固定した `wip/` のリンク一覧**をコメント 1 件で投稿し、同じリンクを PR 本文の `## 統括` にも置いた |
| 7 push | `push.sh` | 同左（0037 は `remote-write:push` を宣言） |
| 8 レビュー | `boundary.sh request --final` | 承認③を AskUserQuestion で取得（人間の最終確認） |
| 9 片付け〜draft 解除 | `finalize.sh release` | 前提検査（todo / doing がこのチケットだけ・md + HTML・`## 統括`）→ 完了検査（DoD × 根拠を下表に写す）→ `wip/` の `.gitkeep` 以外を削除して 1 コミット → `push.sh` → `git fetch` で遅れ・衝突なし → `gh pr ready 7` |

## 残課題

- 2/3（[#9](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9)）: フック本体 11 本・`settings.json` 登録（人間の操作）・§12 TBD T1〜T4・`HOOK_DENY_ID` の既定・作業中 2 枚以上の扱い・`shellcheck` の CI 方針
- 3/3（[#10](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/10)）: タスクスキル 15 本・ワークフロースキル 2 本・エージェント 2 本・`finalize.sh` / `boundary.sh`・参照更新。仕様への申し送り: `fm_get` のエスケープ解除と TICKET-T05（D2-2）、`check-html.sh` の awk 前提（D2-4）、テスト ID の複数ファイル配置（CP-T08）、計画スキルの手順（往復・参照更新一覧・依存テストの洗い出し・ロックアウト対策）、テンプレート実体、敵対的レビューのプロンプト構成
- ルール 11 本（[#11](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/11)）
- 手作業代替で分かったこと（3/3 の `finalize.sh` / `boundary.sh` 仕様へ）: - 別 issue の本文は「フィードバック計画の対応先」と各チケットの「AI アセットに反映すべき内容」から機械的に集められる。`finalize.sh` に集約の下書き（対応先ごとの grep）を持たせると、人間は本文の採否だけを見ればよい
- 承認は 2 か所（別 issue の本文・承認③）で、まとめて 1 回の質問にできた。`boundary.sh request --final` を待たずに済むので、レビュー不要の全体まとめでは質問を 1 回に束ねる設計が要る
- HTML 添付は GitHub 側で `text/html` が許可されず 422 になる（下記）。仕様の代替フロー（省略の事実を本文に書く）はそのまま使えたが、`finalize.sh` は**先に content_type を試して失敗したらリンク一覧に切り替える**形にしておくと手戻りが無い
- 全体まとめチケットは `ticket.sh complete` を使えない（TK005）ため、完了検査に相当する DoD × 根拠を統括レポートに写してから片付けで消す、という手順を明文化しておく必要がある（今回はこのレポートの最終節で代替した）

## このチケット（0037）の DoD × 根拠

片付けでチケットが消えるため、完了検査に相当する内容をここに写す。

| DoD | 根拠 |
|---|---|
| 別 issue の本文案を提示して承認を得てから起票し、番号と URL が統括レポートにある | 本文案 3 件（`wip/tmp/issue-body-{2of3,3of3,rules11}.md`）を AskUserQuestion で提示 → 「3 件とも起票する」→ #9 / #10 / #11 を `gh issue create --body-file` で作成。一覧は「別 issue 一覧」 |
| `git fetch origin` で衝突を確認し、結果が作業ログと統括レポートにある | 衝突なし（`origin/main` = `09a5e6b` のまま、`HEAD..origin/main` = 0、`git merge-tree` の衝突マーカー 0 件）。「衝突確認」に記載 |
| 統括レポート（md + HTML、`check-html.sh` OK）に受け入れ条件 1〜7・各ワークのレビュー結果・残課題・別 issue 一覧・ルールの本数の注記・DoD × 根拠があり、push されて履歴に載っている | この md と同名の HTML（`check-html.sh` OK）。`commit.sh` でコミットし `push.sh` で push |
| PR #7 の本文に `## 統括` 節があり、HTML 添付のコメント 1 件（または代替のリンク）と本文への URL 追記が済んでいる | アップロードは HTTP 422（`text/html` は許可された content_type に無い）で不可 → 片付け前コミットに固定したリンク一覧をコメント 1 件で投稿し、同じリンクを本文の `## 統括` にも置いた |
| 承認③を得てから `wip/` を `.gitkeep` だけにしてコミット・push し、fetch して遅れ・衝突が無いことを確認して `gh pr ready` を実行した。削除件数と最終ゲートの結果が PR コメントにある。マージは行っていない | 承認③取得済み（2026-09-02、「draft 解除まで進む」）。片付けの削除件数・最終ゲート・`gh pr ready` の結果は PR コメントに記す。`gh pr merge` は実行しない |
