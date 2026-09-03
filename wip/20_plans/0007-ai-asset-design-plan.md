---
type: plan
title: 0007 AI アセット設計計画 — 提供コマンドの置き場の決着・overall-summary 仕様の改訂・申し送り 23 項目の反映
description: issue #10 の調査 4 件の結論から、.claude/docs 配下に書く設計チケット 6 枚を起こす計画。提供コマンド 2 本の置き場を仕様側に寄せて食い違い 4 件を解消し、10-task-overall-summary 仕様を追記 B1〜B4 のとおり改訂し、#6 / #9 の申し送り 23 項目を 8 本の仕様書へ反映先ごとに割り付け、eval ID の接頭辞と旧名の扱いを確定させる
tags: [plan, ai-asset-design-plan, issue-10]
keywords: [AI アセット設計計画, 提供コマンドの置き場, boundary.sh, finalize.sh, overall-summary, 申し送り, eval ID, 旧名, 1:1:1, DDR, ヘッドレス]
---

# 0007 AI アセット設計計画 — 提供コマンドの置き場の決着・overall-summary 仕様の改訂・申し送り 23 項目の反映

## 対象

- 対象 issue: #10 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/10
- MR: #35 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/35（draft）
- ブランチ: `feature-10-task-skills-agents-finalize`
- このチケット: `0007-ai-asset-design-plan`（フェーズ 3 の計画）
- 起点: 調査結果 4 件（`wip/30_reports/0003`〜`0006-investigation.md`）。フィードバック計画の候補ではない

## この計画で何をするか

19 本のアセットの**要件定義書と仕様書はすでに全件そろっている**（`.claude/docs/00_requirement/` と `10_spec/` に skills 25・agents 2）。したがってこのフェーズは新規の設計ではなく、**既存の正史の改訂**である。改訂の材料は 3 つに分かれる。

| 材料 | 出どころ | 分量 |
|---|---|---|
| 仕様と実装・issue・運用の食い違い | 0004 の食い違い一覧 8 行 | 8 行（うち仕様と実装の食い違いは 4 件） |
| issue 追記（2026-09-02）の受け入れ条件 | B1〜B4 | 4 件 |
| #6 / #9 の申し送り | 0006 の d1 対応表 24 項目（反映済み 1 項目を除く） | 23 項目 |

これらを 8 本の仕様書 + 要件定義書 + DDR に落とす設計チケットを 6 枚起こす。**アセット本体（`.claude/skills/`・`hooks/`・`agents/`・`settings.json`）には一切触らない**。触るのは `.claude/docs/` 配下だけ。

## 結論方針

### 中核（フック・settings.json）の変更要否: **要（ただし設計フェーズでは仕様のみ）**

保留 P1（提供コマンド 2 本の置き場）を**仕様側（各スキルの `scripts/`）に寄せる**と決めるため、実装済みフック 2 本の 3 行（`session-start.sh:64` のハードコード、`workflow-state-guard.sh:40, 43` の案内文）が変更対象になる。`session-start.sh` は**注入そのものを止め得る**中核なので、実装フェーズのロックアウト対策の入力として設計チケットの成果に明記する。

**なぜ仕様側に寄せるか**（0004 の b4 が挙げた材料からの判断）:

| 論点 | `.claude/skills/*/scripts/` に寄せる | `.claude/hooks/` に寄せる |
|---|---|---|
| 変更行数 | 実装側 7 行（ハードコード 1・案内文 2・テストの入力 4） | 仕様側 4 行（サンプル 3 + Script 処理 1）× 2 本 |
| 一貫性 | 既存の提供コマンド 5 本（`ticket.sh`・`commit.sh`・`push.sh`・`check-html.sh`・`run-tests.sh`）がすべてスキルの `scripts/` にある | フックと提供コマンドが同じディレクトリに混ざる |
| フックの認識 | `scope.sh` の提供コマンド判定は**両方の形を受け付ける**（`.claude/skills/<n>/scripts/<n>.sh` と `.claude/hooks/(<dir>/)*<n>.sh`）ので、どちらでも動く | 同左 |
| 所有関係 | `boundary.sh` は `00-workflow-issue-mr-driven`、`finalize.sh` は `10-task-overall-summary` が使う。スキルに属させるとスキルと一緒に読める | フックはイベント駆動、提供コマンドは呼び出し駆動で性質が違う |

変更行数だけを見れば実装側に寄せる方が少ないが、**既存 5 本との一貫性**と**所有関係の明示**が勝つ。行数の差は 7 行と 8 行でほぼ同じでもある。この判断は申し送り 0028「実装と仕様が食い違う候補は計画の段階でどちらを正にするかまで決める」に従い、ここで決めきる。

### 採る案: 6 枚の設計チケットに分ける

分け方は**反映先の仕様書のまとまり**を軸にする。0006 の d2 が挙げた 3 案（仕様書ごと / 申し送りの出どころごと / 影響の大きさごと）のうち、仕様書ごとを採る。同じ文書を 2 枚のチケットが同時に書き換えると衝突するためで、出どころ軸だと 1 本の仕様書が複数チケットに割れる。

## 文書一覧と骨子

1:1:1（アセット 1 : 要件定義書 1 : 仕様書 1）はすでに成立している。下表は**改訂する文書**とその骨子。

| # | アセット | 要件定義書 | 仕様書 | 骨子 |
|---|---|---|---|---|
| 1 | `00-workflow-issue-mr-driven`（`boundary.sh`） | 更新なし（置き場は仕様の範囲） | `10_spec/skills/00-workflow-issue-mr-driven.md` | 置き場を `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh` と確定（現行どおり）。実装側 7 行を直す旨を「現行アセットとの差分」に追加 |
| 2 | `10-task-overall-summary`（`finalize.sh`） | `00_requirement/skills/10-task-overall-summary.md` | `10_spec/skills/10-task-overall-summary.md` | 手順 6 を「本文の `## 統括` 配下に表で記載」に（B1）／ HTML 添付は人間がブラウザで行い AI は URL を記録（B2）／ `release` の段階順を「片付け直前の SHA 確定 → 本文のリンク一覧更新 → 片付け」に（B3）／ 完了検査の代替＝ DoD × 根拠を統括レポートに写す（B4）／ 全体まとめチケットの DoD の型を新設（申し送り #16）／ 別 issue 起票の承認の取り方（#18） |
| 3 | `hooks/00-SessionStart/session-start` | 更新なし | `10_spec/hooks/.../session-start.md` と `フック共通仕様.md` | 注入の整形（6 行・`position` ごとの文言・WF702 / WF703）が 3/3 で実装される旨と、`boundary.sh` のパスがスキル配下であることを明記（食い違い #3） |
| 4 | `20-common-step-ticket`（`ticket.sh`） | 更新なし | `10_spec/skills/20-common-step-ticket.md` | TK005（`overall-summary` の `complete` を必ず拒否）の**代替経路**を明記し、`finalize.sh release` 段階 2 の出力先と対応させる（食い違い #6） |
| 5 | `10-task-ai-asset-implementation-plan` | 同名要件 | `10_spec/skills/10-task-ai-asset-implementation-plan.md` | 申し送り #2〜#9（テスト ID 割付表の機械生成／`build-test` と `hook-test` の両宣言／実装結果レポートは最初のチケットの DoD／記述順と `next` の実行順を揃える／提供コマンド自身を変えるステップの書き方／参照更新一覧の検索語と期待値／期待値が変更対象に依存するテストの許可範囲／値の往復は同じチケット） |
| 6 | `10-task-ai-asset-design-plan` | 同名要件 | `10_spec/skills/10-task-ai-asset-design-plan.md` | 申し送り #10〜#13（候補に実装を伴うなら次は `ai-asset-implementation-plan`／実装と仕様の食い違いは計画で正を決める／台帳チケットは 1 番号 1 原因を確認／次の計画チケットの目的文に件数を書かない） |
| 7 | `10-task-feedback-plan` | 同名要件 | `10_spec/skills/10-task-feedback-plan.md` | 申し送り #1。処理フロー 4 の**書き換え**（ヘッドレスで「報告して終える」→「対応先を決めて起票まで行い note で報告」）。現行と正反対のため追記ではなく置換 |
| 8 | `10-task-ai-asset-design-exec` | 同名要件 | `10_spec/skills/10-task-ai-asset-design-exec.md` | 申し送り #14（実装を正として写すときは実装の該当行を作業ログに）／#15（分割時は各 DoD に「参照先の再読」） |
| 9 | `agents/adversarial-reviewer` | `00_requirement/agents/adversarial-reviewer.md` | `10_spec/agents/adversarial-reviewer.md` | 申し送り #19 の残り（「問題なしと判断した点」と抜き取り検証の一覧を出力に追加）／モデルと `tools` の確定（保留 P4） |
| 10 | `agents/task-executor` | 同名要件 | `10_spec/agents/task-executor.md` | モデルと `tools` の確定（保留 P4）／起動プロンプトにブランチ名を明示する（0009 で判明。サブエージェントはセッション開始時の gitStatus を見るため） |
| 11 | `20-common-step-shell-script` | 同名要件 | `10_spec/skills/20-common-step-shell-script.md` | 申し送り #21（142・143 行に `\"` / `\\` の解除を明記）／#22（1 つのテスト ID を 2 ファイルに置かない。CP-T08 の重複解消）／#23（`run-tests.sh` の対象本数の数え方） |
| 12 | `20-common-step-report-view` | 同名要件 | `10_spec/skills/20-common-step-report-view.md` | 申し送り #24（前提コマンドに awk）／レポート md テンプレートの置き場の決定（保留 P3・申し送り #20）／md と HTML の対応の自己チェック（0010 の反省） |
| 13 | `10-task-investigation-exec` | 同名要件 | `10_spec/skills/10-task-investigation-exec.md` | 食い違い #8。共通手順 4 の「最初のチケットのレポートに追記」を運用実績（1 チケット 1 レポート）に合わせる |
| 14 | `00-workflow-quick-request` | 更新なし | `10_spec/skills/00-workflow-quick-request.md` | 32 行の旧名の引用の扱い（0005 の c4）。A3 と衝突しない書き方に直す |
| 15 | eval ID の接頭辞（横断） | — | `10_spec/skills/20-common-step-spec.md` または各仕様 | 15 本（スクリプトを持たないスキル）の接頭辞を確定。スクリプトを持つ 2 本とエージェント 2 本に eval が要るかを A1 の文言から判断（0003 の a6・設計への反映 #1・#5） |

## 横断整合

| 文書 | 追加・変更する項目 |
|---|---|
| `00_requirement/自己改善ワークフロー機構.md` | 提供コマンドの置き場の原則（提供コマンドはそれを使うスキルの `scripts/` に置く）。フックとの区別 |
| `00_requirement/rules/ルール体系.md` | 変更なしの見込み（設計チケットで確認する） |
| `90_glossary/` | 「提供コマンド」の定義に置き場の原則を含める。「敵対的レビュー」に上限回数の運用を含めるかを判断 |
| `20_ddr/` | 新規 DDR: (a) 提供コマンドの置き場を仕様側に寄せた判断と却下案（食い違い 4 件の解消）／(b) HTML 添付が API で成立しない実測（B2 が DDR を明示的に要求）／(c) `feedback-plan` のヘッドレス方針を正反対に書き換えた判断／(d) 申し送りのうちこの issue で扱わないものと理由（保留 P5） |

## ヘッドレス実行の帰結

| アセット | ヘッドレスでの帰結 | 根拠 |
|---|---|---|
| `10-task-feedback-plan` | **進む**（対応先を決めて起票まで行い note で報告）。現行仕様の「止まる」を書き換える | 申し送り #1（0022 B7） |
| `10-task-overall-summary` | **止まる**。HTML 添付は人間がブラウザで行う必要があり、draft 解除の直前は人間の確認を残す | B2、全体計画の承認ポイント |
| `agents/task-executor` | **進む**。判断が割れたら結果報告に書いて呼び出し元に返す（自分で承認を代行しない） | 全体計画「切れ目で人間の応答を待たない」 |
| `agents/adversarial-reviewer` | **進む**。指摘を確度付きで返すだけで、対応の可否は呼び出し元が決める | `10_spec/agents/adversarial-reviewer.md` |
| `00-workflow-issue-mr-driven`（`boundary.sh`） | **進む**。切れ目コメントは証跡として投稿し、次のタスクへ着手する | 全体計画 2026-09-03 の合意 |
| その他の共通ステップ | 変更なし（既存の帰結を維持） | — |

## 受け入れ条件（候補）との対応

| 条件 | 担う設計チケット | 落ちる先 |
|---|---|---|
| A1（19 本が仕様と 1:1、eval 定義がある） | 0016 | eval ID の接頭辞と対象本数の確定。実体の作成は実装フェーズ |
| A2（`finalize.sh` / `boundary.sh` が仕様どおり動く） | 0011 | 仕様の Script 処理と置き場の確定。BD-T01〜13・FN-T01〜05 は実装フェーズ |
| A3（旧名が DDR 以外で 0 件） | 0016 | `00-workflow-quick-request.md:32` の書き換え方の決定。置換の実施は実装フェーズ |
| A4（申し送りの反映、`fm_get` と `TICKET-T05`） | 0013・0014・0015 | 8 本の仕様書への反映。`fm_get` は仕様 2 行の文言のみ（実装とテストは済み） |
| A5（食い違いを仕様へ書き戻し、経緯を DDR に） | 0011・0012 | 食い違い 8 行のうち仕様側で決着する分。残りはフィードバック計画へ |
| B1・B2・B4 | 0012 | `10-task-overall-summary` 仕様の該当節と DDR |
| B3（段階順） | 0011・0012 | `finalize.sh release` の段階（0011）と手順 5〜9（0012）の両方で整合させる |

## AI アセット設計チケット

| 番号 | 種類 | 内容 | 先行 | 主な文書 |
|---|---|---|---|---|
| 0011 | `ai-asset-design` | 提供コマンド 2 本の置き場を仕様側に確定し、食い違い #1・#2・#3・#6・#7 と B3 の段階順を解消する | — | `00-workflow-issue-mr-driven`・`10-task-overall-summary`（Script 処理）・`session-start`・`20-common-step-ticket`・DDR (a) |
| 0012 | `ai-asset-design` | `10-task-overall-summary` 仕様を追記 B1〜B4 のとおり改訂し、申し送り #16・#17・#18 と食い違い #4・#5 を反映する | 0011 | `10-task-overall-summary` の要件と仕様・DDR (b) |
| 0013 | `ai-asset-design` | 計画系タスクスキル 3 本に申し送り #1〜#13 を反映する（`feedback-plan` は書き換え） | — | `10-task-ai-asset-implementation-plan`・`10-task-ai-asset-design-plan`・`10-task-feedback-plan`・DDR (c) |
| 0014 | `ai-asset-design` | 実施系タスクスキルとエージェント 2 本に申し送り #14・#15・#19 を反映し、モデルと `tools` を確定する（保留 P4） | — | `10-task-ai-asset-design-exec`・`agents/adversarial-reviewer`・`agents/task-executor` |
| 0015 | `ai-asset-design` | 共通ステップ 2 本に申し送り #20〜#24 を反映し、テンプレートの置き場（保留 P3）と食い違い #8 を決める | — | `20-common-step-shell-script`・`20-common-step-report-view`・`10-task-investigation-exec` |
| 0016 | `ai-asset-design` | eval ID の接頭辞と対象本数を確定し、旧名の扱い（c4）・旧資産 4 件の処遇・扱わない申し送り（保留 P5）を DDR に落とす | 0013・0014・0015 | `20-common-step-spec`・`00-workflow-quick-request`・横断文書・`90_glossary/`・DDR (d) |

- 実行者はすべてメインエージェント（全体計画の方針。`task-executor` はこの issue で作る対象）
- 人間レビューは fable の敵対的レビューで代替する。設計フェーズの 2 回は**実施タスクの切れ目**で使う（1 回目 = 0011〜0016 完了時、2 回目 = 指摘対応後）
- やってよいこと: `write` は `.claude/docs/**` と `wip/**`、`ops` は `read` / `remote-read`。アセット本体への書き込みは含めない

### 次の計画チケット

- `0017-ai-asset-implementation-plan`。`predecessors` に 0011〜0016 の全番号を入れる

## 保留した点

| # | 保留した項目 | 決める時期 |
|---|---|---|
| P1' | `session-start.sh` のハードコード 1 行を実装フェーズのどのチケットで直すか（ロックアウトの危険がある中核） | AI アセット実装計画（0017） |
| P2 | `boundary.sh` を作った後、この issue の切れ目で使い始めるか | AI アセット実装計画（据え置き） |
| P6 | フェーズ 4 のチケット分割の粒度 | AI アセット実装計画（据え置き） |
| P7 | 申し送り #23（`run-tests.sh` の対象本数の数え方）の答えが実測に依存する場合、実装フェーズの検証項目に回すか | 0015 |
| P8 | `20-common-step-requirement` の `####` 小節の件（0006 の d6）が本当に未反映か。#8 の進行中の見直しと重なる可能性がある | 0015（確認だけ行い、重なるなら扱わない） |

## 対象なし

なし。すべての材料に反映先がある。
