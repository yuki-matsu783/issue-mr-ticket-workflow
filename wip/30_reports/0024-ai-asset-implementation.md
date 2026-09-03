---
type: report
title: 0024- AI アセット実装・テスト結果 — 機構の実体を作る
description: issue #10 の実装フェーズの結果報告。テンプレート実体 15 件・提供コマンド 2 本・フック 3 か所の追随・タスクスキル 15 本とエージェント 2 本・eval 定義 19 件・旧名 111 件の参照更新を、チケットごとの節で積み上げる
tags: [report, ai-asset-implementation, issue-10]
keywords: [AI アセット実装, テンプレート, boundary.sh, finalize.sh, 中核, ロックアウト対策, 機械テスト, eval, 参照更新, 旧名]
---

# 0024- AI アセット実装・テスト結果 — 機構の実体を作る

- 対象 issue: [#10](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/10)
- MR: [#35](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/35)（draft）
- ブランチ: `feature-10-task-skills-agents-finalize`
- チケット: 0024〜0032
- 作成日: 2026-09-04

## サマリ

実装フェーズの結果報告。0017 の計画が並べたステップ S1〜S9 を、チケット 0024〜0032 が同じレポートに節を積み上げる（実施タスクの共通手順 4）。

**0024（S1 設定・定義）**: 仕様の OUT ひな形が名前とパスで指定しているテンプレート **15 件**を作った。13 件は各スキルの `assets/`、2 件（レポート・計画書の md 共通の型）は `20-common-step-report-view` の `assets/`。仕様が参照する `*.template.md` は**全件が実体を持つ**状態になった。

**0025（S2 中核: `boundary.sh`）**: タスクの切れ目の判定・レビュー依頼・完了確認を担う提供コマンドを作った。5 サブコマンド、機械テスト **13 件**（アサーション 74 件）が通る。`logs/review-state.json` を書き換える唯一の経路になる。

- ◎良 2 件 / △注意 0 件 / ✕問題 0 件（節は e1〜e2 の 2 件。0025 まで）

### ◆特に見てほしい（判断に困っている）

- **e2**: `boundary.sh` の**引数・環境の誤り**に専用の識別子が無い。仕様の表は `BD001`〜`BD005` しか定義しておらず、他の提供コマンドが持つ `TK008` / `CP007` / `RV008` に相当する番号が欠けている。暫定で `BD001` を終了コード 2 で使い、メッセージの頭に「引数・環境の誤り」と書いた。番号を分けるべきか見てほしい（残課題 R3）

### ◇承認が欲しい（方針は決めた）

- **e1**: 計画書のテンプレート 8 件を「共通の型に足す節だけ」の形にした。共通の型を逐語で複製していないので、単体では完成した文書に見えない。節を 1 つ足すのに 15 か所を直す事態を避ける形（`20-common-step-report-view` 仕様「テンプレートの置き場」）だが、使う側が共通の型を必ずコピーする前提に依存する

### ・細かいレビューは不要（ほぼ確実）

- **e1**: `attachment-comment.template.md` は仕様の改訂で `summary-section.template.md` に置き換わっている（設計フェーズの残課題 R4）。0003 の a2 の表の名前ではなく、現行の仕様書の名前で作った

## 確かめられなかったこと

| 対象 | 確かめられなかった理由 | 引き取り先 |
|---|---|---|
| テンプレートが実際に使えるか（埋めた結果が仕様の OUT を満たすか） | このチケットで作ったのはひな形だけで、使う側の SKILL.md は S6（0029）で作る | S6 以降の実装チケット |
| `markdown-docs` ルールとの整合 | ルール自体が存在しない（`.claude/rules/` に無い）。2 つの設計文書ルールが参照しているが未作成 | 残課題 R1 |
| `boundary.sh` の GitLab 経路 | テストは `gh` のスタブで GitHub 経路だけを通している。`glab` の応答の形は実機でも fixture でも確かめていない | 残課題 R4 |
| `boundary.sh` の実運用 | 保留 P2 の判断どおり、この issue の切れ目では使わない（切れ目の記録は `gh pr comment` の直接実行のまま）。実運用は次の issue から | 次の issue |

## 実施した内容と結果

### e1. テンプレート実体 15 件を作った（S1） ◎良

仕様の OUT ひな形が名前とパスで指定しているテンプレートを作った。作成前の `.claude/skills/*/assets/` にあった `*.template.md` は 9 件（うち旧ワークフロー由来で仕様に無いものが 1 件）で、仕様が名前で参照する 20 種のうち **13 種が実体を持たなかった**。それに md の共通の型 2 件（設計フェーズの残課題 R6）を足して 15 件を作った。

**共通の型 2 件**（`20-common-step-report-view/assets/`）

| ファイル | 節 |
|---|---|
| `report.template.md` | サマリ（重点レビュー依頼 3 区分を含む）→ 確かめられなかったこと → 実施条件（任意）→ 実施した内容と結果 → 検証の結果（任意）→ 設計への反映 → 想定と異なった点 → 残課題 |
| `plan.template.md` | この計画で何をするか → 対象と範囲 → 方法とステップ → 検証 → チケット → リスクと復旧（任意）→ スコープ外（任意）→ 保留した点 / 対象なし |

節構成は同じ `assets/` の HTML ビューのテンプレートと 1 対 1 で対応させた。md が正文で HTML ビューだけがあった状態（0003 の a7）を解消した。

**種類ごとの型 9 件**

`10-task-overall-plan` の `overall-plan.template.md` だけは完成した 1 枚の文書として書いた（HTML ビューを作らない・1 画面程度という仕様のため）。残る 8 件は**共通の型に足す節だけ**を持つ形にした。

| スキル | ファイル | 足す節 |
|---|---|---|
| `10-task-investigation-plan` | `investigation-plan.template.md` | 調査観点 / 対象と方法 / 調査チケット / 成果物の形 |
| `10-task-design-plan` | `design-plan.template.md` | 判断点の結論方針 / 設計書の一覧 / 受け入れ条件との対応 / 設計チケット |
| `10-task-implementation-plan` | `implementation-plan.template.md` | 変更対象 / 許可範囲案 / テスト方針 / ステップ / 検証方法 / リスク / 設計差し戻し |
| `10-task-design-feedback-plan` | `design-feedback-plan.template.md` | 差分一覧 / 書き戻し方針 / 実装漏れ一覧 / 受け入れ条件の確認 / 設計反映チケット |
| `10-task-ai-asset-design-plan` | `ai-asset-design-plan.template.md` | 結論方針 / 文書一覧と骨子 / 横断整合 / ヘッドレス実行の帰結 / 受け入れ条件との対応 / 設計チケット |
| `10-task-ai-asset-implementation-plan` | `ai-asset-implementation-plan.template.md` | 変更対象 / 許可範囲案 / テスト方針 / ステップ / 参照更新一覧 / 依存するテスト / ロックアウト対策 / リスク / 設計差し戻し |
| `10-task-feedback-plan` | `feedback-plan.template.md` | 確認した記録の範囲 / 改善候補の一覧 / 合意 / 起票した issue / 後続フェーズの決定 |
| `10-task-overall-summary` | `summary-section.template.md` | MR 本文の `## 統括` 節（受け入れ条件との対応 / 残課題 / 別 issue / 成果物のリンク一覧の表） |

**ワークフロースキルの型 4 件**（`00-workflow-issue-mr-driven/assets/`）

| ファイル | 内容 |
|---|---|
| `subagent-prompt.template.md` | `task-executor` の起動プロンプト。issue・MR・**ブランチ名**・スキル名・対象・文脈のありか・禁止事項の要点・結果報告の形式 |
| `review-request.template.md` | 切れ目のレビュー依頼。対象タスクとチケット・差分範囲・見てほしい点・人間レビュー省略の有無・敵対的レビュー・次のタスク・確定してほしい判断 |
| `decision-note.template.md` | 承認・判断の書き写し。何を / 誰が / いつ / 内容 の 4 列 |
| `adversarial-review-prompt.template.md` | 敵対的レビュアーの起動プロンプト。patch のパス・対象ファイル・観点・進め方 5 段階・出力スキーマ |

**書き方で固定したこと**

- プレースホルダは二重波括弧で名前を囲む形式（HTML ビューと同じ規約）で、要素の内容として置く。冒頭の HTML コメントに「何を埋めるか」「どの節が必須か」「書き終わりにこのコメントを消すこと」を書いた
- `summary-section.template.md` の「成果物」の表は**骨格だけ**を置き、行を手で書かない。中身は `finalize.sh release` の段階 4 が埋める。空の表を `linked` と誤判定しないよう、判定には固定マーカーを使う（仕様の再導出の規定）
- `adversarial-review-prompt.template.md` には、起動前に差分を `wip/tmp/adversarial-<n>.patch` へ書き出すことと、実行者とモデルが一致したら差し替えることをコメントに書いた。レビュアー自身は `Bash` を持たないので差分を取れない

### e2. `boundary.sh` とテスト 13 件を作った（S2・中核） ◎良

タスクの切れ目の判定・レビュー依頼・完了確認を担う提供コマンドを作った。`logs/review-state.json` を書き換える唯一の経路になる。

**5 サブコマンド**

| サブコマンド | 役割 |
|---|---|
| `status [--offline]` | 切れ目の判定を JSON で返す。`--offline` は CLI を呼ばず `logs/` と作業領域だけで導出する（フックが使う） |
| `note --body-file` | 通常コメントを投稿する。レビュー状態は変えない |
| `request --body-file` | 前提を検査してレビューを依頼し `requested` にする |
| `skip --reason` | レビュー不要の切れ目を `skipped` にする |
| `complete` | 指摘を取得して `completed` にする |

**判定の中身**

- `at_boundary` は「作業中が空 かつ（次が無い、または次の種類が最後のタスクと違う）」。`next` / `current` / `type` / `skill` は `ticket.sh next` の出力をそのまま載せる（種類からスキル名を引く処理を二重に持たない — BD-T02）
- `last_task` は完了群の末尾から**同じ種類が続く範囲**。レビュー要否はその中に 1 枚でも「要」があれば要
- `review.state` は記録の `boundary.last_done` が今の `last_task` の最大連番と一致するときだけ有効。追加チケットが完了すると自動的に `none` に戻る（BD-T07）
- 全体まとめは `--final` で扱う。作業中が全体まとめ 1 枚のとき、切れ目の鍵をそのチケット番号に差し替える（BD-T11）

**再導出と矛盾の検出**

記録が無い・壊れているときは実態から導出する。依頼コメントは本文先頭の固定マーカー `<!-- boundary:request <種類>:<番号> -->` で見分ける（BD-T08）。同じ鍵のマーカーが 2 件あると一意に決められないので `BD005` で止める（BD-T12）。`merge-state` が片付け以降なのに作業領域に成果物が残っている矛盾も同じ扱いにした。

**指摘の選別**

機構が投稿したコメントは**マーカーの有無**だけで除く。ログイン名では除かない（AI はユーザーのトークンで投稿するので、レビュアーが同じアカウントだと人間の指摘まで消える）。未解決スレッドは `BD003` で止め、`--accept-unresolved` で受け入れられる。**変更要求（`CHANGES_REQUESTED`）は `--accept-unresolved` でも通さない**（BD-T05）。

**テスト**: `BD-T01`〜`BD-T13` の 13 件、アサーション 74 件が通る。`gh` はスタブに差し替え、GraphQL とコメント API の応答を fixture で与えた。差分の取得も正規化のスキーマも実物と同じ経路を通る。

**実行時間で 1 度落ちた**。初版は 116 秒かかり、全件実行でテストランナーの既定タイムアウト（120 秒）に当たって `TR003` になった。原因は 2 つで、テストがケースごとに `git commit` していたことと、`boundary.sh` が 1 回の `status` で `jq` を 10 回以上起動していたこと。テスト用リポジトリで作業領域を追跡外にしてコミットを消し、`boundary.sh` は複数の値を 1 回の `jq` でまとめて読むように直して **64 秒**にした。上限に対しておよそ 2 倍の余裕がある。

## 検証の結果

| 検証 | 結果 |
|---|---|
| 仕様が参照する `assets/*.template.md` | 20 種すべてに実体がある（`10_spec/` から抽出した名前を `find` と突合して MISSING 0 件） |
| 今回作った件数 | 15 件（種類ごと 9・ワークフロー 4・共通の型 2） |
| 名前の食い違い | 0 件。`attachment-comment.template.md` は現行仕様に無く、`summary-section.template.md` として作った |
| `boundary.sh` の機械テスト | `BD-T01`〜`BD-T13` の 13 件・アサーション 74 件が PASS（`run-tests.sh --filter '*test_boundary*'` → `OK: 1 本 / 13 件`） |
| `boundary.sh` の終了コード | 成功 0 / 前提未充足 1（BD001〜BD005）/ 引数・環境の誤り 2。最終行は `OK:` または `BDxxx:` |

## 設計への反映

| # | 反映すること | 引き取り先 |
|---|---|---|
| 1 | 種類ごとのテンプレートが「共通の型に足す節だけ」であることは、使う側の SKILL.md にも書く必要がある（テンプレートを 1 枚だけコピーして完成と誤解しないため） | S6（0029） |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| テンプレートは 0003 の a2 の表のパスにそのまま作れる | 9 番の `attachment-comment.template.md` は仕様の改訂で `summary-section.template.md` に置き換わっていた | 現行の仕様書の名前で作った（残課題 R4 の決着） |
| 種類ごとのテンプレートは共通の型を含む完成形で書く | 15 本が同じ節構成を逐語で持つと、節を 1 つ足すのに 15 か所を直すことになる（`report-view` 仕様が明示的に禁じている） | 足す節だけを持つ形にし、冒頭コメントで共通の型の場所を指した |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | `markdown-docs` ルールが存在しない。`design-docs` と `ai-asset-design-docs` の 2 本が frontmatter の規約の正として参照しているが `.claude/rules/` に無い。今回のテンプレートは既存文書の慣行（`type` / `title` / `description` / `tags` / `keywords`）に合わせた | フィードバック計画（0033） |
| R2 | 旧ワークフロー由来の `00-workflow-issue-mr-driven/assets/issue-addendum.template.md` と `issue-notify.template.md` が残っている（削除は S8） | S8（0031） |
| R3 | `boundary.sh` の引数・環境の誤りに専用の識別子が無い（`BD001`〜`BD005` に該当なし）。他の提供コマンドは `TK008` / `CP007` / `RV008` を持つ。暫定で `BD001` を終了コード 2 で使っている | フィードバック計画（0033）→ 設計反映 |
| R4 | `boundary.sh` の GitLab 経路（`glab api discussions` / `approval_state`）は fixture でも実機でも未検証。テストは GitHub 経路だけを通っている | フィードバック計画（0033） |
