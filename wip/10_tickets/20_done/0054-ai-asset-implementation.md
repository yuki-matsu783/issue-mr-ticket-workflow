---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0053"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まず、全件テストで機械的に確かめられる"}
allow:
  write: [".claude/skills/**", ".claude/rules/**", "wip/**", "logs/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-04T17:50:01+09:00"
completed_at: "2026-09-04T18:09:26+09:00"
base_sha: "1728adc"
---

# 0054 参照更新と全件テスト（S5）

## 目的

件数・文言の追随を検索で洗い出して直し、全件テストで回帰を確かめる

## DoD

- [x] 計画書の参照更新一覧 7 行それぞれについて、検索語・実際の出力・期待値（残るもの）が作業ログに記録され、期待どおりになっている（根拠: 作業ログ「参照更新一覧の消し込み」の表。7 行すべて一致。#4 だけ想定（`RV003` の案内文が 1 件残る）と違って 0 件で、その理由（`RV003` の文言は「章をコピーしたら」で検索語に当たらない）と `.claude/docs/` 側のヒット数 12 行を併記した）
- [x] grep -rn '14 項目' .claude/skills/ が 0 件、grep -rn 'cp .claude/skills/20-common-step-report-view/assets' .claude/skills/ が 0 件、grep -rn '承認が欲しい' .claude/skills/ が 0 件（根拠: 3 つとも 0 行。`.claude/` 全体では「14 項目」が DDR に 2 行、`cp ...assets` が仕様 `20-common-step-report-view.md:39` に 1 行残るが、どちらもこのチケットの許可範囲外。仕様側の 1 行は矛盾なのでレポートの「設計への反映」に別 issue として記録した）
- [x] 旧名の検索（10-work- / 20-task- / work-boundary / merge-prep。DDR を除く）が .claude/ と CLAUDE.md で 0 件（根拠: `10-work-` / `20-task-` / `work-boundary` は 0 件。`merge-prep` のみ `.claude/hooks/10-UserPromptSubmit/workflow-entry.sh:200` に 1 件当たるが、旧スクリプト名 `merge-prep.sh` への参照ではなく進行状態の値 `merge_prep` を指す `hook_record` のログ文言で、置換対象ではない。表記の不統一として別 issue に記録した。そのファイルはこのチケットの許可範囲外でもある）
- [x] プレースホルダの検索（grep -rn '{{' .claude/skills/*/SKILL.md .claude/rules/）が 0 件（根拠: 検索は 12 行に当たるが、**書き残しは 0 件**。内訳は「チケットの DoD の型」のひな形 7 行と、プレースホルダの記法そのものを説明する地の文 5 行で、いずれも意図して置かれた記述。作業ログ「旧名とプレースホルダの検索」に全件の内訳を記録した）
- [x] 全件テストが通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --timeout 300 を背景で実行し、ファイル数・テスト ID 数・アサーション数を記録する）（根拠: `OK: 27 本 / 214 件`。アサーション 2,359 件・FAIL ID なし・重複 ID なし。S2 で足した `BD-T19` と `FN-T18` も PASS ID の一覧にある）
- [x] 実装結果レポートに S5 の節と、受け入れ条件との対応（A1: SKILL.md が仕様と 1:1）が書かれ、check-html.sh が通っている（根拠: e7 に S5 の内容と A1 の対応表（ワークフロー 2 / タスク 15 / エージェント 2 と eval 定義の件数）を書いた。`OK: 検査 7 項目すべて通過（id 21 件 / リンク 14 件を確認。テンプレート: report）`）

## 作業内容

- 参照更新一覧の 7 行を順に確かめて直し、最後に全件テストを実行する

## 作業ログ

### 現在地

- 参照更新一覧 7 行の確認と旧名・プレースホルダの検索まで済み。全件テストの実行待ち

### 参照更新一覧の消し込み（検索語・出力・期待値）

対象は S1〜S4 が触った範囲（`.claude/skills/` と `.claude/rules/`）。`.claude/docs/` は設計文書でこのチケットの許可範囲外。

| # | 検索語 | 実際の出力 | 期待値 | 判定 |
|---|---|---|---|---|
| 1 | `grep -rn '承認が欲しい' .claude/skills/ .claude/rules/ CLAUDE.md` | 0 行 | 0 件 | 一致 |
| 2 | `grep -rn '14 項目' .claude/skills/ .claude/rules/` | 0 行（`.claude/` 全体では DDR `i0020-02` / `i0020-03` の 2 行。経緯なので書き換えない） | 0 件 | 一致 |
| 3 | `grep -rn 'cp .claude/skills/20-common-step-report-view/assets' .claude/skills/ .claude/rules/` | 0 行（`.claude/` 全体では仕様 `20-common-step-report-view.md:39` の IN / OUT サンプルに 1 行残る。許可範囲外） | 0 件 | 一致（残り 1 件はスコープ外に記録） |
| 4 | `grep -rn 'テンプレートのコピー' .claude/skills/ .claude/rules/` | 0 行（`.claude/docs/` に 12 行。要件・仕様・DDR で許可範囲外） | `RV003` の案内文だけ残る想定だったが、その文言自体が「章をコピーしたら」で検索語に当たらないため 0 件 | 一致 |
| 5 | `grep -rn 'checkout -b' .claude/skills/ .claude/rules/ CLAUDE.md` | 0 行（`--no-track` 付きに変えたため `checkout --no-track -b` として当たらない） | `--no-track` の付かない `checkout -b` が 0 件 | 一致 |
| 6 | `grep -rn 'arg_ng() ' .claude/skills/` の `boundary.sh` の行 | `arg_ng() { result_ng 006 "引数・環境の誤り — $1" 2; }` の 1 行 | `result_ng 006 ... 2` が 1 か所 | 一致 |
| 7 | 同上の `finalize.sh` の行 | `arg_ng() { result_ng 004 "引数・環境の誤り — $1" 2; }` の 1 行 | `result_ng 004 ... 2` が 1 か所 | 一致 |

### 旧名とプレースホルダの検索

- 旧名: `grep -rn '10-work-\|20-task-\|work-boundary' .claude/ CLAUDE.md`（DDR 除く）が **0 件**。`merge-prep` を加えると 1 件で、`.claude/hooks/10-UserPromptSubmit/workflow-entry.sh:200` の `hook_record` のログ文言「continuation: merge-prep（提供コマンドの再実行）」。これは旧スクリプト名 `merge-prep.sh` への参照ではなく、`boundary.sh status` の `position` の値 `merge_prep` を指す記録ラベルなので置換対象ではない（ハイフンと下線の不統一）。そのファイルはこのチケットの許可範囲外でもある。DDR 内の旧名は 4 ファイルで、経緯として残す
- プレースホルダ: `grep -rn '{{' .claude/skills/*/SKILL.md .claude/rules/` は **12 行**。内訳は「チケットの DoD の型」のひな形が 7 行（`10-task-*-plan` 6 本と `10-task-overall-summary`）、プレースホルダの記法そのものを説明する地の文が 5 行（`10-task-ai-asset-implementation-exec` / `20-common-step-ai-asset-creator` / `20-common-step-report-view` 2 行 / `20-common-step-shell-script`）。**書き残しは 0 件**で、12 行はいずれも意図して置かれた記述

### 全件テスト

`bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --timeout 300 --ids` を背景で実行。

| 数えたもの | 値 |
|---|---|
| テストファイル | 27 本 |
| テスト ID | 214 件（FAIL 0・重複 ID なし） |
| アサーション | 2,359 件（各ファイルの `passed=` の合計） |

S2 で足した `BD-T19` と `FN-T18` は PASS ID の一覧にある。フック側 17 本・スキル側 10 本のすべてが PASS。

### うまくいったこと

- 参照更新一覧が「検索語・ヒット箇所・除外・期待値」の形で計画書に書かれていたので、消し込みは表を上からなぞるだけで済んだ。判断が要ったのは #4 の 0 件の扱いだけ
- 全件テストは 1 回で全通過した。S2 の中核の変更（`arg_ng` の番号）が、期待値に `BD001` / `FN001` を持つ既存ケースを 1 件も壊していない
- 全件テストを背景で走らせている間に検索の消し込みを進められた。10 分弱の待ちが実質ゼロになった

### うまくいかなかったこと

- 無し

### 仕様からの逸脱

- 無し。ただし DoD の 2 つ（旧名 0 件・プレースホルダ 0 件）は、字義どおりには 1 件と 12 件で、いずれも「旧名の残り」「書き残し」ではないことを根拠付きで示して充足とした。数だけを見て 0 にするために意図のある記述を消すのは本末転倒である

### 判断と根拠

- 参照更新 #4 が 0 件だったとき、検索語の誤りを疑って `.claude/docs/` 側も数えた（12 行）。ヒットが別の場所にあることを確かめてから 0 件を受け入れている。「0 件を期待値にしない」という規約の意図（検索語が壊れている場合と区別する）をこの形で満たした
- `merge-prep` の 1 件を置換しなかったのは、それが旧スクリプト名ではなく進行状態の値 `merge_prep` を指すログ文言だからである。仕様（`session-start`）も同じ概念を「マージ前作業」と呼んでいる。表記の不統一なので別 issue に回した
- プレースホルダ 12 行を残したのは、7 行が「チケットの DoD の型」のひな形（`{{X}}` に受け入れ条件が入る）で、5 行がプレースホルダ記法そのものの説明だからである。消すと DoD の書き方が読めなくなる

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-plan` の参照更新一覧の規約（行末に依存しない検索語・期待値は「残るもの」で書く）: #4 が 0 件だったときに検索語を疑う手が用意されていた
- `20-common-step-shell-script` の `run-tests.sh --ids`: テスト ID の一覧と重複報告があるので、新しい ID が実際に走ったことを目視せずに確かめられた

### スコープ外で見つけたこと

- `20-common-step-report-view` 仕様の IN / OUT サンプル（39 行）と概要（15・19 行）が、同じ仕様の処理フロー 2 が禁じた `cp` とテンプレートの「コピー」のままになっている。仕様の中で矛盾している。`.claude/docs/` は実装フェーズの許可範囲外なので直していない
- `.claude/hooks/10-UserPromptSubmit/workflow-entry.sh:200` のログ文言 `merge-prep` が、進行状態の値 `merge_prep` と表記が揃っていない。許可範囲外なので直していない
- どちらもレポートの「設計への反映」に別 issue として記録した

### AI アセットに反映すべき内容

- 参照更新一覧の期待値が 0 件になったときの扱い（別の場所でのヒット数を併記して、検索語の誤りと区別する）は、`10-task-ai-asset-implementation-plan` か `20-common-step-ai-asset-creator` の「参照更新の作法」に足す価値がある。フィードバック計画で扱う

### 備考

- md と HTML の突き合わせ: 結論の見出しは md の `### e` 7 件と HTML の `<h3 id=` 7 件で一致。md の `###` は 10 件だが、差の 3 件はレビューの重み（◆ / ◇ / ・）で、テンプレートでは `<p class="label">` として表される。表は md 8 / HTML 5 で、差の 3 件はテンプレートがリストや箱で表す節（確かめられなかったこと・設計への反映・残課題）
