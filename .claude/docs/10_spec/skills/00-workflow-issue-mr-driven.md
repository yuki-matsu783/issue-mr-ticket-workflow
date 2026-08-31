---
type: spec
title: 00-workflow-issue-mr-driven スキル 仕様
description: 開発作業の振り分けスキル（オーケストレータ）の内部仕様。タスクの種類 → スキル名の対応表（正）、issue 種別ごとのフェーズ列テンプレート、タスクの起動（メイン / サブエージェント）、切れ目の処理、レビュー依頼と完了の提供コマンド boundary.sh（logs/review-state.json・BD0xx）、再開・外部委任・単独実行の扱いを定める
tags: [spec, skill, workflow]
keywords: [オーケストレータ, タスクの種類, type, スキル名対応表, フェーズ列テンプレート, 切れ目, boundary.sh, status, request, complete, skip, note, review-state, 未解決スレッド, 追加チケット, サブエージェント起動, 再開, 外部委任モード, 単独実行モード, BD0xx]
---

# 00-workflow-issue-mr-driven スキル 仕様

## 概要・禁止事項

開発作業向けの振り分けスキルの内部仕様。対応する要件は [00_requirement/skills/00-workflow-issue-mr-driven.md](../../00_requirement/skills/00-workflow-issue-mr-driven.md)。

このスキルはタスクの起動順序と切れ目の処理だけを持ち、タスクの中身は `10-task-*`、操作は `20-common-step-*` に委ねる。**タスクの種類（type）→ スキル名の対応表と、issue 種別ごとのフェーズ列テンプレートはこの仕様が正**で、`ticket.sh next` の `skill` 出力・`10-task-overall-plan` のフェーズ列・`rules/work-defaults.md` の行はこれに合わせる。切れ目の判定・レビュー依頼と完了は、このスキルが持つ提供コマンド `boundary.sh` が行い、進行状態を `logs/review-state.json` に記録する。

禁止事項:

- 次のタスクの目視選択（`ticket.sh next` と `boundary.sh status` の出力に従う）
- `git commit` / `git push` の直接実行、`logs/` 配下の進行状態の直接編集、draft 解除の直接実行（すべて提供コマンド経由。フックが拒否する）
- レビュー依頼のコメントを `gh pr comment` / `glab mr note` で直接投稿すること（`boundary.sh request` 経由。進行状態と証跡が結びつかなくなる）
- レビュー待ちを `AskUserQuestion` で待つこと（応答を終えて次のユーザー発言で再開する）
- ユーザーの言葉だけでレビュー完了とみなすこと（必ず `boundary.sh complete` を通す）
- 完了済みチケットを作業中に戻すこと（指摘は同じ種類の追加チケット）
- 承認された範囲を超える必須フェーズの省略・タスク種類の統合（往復が多いときはレビュー要否を「不要」に倒す）
- MR 本文・コメント・issue に `wip/` 配下のパスを恒久的な参照として書くこと（レビュー依頼の一時的な参照は例外）
- サブエージェントの入れ子起動（チケット単位の分割もこのスキルが起動する）
- チケットの着手・完了・作業ログ・DoD の手順の再掲（各タスクと `20-common-step-ticket` を参照する）
- MR のマージ

## 呼出条件

- `CLAUDE.md`「作業の振り分け」により、開発作業（振る舞いが変わる変更・複数モジュール・テストやレビューが要る変更・`.claude/` 配下のアセット変更・ユーザーが issue / MR を指定した依頼）と判定されたプロンプトで、Skill ツールで読み込まれる（`workflow-entry` フックがこの読み込みを宣言として記録する）
- `00-workflow-quick-request` の判定・範囲超過・振り返りからの切り替え時にも読み込まれる（引き継ぎ項目は quick-request 仕様）
- 再開: 現在ブランチに open な MR があり作業領域にチケットがある状態で読み込まれたとき（session-start フックが伝える現在地から続ける）
- 前提: `glab` / `gh` が使える（使えなければ外部委任モード）。同一 clone 上の並行セッションは想定しない

## IN / OUT

| IN | OUT |
|----|----|
| 依頼（または quick-request からの引き継ぎ: 要約・受け入れ条件・種別・issue 種別・フェーズ列）、作業領域と `logs/` の状態、MR 上のレビュー | issue に紐づく feature ブランチと draft MR 上に積まれたタスクの成果（コミット・MR 本文の要約・レビュー依頼と承認記録のコメント）、全体まとめの draft 解除で停止 |

## IN / OUT サンプル

```bash
bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh status
# => {"mr": {"number": 13, "url": "https://github.com/o/r/pull/13"}, "current": null, "next": {"number": "0005", "type": "design-plan", "skill": "10-task-design-plan"},
#     "at_boundary": true, "last_task": {"type": "investigation", "tickets": ["0003","0004"], "review_required": true},
#     "review": {"state": "none"}, "position": "before_request"}

bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh request --body-file wip/tmp/review-request.md
# => OK: レビューを依頼した（MR !13 コメント https://.../pull/13#issuecomment-123 / 対象 investigation 0003-0004 / 差分 5c19f25..a1b2c3d）

bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh complete
# => BD003: レビューを完了できない。未解決のスレッド 1 件: https://.../pull/13#discussion_r456（auth/validate.ts:42 "境界値のテストが無い"）
```

- 結果報告の受け取り例（サブエージェントから）: 「チケット 0003・0004 完了。レポート `wip/30_reports/0003-investigation.md`。見てほしい点: …」→ このスキルが push・MR 本文更新・レビュー依頼を行う

## 処理フロー

### タスクの種類 → スキル名の対応表（正）

| 順序 | type（チケットの種類・ファイル名） | タスク名 | 種別 | 担当 | スキル名 |
|---|---|---|---|---|---|
| 1 | `overall-plan` | 全体計画 | 計画 | メインエージェント | `10-task-overall-plan` |
| 2 | `investigation-plan` | 調査計画 | 計画 | サブエージェント | `10-task-investigation-plan` |
| 3 | `investigation` | 調査実施 | 実施 | サブエージェント | `10-task-investigation-exec` |
| 4 | `design-plan` | 設計計画 | 計画 | サブエージェント | `10-task-design-plan` |
| 5 | `design` | 設計実施 | 実施 | サブエージェント | `10-task-design-exec` |
| 6 | `implementation-plan` | 実装・テスト計画 | 計画 | サブエージェント | `10-task-implementation-plan` |
| 7 | `implementation` | 実装・テスト実施 | 実施 | サブエージェント | `10-task-implementation-exec` |
| 8 | `feedback-plan` | フィードバック計画 | 計画 | メインエージェント | `10-task-feedback-plan` |
| 9 | `design-feedback-plan` | 設計反映計画 | 計画 | サブエージェント | `10-task-design-feedback-plan` |
| 10 | `design-feedback` | 設計反映実施 | 実施 | サブエージェント | `10-task-design-feedback-exec` |
| 11 | `ai-asset-design-plan` | AI アセット設計計画 | 計画 | サブエージェント | `10-task-ai-asset-design-plan` |
| 12 | `ai-asset-design` | AI アセット設計実施 | 実施 | サブエージェント | `10-task-ai-asset-design-exec` |
| 13 | `ai-asset-implementation-plan` | AI アセット実装・テスト計画 | 計画 | サブエージェント | `10-task-ai-asset-implementation-plan` |
| 14 | `ai-asset-implementation` | AI アセット実装・テスト実施 | 実施 | サブエージェント | `10-task-ai-asset-implementation-exec` |
| 15 | `overall-summary` | 全体まとめ | まとめ | メインエージェント | `10-task-overall-summary` |

- 対応表の実体は `assets/task-types.tsv`（順序・type・スキル名・担当・計画 / 実施の対）。`ticket.sh next` と `boundary.sh` はこのファイルを読み、表と同じ結果を返す（型の追加はこの表と `rules/work-defaults.md` の行追加で済ませ、スクリプトを直さない）
- 計画 / 実施の対: 2-3、4-5、6-7、9-10、11-12、13-14。片方だけの採用は不可
- フェーズ列のテンプレート（issue の種別は全体計画が判定）:

| issue の種別 | フェーズ列 |
|---|---|
| アプリ | 全体計画 → 調査 → 設計 → 実装・テスト → フィードバック計画 → （設計反映 / AI アセット設計 / AI アセット実装・テスト: フィードバック計画で決める）→ 全体まとめ |
| AI アセット | 全体計画 → 調査 → AI アセット設計 → AI アセット実装・テスト → フィードバック計画 → （追加の AI アセット設計 / AI アセット実装・テスト: フィードバック計画で決める）→ 全体まとめ |

順序は表の 1 → 15 に固定し、含めないフェーズだけを飛ばす。全体計画・調査・フィードバック計画・全体まとめは必ず含める。やることの無いフェーズは計画チケットの「対象なし」で即完了する（省かない）。

### 手順 0: 状態確認と再開判定

1. `boundary.sh status` を実行し、`mr`・`current`・`next`・`at_boundary`・`review.state`・`position` を得る（`position` は `in_task` / `before_request` / `requested` / `completed` / `merge_prep` / `none`）
2. `mr` があり作業領域にチケットがある → **再開**。全体計画をやり直さず `position` から続ける: `in_task` → 手順 2 のタスク起動（作業中チケットの続き）/ `before_request` → 手順 3 / `requested` → レビュー完了の連絡が無ければ応答を終える / `completed` → 手順 4 の指摘の扱いから / `merge_prep` → `10-task-overall-summary` の `finalize.sh release` 再実行
3. 開始・再開のどちらでも `git fetch origin` し、`git rev-list --count HEAD..origin/<default>` が 0 でなければ default に未取り込みのコミットがあることを伝え、`git merge origin/<default>` での取り込みを提案する（DDR i0001-25。衝突が無くても知らせる。取り込みは承認後）
4. チケットも MR も無い → 手順 1 へ

### 手順 1: 全体計画チケットの配置と全体計画タスク

1. `ticket.sh create overall-plan` で全体計画チケットを作る（やってよいこと: `wip/`・issue の起票と追記・ブランチと MR の作成・push。default ブランチ上なのでコミットは保留される — DDR i0004-04）→ `ticket.sh start`。この時点で作業領域にチケットがあるため、以降のプロンプトで振り分けの再宣言は求められない
2. `10-task-overall-plan` を Skill ツールで読み込み、メインエージェント自身で実施する（issue の確定・ブランチと draft MR・フェーズ列と方針の合意・最初の計画チケットまで。承認①②③はそのタスクの中）
3. 全体計画の結果が「対応なし」→ `ticket.sh cancel --reason` で全体計画チケットを取り消して停止。「issue の起票だけ（着手の指示なし）」→ 同様に取り消し、着手の指示を待つ
4. 全体計画チケットが完了したら手順 3（切れ目の処理）へ。全体計画の切れ目のレビュー要否は全体計画チケットの記載に従う

### 手順 2: タスクの起動（ループ）

`boundary.sh status` の `next` が null になるまで繰り返す。

1. `next.type` を対応表で引く。対応するスキルが無ければ「type 定義とスキルの不整合」として報告して停止する
2. 担当がメインエージェント（`overall-plan` / `feedback-plan` / `overall-summary`）→ そのスキルを Skill ツールで読み込み、自身で実施する
3. 担当がサブエージェント → `assets/subagent-prompt.template.md` から指示文を作り、Agent ツールで起動する（モデルはチケットの「実行者」。指示文の内容: issue / MR 番号と URL、読み込むスキル名、対象チケットの番号、結果報告の形式、禁止事項の要点 — 入れ子起動禁止・並列禁止・push と MR 操作はしない）。サブエージェントはユーザーと対話しないため、承認が要る事態は結果報告で戻ってくる
4. タスクから「チケットの実行者がタスクのモデルと異なる / 新しいコンテキストで実施したい」という要求が返ったら、そのチケット 1 枚を対象にした指示文で別のサブエージェントを起動する（1 枚ずつ。並列に起動しない — DDR i0001-23）
5. 結果報告を受け取る。報告に「状態の不整合」「承認が必要」「差し戻し提案（設計の追加チケット等）」が含まれていればユーザーに提示し、指示に従って追加チケットを `ticket.sh create` で起こすか停止する
6. サブエージェントが結果報告を返さずに終わった（失敗・中断）→ `ticket.sh next` で `current` を確認し、作業中のまま残ったチケットの番号と作業ログの現在地を報告してユーザーの指示を待つ（勝手に完了・取り消ししない）
7. `boundary.sh status` を再実行し、`at_boundary` が true なら手順 3 へ、false（同じ種類のチケットが残っている）なら 1 へ

### 手順 3: 切れ目の処理

`at_boundary` のときに行う。順序は固定。

1. **push**: `push.sh`（前チェック込み。作業中チケットが無いので拒否されない）
2. **MR 本文の更新**: `## 変更点` に `- <タスク名>（チケット <番号範囲>）: <成果の要約 1〜2 行>` を追記する。人間レビューを省略する切れ目なら行末に `（人間レビュー省略: <理由>）` を付ける。GitHub は `gh pr edit --body-file`、GitLab は issue 仕様「GitLab の長文送信」。`wip/` 配下のパスを書かない（レポートは要約で書く）
3. **承認・判断の書き写し**: このタスクの間にチャットで受けた承認・判断・保留点への回答があれば `assets/decision-note.template.md`（項目: 何を・誰が・いつ・内容）で本文を作り、`boundary.sh note --body-file` で MR の通常コメントとして投稿する（DDR i0001-26）。無ければ省く
4. **レビュー要否の分岐**: `last_task.review_required`（そのタスクのチケットに 1 枚でも「人間レビュー要」）が
   - true → `assets/review-request.template.md`（対象タスクとチケット・差分範囲（基準 SHA..HEAD の比較リンク）・見てほしい点（結果報告の「見てほしい点」を転記）・次のタスク・確定してほしい判断）で本文を作り、`boundary.sh request --body-file` を実行する。成功したらチャットで「タスク X を push しレビューを依頼した。完了したら知らせてほしい」と報告して**応答を終える**
   - false → `boundary.sh skip --reason "<理由>"` で省略を記録し、チャットで「人間レビューを省略して次のタスクに進む（理由）」と報告して手順 5 へ

### 手順 4: レビュー完了

レビュー完了の連絡（次のユーザー発言）を受けたら:

1. ユーザーがチャットでレビュー判断（「指摘なし」「この点を直して」等）を伝えた場合は、先にその内容を `boundary.sh note --body-file` で MR の通常コメントに記録する
2. `boundary.sh complete` を実行する。通れば `completed` になり、依頼以降の指摘（自分の投稿を除く）が JSON で返る
3. 指摘 0 件・未解決スレッド無し → 手順 5 へ
4. 指摘あり → 全件を提示し、**すべて**を同じ種類の追加チケットとして `ticket.sh create` で起こす（先行チケット: なし、DoD: 指摘の内容、実行者・レビュー要否: 元のタスクと同じ。1 指摘 1 項目で 1 チケットにまとめてよい）。手順 2 に戻る（追加チケットの完了で切れ目が再び発生し、手順 3・4 を繰り返す）
5. `complete` が BD003（未解決スレッドあり / 変更要求あり）で止まった → スレッドの URL と要旨を提示し、MR 上で resolve することを勧める。`AskUserQuestion` で「resolve してもらってから再実行 / このまま次のタスクに進む / 追加チケットにする」を確認する。「このまま進む」なら `boundary.sh complete --accept-unresolved`（受け入れたスレッドの ID と確認者を記録する）、「追加チケット」なら 4 と同じ、それ以外は再実行を待つ

### 手順 5: 次のタスクへ

1. 未着手チケットの見直し: レビュー結果・新しい知見に応じて未着手（`00_todo/`）チケットの範囲・実行者・レビュー要否・DoD を Edit で直してよい。変更した場合はチャットで内容を伝える（作業中・完了のチケットは触らない）
2. 手順 2 へ。`next` が null（全チケット完了）なら、最後のタスクは全体まとめのはずなので `finalize.sh release` の結果を確認して停止する（マージしない）。全体まとめ以外で null になった（全体まとめチケットが起こされていない）場合は不整合として報告する

### 実行形態ごとの扱い

- **ヘッドレス**（`claude -p`・CI）: タスクの中の承認が必要になった時点で内容を報告してセッションを終える。切れ目で `request` を実行したらそのセッションの応答は完了。次回セッションで手順 0 から再開する。1 セッションで全タスクを完走することは想定しない
- **外部委任モード**（`command -v gh` / `glab` が失敗）: MR の読み書きを MCP ツールで代行し、`boundary.sh` には結果をフラグで渡す（`request --external --comment-url <url>`、`complete --external --report-file <json>`）。WebFetch / curl へ落とさない。状態に `via: external` が残り、証跡の強度が劣ることを結果報告に明記する
- **単独実行モード**（issue と MR を作らずチケット駆動だけを試す）: `boundary.sh request --standalone` / `complete --standalone` で、MR への投稿の代わりにチャット上の確認を証跡として記録する（`via: chat`）。会話上の承認に依存することを状態と報告に残す

## OUT ひな形

| ファイル | 用途 | 内容 |
|----|------|------|
| `assets/task-types.tsv` | 対応表の実体 | 順序 / type / タスク名 / 担当 / スキル名 / 対の相手 |
| `assets/subagent-prompt.template.md` | サブエージェントへの指示文 | issue・MR / 読み込むスキル / 対象チケット / 結果報告の形式（完了チケット・成果物の場所・見てほしい点・承認が必要な事項・不整合）/ 禁止事項の要点 |
| `assets/review-request.template.md` | レビュー依頼コメント | 対象タスクとチケット / 差分範囲（比較リンク）/ 見てほしい点 / 人間レビュー省略の有無 / 次のタスク / 確定してほしい判断 |
| `assets/decision-note.template.md` | 承認・判断の書き写しコメント | 項目ごとに 何を / 誰が / いつ / 内容 |

MR 本文の「変更点」の行形式は手順 3-2 のとおり。

## 参照ナレッジ

- チケット操作・`next` の出力: `10_spec/skills/20-common-step-ticket.md`
- push・前チェック: `10_spec/skills/20-common-step-commit-push.md`
- MR 本文の長文送信・`--paginate`・ホスト判定: `10_spec/skills/20-common-step-issue.md`
- 全体計画・フィードバック計画・全体まとめの中身と承認: 各 task 仕様（`10-task-overall-plan` / `feedback-plan` / `overall-summary`）
- 実行者・レビュー要否の既定: `rules/work-defaults.md`
- 継続条件・現在地の注入: `hooks/10-UserPromptSubmit/workflow-entry`・`hooks/00-SessionStart/session-start` の仕様（未作成。`boundary.sh status` と同じ判定規則を共有する — 本仕様「切れ目の判定」が正）
- 経緯: DDR i0001-06（type で識別）、i0001-15（未解決スレッドの確認）、i0001-18（切れ目でのリモート統制）、i0001-23（並列禁止）、i0001-25（ベース追従）、i0001-26（承認の書き写し）、i0001-28（logs/）

## Script 処理

`scripts/boundary.sh <subcommand> [options]`。終了コード: 成功 0 / 前提・状態の未充足 1 / 引数・環境の誤り 2。出力の最終行は AI が読む結果（`OK:` または `BDxxx:`）。`status` と `complete` の本体出力は JSON。ログ: 共通 logger（`20-common-step-shell-script` の `scripts/logger.sh`）。ホスト判定は issue 仕様の手順と同じ。リモート操作は `gh` / `glab` だけを使い、フックの判定材料にはならない（フックはリモートに問い合わせない — DDR i0001-14。フックが読むのは `logs/` の記録だけ）。

### 進行状態と記録

- `logs/mr.json`: `{"host": "github"|"gitlab", "issue": N, "mr": M, "url": ...}`。`status` が MR を CLI から特定できたときに書く（以後のサブコマンドとフックはこれを読む。無ければフックは MR を「不明」として扱い、`status` が再導出する）
- `logs/review-state.json`: `{"mr": M, "boundary": {"task_type": ..., "tickets": [...], "last_done": "0004"}, "state": "none"|"requested"|"completed"|"skipped", "via": "cli"|"external"|"chat", "base_sha": ..., "head_sha": ..., "request_comment_url": ..., "requested_at": ..., "completed_at": ..., "accepted_unresolved": [...], "findings": [...], "skip_reason": ...}`。切れ目ごとに上書きし、直前の内容は `logs/review-history.jsonl` に 1 行追記する（振り返りの材料）
- 直接編集は `workflow-state-guard` が拒否する。`boundary.sh` 内部の書き換えだけが経路
- 記録が無い・壊れている場合: `status` は作業領域と MR の実態から再導出して書き戻す（チケットの配置 → 切れ目、依頼コメントの有無 → `requested`。依頼コメントは本文先頭の固定マーカー `<!-- boundary:request <task_type>:<last_done> -->` で識別する）。再導出できない項目は `none` に倒す（拒否側）

### 切れ目の判定（正）

- `at_boundary` = `10_doing/` が空 かつ（`00_todo/` が空 または `00_todo/` の最小連番の type ≠ `20_done/` の最大連番の type）
- `last_task` = `20_done/` の最大連番のチケットと同じ type で連続する完了チケット群。`review_required` = その中に人間レビュー要否が「要」のものが 1 枚でもある
- `review.state` は `boundary.last_done` が現在の `last_task` の最大連番と一致するときだけ有効。一致しなければ（追加チケットが完了した等）`none` として扱う
- `position`: `current` あり → `in_task` / `at_boundary` かつ state none → `before_request` / requested → `requested` / completed または skipped → `completed` / チケット無しで `logs/merge-state.json` が `started`〜`pushed` → `merge_prep` / それ以外 → `none`

### 全体まとめの切れ目（`--final`）

全体まとめチケットは完了が `finalize.sh release` に内包され、レビューは release の前（チケットが作業中のまま）に行う。そのため `10_doing/` が全体まとめチケット 1 枚のときは `at_boundary` を false のまま、`request` / `skip` / `complete` を `--final` 付きで受け付ける（`boundary.task_type` は `overall-summary`、`last_done` はそのチケット番号）。`--final` 無しの `request` は BD001、全体まとめ以外での `--final` も BD001。release は前提検査でこの記録（レビュー要なら `completed`、不要なら `skipped`）を確認する（`10-task-overall-summary` 仕様）。

### status

1. 対応表 `assets/task-types.tsv` を読み、`ticket.sh next` の結果に `skill` を添えて `next` / `current` を返す
2. 上記の判定で `at_boundary`・`last_task`・`review`・`position` を求める
3. MR を `logs/mr.json` から読み、無ければ CLI（`gh pr view --json number,url,state` / `glab mr list --source-branch <ブランチ>`）で特定して書く。CLI が使えず記録も無ければ `mr: null`
4. JSON を出力する（終了コードは常に 0。判定不能な項目は null）

### note --body-file <path>

1. 本文が空なら BD001。MR が無ければ（単独実行モード）BD001 で `--standalone` を案内する
2. `gh pr comment <M> --body-file` / `glab mr note <M> --message "$(cat ...)"` で通常コメントを投稿し、URL を `logs/review-history.jsonl` に `{"kind": "note", ...}` として追記する（review-state の `state` は変えない）

### request --body-file <path> [--external --comment-url <url>] [--standalone]

1. 前提を検査し、未充足を全件列挙して BD001 で拒否する: `at_boundary` である / 未コミットの変更が無い / HEAD が push 済み（`git rev-list origin/<ブランチ>..HEAD` が空）/ MR がある（`--standalone` を除く）/ 現在の切れ目で `requested` でない / 本文が空でない
2. 本文の先頭に固定マーカーを付け、`gh pr comment` / `glab mr note` で投稿する。`--external` ではコメントを投稿せず `--comment-url` を証跡として受け取る。`--standalone` ではチャットで依頼した旨を本文ごと記録する
3. `logs/review-state.json` に `requested`、`base_sha`（前回の切れ目の `head_sha`、無ければ開始コミット）、`head_sha`、コメント URL、時刻、`via` を書く
4. `OK:` にコメント URL・対象・差分範囲を出力する

### skip --reason <理由>

1. `at_boundary` かつ `last_task.review_required` が false でなければ BD001（レビュー要の切れ目は省略できない）。理由が空なら BD001
2. `state: skipped` と理由・時刻を記録し、`OK:` を出力する（MR 本文への省略表示は手順 3-2 の AI の記載）

### complete [--accept-unresolved] [--external --report-file <json>] [--standalone]

1. 現在の切れ目の `state` が `requested` でなければ BD002（`request` からやり直す）
2. リモートから取得する（`--external` は `--report-file` の JSON を同じスキーマとして読む。`--standalone` は取得せず、チャットでの完了の連絡を記録して 5 へ）:
   - GitHub: `gh api graphql` で `pullRequest.reviewThreads`（`isResolved`・コメントの URL・パス・行・本文先頭）と `reviews`（`state`・`author`・`submittedAt`）、`gh api --paginate repos/:owner/:repo/issues/<M>/comments` で `requested_at` 以降の通常コメント
   - GitLab: `glab api --paginate projects/:id/merge_requests/<M>/discussions`（`resolvable && !resolved` を未解決とする。`notes[].body`・`position`）、`glab api projects/:id/merge_requests/<M>/approval_state`（変更要求に相当する `approved: false` の明示的な拒否は GitLab に無いため、未解決スレッドだけを止める条件にする）
   - 取得できなければ BD004（コマンドと出力）
3. 自分の投稿（`gh api user` / `glab api user` のログイン名、および固定マーカー付きコメント）を除外し、`requested_at` 以降の指摘を `findings[]`（`kind: thread|review|comment`、`url`、`author`、`path`、`line`、`summary`、`resolved`）に整形する
4. 未解決スレッドがある、または最新のレビューが `CHANGES_REQUESTED`（GitHub）→ `--accept-unresolved` が無ければ BD003 で一覧を出力して止まる。`--accept-unresolved` があれば `accepted_unresolved` にスレッド ID を記録して進む（`CHANGES_REQUESTED` は `--accept-unresolved` でも通さない — レビュアーが dismiss / approve するまで待つ）
5. `state: completed`、`completed_at`、`findings` を記録し、直前の状態を `logs/review-history.jsonl` に追記する
6. `findings` の JSON を出力し、`OK:` に件数（指摘 N 件 / 受け入れた未解決 M 件）を出力する

### エラー識別子

| ID | 条件 | メッセージに含める内容 |
|----|------|----------------------|
| BD001 | `request` / `note` / `skip` の前提未充足 | 未充足の全件と対処（コミット・push・切れ目まで進める・レビュー要の切れ目は省略不可 等） |
| BD002 | `complete` の状態不一致（`requested` でない） | 現在の状態と、`request` からやり直すこと |
| BD003 | 未解決スレッドあり / 変更要求あり | 該当スレッドの URL・位置・要旨の一覧。resolve を勧める文と `--accept-unresolved` の条件（変更要求は不可） |
| BD004 | リモートの取得・投稿に失敗 | 実行したコマンドと出力。外部委任モードの案内（CLI が無い場合） |
| BD005 | 進行状態の再導出に失敗（記録が壊れ、実態からも決められない） | 見つかった矛盾（例: 依頼コメントが 2 件）と、人間が確認すべき点 |

### テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| BD-T01 | 正常系 | `status` の `at_boundary` が、doing あり / 同 type の todo 残り / type が変わる / todo 空 のそれぞれで期待どおり |
| BD-T02 | 正常系 | `status` の `skill` が対応表 15 行すべてで `ticket.sh next` と一致する |
| BD-T03 | 異常系 | 未コミット・未 push・切れ目でない・二重依頼の `request` が BD001 で全件列挙 |
| BD-T04 | 正常系 | `request` → `complete`（指摘 0）で `completed` になり、`findings` が空 |
| BD-T05 | 異常系 | 未解決スレッドがある `complete` が BD003、`--accept-unresolved` で通り記録に残る。`CHANGES_REQUESTED` は `--accept-unresolved` でも BD003 |
| BD-T06 | 正常系 | 自分の投稿と固定マーカー付きコメントが `findings` から除外される |
| BD-T07 | 境界 | 追加チケットの完了で `last_done` が変わり、直前の `completed` が `none` として扱われる |
| BD-T08 | 正常系 | `logs/review-state.json` を削除しても `status` が依頼コメントのマーカーから `requested` を再導出する |
| BD-T09 | 異常系 | レビュー要の切れ目での `skip` が BD001 |
| BD-T10 | 正常系 | `--external` / `--standalone` で `via` が記録され、`complete --external --report-file` が同じスキーマで処理される |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 最初に全体計画チケットを作業中に置き全体計画に入る・リモート操作は宣言内 | 手順 1-1・1-2 |
| メイン: 担当の分岐（メイン自身 / サブエージェント）と起動・報告受け取り・切れ目に徹する | 手順 2-2・2-3・2-5 |
| メイン: 次のタスクは機構の結果に従い、スキルが無ければ停止 | 手順 2-1、禁止事項 |
| メイン: 切れ目で push と MR 本文の要約 | 手順 3-1・3-2 |
| メイン: チャットの承認・判断を MR コメントに書き写す | 手順 3-3、`note` |
| メイン: `wip/` パスを恒久参照にしない | 禁止事項、手順 3-2 |
| メイン: レビュー要の切れ目は観点を添えて依頼し応答を終える・完了まで進めない | 手順 3-4、`request`、禁止事項 |
| メイン: レビュー不要の切れ目は報告して続行 | 手順 3-4（`skip`） |
| メイン: 完了連絡時は未解決スレッドを必ず確認し結果を提示 | 手順 4-2、`complete` 2〜4 |
| メイン: 指摘 0 件なら次へ | 手順 4-3 |
| メイン: 指摘は全件を同種の追加チケットに（完了済みは戻さない） | 手順 4-4 |
| メイン: 未解決スレッドが残るときの提示・確認・分岐 | 手順 4-5（`--accept-unresolved`） |
| メイン: 未着手チケットの見直しと通知 | 手順 5-1 |
| メイン: 全体まとめ完了後はマージせず停止 | 手順 5-2 |
| 代替: 再開は現在地から（レビュー待ちなら応答を終える） | 手順 0-1・0-2 |
| 代替: default 未取り込みの検知と取り込み提案 | 手順 0-3 |
| 代替: 対応なし / 起票のみ → 全体計画チケットの取り消し | 手順 1-3 |
| 代替: 往復過剰はレビュー要否を不要に倒し即完了で対処 | 禁止事項、対応表の注記 |
| 代替: CLI 不在は外部委任モード | 実行形態ごとの扱い、`--external` |
| 代替: チャットでのレビュー判断は先に MR コメントへ | 手順 4-1 |
| 例外: 依頼の前提未充足は解消して再実行・切れ目でなければ次のチケット | `request` 1（BD001）、手順 2-7 |
| 例外: 変更要求 / 未返信スレッドは追加チケットと返信で対応し状態を直さない | 手順 4-5、`complete` 4、禁止事項 |
| 例外: サブエージェントが報告を返さない → 状態確認して指示待ち | 手順 2-6 |
| 例外: タスク内の承認で却下 → その段階に留まる | 手順 2-5（タスクの結果報告に従う） |
| タスクの構成: 15 種・担当・フェーズ列テンプレート・順序固定・対・必須フェーズ | 対応表、フェーズ列のテンプレート |
| タスクの構成: 対象なしの即完了・計画タスクが実施群 + 次の計画 1 枚 | 対応表の注記（実現は各計画タスク仕様） |
| タスクの構成: 切れ目の定義とレビュー要の判定 | 切れ目の判定（正） |
| タスクの構成: 1 枚ずつ・分割はこのスキルが起動・並列禁止 | 手順 2-4 |
| 承認ポイント: このスキルが待つのは MR レビューと未解決スレッドの確認だけ・ヘッドレスは報告して終了 | 手順 3-4・4-5、実行形態ごとの扱い |
| 整合: 提供コマンド経由のみ・直接実行の禁止 | 禁止事項、Script 処理 |
| 整合: リモート読み取りは自由・書き込みは切れ目か宣言内 | 手順 3、手順 1-1 |
| 整合: 片付け後の push・draft 解除は拒否されず再宣言不要 | 手順 0-2（`merge_prep`）、`position` |
| 整合: チケット運用の手順を再掲しない | 禁止事項、参照ナレッジ |
| 非機能: 人間レビューの省略が MR 本文とチャットで分かる | 手順 3-2・3-4 |
| 機構 代替: 単独実行モード・外部委任モードの証跡の弱さの明記 | 実行形態ごとの扱い、`via` |
