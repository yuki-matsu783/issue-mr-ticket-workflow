---
type: plan
title: 0002 調査計画 — 作るものの一覧・提供コマンド仕様の食い違い・旧名の残存・申し送りの割り付け
description: issue #10 の主作業（タスクスキル 15 本・ワークフロースキル 2 本・エージェント 2 本・提供コマンド 2 本の実装と参照更新）に入る前に、読み取りだけで答えられる問い（作成物の全件一覧と共通化候補、boundary.sh / finalize.sh の仕様と実装済みフックの食い違い、旧名 5 種の残存箇所、#6 / #9 の申し送りの反映先）を 4 枚の調査チケットに割り付け、実測が要る問いは実装フェーズの検証項目として一覧化する調査計画
tags: [plan, investigation-plan, issue-10]
keywords: [調査計画, タスクスキル, エージェント, boundary.sh, finalize.sh, 置き場の食い違い, 旧名の残存, 参照更新, 申し送り, 実装フェーズの検証項目, BD-T01, FN-T01]
---

# 0002 調査計画 — 作るものの一覧・提供コマンド仕様の食い違い・旧名の残存・申し送りの割り付け

## 対象

- 対象 issue: #10 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/10
- MR: #35 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/35（draft）
- ブランチ: `feature-10-task-skills-agents-finalize`
- このチケット: `0002-investigation-plan`（フェーズ 2 の計画）

## この計画で何をするか

issue #10 の主作業（フェーズ 4）に入る前に、**読み取りだけで答えられる問い**を 4 枚の調査チケットに割り付ける。実測が要る問い（作った提供コマンドが実際に自分に対して通るか、eval を実行したらどうか）は、この調査では実施せず「実装フェーズの検証項目」として確かめ方だけを整理する。

決めたこと:

- 調査チケットは 4 枚（0003 / 0004 / 0005 / 0006）。1 観点のまとまり = 1 チケット
- **外部技術調査は計画しない**。この issue の対象はすべてリポジトリ内の仕様書とアセットで、外部の情報に依存する問いが無い。`allow.ops` に `web` を宣言するチケットは無い
- **既存のテスト・ビルドの実行を 1 枚だけ計画する**（0006）。`fm_get` のエスケープ解除と `TICKET-T05` の期待値は「今どちらの形か」を実行して確かめないと反映先を決められないため、そのチケットにだけ `build-test` を宣言する
- `.claude/**` への一時的な変更は計画しない（`10-task-investigation-plan` 仕様「調査計画の固有手順」。`investigation` は `.claude/**` を deny）
- 次の計画チケットは `0007-ai-asset-design-plan`。`predecessors` に 0003・0004・0005・0006 を入れる
- 実装フェーズの検証項目は**この計画書が表として持つ**（下記）。調査チケットは作らない

## 調査観点

| 観点 | 問い | 効く先 |
|---|---|---|
| 観点 A（0003） | タスクスキル 15 本・ワークフロースキル 2 本・エージェント 2 本の仕様から、作るもの（SKILL.md の節・`assets/` のテンプレート実体・`references/`・eval 定義）は全部で何か。重複しているもの・どの仕様にも書かれていないもの・共通化できるものはどれか | 受け入れ条件 A1、保留 P3（テンプレートの置き場）、P4（エージェントのモデルと tools）、P6（チケット分割の粒度） |
| 観点 B（0004） | `boundary.sh`（BD001〜005 / BD-T01〜13）と `finalize.sh`（FN001〜003 / FN-T01〜05）は、どの前提をどの順に検査し、何を入出力し、`logs/` に何を書くのか。実装済みのフック・提供コマンド・仕様の間で食い違っている点はどこか（置き場を含む） | 受け入れ条件 A2、保留 P1（置き場）、P2（この issue で使い始めるか） |
| 観点 C（0005） | 旧名 5 種（`work-boundary.sh` / `merge-prep.sh` / `10-work-` / `20-task-gh-` / `workflow-lib.sh`）は、DDR と `参考ディレクトリ/` と `logs/` を除いてどこに何件残っているか。それぞれ何に置き換わるのか。置換後に「残るもの」で書ける期待値は何か | 受け入れ条件 A3 |
| 観点 D（0006） | issue #10 の「#6 からの申し送り」の各項目は、どの仕様書のどの節に落ちるのか。すでに反映済みのものはどれか。`fm_get` のエスケープ解除と `TICKET-T05` の期待値は現在どちらの形か | 受け入れ条件 A4、保留 P5（扱わないものの線引き） |

答えが後続の計画に効かない問い（例: 参考実装 `参考ディレクトリ/agent-workflow` の旧スキルがどう書かれていたか）は観点に含めない。参考実装は、作るものの書き方の**参考**としてフェーズ 4 で読めばよく、調査の結論にはしない。

## 対象と方法

| 観点 | 読む場所 | 確かめ方 |
|---|---|---|
| A | `.claude/docs/10_spec/skills/10-task-*.md`（15 本）、`.claude/docs/10_spec/skills/00-workflow-*.md`（2 本）、`.claude/docs/10_spec/agents/*.md`（2 本）、対応する `00_requirement/`、既存の `.claude/skills/20-common-step-*/`（作法の実例）、`.claude/evals/`（既存 9 本の書き方）、`20-common-step-ai-asset-creator` の仕様と `assets/skill.template.md` / `eval.template.md` | 各仕様の「処理フロー」「OUT ひな形」「参照ナレッジ」「Script 処理」から、作成物を 1 行 1 件で書き出す。`assets/` として名前が出ているファイルを全件拾い、同じ名前が複数の仕様に出るものを重複候補として印を付ける |
| B | `.claude/docs/10_spec/skills/00-workflow-issue-mr-driven.md`（`boundary.sh` の Script 処理・BD001〜005・BD-T01〜13）、`.claude/docs/10_spec/skills/10-task-overall-summary.md`（`finalize.sh`）、`.claude/docs/10_spec/フック共通仕様.md`、実装済みの `.claude/hooks/20-PreToolUse/workflow-state-guard.sh`・`.claude/hooks/00-SessionStart/session-start.sh`・`.claude/hooks/10-UserPromptSubmit/workflow-entry.sh`、`.claude/hooks/lib/*.sh`（再利用できる関数）、既存の提供コマンド `ticket.sh` / `commit.sh` / `push.sh`（作法の実例） | 仕様の記述と実装済みフックの参照先を突き合わせ、食い違いを「どちらが何と言っているか」の表にする。`logs/` の各ファイル（`mr.json` / `review-state.json` / `review-history.jsonl` / `merge-state.json`）のスキーマを、書く側（仕様）と読む側（フック）の両方から書き出して一致を見る |
| C | `CLAUDE.md`、`.claude/skills/00-workflow-issue-mr-driven/`（SKILL.md・`assets/`・`evals/`）、`.claude/skills/00-workflow-quick-request/`（同）、`.claude/docs/10_spec/skills/00-workflow-quick-request.md`、`.claude/docs/90_glossary/`、`.claude/hooks/config/entry-skills.txt` | `grep -rn` で 5 種を全件出し、`参考ディレクトリ/`・`logs/`・`.git/`・`.claude/docs/20_ddr/` を除外した一覧を作る。各件について置換後の名前を決められるか（決められないものは設計へ回す印）を書く。期待値は「置換後に残るもの」の形で書き、行末に依存する検索語にしない（申し送り 0038） |
| D | issue #10 の本文（「#6 からの申し送り」の全項目）、反映先候補の `.claude/docs/10_spec/skills/*.md`、`.claude/docs/20_ddr/`、`.claude/skills/20-common-step-shell-script/scripts/frontmatter.sh`、`.claude/skills/20-common-step-ticket/scripts/tests/test_ticket.sh`（TICKET-T05） | 申し送りを 1 行 1 件に分解し、反映先の仕様書とその節を割り当てる。すでに書かれているものは「反映済み」として根拠（ファイル:行）を添える。`fm_get` は `run-tests.sh --ids TICKET-T05` を実行して現在の期待値の形を確かめる |

## 調査チケット

| 番号 | 種類 | 担う観点 | 先行 | やってよいこと |
|---|---|---|---|---|
| 0003 | investigation | 観点 A（作るものの一覧と共通化候補） | 0002 | write `wip/**` / ops `read`, `remote-read` |
| 0004 | investigation | 観点 B（提供コマンド 2 本の仕様と食い違い） | 0002 | write `wip/**` / ops `read`, `remote-read` |
| 0005 | investigation | 観点 C（旧名の残存と置換後の期待値） | 0002 | write `wip/**` / ops `read`, `remote-read` |
| 0006 | investigation | 観点 D（申し送りの割り付けと `fm_get` の現状） | 0002 | write `wip/**` / ops `read`, `remote-read`, `build-test` |
| 0007 | ai-asset-design-plan | 次の計画 | 0003, 0004, 0005, 0006 | write `wip/**` / ops `read`, `remote-read` |

- 4 枚は互いに独立で、順序の依存が無い（先行はすべて 0002 のみ）
- 人間レビュー要否・敵対的レビュー要否は全体計画の方針に従う（人間レビューは代替、敵対的レビューは実施タスクの切れ目で最大 2 回）
- `build-test` を宣言するのは 0006 だけ。実行するのは `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids TICKET-T05` と、必要なら `--ids` を絞った frontmatter のテストのみ。全件テスト（10 分前後）は回さない

## 成果物の形

各調査チケットは `wip/30_reports/<番号>-investigation.md` とその HTML を残す。次の計画（`0007-ai-asset-design-plan`）が判断できるよう、次を含めること。

| 観点 | レポートに必ず含めるもの |
|---|---|
| A | 作成物の全件一覧（種類 / パス / 出典の仕様の節 / 既存の有無）。重複候補と共通化候補は「どれとどれが同じか」を明示。どの仕様にも書かれていないが必要なものは「欠落」として別表に |
| B | 判定順と入出力の要約（サブコマンドごと）、`logs/` の各ファイルのスキーマ（書く側 / 読む側）、食い違いの一覧（項目 / 仕様の言い分 / 実装の言い分 / 実測に依存するか） |
| C | 残存箇所の全件（ファイル:行 / 旧名 / 置換後の候補 / 決められない場合はその理由）、置換後の期待値の書き方（「残るもの」の形）、期待値が変更対象に依存するテストファイルの一覧 |
| D | 申し送り × 反映先の対応表（項目 / 反映先の仕様書と節 / 反映済みか / この issue で扱うか）、`fm_get` と `TICKET-T05` の現在の形（実行結果を添える） |

共通: 答えが出なかった問いは理由付きで「残課題」に残す。設計で決めるべきものは「設計へ回す」と明示する（調査は実装方針を決めない）。

## 実装フェーズの検証項目

読み取りでは答えが出ず、フェーズ 4 で実際に動かして確かめるものを一覧にする。調査チケットは作らない。

| # | 確かめること | どの段で | 確かめ方 |
|---|---|---|---|
| V1 | `boundary.sh status` が、このリポジトリの実際の作業領域と `logs/` から正しい現在地を返すか | 4a の直後 | 作業中チケットがある状態・無い状態の両方で実行し、`at_boundary` と `position` を目視で照合 |
| V2 | `session-start` フックが `boundary.sh status --offline` の出力を受けて注入テキストを組み立てられるか（2/3 で保留した部分） | 4a の直後 | 新しいセッションを開いて注入の有無を確認。組み立ての実装が要るなら実装チケットに追加 |
| V3 | `boundary.sh request` / `complete` が実際の MR に対して通るか（この issue の切れ目で使い始める場合） | 4a の後の最初の切れ目 | 実際の切れ目で 1 回使い、`logs/review-state.json` が書かれることを確認。失敗したら直接投稿に戻す |
| V4 | `finalize.sh release` の前提検査（FN001）が、この issue の途中の状態で正しく拒否するか | 4a の直後 | チケットが残っている状態で実行し、FN001 と未充足の列挙が出ることを確認（片付けは起こらないこと） |
| V5 | `finalize.sh release` がフェーズ 7 で実際に通るか | 7 | 全体まとめで実行。通らなければ #9 と同じく手作業で代替し、原因をフィードバック計画へ |
| V6 | 参照更新後に旧名が 0 件になるか（`grep` の除外条件込み） | 4d の直後 | 観点 C のレポートに書いた検索コマンドをそのまま実行 |
| V7 | `run-tests.sh --ids` の全件が通るか（BD-T01〜13 / FN-T01〜05 / TICKET-T05 を含む） | 4 の最後 | 全件実行（10 分前後。他のテストと同時に走らせない） |

eval の実行は issue のスコープ外（定義を作るだけ）。

## 保留した点

| # | 保留した項目 | 決める時期 |
|---|---|---|
| Q1 | 観点 B で見つかる食い違いを「仕様を直す」「実装（フック）を直す」のどちらで解消するか | `0007-ai-asset-design-plan`（調査は列挙まで） |
| Q2 | 観点 A の共通化候補（同じテンプレートを複数スキルが使う場合）を、共通ステップに寄せるか各スキルに複製するか | `0007-ai-asset-design-plan` |
| Q3 | 観点 D で「この issue で扱わない」と判定した申し送りを DDR に残すか別 issue にするか | `0007-ai-asset-design-plan`、および フェーズ 5 |
