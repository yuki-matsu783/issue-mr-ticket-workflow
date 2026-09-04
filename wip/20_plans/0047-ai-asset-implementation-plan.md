---
type: plan
title: 0047 AI アセット実装・テスト計画 — 仕様に本体を追随させる
description: issue #10 の設計フェーズ（0043〜0048）が書き戻した 19 本の仕様に、アセット本体（テンプレート 3 件・提供コマンド 2 本・SKILL.md 14 本・ルール 1 本）を追随させる計画。設計への差し戻し 1 件、実装ステップ S1〜S5、許可範囲・テスト割付・参照更新・ロックアウト対策を定める
tags: [plan, ai-asset-implementation-plan, issue-10]
keywords: [実装計画, 追随, BD006, FN004, SKILL.md, テンプレート, 参照更新, ロックアウト対策, 設計差し戻し]
---

# 0047 AI アセット実装・テスト計画 — 仕様に本体を追随させる

- 対象 issue: [#10](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/10)
- MR: [#35](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/35)（draft）
- 根拠とする要件・仕様: 設計フェーズ（0043〜0048）が変更した要件定義書 11 本・仕様書 18 本・横断仕様 1 本

## この計画で何をするか

設計フェーズが正史に書き戻した内容に、アセット本体を追随させる。受け入れ条件 A1（SKILL.md が仕様と 1:1）を満たすことが目的で、**新しい振る舞いを設計しない**。

追随が要るのは 4 種類ある。

1. **テンプレート**: 視覚語彙の見出しと、新設した節（消し込み表）
2. **提供コマンド**: 引数・環境の誤りの識別子（`BD006` / `FN004`）を、前提未充足（`BD001` / `FN001`）から分ける
3. **SKILL.md とルール**: 仕様に足した手順・規約の要約
4. **数値・文言の追随**: 「セルフレビュー項目 14 項目」のように仕様の件数を引用している箇所

## 対象と範囲

| 含む | 含まない |
|---|---|
| `.claude/skills/*/SKILL.md` 14 本の追随 | `.claude/docs/` の変更（設計フェーズが済ませた） |
| `.claude/skills/*/assets/` のテンプレート 3 件 | フック本体・`settings.json`（今回の仕様変更は中核の振る舞いを変えていない） |
| 提供コマンド 2 本（`boundary.sh` / `finalize.sh`）の識別子 | 別 issue に回した 11 件 |
| `.claude/rules/work-defaults.md` | 新しいアセットの新設 |
| 上記に依存する機械テスト 2 ファイル | eval の実行（定義済み・実行は人間の判断） |

**中核の変更**: 提供コマンド 2 本を含むので中核ありとして扱う（フック本体と `settings.json` は変えない）。

## 設計への差し戻し（実装より先に閉じる）

| # | 不足 | なぜ実装計画で埋めないか | 起こすチケット |
|---|---|---|---|
| 1 | `BD006` / `FN004` に対応する**テスト観点が仕様に無い**。`00-workflow-issue-mr-driven` 仕様のテスト観点は `BD-T01`〜`BD-T18`、`10-task-overall-summary` 仕様は `FN-T01`〜`FN-T17` で、いずれも終了コード 2（引数・環境の誤り）を固定する行を持たない | テスト ID の無いアセット変更をステップに入れない規約（このスキルの禁止事項）。仕様に観点を足すのは設計フェーズの担当で、実装計画が仕様を書き換えてはならない | **0049**（`ai-asset-design`）。`BD-T19` と `FN-T18` の行を 2 本の仕様のテスト観点表に足す |

`0049` が終わるまで S2 に入らない（`predecessors` で固定する）。

## 変更対象

| # | アセット | 区分 | 根拠（仕様書の節） | 割り付け |
|---|---|---|---|---|
| 1 | `20-common-step-report-view/assets/report.template.html` | 更新 | `20-common-step-report-view` OUT ひな形（視覚語彙。◇ の見出しを「判断が欲しい」に） | S1 |
| 2 | `20-common-step-report-view/assets/report.template.md` | 更新 | 同上（HTML と節構成が 1 対 1） | S1 |
| 3 | `10-task-feedback-plan/assets/feedback-plan.template.md` | 更新 | `10-task-feedback-plan` OUT ひな形（消し込み表の節） | S1 |
| 4 | `00-workflow-issue-mr-driven/scripts/boundary.sh` | 更新 | `00-workflow-issue-mr-driven` エラー識別子（`BD006`） | S2 |
| 5 | `10-task-overall-summary/scripts/finalize.sh` | 更新 | `10-task-overall-summary` エラー識別子（`FN004`） | S2 |
| 6 | `00-workflow-issue-mr-driven/scripts/tests/test_boundary.sh` | 更新 | 同上（`BD-T19`。0049 が仕様に足す） | S2 |
| 7 | `10-task-overall-summary/scripts/tests/test_finalize.sh` | 更新 | 同上（`FN-T18`。0049 が仕様に足す） | S2 |
| 8 | `00-workflow-issue-mr-driven/SKILL.md` | 更新 | 手順 2a（起動プロンプトのブランチ名・必須節の観点・モデルの代替）、`position` の `before_request`、`BD006` | S3 |
| 9 | `10-task-investigation-plan/SKILL.md` | 更新 | 共通手順 4 の但し書き、保留の書き方 2 項目 | S3 |
| 10 | `10-task-investigation-exec/SKILL.md` | 更新 | 共通手順 4 の但し書き 3 項目（過去の節・表に行を足す・成果物の形） | S3 |
| 11 | `10-task-ai-asset-design-exec/SKILL.md` | 更新 | 固有手順（ルールを読む・採番と定義・旧名のセルフレビュー） | S3 |
| 12 | `10-task-ai-asset-implementation-plan/SKILL.md` | 更新 | 固有手順 4 項目（削除対象・`--filter`・実測値・ロックアウト対策） | S3 |
| 13 | `10-task-overall-plan/SKILL.md` | 更新 | 処理フロー 4 の但し書き（前 issue の残骸） | S3 |
| 14 | `10-task-overall-summary/SKILL.md` | 更新 | 進行状態の `branch`・`--linked` の前提・draft の 3 値・`FN004` | S3 |
| 15 | `10-task-feedback-plan/SKILL.md` | 更新 | 類型の文言・消し込み表 | S3 |
| 16 | `20-common-step-ai-asset-creator/SKILL.md` | 更新 | 標準構成の但し書き・移設の完了条件・参照更新の作法・eval の要否 | S4 |
| 17 | `20-common-step-feature-mr/SKILL.md` | 更新 | 手順 3 の但し書き（`--no-track`） | S4 |
| 18 | `20-common-step-report-view/SKILL.md` | 更新 | 処理フロー 2（Read + Write）・節の対応表・数え方 | S4 |
| 19 | `20-common-step-requirement/SKILL.md` | 更新 | セルフレビュー項目 16 項目・数の書き方 | S4 |
| 20 | `20-common-step-shell-script/SKILL.md` | 更新 | テストの書き方 5 項目・`--filter` の意味 | S4 |
| 21 | `20-common-step-spec/SKILL.md` | 更新 | 識別子の規約・eval の階層・番号参照 | S4 |
| 22 | `.claude/rules/work-defaults.md` | 更新 | `00_requirement/rules/work-defaults.md`（レビュアーのモデルの代替） | S4 |

**対象にしないもの**（仕様は変えたが本体の追随が要らない）: `session-start` 仕様と `00-workflow-quick-request` 仕様（過渡期の記述を落としただけ）、`workflow-guard` 仕様（削除の判定は 0036・0038 で実装済み）、`20-common-step-issue` 仕様（見出しの階層だけ）、`フック共通仕様`（採番台帳は文書のみ）。

## 方法とステップ

固定順（設定・定義 → 中核 → 中核のテスト → スキル・ルール・エージェント → 参照更新）に並べる。連番は実行順と一致させる。

| # | ステップ | チケット | 先行 | 中核 |
|---|---|---|---|---|
| S0 | 設計差し戻し: `BD-T19` / `FN-T18` の観点を仕様に足す | 0049 | 0047 | — |
| S1 | 定義: テンプレート 3 件（◇ の見出し・消し込み表の節）と実装結果レポートの作成 | 0050 | 0049 | — |
| S2 | 中核: 提供コマンド 2 本の識別子と、その機械テスト 2 件 | 0051 | 0050 | **要** |
| S3 | ワークフロー・タスクスキル 8 本の SKILL.md | 0052 | 0051 | — |
| S4 | 共通ステップスキル 6 本の SKILL.md とルール 1 本 | 0053 | 0052 | — |
| S5 | 参照更新（件数・文言の追随）と全件テスト | 0054 | 0053 | — |

- **S2 で中核の変更と機械テストを同じチケットに置く**。`boundary.sh` は自分が使う提供コマンドなので、書き換えた直後の 1 回目が壊れているとそのチケットを完了させる手段が無くなる
- **S2 の最初の操作を手順として明示する**: 変更 → `bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "..." <変更したパス>`（この 1 回目が検証を兼ねる）→ テスト 2 ファイルを実行 → `ticket.sh complete`。失敗したら基準点（そのチケットの `base_sha`）に戻す
- S3 と S4 を分けたのは、1 枚で 14 本の SKILL.md を触ると失敗時に戻す範囲が広くなりすぎるため。層（タスク層 / 共通ステップ層）で切った

## 許可範囲案

| ステップ | write | ops |
|---|---|---|
| S0（0049） | `.claude/docs/**`, `wip/**` | `read`, `remote-read` |
| S1（0050） | `.claude/skills/20-common-step-report-view/assets/**`, `.claude/skills/10-task-feedback-plan/assets/**`, `wip/**` | `read`, `remote-read` |
| S2（0051） | `.claude/skills/00-workflow-issue-mr-driven/scripts/**`, `.claude/skills/10-task-overall-summary/scripts/**`, `wip/**`, `logs/**` | `read`, `remote-read`, `build-test`, `hook-test` |
| S3（0052） | `.claude/skills/00-workflow-issue-mr-driven/SKILL.md`, `.claude/skills/10-task-*/SKILL.md`, `wip/**` | `read`, `remote-read` |
| S4（0053） | `.claude/skills/20-common-step-*/SKILL.md`, `.claude/rules/work-defaults.md`, `wip/**` | `read`, `remote-read` |
| S5（0054） | `.claude/skills/**`, `.claude/rules/**`, `wip/**`, `logs/**` | `read`, `remote-read`, `build-test`, `hook-test` |

- **S2 と S5 は `build-test` と `hook-test` を両方宣言する**。テストの置き場（`.claude/skills/*/scripts/tests/*.sh`）は `hook-test` に分類されるが、`run-tests.sh` 自身は提供コマンドとして走るので、片方だけだと WF204 で止まる
- S2 は `logs/**` を含める（提供コマンドが共通 logger でログを書く）
- S5 の `write` を広く取るのは、件数・文言の追随がどのファイルに出るか検索の結果で決まるため。狭く宣言して途中で広げる相談になるより、参照更新のステップとして広く取るほうがよい

## テスト方針

設計フェーズが変更した仕様書 19 本から機械的に抜き出したテスト ID は **183 件**。

```
grep -rhoE "[A-Z]{2,6}-[TE][0-9]{2}[a-z]?" <設計フェーズが変更した仕様書 19 本> | sort -u | wc -l
=> 183
```

この 183 件に、0049 が足す 2 件（`BD-T19` / `FN-T18`）を加えた **185 件**を割り付ける。

| 接頭辞 | 件数 | 種別 | ステップ | 実行方法 / 定義先 |
|---|---|---|---|---|
| `BD-T01`〜`BD-T18` | 18 | 機械 | S2（回帰） | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_boundary*'` |
| `BD-T19`（新規） | 1 | 機械 | S2（新規） | 同上。未知のサブコマンドと引数の欠落が `BD006`・終了 2 になる |
| `FN-T01`〜`FN-T17` | 17 | 機械 | S2（回帰） | `run-tests.sh --filter '*test_finalize*'` |
| `FN-T18`（新規） | 1 | 機械 | S2（新規） | 同上。未知のサブコマンドと引数の欠落が `FN004`・終了 2 になる |
| `WG-T01`〜`WG-T18` | 18 | 機械 | S5（回帰） | 全件テスト |
| `SE-T01`〜`SE-T10` | 10 | 機械 | S5（回帰） | 全件テスト |
| `HK-T01`〜`HK-T20` | 20 | 機械 | S5（回帰） | 全件テスト |
| `RV-T01`〜`RV-T08` | 8 | 機械 | S1・S5（テンプレートを変えるので S1 で `check-html.sh`、S5 で全件） | `check-html.sh` と全件テスト |
| `TR-T01`〜`TR-T06` | 6 | 機械 | S5（回帰） | 全件テスト |
| `SS-T01`〜`SS-T05` | 5 | 機械 | S5（回帰） | 全件テスト |
| `LG-T01`〜`LG-T05` | 5 | 機械 | S5（回帰） | 全件テスト |
| `FR-T01`〜`FR-T05` | 5 | 機械 | S5（回帰） | 全件テスト |
| `UR-T01` `UR-T02` `UR-T05` | 3 | 機械 | S5（回帰） | 全件テスト |
| `PP-T01` `PP-T08` | 2 | 機械 | S5（回帰） | 全件テスト |
| `WD-T06` | 1 | 機械 | S5（回帰） | 全件テスト |
| eval（`*-E01`〜、`AC` / `ADE` / `AIP` / `AS` / `FBP` / `FM` / `IS` / `IVE` / `IVP` / `OP` / `OSM` / `QR` / `RQ` / `SC` / `WFD`） | 65 | eval | S3・S4（定義の見直しのみ。実行しない） | `.claude/evals/<アセット名>.md` |
| 合計 | **185** | — | — | — |

- 件数の合計 185 が、抽出の 183 + 新規 2 と一致する（この表は 1 行 1 ID ではなく接頭辞ごとにまとめている。1 行 1 ID の表にすると 185 行になり読めなくなるため、**割り付いていない ID が無いことを件数の合計で担保する**形に替えた）
- eval は実装フェーズでは定義までとし、実行しない。SKILL.md を変える S3・S4 で、既存の eval 定義が新しい手順と食い違わないかだけを見る

## 検証

| # | 何を | どう確かめるか |
|---|---|---|
| 1 | 提供コマンドの識別子が分かれた | `bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh nosuchsub` が `BD006:` と終了 2、前提未充足は `BD001:` と終了 1（`BD-T19` / 既存の `BD-T03`・`BD-T16`） |
| 2 | SKILL.md が仕様と 1:1 | 変更した 14 本それぞれについて、仕様に足した項目の要約が SKILL.md にあることを対応表で示す（S5 の実装結果レポート） |
| 3 | 件数の引用が追随した | `grep -rn '14 項目' .claude/skills/` が 0 件（`20-common-step-requirement/SKILL.md` の「セルフレビュー項目 14 項目」が 16 項目になる） |
| 4 | `cp` の案内が残っていない | `grep -rn 'cp .claude/skills/20-common-step-report-view/assets' .claude/skills/` が 0 件 |
| 5 | ◇ の見出しが揃った | `grep -rn '承認が欲しい' .claude/skills/` が 0 件（既存レポートの本文は対象外） |
| 6 | 全件テストが通る | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --timeout 300`（10 分前後かかるので背景実行） |
| 7 | 旧名が増えていない | `grep -rn '10-work-\|20-task-\|work-boundary\|merge-prep' .claude/ CLAUDE.md --exclude-dir=20_ddr` が 0 件 |
| 8 | プレースホルダが残っていない | `grep -rn '{{' .claude/skills/*/SKILL.md .claude/rules/` が 0 件 |

## チケット

| 番号 | 種類 | 新規 / 修正 | 内容 | 先行 | 実行者 | 人間レビュー | 敵対的レビュー |
|---|---|---|---|---|---|---|---|
| 0049 | `ai-asset-design` | 新規 | `BD-T19` / `FN-T18` の観点を 2 本の仕様に足す | 0047 | メイン | 不要 | 不要（設計フェーズの上限 1 回に到達済み） |
| 0050 | `ai-asset-implementation` | 新規 | テンプレート 3 件と実装結果レポートの作成 | 0049 | メイン | 不要 | 不要 |
| 0051 | `ai-asset-implementation` | 新規 | 提供コマンド 2 本の識別子と機械テスト 2 件（**中核**） | 0050 | メイン | 不要 | **要** |
| 0052 | `ai-asset-implementation` | 新規 | ワークフロー・タスクスキル 8 本の SKILL.md | 0051 | メイン | 不要 | 不要 |
| 0053 | `ai-asset-implementation` | 新規 | 共通ステップスキル 6 本の SKILL.md とルール 1 本 | 0052 | メイン | 不要 | 不要 |
| 0054 | `ai-asset-implementation` | 新規 | 参照更新と全件テスト | 0053 | メイン | 不要 | 不要 |
| 0055 | `overall-summary` | 新規 | 全体まとめ（別 issue の確認・統括レポート・片付け・draft 解除） | 0054 | メイン | 要（最終確認） | 不要 |

- **実行者をメインエージェントに倒した**（基準は `implementation` がサブエージェント（sonnet））。理由は 0024 以降の実装と同じで、提供コマンドが未完成な状態でサブエージェントに状態遷移を任せると、失敗時にチケットが作業中のまま残るため。基準との差分として全体計画に記録済み
- **人間レビューは全チケットで不要**（基準は `implementation` が要）。承認③で「切れ目で止めず、人間レビューの代わりに敵対的レビューを置く」と合意しているため。全体まとめだけは最終確認として要
- **敵対的レビューは 0051 のみ要**（基準は `ai-asset-implementation` が要）。中核（提供コマンド）を含むのが 0051 だけで、残りは文書の追随だから。実施回数の上限はタスクごとに 1 回

## 参照更新一覧

| # | 旧 | 新 | 検索語（行末に依存しない） | ヒット箇所 | 除外 | 期待値 |
|---|---|---|---|---|---|---|
| 1 | `◇承認が欲しい` | `◇判断が欲しい` | `承認が欲しい` | `report.template.html` 2 か所（18 行・213 行）、`report.template.md` 1 か所（37 行） | `wip/30_reports/` の既に書いたレポート（過去の節は書き換えない） | `.claude/` 配下が 0 件、`wip/30_reports/` に既存レポートの分だけ残る |
| 2 | `セルフレビュー項目」14 項目` | `セルフレビュー項目」16 項目` | `14 項目` | `20-common-step-requirement/SKILL.md` 47 行 | なし | `.claude/` 配下が 0 件 |
| 3 | `cp <テンプレート> <出力先>` | Read + Write | `cp .claude/skills/20-common-step-report-view/assets` | `20-common-step-report-view/SKILL.md` 22・23 行 | なし | `.claude/` 配下が 0 件 |
| 4 | `テンプレートのコピー` | `テンプレートの書き出し` | `テンプレートのコピー` | `20-common-step-report-view/SKILL.md` 4・11・49 行 | `RV003` の案内文（章の複製の話で、テンプレートの複製ではない） | `.claude/` 配下が 1 件（`RV003:` の行）だけ残る |
| 5 | `git checkout -b <ブランチ名> origin/<default>` | `git checkout --no-track -b ...` | `checkout -b` | `20-common-step-feature-mr/SKILL.md` 24 行 | なし | `--no-track` の付かない `checkout -b` が `.claude/` 配下で 0 件 |
| 6 | `BD001`（引数・環境の誤り） | `BD006` | `arg_ng` | `boundary.sh` 52 行 | 前提未充足の `result_ng 001 ... 1`（意味が違うので置換しない） | `boundary.sh` の `arg_ng` が `result_ng 006 ... 2` の 1 か所 |
| 7 | `FN001`（引数・環境の誤り） | `FN004` | `arg_ng` | `finalize.sh` 44 行 | 同上 | `finalize.sh` の `arg_ng` が `result_ng 004 ... 2` の 1 か所 |

**0 件を期待値にしていない行**（#4・#6・#7）は、検索語が間違って何もヒットしない場合と区別するため「残るもの」で書いている。

## 依存するテスト

| 変更対象 | 依存するテスト | 入れるステップ |
|---|---|---|
| `boundary.sh` の `arg_ng` | `test_boundary.sh`（`BD-T03` `BD-T09` `BD-T16` が `BD001` を期待値に持つ。いずれも**終了 1 の前提未充足**なので期待値は変わらないが、同じチケットで実行して確かめる） | S2 |
| `finalize.sh` の `arg_ng` | `test_finalize.sh`（`FN-T02` `FN-T10` が `FN001` を期待値に持つ。同じく終了 1 で変わらない） | S2 |
| `report.template.html` | `test_check_html.sh`（`RV-T01`〜`RV-T08` がテンプレートから必須節を導出する） | S1 |
| `feedback-plan.template.md` | 機械テストなし（eval `FBP-E01`〜`E05` の対象） | S1 |

`grep -rn 'BD001\|FN001' --include="test_*.sh" .claude/` の結果は上の 2 ファイル 5 か所で、いずれも終了 1 のケース。**期待値の変更は無い**が、変更対象と同じチケットで実行する。

## ロックアウト対策

| ステップ | 確かめる操作（そのパスを実際に踏むもの） | 復旧手順 |
|---|---|---|
| S2（`boundary.sh`） | 変更の直後に `commit.sh` で自分をコミットし、続けて `boundary.sh status` を実行する（`status` は `ticket.sh complete` の後に切れ目の判定で必ず通る経路）。`BD-T19` と `BD-T03`・`BD-T16` を実行する | `git checkout <0051 の base_sha> -- .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh` |
| S2（`finalize.sh`） | `FN-T18` と `FN-T02`・`FN-T10` を実行する。`finalize.sh` は全体まとめ（0055）まで実運用では走らないので、テストが唯一の検証経路になる | `git checkout <0051 の base_sha> -- .claude/skills/10-task-overall-summary/scripts/finalize.sh` |

- `boundary.sh` が壊れると切れ目の判定・レビュー依頼・省略の記録がすべて止まる。`ticket.sh` / `commit.sh` は変えないので、チケットの完了とコミットの経路は生きている
- 強制無効化（`WORKFLOW_ENFORCE=0` / `WORKFLOW_ENTRY_ENFORCE=0`）は使わない。ユーザーの明示があるときだけ

## リスクと復旧

| # | リスク | 影響範囲 | 巻き戻し方 |
|---|---|---|---|
| 1 | `arg_ng` の識別子を変えたとき、`usage` を出す経路（`-h` / `--help` / サブコマンド無し）が終了 0 のままかどうかを取り違える | `boundary.sh` / `finalize.sh` のヘルプ表示 | `BD-T19` / `FN-T18` に「`--help` は終了 0」を含めて固定する。壊れたら基準点に戻す |
| 2 | SKILL.md の追随で、仕様に無いことを書き足してしまう | タスクスキル 14 本 | 各チケットの DoD に「仕様書の該当節と 1:1」を置く。差分は仕様の該当行を根拠として作業ログに残す |
| 3 | 全件テストが 10 分前後かかり、既定のタイムアウトで落ちる | S5 の検証 | `--timeout 300` を付けて背景で実行する。2 本同時に走らせない |
| 4 | テンプレートの見出しを変えると、既に書いたレポートの HTML と文言が食い違う | `wip/30_reports/` の既存レポート | 過去の節は書き換えない（実施タスクの共通手順）。テンプレートだけを変え、既存レポートはそのまま残す |

## スコープ外

- 別 issue に回した 11 件（候補 21〜27・29・33・35・40）。MR 本文に一覧として残してある
- eval の実行（定義までが実装フェーズの担当）
- フック本体と `settings.json`（今回の仕様変更は中核の振る舞いを変えていない）

## 保留した点 / 対象なし

| # | 保留 | 誰がいつ決めるか |
|---|---|---|
| P1 | テスト ID の割付表を 1 行 1 ID（185 行）ではなく接頭辞ごとの件数表にした。割り付いていない ID が無いことは件数の合計で担保しているが、規約の字面（「抜き出しの結果と割付表の行数が一致する」）とは違う | この計画の人間レビュー（省略しているので、次のフィードバック計画で規約の書き方を見直す候補にする） |
| P2 | `BD-T19` / `FN-T18` の観点の細かさ（未知のサブコマンド・引数の欠落・依存コマンドの不在の 3 つを 1 つの ID に入れるか分けるか） | 0049（設計チケット）が決める |

## レビューで見てほしい点

- ステップ順と、中核（S2）とその機械テストが同じチケットに入っていること
- テスト ID の割付に漏れが無いこと（P1 の形で担保している）
- 参照更新一覧の検索根拠と、0 件を期待値にしていない 3 行（#4・#6・#7）の書き方
- ロックアウト対策が `boundary.sh` の実際に踏む経路（`status`）を指していること
