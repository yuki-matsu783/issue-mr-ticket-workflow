---
type: report
title: 0005 調査結果 — 旧名の残存箇所と置換後の期待値
description: 旧名 5 種を DDR・参考ディレクトリ・logs を除いて全件洗い出し、6 ファイル 111 件の残存と 9 種の置換表、置換先の無い旧名 2 種、仕様書に 1 件残る旧名の扱い、0 件を判定できる検索コマンドをまとめた調査結果
tags: [report, investigation, issue-10]
keywords: [旧名, 参照更新, work-boundary.sh, merge-prep.sh, 10-work-, 20-task-gh-, workflow-lib.sh, 置換表, 検索コマンド, 用語集, retrospective]
---

# 0005 調査結果 — 旧名の残存箇所と置換後の期待値

## サマリ

旧名の残存は **6 ファイル・111 件**で、そのすべてが `.claude/skills/00-workflow-*/`（旧ワークフロースキル 2 本の SKILL.md・evals・assets）と `.claude/docs/10_spec/skills/00-workflow-quick-request.md` の 1 行に収まっている。**`CLAUDE.md` と用語集（`.claude/docs/90_glossary/`）は既に新名で書かれており、追加の変更は要らない**（受け入れ条件 A3 が挙げる 3 つのうち 2 つは反映済み）。

置換は 9 種で、うち 7 種は 1:1 の名前の置き換え、2 種は**置換先が無い**（機構から消えた概念）。0 件を判定する検索コマンドは、単純な旧名の grep では `00-workflow-issue-mr-driven` の部分一致を拾ってしまうため、**前置の `00-` を除外する形**にする必要がある。

引っかかるのは 1 件だけ。`.claude/docs/10_spec/skills/00-workflow-quick-request.md` の 32 行目が、移行の説明として旧名 `10-work-ticket-driven` を**意図的に引用**している。受け入れ条件 A3 は「`.claude/docs/` の DDR 以外で 0 件」を求めるので、この行の扱いを決めないと条件を満たせない。

- ◎良 5 件 / △注意 1 件 / ✕問題 1 件

### ◆特に見てほしい（判断に困っている）

- **c4**: 仕様書 `00-workflow-quick-request.md:32` が旧名を意図的に引用している。「引用も 0 件にする（言い換える）」「DDR へ移す」「A3 の判定から仕様書の引用を除外する」のどれを採るか。**A3 の文言をそのまま読むと違反**なので、設計で決めないと受け入れ条件が閉じない

### ◇承認が欲しい（方針は決めた）

- **c3**: 置換先の無い旧名が 2 種ある。`20-task-gh-install`（3 件）は新設計に対応するスキルが無く、`20-common-step-issue` の停止条件「CLI 未導入・未認証は停止」に吸収されるので**記述ごと削除**。`retrospective`（10 件）はタスク種別から消え `feedback-plan` に置き換わっているので**言い換え**が妥当

### ・細かいレビューは不要（ほぼ確実）

- **c1**・**c2**: 残存 6 ファイル 111 件の内訳と 9 種の置換表
- **c5**: 除外条件込みの検索コマンド（そのまま V6 で使える）
- **c6**: 旧名を期待値に持つテストは 1 本も無い（置き場に依存するテスト 4 行は別。0004 の b4）
- **c7**: `CLAUDE.md` と用語集は既に新名

## 確かめられなかったこと（この結果が言っていないこと）

- 置換後の**文章として成立するか**（旧名を新名に置き換えるだけでは、手順の中身が新設計と合わない。SKILL.md 2 本は「改訂」であって「置換」ではない — 0003 の a1 のとおり）
- 旧名 5 種以外の陳腐化（例: 手順の構造そのものが旧いこと）。この観点は名前だけを見ている
- `参考ディレクトリ/agent-workflow` 配下の旧名（gitignore 対象。リポジトリに含まれない）
- `logs/` に残る旧名（ローカル限りで追跡しない。gitignore 対象）
- 置換の実施（実装フェーズ。この報告は対象と期待値まで）

## 実施条件（読んだ対象）

| 対象 | 方法 |
|---|---|
| リポジトリ全体の `*.md` / `*.json` / `*.tsv` / `*.txt` / `*.sh` | `grep -rn` で旧名 5 種を検索し、`参考ディレクトリ/`・`logs/`・`wip/`・`.claude/docs/20_ddr/` を除外 |
| `.claude/docs/90_glossary/スキル名.md`・`ワークフロー用語.md` | 新名で書かれているかの確認 |
| `CLAUDE.md` | 同上 |
| `.claude/hooks/config/entry-skills.txt` | 振り分けスキル名の一覧（新名） |
| `.claude/hooks/*/tests/`・`.claude/skills/*/scripts/tests/` | 期待値が旧名に依存するテストの有無 |
| `.claude/docs/10_spec/skills/20-common-step-issue.md` | `20-task-gh-install` の置換先の有無 |

読み取りのみ。テスト・ビルドは実行していない。

## 実施した内容と結果

### c1. 旧名の残存は 6 ファイル・111 件 ◎良

| ファイル | 件数 | 内訳 |
|---|---|---|
| `.claude/skills/00-workflow-issue-mr-driven/SKILL.md` | 77 | `merge-prep.sh` 20 / `work-boundary.sh` 14 / `20-task-gh-issue` 11 / `20-task-gh-feature` 9 / `10-work-<phase>` 8 / `10-work-overall-plan` 7 / `10-work-ticket-driven` 6 / `20-task-gh-install` 2 |
| `.claude/skills/00-workflow-issue-mr-driven/evals/evals.json` | 25 | `work-boundary.sh` 12 / `merge-prep.sh` 5 / `10-work-ticket-driven` 4 / `10-work-overall-plan` 4 |
| `.claude/skills/00-workflow-quick-request/SKILL.md` | 6 | `20-task-gh-issue` 2 / `20-task-gh-install` 1 / `20-task-ai-asset-creator` 1 / `10-work-ticket-driven` 1 / `10-work-overall-plan` 1 |
| `.claude/skills/00-workflow-issue-mr-driven/assets/issue-notify.template.md` | 1 | `merge-prep.sh` 1 |
| `.claude/skills/00-workflow-quick-request/evals/evals.json` | 1 | `workflow-lib.sh` 1 |
| `.claude/docs/10_spec/skills/00-workflow-quick-request.md` | 1 | `10-work-ticket-driven` 1（c4） |
| 合計 | 111 | — |

`assets/issue-notify.template.md`（1 件）は 0003 の a8 で**削除**の対象なので、ファイルごと無くなる。

**［訂正 — 敵対的レビュー 1 回目の指摘 6］** 初版は `evals/evals.json` 2 本（26 件）も「ファイルごと無くなる」に含めていたが、**誤り**。0003 の a8 の見立ては削除ではなく `.claude/evals/<アセット名>.md` への**移行**で、`20-common-step-ai-asset-creator` 仕様の `eval.template.md` は「`evals.json` の項目を Markdown の表に写す」ものである。写した先は `.md` なので、**旧名は移行先に持ち越され、c5 の検索（`*.md` を含む）に引っかかる**。移行時に書き換えなければ V6 が落ちる。

したがって置換・書き換えが要るのは次のとおり。

| 対象 | 件数 | 扱い |
|---|---|---|
| `00-workflow-issue-mr-driven/SKILL.md` | 77 | 改訂の中で置換 |
| `00-workflow-quick-request/SKILL.md` | 6 | 同上 |
| `10_spec/skills/00-workflow-quick-request.md` | 1 | c4 の判断による |
| `00-workflow-issue-mr-driven/evals/evals.json` → `.claude/evals/00-workflow-issue-mr-driven.md` | 25 | **移行時に書き換える**（旧名を持ち越さない） |
| `00-workflow-quick-request/evals/evals.json` → `.claude/evals/00-workflow-quick-request.md` | 1 | 同上 |
| `00-workflow-issue-mr-driven/assets/issue-notify.template.md` | 1 | ファイルごと削除 |
| 合計 | 111 | — |

なお `evals/evals.json` には旧名 5 種の外に `retrospective` が 4 件ある（c3 の 6 件は SKILL.md だけを数えたもの）。移行先でも同じ言い換えが要る。

### c2. 置換は 9 種。うち 7 種は 1:1 の名前の置き換え ◎良

| 旧名 | 新名 | 件数 | 根拠 |
|---|---|---|---|
| `work-boundary.sh` | `boundary.sh` | 26 | `00-workflow-issue-mr-driven` 仕様 Script 処理 |
| `merge-prep.sh` | `finalize.sh` | 26 | `10-task-overall-summary` 仕様 Script 処理 |
| `10-work-overall-plan` | `10-task-overall-plan` | 12 | `task-types.tsv` のスキル名列 |
| `10-work-<phase>-plan` / `10-work-<phase>-exec` | `10-task-<phase>-plan` / `10-task-<phase>-exec` | 8 | 同上 |
| `20-task-gh-issue` | `20-common-step-issue` | 13 | `.claude/skills/` の現物と仕様 |
| `20-task-gh-feature` | `20-common-step-feature-mr` | 9 | 同上 |
| `20-task-ai-asset-creator` | `20-common-step-ai-asset-creator` | 1 | 同上 |
| `workflow-lib.sh` | `.claude/hooks/lib/` の 5 本（`hook-common.sh` ほか） | 1 | 実装済みの現物。1:1 ではないので文脈に応じて書き換える |
| `10-work-ticket-driven` | 分割先が複数 | 12 | 下記 |

この表の合計は 108 件。残る 3 件は `20-task-gh-install` で、置換先が無いため c3 で扱う（108 + 3 = 111）。

`10-work-ticket-driven` は 1 つのスキルが複数に分かれたため、**行ごとに参照先が変わる**。

- チケット操作（着手・完了・境界判定）→ `20-common-step-ticket` と `boundary.sh`
- 計画タスクの共通手順 → `10-task-investigation-plan`（正）
- 実施タスクの共通手順 → `10-task-investigation-exec`（正）
- 振り返り（`retrospective`）→ `10-task-feedback-plan`（c3）

### c3. 置換先の無い旧名が 2 種ある △注意

| 旧名 | 件数 | 状況 | 見立て |
|---|---|---|---|
| `20-task-gh-install` | 3 | 新設計に対応するスキルが無い。`20-common-step-issue` 仕様の停止条件は「CLI 未導入・未認証 → 停止」とだけ定め、導入を案内するスキルを持たない | **記述ごと削除**し、「CLI 未導入・未認証は停止して案内する」に書き換える |
| `retrospective`（チケット type） | **10** | `task-types.tsv` の 15 種に存在しない。用語集は「フィードバック計画: 実装より後に置く振り返りのタスク」と定義しており、概念は `feedback-plan` に吸収された。内訳は `00-workflow-issue-mr-driven/SKILL.md` 6 件（53・121・202 行に各 2）と同 `evals/evals.json` 4 件（43・45・104・106 行）。初版は SKILL.md だけを数えて 6 件としていた（敵対的レビュー 2 回目の指摘 7 による訂正） | **`feedback-plan` に言い換える**。「振り返り」という日本語は用語集が使い続けているので、語としては残してよい。`evals.json` の 4 件は移行先の `.md` で言い換える |

どちらも旧名 5 種の検索には引っかからないが、SKILL.md の改訂では必ず触ることになる。**改訂の抜けを防ぐため、置換一覧に含めておく**。

### c4. 仕様書に旧名が 1 件残っており、A3 の文言と衝突する ✕問題

`.claude/docs/10_spec/skills/00-workflow-quick-request.md` の 32 行目:

> 現行アセットとの差分で実装時に追従が要る箇所: …… / 旧 SKILL.md エラーハンドリングの旧スキル名（`10-work-ticket-driven` 等）。AI アセット実装計画の参照更新一覧に載せる

これは**移行の指示として旧名を引用している**行で、誤記ではない。しかし受け入れ条件 A3 は「旧名が `.claude/docs/` の DDR 以外で 0 件」を求めており、文言どおりなら違反になる。

| 案 | 内容 | 影響 |
|---|---|---|
| (a) 引用も 0 件にする | 「旧 SKILL.md のエラーハンドリングに残る旧スキル名」と、名前を出さずに書き換える | 仕様の情報量が少し落ちる（どの名前かは参照更新一覧を見ればよい） |
| (b) DDR へ移す | 移行の経緯として DDR に書き、仕様からは消す | 経緯は DDR という原則に合う。仕様の当該行は削除 |
| (c) A3 の判定から仕様書の引用を除外する | 検索コマンドに除外条件を足す | 除外条件が増えるほど「0 件」の意味が弱くなる |

**(b) が原則（経緯は DDR、仕様は現在の正史）に最も合う**。ただしこの行は「実装時に追従が要る箇所」という**これからの作業の指示**でもあるので、実装が終われば役目を終える。実装後に削除する形（(a) と (b) の折衷）も成立する。決定は 0007。

### c5. 0 件を判定する検索コマンドは、前置の `00-` を除外する形にする ◎良

単純に `grep -r "workflow-issue-mr-driven"` とすると、**新名 `00-workflow-issue-mr-driven` の部分一致を全部拾う**（実測で 100 件超の偽陽性）。旧名だけを数えるには、前に `0` `9` `-` が来ないことを条件にする。

```
grep -rnoE "(^|[^0-9-])(workflow-issue-mr-driven|workflow-quick-request)|20-task-ai-asset-creator|20-task-gh-[a-z]*|10-work-[a-z-]*|work-boundary\.sh|merge-prep\.sh|workflow-lib\.sh" \
  --include='*.md' --include='*.json' --include='*.tsv' --include='*.txt' --include='*.sh' . \
  | grep -v '^\./参考ディレクトリ/' | grep -v '^\./logs/' | grep -v '^\./wip/' | grep -v '^\./\.claude/docs/20_ddr/'
```

**［訂正 — 敵対的レビュー 1 回目の指摘 14］** 初版は前置を `[^0-9-]` の 1 文字必須で書いていたため、**行頭から始まる旧名を拾えなかった**。`(^|[^0-9-])` に直した。現状は該当が無いので実害は出ていないが、V6 でそのまま使う前提なので直しておく。

**期待値は「残るもの」で書く**（申し送り 0038）:

- 上のコマンドの出力が空であること
- `.claude/skills/` 配下のスキルディレクトリが **26 個**であること（`ls -d .claude/skills/*/ | wc -l` が 26）。内訳は現在の 11 個（`00-workflow-*` 2 + `20-common-step-*` 9）+ 新規のタスクスキル 15 本
- `.claude/hooks/config/entry-skills.txt` の非コメント行が `00-workflow-quick-request` と `00-workflow-issue-mr-driven` の 2 行であること

**［訂正 — 敵対的レビュー 1 回目の指摘 1］** 初版は「17 個」と書いていた。これは `15 + 2` の計算で、既存の `20-common-step-*` 9 本を数え落としている。実測（`ls -d .claude/skills/*/ | wc -l`）は現在 11 で、完了時は 26。**17 のまま実装チケットの DoD に貼ると、正しく実装しても V6 が落ちる**。

行末に依存する検索語（`work-boundary.sh$` のような形）は使っていない。

### c6. 旧名を期待値に持つテストは 1 本も無い（ただし置き場に依存するテストは 4 行ある） ◎良

スキル名を含むテストは 2 本あるが、いずれも**新名**を期待値にしている。

| テスト | 参照している名前 | 影響 |
|---|---|---|
| `.claude/hooks/10-UserPromptSubmit/tests/test_workflow_entry.sh` | `00-workflow-quick-request` / `00-workflow-issue-mr-driven`（`entry-skills.txt` の内容） | 無し（新名は変わらない） |
| `.claude/hooks/lib/tests/test_hook_common.sh` | 同上 | 無し |

旧名 5 種を期待値に持つテストは無い。**参照更新でテストが赤くなることはない**（申し送り 0038 の「期待値が変更対象に依存するテストを同じチケットの許可範囲に入れる」は、このケースでは対象なし）。

**［追記 — 敵対的レビュー 1 回目の指摘 7］** ただしこれは**旧名 5 種だけを見た結論**である。旧名とは別に、**保留 P1（提供コマンドの置き場）に依存するテストが 4 行ある**（`test_workflow_entry.sh:143, 144` と `test_workflow_state_guard.sh:117, 118` が `bash .claude/hooks/finalize.sh release` などを入力にしている。詳細は 0004 の b4）。置き場を `skills/*/scripts/` に決めるなら、この 4 行も同じチケットの許可範囲に入れる必要がある。**旧名の観点（0005）と置き場の観点（0004）の隙間に落ちていた**。

### c7. `CLAUDE.md` と用語集は既に新名で書かれている ◎良

受け入れ条件 A3 は「`CLAUDE.md`・旧 SKILL.md・用語集の参照更新」を挙げるが、実測では **`CLAUDE.md` と `.claude/docs/90_glossary/` に旧名は 1 件も無い**。

- `CLAUDE.md`「スキルの3層構造」は `00-workflow-*` / `10-task-*` / `20-common-step-*` の 3 層で書かれている
- `.claude/docs/90_glossary/スキル名.md` はタスクスキル 15 本を新名で列挙している
- `.claude/docs/90_glossary/ワークフロー用語.md` は「フィードバック計画」を定義しており、`retrospective` は使っていない

**A3 で実際に手を入れるのは「旧 SKILL.md」だけ**（と c4 の仕様書 1 行）。

## 検証の結果

| 検証 | 結果 |
|---|---|
| 旧名 5 種の全件検索（除外条件込み） | 6 ファイル・111 件。c1 の表のとおり |
| 単純検索との差 | 前置 `00-` を除外しないと 100 件超の偽陽性（新名の部分一致） |
| `CLAUDE.md` / 用語集の旧名 | 0 件 |
| 旧名を期待値に持つテスト | 0 本 |
| `20-task-gh-install` の置換先 | 無し（`20-common-step-issue` の停止条件に吸収） |
| `retrospective` の置換先 | `feedback-plan`（`task-types.tsv` の 15 種に `retrospective` は無い） |

## 設計への反映

| # | 設計で決めること | 効く受け入れ条件・保留 |
|---|---|---|
| 1 | `00-workflow-quick-request.md:32` の旧名の引用の扱い（c4 の案 a / b / c） | A3 |
| 2 | `10-work-ticket-driven` の 12 件を行ごとにどこへ振り分けるか（c2 の 4 分割。行ごとの一覧は下記「付録: 置換対象の行単位の一覧」） | A3 |
| 3 | `20-task-gh-install` を削除して「停止して案内する」に書き換える文言 | A3 |
| 4 | `retrospective` を `feedback-plan` に言い換える範囲（日本語の「振り返り」は残すか） | A3 |
| 5 | A3 の判定に使う検索コマンドを仕様のどこに置くか（実装チケットの DoD に貼るか、`20-common-step-ai-asset-creator` の参照更新の作法に置くか） | A3、申し送り 0038 |

## 付録: 置換対象の行単位の一覧

計画書 0002「成果物の形 C」が求める「ファイル:行 / 旧名 / 置換後の候補」の形（敵対的レビュー 1 回目の指摘 8 による追加）。

**1:1 の置換で済む 7 種（95 件）は行単位の一覧を作らない**。置換後の名前が文脈によらず決まるため、`sed` 相当の一括置換で足り、行番号は実装時の `grep` で足りる（c2 の表がその対応表）。行ごとに参照先が変わるものだけを列挙する。

内訳は 95（1:1）+ 12（`10-work-ticket-driven`）+ 3（`20-task-gh-install`。置換先なし。c3）+ **1（`workflow-lib.sh`）** = 111。`workflow-lib.sh` は c2 が「1:1 ではないので文脈に応じて書き換える」と分類しているので、下表に含める（初版は「7 種 96 件」と数えてこの 1 件をどの一覧にも載せていなかった — 敵対的レビュー 2 回目の指摘 2 による訂正）。

| # | ファイル:行 | 文脈 | 置換後の候補 |
|---|---|---|---|
| 1 | `00-workflow-issue-mr-driven/SKILL.md:53` | 役割分担表の行「チケット運用の仕組み（着手・完了・境界判定・フックのブロック時の対処）」 | 3 つに割れる: チケット操作 → `20-common-step-ticket` / 境界判定 → `boundary.sh` / 共通手順 → `10-task-investigation-plan`・`10-task-investigation-exec`（正） |
| 2・3 | `00-workflow-issue-mr-driven/SKILL.md:121`（2 件） | 「`10-work-ticket-driven` の retrospective チケットの振り返り合意」 | `10-task-feedback-plan`（`retrospective` の言い換えも同時。c3） |
| 4 | `00-workflow-issue-mr-driven/SKILL.md:202` | 手順 5-1「`todo_head_type` から次のスキルを選び」 | `boundary.sh status` の `next.skill`（type → スキル名の解決は `ticket.sh next` に一本化された） |
| 5 | `00-workflow-issue-mr-driven/SKILL.md:209` | 手順 5-8「`10-work-ticket-driven` 手順 2 の要領で同じ type の追加チケット」 | `20-common-step-ticket`（`create`）+ 計画タスクの共通手順（`10-task-investigation-plan`） |
| 6 | `00-workflow-issue-mr-driven/SKILL.md:217` | 完了処理の導入文（`merge-prep.sh` と同じ行） | `10-task-overall-summary` と `finalize.sh release` |
| 7 | `00-workflow-issue-mr-driven/evals/evals.json:7` | eval の期待出力の文中 | 移行時に新名へ（`10-task-overall-plan` 系） |
| 8 | 同上 `:21` | 同上 | 同上 |
| 9 | 同上 `:33` | 同上 | 同上 |
| 10 | 同上 `:140` | 「手順 1 でチケット全件を作るのではなく」 | `10-task-overall-plan`（全件を作らない規則はそちらへ移った） |
| 11 | `00-workflow-quick-request/SKILL.md:51` | 「チケット駆動ワークフローの作業中。`10-work-ticket-driven` の再開が正しいか確認」 | `00-workflow-issue-mr-driven`（手順 0 の再開判定） |
| 12 | `10_spec/skills/00-workflow-quick-request.md:32` | 移行の指示としての引用 | c4 の判断による（(a) 名前を出さない / (b) DDR へ / (c) 除外） |
| 13 | `00-workflow-quick-request/evals/evals.json:21` | eval の期待出力「`.claude/hooks/workflow-lib.sh` の判定順序を読んで説明する」 | `.claude/hooks/lib/` の 5 本（`hook-common.sh` / `cmdpos.sh` / `scope.sh` / `push-detect.sh` / `transcript.sh`）。判定順序を読む対象としては `scope.sh` と `cmdpos.sh`。移行時に書き換える |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| `CLAUDE.md` と用語集にも旧名が残っている | どちらも 0 件。既に新名で書かれていた | c7 として記録し、A3 で手を入れるのは旧 SKILL.md だけと確定させた |
| 旧名 5 種を数えれば足りる | `20-task-ai-asset-creator` と `retrospective` という、5 種に含まれない旧名があった | c2・c3 に加えて 9 種の置換表にした |
| 単純な grep で 0 件を判定できる | 新名 `00-workflow-issue-mr-driven` の部分一致で偽陽性が大量に出る | c5 で前置除外の検索コマンドを用意した |
| 参照更新でテストが赤くなる | 旧名を期待値に持つテストは 0 本 | c6 として記録した |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | SKILL.md 2 本は「置換」ではなく「改訂」であり、旧名を新名に置き換えるだけでは手順が新設計と合わない。改訂の範囲は 0003 の a1・a9 と合わせて設計で決める | 設計（0007） |
| R2 | 旧名 5 種以外の陳腐化（手順の構造そのもの）は見ていない。改訂の過程で出てくる想定 | 実装フェーズ（逸脱として作業ログへ） |
| R3 | c5 の検索コマンドは `--include` で拡張子を絞っている。拡張子の無いファイル（例: `.gitignore`）に旧名が入った場合は拾えない | 設計（検索の網羅性をどこまで求めるか） |
