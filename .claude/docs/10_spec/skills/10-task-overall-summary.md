---
type: spec
title: 10-task-overall-summary スキル 仕様
description: 全体まとめタスクの内部仕様。固定順序の処理フロー、finalize.sh release のインターフェースと段階実行・検査、成果物のリンク一覧を MR 本文に置く方針と HTML 添付を人間に委ねる理由、全体まとめチケットの DoD の型、logs/ のマージ前進行状態、エラー識別子（FN0xx）を定める
tags: [spec, skill, task]
keywords: [全体まとめ, finalize.sh, cleanup, ready, 片付け, draft 解除, リンク一覧, 添付, 統括レポート, 完了検査, DoD の型, logs, FN0xx]
---

# 10-task-overall-summary スキル 仕様

## 概要・禁止事項

全体まとめタスクの内部仕様。対応する要件は [00_requirement/skills/10-task-overall-summary.md](../../00_requirement/skills/10-task-overall-summary.md)。

固定順序（別 issue 起票 → 衝突解消 → 統括レポート → MR 本文の最終化 → 添付の受け取り → push → レビュー → 完了検査 → **SHA 確定とリンク一覧** → 片付け → push → draft 解除）で issue の作業を締める。**完了検査から draft 解除まで**は、このスキルが持つ `finalize.sh release` が 1 コマンドで連続して行い、進行状態を `logs/` に記録する（チケットが無い状態の個別操作を AI に残さないため。失敗時は再実行で続きから）。成果物のリンク一覧が片付け直前の SHA に依存するため、**本文のリンク一覧の書き込みは片付けより前・かつ release の中**に置く（issue #10 追記 3）。

禁止事項:

- サブエージェントへの委譲（承認が続けて挟まる。メインエージェント専任）
- 手順の順序の入れ替え、済んだ手順のやり直し（二重起票・二重添付）
- 作業中の issue への書き込み（コメント含む一切。情報は MR 本文で揃える）
- 成果物のリンクを列挙した**通常コメントの投稿**（本文の `## 統括` 配下に置く。issue #10 追記 1）
- **GitHub への HTML 添付を AI が行うこと**（`uploads.github.com` への `curl`、web ルートの `upload/policies/repository-files` への再現を含む。DDR `i0010-02`）
- rebase・片側丸ごと採用の衝突解消、承認なしの衝突解消
- MR のマージ、`gh pr ready` / `glab mr update --ready` 相当の直接実行（`finalize.sh ready` 経由のみ）
- ソースコード・設計文書・`.claude/` 配下への書き込み（衝突解消の取り込みで生じる変更を除く）
- 進行状態（`logs/` のファイル）の直接編集
- `.claude/docs/` への書き写し（残すべき内容が未反映なら別 issue 起票に回す）

## 呼出条件

- `00-workflow-issue-mr-driven` の `next` が全体まとめチケットを示したとき、メインエージェントが読み込む（フェーズ列の末尾）
- 再開時は `logs/merge-state.json` の進行状態から続きを行う

## IN / OUT

| IN | OUT |
|----|----|
| フィードバック計画より後の全チケットの作業ログ・レポート、issue の受け入れ条件、各タスクのレビュー結果、人間が本文に添付した HTML の URL（あれば） | 起票された別 issue（あれば）、衝突解消済みのブランチ、統括レポート（md + HTML。「完了検査」節を含む）、`## 統括` 節に要約と成果物のリンク一覧の表を持つ MR 本文、空になった作業領域、draft 解除済みの MR、停止（マージは人間） |

## IN / OUT サンプル

```bash
bash .claude/skills/10-task-overall-summary/scripts/finalize.sh release
# => OK: チケット 0009 を完了し 14 ファイルを片付け、push して draft を解除した。レポート: https://github.com/<o>/<r>/tree/<sha>/wip/30_reports
# => FN003: draft を解除できない。未充足: origin/main が 2 コミット進んでいる（取り込んでから release を再実行）
```

## 処理フロー

1. **着手**: `ticket.sh start` で全体まとめチケットに着手する（宣言: レポート・チケット・`wip/tmp/` と、別 issue 起票・衝突取り込み・push・MR 本文の編集・draft 解除。GitHub での HTML 添付は AI が行わないので宣言に含めない）
2. **別 issue 起票**: フィードバック計画より後のタスクの作業ログ・レポートから反映すべき内容（改善候補・スコープ外の気づき）を集め、あれば本文案の承認を得て `20-common-step-issue` で起票する。無ければ「追加の反映なし」と確認範囲を統括レポートに書く。**承認の取り方**: 起票する issue が複数あっても、承認は**候補の一覧を 1 回**で取る（1 件ずつ聞かない）。一覧には各候補の「タイトル案・1 行の要旨・出どころ（チケット番号と作業ログの節）」を並べ、ユーザーは「全部起票 / 一部だけ（番号を指定）/ 起票しない」から選ぶ。ヘッドレス実行では承認が取れないので、候補の一覧を統括レポートに書いて**起票せずに次の手順へ進む**（起票は次のセッションか別 issue で行う。承認が要る外部への副作用を無断で起こさない）
3. **衝突解消**: `git fetch origin` して default との衝突を確認する。無ければ承認なしで次へ。あれば衝突ファイルと解消方針を提示して承認を得てから `git merge origin/<default>` で取り込み、解消してコミットする（方針が一意でなければ両側の意図を要約して判断を仰ぐ）
4. **統括レポート**: `wip/30_reports/` に md + HTML（report-view の手順）で 1 つ作る。内容: 受け入れ条件との対応（どのタスク・テストで満たしたか）/ 各タスクのレビュー結果（省略はその旨）/ フィードバック計画の対応（この MR / 別 issue / 対応しない）/ 残課題
5. **MR 本文の最終化**: 統括レポートの要約（受け入れ条件との対応・残課題・別 issue 一覧）を、MR 本文の見出し `## 統括` の節として書き写す。GitHub は `gh pr edit --body-file`、GitLab は issue 仕様「GitLab の長文送信」の API 経由（`wip/` 配下のパスを恒久参照として書かない）
6. **成果物のリンク一覧と HTML 添付**: 成果物の所在は**通常コメントではなく MR 本文（description）で辿れるようにする**。コメントは流れて見つけにくいためで、**リンクを列挙したコメントの投稿は行わない**（issue #10 追記 1）。
   - **リンク一覧（必須）**: `wip/30_reports/` の HTML レポートへのリンクを、MR 本文の見出し `## 統括` 配下に**表**（レポート名 / 1 行説明 / リンク）で記載する。リンクは片付け直前の SHA に固定した blob URL（`https://<ホスト>/<owner>/<repo>/blob/<SHA>/wip/30_reports/<ファイル>`）を使うため、**この書き込みは `finalize.sh release` の段階 3 が行う**（手順 9。`pre_cleanup_sha` が確定するのがそこであるため）。手順 5 と 6 では本文の要約だけを書き、リンク一覧の場所（見出し `## 統括` 配下）を空けておく
   - **HTML の添付（任意）**: 添付は**人間がブラウザで MR 本文に対して行う**。AI は添付を行わず、人間から渡された URL（`user-attachments/files/<id>/<name>`）を本文に記録するだけにする。GitHub の API（`uploads.github.com/user-attachments/assets`）は `.html` を受け付けず（`content_type is not included in the list of allowed content types`。`image/png` だけが通る）、ブラウザ側の経路はセッション Cookie と CSRF トークンを要求するため API トークンでは再現できない。**AI が API での添付を試みてはならない**（実測の根拠は DDR `i0010-02`）
   - GitLab は `glab api "projects/:id/uploads" --form "file=@<ファイル>"` が使えるので、AI が添付して返された markdown リンクを本文に書いてよい
   - 添付が無くても、リンク一覧が本文にある以上、成果物は辿れる。したがって**添付の有無を代替フローの分岐にしない**（「添付できない環境」という縮退の記述は不要になった）
7. **push**: `push.sh` で push し、統括レポートを履歴に載せる（片付けで消える前に、リンク一覧が指す先を実在させるため）
8. **（レビュー要の場合のみ）** `boundary.sh request --final` でレビューを依頼し（全体まとめチケットは作業中のままなので `--final` が要る — `00-workflow-issue-mr-driven` 仕様）、完了連絡を受けて `boundary.sh complete --final`（未解決スレッドの確認込み）が通ってから次へ。レビュー不要なら `boundary.sh skip --final --reason`
9. **完了検査から draft 解除まで**: `finalize.sh release` を実行する（下記。完了検査 → **SHA の確定と本文のリンク一覧の更新** → 片付け → push → 最終ゲート → draft 解除 を 1 コマンドで連続実行。途中で失敗したら同じコマンドの再実行で続きから進む）
10. **報告**: 結果（issue・MR 番号、別 issue 一覧、衝突解消の有無、片付けの件数）と、`pre_cleanup_sha` から組み立てた作業領域リンクを報告して停止する。マージしない

### 全体まとめチケットの DoD の型

全体まとめチケットは `ticket.sh complete` を通れない（TK005）ので、DoD は `finalize.sh release` の段階 2 が検査し、結果を統括レポートの「完了検査」節へ書き出す（B4）。DoD は次の型で書く（申し送り 0038）:

- 「別 issue に起票すべき内容を確認し、起票したか『追加の反映なし』を統括レポートに書いた」
- 「default ブランチとの衝突を確認し、あれば承認を得て解消した」
- 「統括レポート（md + HTML）があり、受け入れ条件との対応・各タスクのレビュー結果・フィードバック計画の対応・残課題の 4 つが埋まっている」
- 「MR 本文の `## 統括` 節に統括レポートの要約が書き写されている」
- 「issue の受け入れ条件 {{X}} が、どのタスク・どのテスト ID で満たされたかを根拠付きで示している」
- 「作業領域に残る成果物のうち、`.claude/docs/` に残すべきものが無いことを確認した（あれば別 issue の起票に回した）」

根拠欄には**チケット番号・レポートの節・テスト ID**を書く。`wip/` 配下のパスは片付けで消えるので、恒久参照としては書かない（`pre_cleanup_sha` に固定したリンクは release が本文に書く）。

## OUT ひな形

- 統括レポート: report-view のレポートテンプレートを使う（節は処理フロー 4 の内容 + 「完了検査」節。後者は release の段階 2 が書き出す）
- 本文の `## 統括` 節: `assets/summary-section.template.md`（受け入れ条件との対応の表 / 残課題 / 別 issue 一覧 / **成果物のリンク一覧の表**（レポート名・1 行説明・リンク。中身は release の段階 3 が埋める））
- 添付コメントのテンプレートは持たない（リンク一覧は本文に置き、コメントは投稿しないため。issue #10 追記 1）

## 参照ナレッジ

- 片付けが消す範囲と logs/ の記録: DDR `i0001-22`・`i0001-28`、`20-common-step-ticket` 仕様（完了の内包）
- 衝突解消・ベース追従の方針: DDR `i0001-25`（draft 解除直前の最終ゲート）
- MR 本文の長文送信・`--paginate`: `10_spec/skills/20-common-step-issue.md`

## Script 処理

`scripts/finalize.sh <subcommand>`。**実体の置き場は `.claude/skills/10-task-overall-summary/scripts/finalize.sh`**（このスキルが所有する提供コマンド。既存の 5 本と同じく、使うスキルの `scripts/` に置く）。起動は常にリポジトリルート相対表記で行う（`フック共通仕様` §8）。実装済みのフックが `.claude/hooks/finalize.sh` を案内している 3 行（`workflow-state-guard.sh:40, 43` とテスト 2 行）は実装フェーズで直す（一覧は `00-workflow-issue-mr-driven` 仕様「現行アセットとの差分」）。進行状態は `logs/merge-state.json`（`{"issue": N, "mr": M, "state": "started" | "linked" | "cleaned" | "pushed" | "ready", "via": "cli" | "external", "pre_cleanup_sha": ..., "started_at": ..., "linked_at": ..., "cleaned_at": ..., "pushed_at": ..., "ready_at": ...}`）に記録し、直接編集はフックが拒否する。終了コード: 成功 0 / 未充足 1 / 引数・環境 2。ログ: 共通 logger（`20-common-step-shell-script` の `scripts/logger.sh`。内部仕様は `10_spec/skills/20-common-step-shell-script.md`）を使う。使い分けは `rules/logger.md`。

`logs/merge-state.json` が無い・壊れている場合、release は状態を実態から再導出して書き戻してから続ける: `wip/` に成果物があり本文にリンク一覧の表が無い → 未実施（`started` の記録があっても前提検査からやり直す）/ `wip/` に成果物があり本文にリンク一覧の表がある → `linked` / `wip/` が空で HEAD が未 push → `cleaned` / push 済みで MR が draft → `pushed` / MR が draft でない → `ready`。`pre_cleanup_sha` を失った場合は、`wip/` を削除した片付けコミットの親を履歴から特定して再構成する（`logs/` を唯一の正にしない — `i0001-28`）。

### release

本文のリンク一覧の更新から draft 解除までを段階（stage）として順に実行する。各段階の完了を `logs/merge-state.json` の `state`（`started` → `linked` → `cleaned` → `pushed` → `ready`）に記録し、再実行時は記録済みの段階を飛ばして続きから行う（冪等）。

1. **前提検査**（初回のみ）: 未充足を全件列挙して FN001 で拒否する: 全体まとめチケットが作業中 / それ以外に未着手・作業中のチケットが無い / 統括レポートの md + HTML が存在する / MR 本文の最終化が済んでいる（本文に見出し `## 統括` がある — 手順 5 の見出し文字列と一致で判定）/ 統括レポートを含む HEAD が push 済み（片付けで消える前に履歴に載っている）/ 全体まとめチケットが人間レビュー要なら `logs/review-state.json` の最終レビューが `completed`、不要なら `skipped`（`boundary.sh` の記録。`00-workflow-issue-mr-driven` 仕様）
2. **完了検査**（初回のみ）: 全体まとめチケットの完了検査（DoD・作業ログ・根拠欄）を行い、未充足は FN002 で拒否する。検査ロジックは `ticket.sh` の完了検査を共通関数として source して使い、二重実装しない。**検査の結果（DoD 1 件ごとの合否と根拠欄の内容）は統括レポートの「完了検査」節へ書き出す**。全体まとめチケット自身は `ticket.sh complete` を通れない（TK005 が必ず拒否する — `20-common-step-ticket` 仕様）ため、チケットに残る形の完了記録が存在しない。片付けでチケットごと消える前に、検査の通過を統括レポートという残る場所へ写すのがこの段階の役目である（issue #10 追記 4 の受け入れ条件 B4）
3. **片付け直前の SHA の確定と本文のリンク一覧の更新**: 片付け直前の HEAD の SHA を `pre_cleanup_sha` として記録し、その SHA に固定した成果物リンクの一覧（`https://<ホスト>/<owner>/<repo>/blob/<SHA>/wip/30_reports/<ファイル>`）を組み立てて、MR 本文の見出し `## 統括` 配下に**表として**書き込む。`state` を `linked` にする。本文の他の節（処理フロー 5 で書いた要約）は書き換えない。**この段階を片付けより前に置くのは、リンクが `pre_cleanup_sha` に依存するためである**。処理フロー 5（本文の最終化）の時点では片付けがまだ行われておらず SHA が確定しないので、リンク一覧だけをここへ分けている（issue #10 追記 3）
4. **片付け**: 完了時刻を記録して、作業領域（`wip/` 配下の全成果物: 全体計画書・チケット・計画書・レポート・ブランチ内の進行状態・`wip/tmp/` の中身。`.gitkeep` は残す）を削除して 1 コミットにまとめ、`state` を `cleaned` にする
5. **push**: `push.sh` を内部から実行し（前チェック込み）、`state` を `pushed` にする
6. **最終ゲートと draft 解除**: `git fetch` して origin/<default> に対する遅れ・衝突が無いことを検査し、`gh pr ready <M>` / `glab mr update <M> --ready` を実行して `state` を `ready` にする。検査で止まったら（FN003）取り込み（処理フロー 3 の要領で承認を得て merge）を行い、release を再実行する。統括レポート・添付・本文はやり直さない（取り込みが成果物の内容に影響した場合のみ、該当箇所を更新して push してから再実行する）
7. **出力**: 解除した MR の番号と URL、削除した件数、`pre_cleanup_sha` から組み立てた作業領域リンク（GitLab: `https://<ホスト>/<プロジェクト>/-/tree/<SHA>/wip/30_reports`、GitHub: `https://github.com/<owner>/<repo>/tree/<SHA>/wip/30_reports`。コミット固定のため片付け後も辿れる）を出力する

段階と `state` の対応: 前提検査・完了検査 → `started` / リンク一覧の更新 → `linked` / 片付け → `cleaned` / push → `pushed` / draft 解除 → `ready`。

### CLI が使えない環境での release

`gh` / `glab` のどちらも使えない環境では、段階 3（本文のリンク一覧の更新）と段階 6（draft 解除）がリモートに書けない。この 2 段階だけを呼び出し元に代行させる:

- 段階 3: `release --external --pr <M> --body-file <path>` を渡すと、スクリプトはリンク一覧を組み立てて `<path>` に書き出し、`state` を `linked` にせずに終了 0 で戻る。呼び出し元が MCP ツール（`mcp__github__update_pull_request` 等）で本文を更新したあと、`release --external --pr <M> --linked` で再開する
- 段階 6: 呼び出し元が MCP ツールで draft を解除したうえで `release --external --pr <M>` を実行すると、最終ゲートの検査だけを行って `state` を `ready` にする
- `--external` は `logs/merge-state.json` に `via: "external"` を残す。`gh` 自身が確認する強度より劣ることを統括レポートに明記する。`curl` / `WebFetch` へ落とすことはしない（旧 SKILL.md が持っていた外部委任の経路を、`finalize.sh` の該当段階として引き取ったもの）

### エラー識別子

| ID | 条件 | メッセージに含める内容 |
|----|------|----------------------|
| FN001 | release の前提未充足（初回検査） | 未充足の全件と、戻るべき手順（チケットの継続・レポート作成・本文最終化・push） |
| FN002 | 全体まとめチケットの完了検査未充足 | ticket 仕様 TK003 と同じ列挙 |
| FN003 | 最終ゲートの未充足（ベースの遅れ・衝突） | 遅れ・衝突の内容。取り込み（処理フロー 3）後に release を再実行すること |

### テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| FN-T01 | 正常系 | release が完了検査 → リンク一覧の更新 → 片付け → push → 解除を 1 回で行い、状態が ready になる |
| FN-T02 | 異常系 | 他のチケットが残っている release が FN001、DoD 未充足が FN002 |
| FN-T03 | 異常系 | base が進んでいる release が FN003 で止まり、片付けは巻き戻らない |
| FN-T04 | 正常系 | push で失敗した後の再実行が片付けをやり直さず push から続く |
| FN-T05 | 正常系 | ready 後の再実行が何もせず成功する（冪等） |
| FN-T06 | 正常系 | 本文に書き込むリンク一覧が `pre_cleanup_sha` に固定されており、片付けコミットの後もそのリンクから成果物が辿れる（段階 3 が段階 4 より前に走ることを固定する。issue #10 追記 3） |
| FN-T07 | 正常系 | 完了検査の結果（DoD 1 件ごとの合否と根拠）が統括レポートの「完了検査」節に書き出されてから片付けが走る（issue #10 追記 4） |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: メインエージェント専任 | 禁止事項・呼出条件 |
| メイン: 着手と固定順序 | 処理フロー 1〜10、禁止事項（順序） |
| メイン: 別 issue 起票（承認 → 起票） | 処理フロー 2 |
| メイン: 衝突確認・承認 → merge・rebase 禁止 | 処理フロー 3、禁止事項 |
| メイン: 統括レポート（md + HTML・内容 4 点） | 処理フロー 4 |
| メイン: MR 本文の最終化（書き写し） | 処理フロー 5 |
| メイン: 成果物のリンク一覧と HTML 添付 | 処理フロー 6（リンク一覧は本文の `## 統括` 配下の表。書き込みは release 段階 3）・release 段階 3。GitHub での添付は人間がブラウザで行い AI は URL を記録する（DDR `i0010-02`）。GitLab は `glab api uploads` を AI が使ってよい |
| メイン: 作業中 issue へ書き込まない | 禁止事項 |
| メイン: 書き写しは MR 本文と添付に限る・未反映は別 issue | 処理フロー 2・5、禁止事項 |
| メイン: 片付け（提供コマンド・完了内包・logs は対象外） | finalize.sh release 1〜3 |
| メイン: 統括レポートの push（毎回・履歴に載せる） | 処理フロー 7、FN001（push 済み検査）。片付けで消える前にリンク一覧が指す先を実在させる |
| メイン: 全体まとめチケットの DoD の型 | 「全体まとめチケットの DoD の型」節（申し送り 0038） |
| メイン: 完了検査の代替（DoD × 根拠を統括レポートへ） | release 段階 2、`20-common-step-ticket` 仕様 complete 2（TK005 は設計） |
| メイン: 片付け以降は 1 コマンド・個別操作なし・再実行のみ許可 | finalize.sh release 4・5（entry の継続判定は logs/ の記録） |
| メイン: draft 解除直前の再確認 | finalize.sh release 5（最終ゲート） |
| メイン: 結果報告と停止・マージしない・作業領域リンクを添える | 処理フロー 10・finalize.sh release 6、禁止事項 |
| 代替: 反映なし・再開・添付なし・draft のまま | 処理フロー 2・呼出条件（logs から再開）・処理フロー 6（添付は任意。リンク一覧が本文にあるので縮退にならない）・ユーザー選択で停止 |
| 代替: CLI が使えない環境 | 「CLI が使えない環境での release」（段階 3 と 6 だけを `--external` で代行） |
| 代替: レビュー要時のレビュー依頼 | 処理フロー 8（push は 7 で毎回実施済み） |
| 例外: 片付け前提未充足・衝突判断・起票の失敗 | FN001〜003・処理フロー 3・停止（再試行しない） |
| チケットの扱い（宣言・レビュー既定不要） | 処理フロー 1（宣言）・全体計画の方針 |
| 整合: 提供コマンド経由・進行状態の直接編集禁止 | Script 処理・禁止事項 |
| 整合: draft 解除時の作業領域が空の検査 | finalize.sh ready 1 |
