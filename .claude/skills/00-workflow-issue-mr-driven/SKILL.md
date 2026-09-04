---
name: 00-workflow-issue-mr-driven
description: >
  開発作業（振る舞いが変わる変更・複数モジュール・テストやレビューが要る変更・.claude/ 配下のアセット変更）を
  issue と draft MR に紐づけてチケット駆動で進める振り分けスキル。タスクの起動順序と切れ目の処理だけを持ち、
  タスクの中身は 10-task-*、操作は 20-common-step-* に委ねる。切れ目の判定・レビュー依頼と完了は boundary.sh が行う。
  Use when the user asks for development work of any size, names an issue or MR, or when 00-workflow-quick-request
  hands over because the request exceeded 軽作業; also on resume when a draft MR and tickets already exist.
---

# 00-workflow-issue-mr-driven — issue と MR に紐づけてタスクを回す

次のタスクを目視で選ばない（`ticket.sh next` と `boundary.sh status` の出力に従う）。`git commit` / `git push` を直接実行せず、`logs/` 配下の進行状態を直接編集せず、draft 解除を直接実行しない（すべて提供コマンド経由。フックが拒否する）。レビュー依頼のコメントを `gh pr comment` / `glab mr note` で直接投稿しない（`boundary.sh request` 経由。進行状態と証跡が結びつかなくなる）。レビュー待ちを `AskUserQuestion` で待たない（応答を終えて次のユーザー発言で再開する）。ユーザーの言葉だけでレビュー完了とみなさない（必ず `boundary.sh complete` を通す）。完了済みチケットを作業中に戻さない（指摘は同じ種類の追加チケット）。承認された範囲を超えて必須フェーズを省略せず、タスクの種類を統合しない。MR 本文・コメント・issue に `wip/` 配下のパスを恒久的な参照として書かない。サブエージェントを入れ子で起動しない。チケットの着手・完了・作業ログ・DoD の手順を再掲しない。**MR をマージしない**。

## 目的

依頼をコードに触る前に issue と draft MR に結び付け、タスク（同じ種類のチケット群）を 1 つずつ回して、切れ目ごとにレビューを挟む。最後は全体まとめの draft 解除で停止する。

- 要件: `.claude/docs/00_requirement/skills/00-workflow-issue-mr-driven.md`
- 仕様（正。対応表・フェーズ列テンプレート・手順 0〜5・`boundary.sh` の全サブコマンド・BD001〜BD005）: `.claude/docs/10_spec/skills/00-workflow-issue-mr-driven.md`
- 対になる振り分け: `00-workflow-quick-request`（issue と MR を作るまでもない軽作業。判定表は同スキルの手順 0 が正）

引き継ぎ項目（`00-workflow-quick-request` からの切り替え時。同じ名前で受け取る）: `summary`（依頼の要約 1〜2 行）/ `acceptance`（受け入れ条件）/ `issue_kind`（issue のラベル種別）/ `asset_type`（アプリ / AI アセット）。検索語とフェーズ列は渡されない（全体計画が組み立てる）。

## タスクの種類 → スキル名の対応表（正）

| # | type | タスク名 | 種別 | 担当 | スキル名 |
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

- 実体は `.claude/hooks/config/task-types.tsv`。type → スキル名の解決は **`ticket.sh next` だけ**が行い、`boundary.sh status` はその出力を透過する
- 計画 / 実施の対: 2-3、4-5、6-7、9-10、11-12、13-14。片方だけの採用は不可
- 表の `#` は行番号であって実行順序ではない

**フェーズ列のテンプレート**（issue の種別は全体計画が判定する）:

| issue の種別 | フェーズ列 |
|---|---|
| アプリ（`apl/<アプリ名>/` の設計文書・ソースコードの変更が主目的） | 全体計画 → 調査 → 設計 → 実装・テスト → フィードバック計画 → （設計反映 / AI アセット設計 / AI アセット実装・テスト: フィードバック計画で決める）→ 全体まとめ |
| AI アセット（`.claude/` 配下の変更が主目的） | 全体計画 → 調査 → AI アセット設計 → AI アセット実装・テスト → フィードバック計画 → （追加の AI アセット設計 / AI アセット実装・テスト）→ 全体まとめ |

全体計画・調査・フィードバック計画・全体まとめは必ず含める。やることの無いフェーズは計画チケットの「対象なし」で即完了する（省かない）。

## 手順

### 手順 0: 状態確認と再開判定

1. `bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh status` を実行し、`mr` / `current` / `next` / `at_boundary` / `review.state` / `position` を得る（`position` は `in_task` / `before_request` / `requested` / `completed` / `merge_prep` / `none`）
2. `mr` があり作業領域にチケットがある → **再開**。全体計画をやり直さず `position` から続ける
   - `in_task` → 手順 2 のタスク起動（作業中チケットの続き）
   - `before_request` → 手順 3
   - `requested` → レビュー完了の連絡が無ければ応答を終える（全体まとめの `--final` 待ちも同じ。連絡後は `complete --final` を通してから `10-task-overall-summary` の手順 9 から続け、統括レポートと本文の書き写しをやり直さない）
   - `completed` → 手順 4 の指摘の扱いから
   - `merge_prep` → `10-task-overall-summary` の `finalize.sh release` を再実行
3. 開始・再開のどちらでも `git fetch origin` し、`git rev-list --count HEAD..origin/<default>` が 0 でなければ default に未取り込みのコミットがあることを伝え、`git merge origin/<default>` での取り込みを提案する（衝突が無くても知らせる。取り込みは承認後）
4. チケットも MR も無い → 現在ブランチが default 以外なら `AskUserQuestion` で「default ブランチに切り替えて開始 / このブランチのまま / 中断」を確認する。default（または確認済み）なら手順 1 へ

### 手順 1: 全体計画チケットの配置と全体計画タスク

1. `bash .claude/skills/20-common-step-ticket/scripts/ticket.sh create overall-plan` で全体計画チケットを作る（やってよいこと: `wip/`・issue の起票と追記・ブランチと MR の作成・push）→ `ticket.sh start`。この時点で作業領域にチケットがあるので、以降のプロンプトで振り分けの再宣言は求められない
2. `10-task-overall-plan` を Skill ツールで読み込み、メインエージェント自身で実施する（issue の確定・ブランチと draft MR・フェーズ列と方針の合意・最初の計画チケットまで。承認①②③はそのタスクの中）
3. 結果が「対応なし」→ `ticket.sh cancel <番号> --reason <理由>` で取り消して停止。「issue の起票だけ」→ 同様に取り消し、着手の指示を待つ
4. 全体計画チケットが完了したら手順 3 へ

### 手順 2: タスクの起動（ループ）

`boundary.sh status` の `next` が null になるまで繰り返す。

1. `next.type` を対応表で引く。対応するスキルが無ければ「type 定義とスキルの不整合」として報告して停止する
2. 担当がメインエージェント（`overall-plan` / `feedback-plan` / `overall-summary`）→ そのスキルを Skill ツールで読み込み、自身で実施する
3. 担当がサブエージェント → `assets/subagent-prompt.template.md` から指示文を作り、Agent ツールで `task-executor` を起動する（モデルはチケットの `executor`）。指示文には issue / MR の番号と URL、**作業中のブランチ名**、読み込むスキル名、対象チケットの番号、結果報告の形式、禁止事項の要点（入れ子起動禁止・並列禁止・push と MR 操作をしない）を書く。**ブランチ名を必ず書く**のは、サブエージェントに与えられる環境の情報がセッション開始時点のもので、その後のブランチ切り替えが反映されないためである
4. タスクから「チケットの実行者がタスクのモデルと異なる / 新しいコンテキストで実施したい」という要求が返ったら、そのチケット 1 枚を対象にした指示文で別のサブエージェントを起動する（1 枚ずつ。並列に起動しない）
5. 結果報告を受け取る。「状態の不整合」「承認が必要」「差し戻し提案」が含まれていればユーザーに提示し、指示に従って追加チケットを起こすか停止する
6. サブエージェントが結果報告を返さずに終わった（失敗・中断）→ `ticket.sh next` で `current` を確認し、作業中のまま残ったチケットの番号と作業ログの現在地を報告して指示を待つ（勝手に完了・取り消ししない）
7. `boundary.sh status` を再実行し、`at_boundary` が true なら手順 2a を経て手順 3 へ、false なら 1 へ

### 手順 2a: 敵対的レビュー（切れ目の前）

タスク層の承認者は「人間 or 敵対的レビューエージェント」。切れ目に達したら、push と人間レビューの前に次を行う。

1. そのタスクに敵対的レビューを挟むかを決める: チケットの `adversarial_review` があればそれ、無ければ `.claude/rules/work-defaults.md` の既定。実施回数の上限は同ルールが持つ（既定 1 回）
2. 要なら `git diff <base>..HEAD` を `wip/tmp/adversarial-<n>.patch` に書き出す（`base` は前の切れ目の `head_sha`、無ければ開始コミット）。対象ファイルに効く成果物ルール（`.claude/rules/` の観点章）から観点を集め、`assets/adversarial-review-prompt.template.md` で `adversarial-reviewer` を Agent ツールで起動する（読み取り専用）
   - **起動の前にモデルを突き合わせる**: レビュー対象を作った実行者（完了したチケットの `executor`。メインエージェントが実施したタスクは自分のモデル）とエージェント定義の `model` が同じなら、Agent ツールの `model` で別のモデルに差し替える。差し替えたら手順 5 のコメントにモデル名を添える
3. 返った指摘のうち `confidence >= 0.5` を採用し、一覧を `boundary.sh note --body-file <path>` でマーカー付きの通常コメントとして MR に残す（人間の指摘と同列に扱う）
4. 採用した指摘が 1 件以上 → 手順 4-4 と同じ要領で同じ種類の追加チケットを起こし（次の計画チケットの `predecessors` にも加える）、手順 2 へ戻る。上限回数に達した後の指摘は追加チケットにせず、レビュー依頼の「見てほしい点」に転記して人間に委ねる
5. 0 件、または不要 → 手順 3 へ。実施の有無と件数は MR 本文の「変更点」の行に添える（`（敵対的レビュー: 指摘 2 件 → 追加チケット 0009）` / `（敵対的レビュー: 省略）` / `（敵対的レビュー: 実行者と同じモデルのため <モデル名> で実施）`）

### 手順 3: 切れ目の処理

`at_boundary` のときに行う。順序は固定。

1. **push**: `bash .claude/skills/20-common-step-commit-push/scripts/push.sh`（前チェック込み。作業中チケットが無いので拒否されない）
2. **レビュー省略の記録**: `last_task.review_required` が false なら先に `boundary.sh skip --reason "<理由>"` で省略を記録する（記録だけで外部への効果は無い）
3. **MR 本文の更新**: 現在の本文を取得 → `## 変更点` に `- <タスク名>（チケット <番号範囲>）: <成果の要約 1〜2 行>` を追記 → 送信の直前に本文を再取得して一致を確認してから `gh pr edit --body-file`（GitLab は `20-common-step-issue` の「GitLab の長文送信」）。一致しなければ人間が編集した可能性があるので取り込み直して再試行する。人間レビューを省略する切れ目なら行末に `（人間レビュー省略: <理由>）` を付ける。`wip/` 配下のパスを書かない
4. **承認・判断の書き写し**: このタスクの間にチャットで受けた承認・判断・保留点への回答があれば `assets/decision-note.template.md` で本文を作り、`boundary.sh note --body-file <path>` で MR の通常コメントとして投稿する。無ければ省く
5. **レビュー要否の分岐**: `last_task.review_required`（そのタスクのチケットに 1 枚でも「人間レビュー要」）が
   - true → `assets/review-request.template.md` で本文を作り、`boundary.sh request --body-file <path>` を実行する。成功したらチャットで「タスク X を push しレビューを依頼した。完了したら知らせてほしい」と報告して**応答を終える**
   - false → チャットで「人間レビューを省略して次のタスクに進む（理由）」と報告して手順 5 へ

### 手順 4: レビュー完了

レビュー完了の連絡（次のユーザー発言）を受けたら:

1. ユーザーがチャットでレビュー判断を伝えた場合は、先にその内容を `boundary.sh note --body-file <path>` で MR の通常コメントに記録する
2. `boundary.sh complete` を実行する。通れば `completed` になり、依頼以降の指摘が JSON で返る
3. 指摘 0 件・未解決スレッド無し → 手順 5 へ
4. 指摘あり → 全件を提示し、**すべて**を同じ種類の追加チケットとして `ticket.sh create` で起こす（DoD は指摘の内容、実行者・レビュー要否は元のタスクと同じ。1 指摘 1 項目で 1 チケットにまとめてよい）。続けて、未着手にある**次のフェーズの計画チケットの `predecessors` に追加チケットの番号を加える**。`ticket.sh next` は先行が未完了のチケットを飛ばすので、連番が大きい追加チケットが次に走る。手順 2 に戻る
5. `complete` が BD003（未解決スレッドあり / 変更要求あり）で止まった → スレッドの URL と要旨を提示し、MR 上で resolve することを勧める。`AskUserQuestion` で「resolve してもらってから再実行 / このまま次のタスクに進む / 追加チケットにする」を確認する。「このまま進む」なら `boundary.sh complete --accept-unresolved`、「追加チケット」なら 4 と同じ

### 手順 5: 次のタスクへ

1. 未着手（`00_todo/`）チケットの範囲・実行者・レビュー要否・DoD を、レビュー結果や新しい知見に応じて直してよい。変更したらチャットで伝える（作業中・完了のチケットは触らない）
2. 手順 2 へ。`next` が null（全チケット完了）なら、最後のタスクは全体まとめのはずなので `finalize.sh release` の結果を確認して停止する（マージしない）。全体まとめ以外で null になったら不整合として報告する

## 実行形態ごとの扱い

- **ヘッドレス**（`claude -p`・CI）: タスクの中の承認が必要になった時点で内容を報告してセッションを終える。切れ目で `request` を実行したらそのセッションの応答は完了。次回セッションで手順 0 から再開する。1 セッションで全タスクを完走することは想定しない
- **外部委任モード**（`command -v gh` / `glab` が失敗）: MR の読み書きを MCP ツールで代行し、`boundary.sh` には結果をフラグで渡す（`request --external --comment-url <url>`、`complete --external --report-file <json>`）。`WebFetch` / `curl` へ落とさない。状態に `via: external` が残り、証跡の強度が劣ることを結果報告に明記する
- **単独実行モード**（issue と MR を作らずチケット駆動だけを試す）: `boundary.sh request --standalone` / `complete --standalone` で、MR への投稿の代わりにチャット上の確認を証跡として記録する（`via: chat`）

## 参照

- 提供コマンド: `scripts/boundary.sh`（`status` / `note` / `request` / `skip` / `complete`。進行状態は `logs/review-state.json`。直接編集はフックが拒否する）
- チケット操作・`next` の出力: `20-common-step-ticket`
- push・前チェック: `20-common-step-commit-push`
- MR 本文の長文送信・`--paginate`・ホスト判定: `20-common-step-issue`
- ブランチと draft MR: `20-common-step-feature-mr`
- 各タスクの中身: `10-task-*`（計画型の共通手順の正は `10-task-investigation-plan`、実施型の正は `10-task-investigation-exec`）
- エージェント定義: `.claude/agents/task-executor.md` / `.claude/agents/adversarial-reviewer.md`
- 実行者・レビュー要否・敵対的レビュー要否の既定: `.claude/rules/work-defaults.md`
- テンプレート: `assets/subagent-prompt.template.md` / `assets/review-request.template.md` / `assets/decision-note.template.md` / `assets/adversarial-review-prompt.template.md`

## エラー時の対処

| 状況 | 対処 |
|------|------|
| `next.type` に対応するスキルが無い | type 定義とスキルの不整合として報告して停止する。目視で別のスキルを選ばない |
| `boundary.sh request` が BD001 | 未充足（未コミット / 未 push / MR なし / 切れ目でない / 既に requested）を解消して再実行する |
| `boundary.sh complete` が BD003 | 手順 4-5 に従う。状態ファイルを直して通そうとしない |
| `boundary.sh status` が BD005（矛盾の検出） | 提示された矛盾を解消する。`logs/` を直接編集しない |
| `git commit` / `git push` / `gh pr ready` がフックに拒否された | 迂回しない。提供コマンド（`commit.sh` / `push.sh` / `finalize.sh release`）に切り替える |
| サブエージェントが結果報告を返さずに終わった | 勝手に完了・取り消ししない。作業中チケットの番号と現在地を報告して指示を待つ |
| ヘッドレスで承認が必要になった | 内容を報告してセッションを終える。次回セッションで手順 0 から再開する |
| `gh` / `glab` が使えない | 外部委任モード（`--external`）に切り替える。`WebFetch` / `curl` へ落とさない |
| default ブランチが進んでいる | 承認を得て `git merge origin/<default>` で取り込む。`git rebase` は使わない |
| 依頼が軽作業だと分かった | `00-workflow-quick-request` を Skill ツールで読み込んで切り替える |
