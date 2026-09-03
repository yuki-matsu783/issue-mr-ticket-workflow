---
type: plan
title: 0017 AI アセット実装・テスト計画 — 作成物 57 件・テスト 33 件・旧名 111 件の割り付け
description: issue #10 の実装フェーズの計画。作成物 57 件を 9 枚の実装チケットに割り付け、テスト ID 218 件のうちこの issue で足す 33 件を各ステップに配し、旧名 111 件の参照更新と 0 件判定の検索を決め、中核 3 か所（session-start.sh・workflow-state-guard.sh・提供コマンド 2 本）のロックアウト対策を付ける
tags: [plan, ai-asset-implementation, issue-10]
keywords: [実装計画, 作成物 57 件, boundary.sh, finalize.sh, テスト ID, 参照更新, 旧名, ロックアウト対策, 許可範囲, eval, 設計差し戻し]
---

# 0017 AI アセット実装・テスト計画 — 作成物 57 件・テスト 33 件・旧名 111 件の割り付け

## 対象

- 対象 issue: [#10](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/10)
- MR: [#35](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/35)（draft）
- 根拠とする正史: `.claude/docs/00_requirement/` と `10_spec/` の 19 アセット分（設計フェーズ 0011〜0016・0021・0019・0020・0022 で改訂済み）、`フック共通仕様`、DDR `i0010-01`〜`i0010-05`
- 入力の調査結果: 0003（作成物の全件）・0004（提供コマンド 2 本と実装済みフックの食い違い）・0005（旧名の残存と検索）・0006（申し送りとテスト ID）・0011（設計結果）

## 設計への差し戻し（実装より先に閉じる）

**19 アセットの仕様書に「テスト観点」節（eval ID の表）が 1 つも無い。** 受け入れ条件 A1（eval 定義 19 件）に直接効く欠落で、実装計画で埋めてよいものではない（`10-task-ai-asset-implementation-plan` 仕様の例外 1「仕様書にテスト ID が無い場合は実装チケットを起こさず、不足を結果報告に書いて設計の追加チケットを起こす提案を返す」）。

| 事実 | 実測 |
|---|---|
| eval 節を持つ仕様書 | 5 本（`20-common-step-` の ai-asset-creator / feature-mr / issue / requirement / spec） |
| eval 節を持たない 19 アセット | `00-workflow-*` 2 本・`10-task-*` 15 本・`agents/*` 2 本の**全件** |
| 登録済みの eval ID 接頭辞 | 19 種（`フック共通仕様` §6。0016 で確定） |
| 実体としての eval ID | **0 件**（接頭辞だけが台帳にあり、`<接頭辞>-E<2 桁>` の表が無い） |

接頭辞は決まっているので、残るのは各仕様書に表を書くことだけ。**設計の追加チケット 0023 を実装チケット群の先頭に置く**（実装チケットを起こさない選択は採らない。欠けているのは 19 節だけで、機械テストの ID 198 件は揃っており、フェーズ全体を止める理由にならない）。

## 変更対象

0003 の a1 が数えた 55 件に、設計フェーズで加わった 2 件（レポート・計画書の md 共通テンプレート。残課題 R6）を足した **57 件**。`summary-section.template.md` は `attachment-comment.template.md` の置き換えなので増減しない（残課題 R4）。

| 種類 | 件数 | 新規 / 改訂 / 移行 | 割り付け |
|---|---|---|---|
| `assets/` のテンプレート実体 | 13 | 全件新規 | S1（0024） |
| md の共通テンプレート | 2 | 全件新規（R6） | S1（0024） |
| 提供コマンド `boundary.sh` | 1 | 新規 | S2（0025） |
| 同テスト | 1 | 新規 | S2（0025） |
| 提供コマンド `finalize.sh` | 1 | 新規 | S3（0026） |
| 同テスト | 1 | 新規 | S3（0026） |
| SKILL.md（タスクスキル） | 15 | 全件新規 | S6（0029） |
| エージェント定義 | 2 | 全件新規 | S6（0029） |
| SKILL.md（ワークフロースキル） | 2 | 全件改訂 | S7（0030） |
| eval 定義 | 19 | 新規 17 / 移行 2 | S8（0031） |
| 合計 | **57** | — | — |

57 件に含まれないが、この issue の実装に入るもの（0003 の a1 の注記）:

| 対象 | 内容 | 割り付け |
|---|---|---|
| `session-start.sh:64` | `boundary.sh` のパスを新しい置き場へ（中核） | S4（0027） |
| `workflow-state-guard.sh:40, 43` | 案内文の 2 行（中核） | S4（0027） |
| テスト 4 行 | `test_workflow_entry.sh:143, 144` / `test_workflow_state_guard.sh:117, 118`（期待値が置き場に依存） | S4（0027） |
| `session-start` の注入整形 | SE-T05・SE-T06 の**前半**の実装（ID は既に PASS 一覧にあるが実装が残る） | S4（0027） |
| `check-html.sh` の `RV009` | `awk` 不在の検査（DDR `i0010-05`） | S5（0028） |
| `test_push.sh` の `CP-T08` | `CP-T11` へ振り直し（1 ID を 2 ファイルに置かない） | S5（0028） |
| 旧資産 5 件 | 削除 2・移設 1・移行 2（DDR `i0010-04`） | S8（0031） |

## ステップ

固定順（設定・定義 → 中核 → 中核のテスト → スキル・ルール・エージェント → 参照更新）に並べた。**計画書のこの並びとチケットの実行順（`ticket.sh next` が返す順）を一致させる**ため、連番は実行順に振ってある。

| # | ステップ | チケット | 種類 | 先行 | 中核 |
|---|---|---|---|---|---|
| S0 | 19 アセットの仕様書に eval ID の表を書く（設計の差し戻し） | 0023 | `ai-asset-design` | 0017 | — |
| S1 | 設定・定義: テンプレート実体 15 件 | 0024 | `ai-asset-implementation` | 0023 | — |
| S2 | 中核: `boundary.sh` とそのテスト（BD-T01〜13） | 0025 | 同上 | 0024 | **要** |
| S3 | 中核: `finalize.sh` とそのテスト（FN-T01〜09）・完了検査の共有 | 0026 | 同上 | 0025 | **要** |
| S4 | 中核: フック 3 行の追随とテスト 4 行・`session-start` の注入（SE-T01〜10・WE-T10） | 0027 | 同上 | 0026 | **要** |
| S5 | `check-html.sh` の RV009（RV-T08）と CP-T08 の振り直し（CP-T11） | 0028 | 同上 | 0027 | — |
| S6 | スキル・エージェント: タスクスキル 15 本 + エージェント 2 本 | 0029 | 同上 | 0028 | — |
| S7 | ワークフロースキル 2 本の SKILL.md 改訂（旧名 83 件） | 0030 | 同上 | 0029 | — |
| S8 | eval 定義 19 件と旧資産 5 件の処遇（旧名 26 件） | 0031 | 同上 | 0030 | — |
| S9 | 参照更新の総仕上げと 0 件判定 | 0032 | 同上 | 0031 | — |
| — | 次の計画チケット（フィードバック計画） | 0033 | `feedback-plan` | 0024〜0032 | — |

**S2 と S3 を分けた理由**: どちらも提供コマンド 1 本 + そのテストで、`boundary.sh` は 5 サブコマンド 13 テスト、`finalize.sh` は 1 サブコマンド 8 段階 9 テスト。1 枚にすると 1 チケットの差分が大きくなりすぎ、失敗時に戻す範囲が広がる。中核の変更は「小さく変えて都度テストする」（要件の制約）。

**S4 を S2・S3 の後に置いた理由**: `session-start.sh` と `workflow-entry` のテスト 8 件は `boundary.sh status --offline` に依存する（0006 の e5）。`boundary.sh` が無い状態では「本物と一致するか」という観点が成立しない。

### S2・S3 は提供コマンド自身を作るステップ

`boundary.sh` と `finalize.sh` は**この機構が自分の作業に使う提供コマンド**なので、書いた直後の 1 回目が壊れているとそのチケットを終わらせる手段が無くなる。両ステップの手順に次を明示する（申し送り 0031）。

1. スクリプトを書く
2. **`bash .claude/skills/20-common-step-commit-push/scripts/commit.sh` で自分をコミットする**（この 1 回目が `commit.sh` 側の検証を兼ねる。`boundary.sh` / `finalize.sh` 自身はまだ手順に組み込まない）
3. テストを書いて `run-tests.sh --filter` で対象だけ実行する
4. `bash .claude/skills/20-common-step-ticket/scripts/ticket.sh complete <番号>`
5. **失敗したら `git reset --hard <base_sha>` で戻す**（`base_sha` はチケットの frontmatter に機構が記録している）

**この issue の切れ目で `boundary.sh` を使い始めない**（全体計画の保留 P2 の判断）。理由は 2 つ。作りかけのコマンドに自分の進行を依存させると、失敗の原因が「実装の欠陥」か「運用の誤り」か切り分けられない（全体計画の ※1 と同じ判断）。もう 1 つは、`boundary.sh` が読む `logs/review-state.json` はこの issue では一度も書かれておらず、切れ目の記録は MR コメントに直接投稿してきたため、途中から経路を変えると証跡が 2 系統に割れる。**実運用は次の issue から**始める。

## 許可範囲案

ステップごとに最小。ただし次の 3 つは「最小」より優先する（`10-task-ai-asset-implementation-plan` 仕様）。テストを走らせるチケットは `build-test` と `hook-test` を**両方**宣言する。依存するテストファイルと、値の往復の両側は同じチケットに入れる。

| チケット | `allow.write` | `allow.ops` |
|---|---|---|
| 0023 | `.claude/docs/**`, `wip/**` | `read`, `remote-read` |
| 0024 | `.claude/skills/**`, `wip/**` | `read`, `remote-read` |
| 0025 | `.claude/skills/00-workflow-issue-mr-driven/**`, `logs/**`, `wip/**` | `read`, `build-test`, `hook-test`, `remote-read` |
| 0026 | `.claude/skills/10-task-overall-summary/**`, `.claude/skills/20-common-step-ticket/**`, `logs/**`, `wip/**` | `read`, `build-test`, `hook-test`, `remote-read` |
| 0027 | `.claude/hooks/**`, `logs/**`, `wip/**` | `read`, `build-test`, `hook-test`, `remote-read` |
| 0028 | `.claude/skills/20-common-step-report-view/**`, `.claude/skills/20-common-step-commit-push/**`, `logs/**`, `wip/**` | `read`, `build-test`, `hook-test`, `remote-read` |
| 0029 | `.claude/skills/**`, `.claude/agents/**`, `wip/**` | `read`, `remote-read` |
| 0030 | `.claude/skills/00-workflow-issue-mr-driven/**`, `.claude/skills/00-workflow-quick-request/**`, `wip/**` | `read`, `remote-read` |
| 0031 | `.claude/evals/**`, `.claude/skills/**`, `.claude/rules/**`, `wip/**` | `read`, `remote-read` |
| 0032 | `.claude/**`, `wip/**` | `read`, `build-test`, `hook-test`, `remote-read` |

**0026 が `20-common-step-ticket/**` も持つ理由（値の往復）**: `finalize.sh` の段階 2 は完了検査を `ticket.sh` の共通関数 `ticket_check_completion` として source する（`20-common-step-ticket` 仕様）。切り出す側（`ticket.sh`）と使う側（`finalize.sh`）の両方に手が入り、両者の往復を確かめるテストも同じチケットに要る。片側だけを直すと、もう一方が古い形を期待して壊れる。

**0027 が `.claude/hooks/**` を丸ごと持つ理由（依存するテスト）**: `session-start.sh` のパスを変えると、期待値にそのパスを持つテスト 4 行（`test_workflow_entry.sh:143, 144` / `test_workflow_state_guard.sh:117, 118`）が赤くなる。実装とテストを同じチケットに閉じる（申し送り 0038）。

**0028 が `20-common-step-commit-push/**` も持つ理由**: `CP-T08` の振り直しは `test_push.sh` 側を触る。`check-html.sh` の `RV009` とは別の変更だが、どちらも「既存の提供コマンドの小さな修正 + テスト」で、分けると 2 枚とも数行のチケットになる。

**0032 が `.claude/**` を持つ理由**: 参照更新の総仕上げで、旧名がどこに残っているかは検索の結果で決まる。事前に対象を絞れない。ただし書き込みは「旧名を新名に置き換える」ことに限り、振る舞いを変える変更は行わない（DoD で担保する）。

## テスト方針

### 抜き出しと突合

```
grep -rhoE "[A-Z]{2,6}-[TE][0-9]{2}[a-z]?" .claude/docs/10_spec/ | sort -u
```

この正規表現は `run-tests.sh` が `PASS` / `FAIL` 行から ID を抽出する形（`^(PASS|FAIL) ([A-Z]{2,6}-[TE][0-9]{2}[a-z]?)`）と同じにしてある（`20-common-step-shell-script` 仕様）。

| 区分 | 件数 |
|---|---|
| 抜き出しの出力 | 220 |
| うち仕様書の IN / OUT サンプルに書かれた**例示**（`WD-T06`・`AS-E01`。実在の観点ではない） | 2 |
| 実在する ID | **218** |
| 内訳: 機械テスト（`-T`） | 198 |
| 内訳: eval（`-E`） | 20（既存 5 仕様のぶん。19 アセットぶんは 0023 が足す） |

**割付表の行数は 218 で、抜き出しの結果と一致する**（例示 2 件を除いた数）。

### この issue で足す機械テスト 33 件

現在通っているのは 165 件（0006 の e1 の実測）。完了時は 198 件。

| 出どころ | テスト ID | 件数 | ステップ |
|---|---|---|---|
| `boundary.sh` | BD-T01〜BD-T13 | 13 | S2（0025） |
| `finalize.sh` | FN-T01〜FN-T09 | 9 | S3（0026） |
| `session-start` | SE-T01〜04・SE-T07〜10 | 8 | S4（0027） |
| `workflow-entry` | WE-T10 | 1 | S4（0027） |
| `check-html.sh` | RV-T08 | 1 | S5（0028） |
| `push.sh` | CP-T11 | 1 | S5（0028） |
| 合計 | — | **33** | — |

165 + 33 = **198**。

**ID 数に現れないが実装が残るもの**: `SE-T05`・`SE-T06` の**前半**。仕様は両方とも「前半は 3/3 へ」と定めるが、issue #9 は後半だけを実装したため ID は PASS 一覧に載っている（0006 の e5）。S4（0027）の DoD に「前半の観点が実装され、テストの本文が両方の観点を踏む」を明示する。

### eval 19 件

0023 が仕様書に表を書き、S8（0031）が `.claude/evals/<アセット名>.md` に定義を作る。**定義までで実行はしない**（DDR `i0001-20`）。既存 9 本（`20-common-step-*` 5 本・ルール 4 本）と合わせて 28 本になる。

### 実行方法

```
bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '<対象>'   # ステップごと
bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids               # 全件と ID の突合
```

全件実行は 10 分前後かかる（既定のタイムアウトは 1 本あたり 120 秒で、全件の合計ではない）。**2 本同時に走らせない**（無関係なテストまで TIMEOUT する）。各ステップは `--filter` で対象だけを回し、`--ids` の全件突合は S9（0032）で 1 回行う。

## 参照更新の一覧

旧名は **6 ファイル・111 件**（0005 の c1）。検索語は行末に依存しない形で書き、**期待値は「残るもの」で書く**（申し送り 0038）。

| 旧名 | 新名 | 件数 | 入れるステップ |
|---|---|---|---|
| `work-boundary.sh` | `boundary.sh` | 26 | S7（14）・S8（12） |
| `merge-prep.sh` | `finalize.sh` | 26 | S7（20）・S8（5）・S8 の削除（1） |
| `10-work-overall-plan` | `10-task-overall-plan` | 12 | S7（8）・S8（4） |
| `10-work-<phase>-plan` / `-exec` | `10-task-<phase>-plan` / `-exec` | 8 | S7 |
| `20-task-gh-issue` | `20-common-step-issue` | 13 | S7 |
| `20-task-gh-feature` | `20-common-step-feature-mr` | 9 | S7 |
| `20-task-ai-asset-creator` | `20-common-step-ai-asset-creator` | 1 | S7 |
| `workflow-lib.sh` | `.claude/hooks/lib/` の 5 本 | 1 | S8（文脈に応じて書き換える。1:1 ではない） |
| `10-work-ticket-driven` | 行ごとに参照先が変わる | 12 | S7（6）・S8（4）・S9（仕様書の 1 件） |
| `20-task-gh-install` | **置換先なし**（機構から消えた） | 3 | S7（文を落とす） |
| `retrospective` | `10-task-feedback-plan` の振り返り | 10 | S7（6）・S8（4） |
| 合計 | — | **111** | — |

### 0 件を判定する検索

```
grep -rnoE "(^|[^0-9-])(workflow-issue-mr-driven|workflow-quick-request)|20-task-ai-asset-creator|20-task-gh-[a-z]*|10-work-[a-z-]*|work-boundary\.sh|merge-prep\.sh|workflow-lib\.sh" \
  --include='*.md' --include='*.json' --include='*.tsv' --include='*.txt' --include='*.sh' . \
  | grep -v '^\./参考ディレクトリ/' | grep -v '^\./logs/' | grep -v '^\./wip/' | grep -v '^\./\.claude/docs/20_ddr/'
```

前置を `(^|[^0-9-])` にしてあるのは、新名 `00-workflow-issue-mr-driven` の部分一致（実測で 100 件超の偽陽性）を避けつつ、行頭から始まる旧名も拾うため。

**期待値（残るもので書く）**:

| 検査 | 期待値 |
|---|---|
| 上の検索の出力 | 空 |
| `.claude/docs/20_ddr/` の旧名 | 経緯の記録として**残る**（除外している） |
| `.claude/docs/90_glossary/` の別名・禁止表記 | 旧称が別名として**残る**（除外していないので、ヒットしたら禁止表記の欄かを目視で確かめる） |
| `ls -d .claude/skills/*/ \| wc -l` | **26**（現在 11 = `00-workflow-*` 2 + `20-common-step-*` 9、新規のタスクスキル 15） |
| `.claude/hooks/config/entry-skills.txt` の非コメント行 | `00-workflow-quick-request` と `00-workflow-issue-mr-driven` の 2 行 |
| `.claude/evals/` のファイル数 | **28**（既存 9 + 新規 19） |

0 件だけを期待値にしないのは、検索語が間違っていて何もヒットしない場合と区別が付かないため。スキルディレクトリ数と eval のファイル数が「残るもの」の側の担保になる。

## 依存するテスト

変更対象ごとに、それを入力または期待値に持つテストファイルを洗い出した（`grep -rn "<旧名・旧パス>" --include="test_*.sh"`）。

| 変更対象 | 依存するテスト | 入れるステップ |
|---|---|---|
| `.claude/hooks/boundary.sh` → `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh` | `test_workflow_entry.sh:144`（WE-T11）・`test_workflow_state_guard.sh:118`（SG-T05） | S4（0027） |
| `.claude/hooks/finalize.sh` → `.claude/skills/10-task-overall-summary/scripts/finalize.sh` | `test_workflow_entry.sh:143`（WE-T06）・`test_workflow_state_guard.sh:117`（SG-T05） | S4（0027） |
| `ticket.sh` の完了検査の切り出し | `test_ticket.sh`（TICKET-T02〜T04・T07） | S3（0026） |
| `CP-T08` の振り直し | `test_push.sh` | S5（0028） |

**旧名を期待値に持つテストは 1 本も無い**（0005 の c6）。旧名の置換でテストが赤くなることはない。赤くなるのは**置き場の変更**の 4 行だけで、上の表に入れてある。

## ロックアウト対策

中核を変えるステップは 3 つ（S2・S3・S4）。それぞれ「変更後の最初の操作で自分が止まる可能性」と復旧手順を書く。

| ステップ | 止まり方 | 検知 | 復旧 |
|---|---|---|---|
| S2（`boundary.sh` 新規） | **止まらない**。新規作成でフックは参照していない（`session-start.sh` は不在なら無出力で終了 0）。作った直後に自分の進行へ組み込まないので、壊れていても作業は続く | `run-tests.sh --filter boundary` | `git reset --hard <base_sha>` |
| S3（`finalize.sh` 新規・`ticket.sh` の切り出し） | **`ticket.sh` が止まると全チケットの状態遷移ができなくなる**。関数を切り出す変更なので、source の順序や変数名の衝突で `ticket.sh` 自体が壊れうる | 切り出した直後に `ticket.sh next` を実行して JSON が返ることを確かめる（この 1 回目が検証を兼ねる） | `git reset --hard <base_sha>`。`ticket.sh` が動かない状態では `ticket.sh complete` も打てないので、**先に git で戻してから**やり直す |
| S4（`session-start.sh:64`・`workflow-state-guard.sh:40, 43`） | `session-start.sh` は**セッション開始時の注入そのもの**を行う。パスを取り違えると現在地が一切注入されなくなり、**不在時は無出力で終了 0 に倒れるため壊れたことに気づきにくい**。`workflow-state-guard.sh` は案内文だけなので拒否の挙動は変わらない | **SE-T10**（新しい置き場に置いたときに注入され、旧い置き場だけに置いたときは注入されず `hook_record skip` の理由が「不在」になる）。**`SE-T05` の後半では代えられない** — `jq` の検査はスクリプト不在の分岐より後にあり、パスを取り違えたままでも同じ結果（無出力・終了 0）になる | `git reset --hard <base_sha>`。注入が無くても作業は続けられる（現在地が出ないだけ）ので、セッションが使えなくなる形の詰まり方はしない |

`WORKFLOW_ENTRY_ENFORCE=0` による強制の無効化は**使わない**（ユーザーの明示的な指示があるときだけ。`CLAUDE.md`）。

## リスク

| # | リスク | 影響 | 巻き戻し |
|---|---|---|---|
| 1 | `ticket_check_completion` を関数として切り出せない（現行の `ticket.sh` の構造次第） | S3 が止まる。`finalize.sh` の段階 2 が検査を二重実装することになり、仕様と食い違う | 切り出しが無理なら**設計へ差し戻す**（`20-common-step-ticket` 仕様の「二重実装しない」を書き直す）。実装で辻褄を合わせない |
| 2 | タスクスキル 15 本の SKILL.md が 1 枚のチケットに収まらない | S6 の差分が大きくなりレビューが効かなくなる | 着手時に分量を見て、計画側 8 本 / 実施側 7 本の 2 枚に割る。割ったら計画書のステップ表も同じチケットの中で書き直す（記述順と実行順の一致） |
| 3 | 旧名の置換で新名の部分一致を巻き込む | `00-workflow-issue-mr-driven` が `00-00-workflow-...` のように壊れる | S9 の 0 件判定に加えて、スキルディレクトリ数 26 と `entry-skills.txt` の 2 行を検査する。壊れていればこの 2 つが落ちる |
| 4 | 全件テストが 10 分前後かかり、S9 で初めて全体の赤が見つかる | 手戻りが S2 まで遡りうる | 各ステップで `--filter` を回し、S9 の全件は確認の位置づけにする。`--filter` が通ったものが `--ids` で落ちるのは重複 ID のときだけ |

## 保留した点

| # | 保留 | 判断の時期 |
|---|---|---|
| P2 | `boundary.sh` をこの issue の切れ目で使い始めるか | **この計画で決めた**。使い始めない（上記「S2・S3 は提供コマンド自身を作るステップ」） |
| P6 | 作成物 55 件をどうチケットに割るか | **この計画で決めた**。57 件を 9 枚に割った（変更対象の表） |
| P1' | `session-start.sh` の 1 行をどのチケットで直すか | **この計画で決めた**。S4（0027）。ロックアウト対策は SE-T10 |
| R7 / R9 | `rules/work-defaults.md` に敵対的レビュアーのモデルを書く列が無い | S8（0031）で `.claude/rules/` に足す。0020 で「モデルの突き合わせは起動側の責務」と決めたので、差し替え先のモデルを書く場所が要る |
| R10 | エージェント定義の `model` を機構が検査できない | この issue では扱わない。フィードバック計画（0033）へ回す |
| R11 | md と HTML の対応の自己チェックの数え方 | この issue では扱わない。フィードバック計画（0033）へ回す |

## レビューで見てほしい点

1. **ステップ順と中核・テストの隣接**: S2・S3・S4 が中核で、それぞれのテストを同じチケットに置いた。S4 を S2・S3 の後に置いたのは、`session-start` のテスト 8 件が `boundary.sh` に依存するため
2. **テスト ID の割付の漏れ**: 抜き出し 220 − 例示 2 = 218 件が割付表の行数と一致する。この issue で足すのは 33 件で、165 + 33 = 198
3. **参照更新一覧の検索根拠**: 検索コマンドは 0005 の c5 の訂正版（前置 `(^|[^0-9-])`）。期待値は「残るもの」で書き、スキルディレクトリ 26 個と eval 28 本を担保に置いた
4. **ロックアウト対策**: S4 の対策を `SE-T05` 後半から **SE-T10** に差し替えてある。前者はパスを踏まないので対策にならない（0020 の発見）
5. **設計への差し戻し**: 19 アセットの eval 節が無いことを実装計画で埋めず、設計チケット 0023 を先頭に置いた。この判断が妥当か
