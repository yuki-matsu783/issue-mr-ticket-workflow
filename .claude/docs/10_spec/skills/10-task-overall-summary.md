---
type: spec
title: 10-task-overall-summary スキル 仕様
description: 全体まとめタスクの内部仕様。固定順序の処理フロー、finalize.sh（cleanup / ready）のインターフェースと検査、HTML レポートの MR 添付の実現方法（GitLab uploads / GitHub は不可）、logs/ のマージ前進行状態、エラー識別子（FN0xx）を定める
tags: [spec, skill, task]
keywords: [全体まとめ, finalize.sh, cleanup, ready, 片付け, draft 解除, 添付, uploads, 統括レポート, logs, FN0xx]
---

# 10-task-overall-summary スキル 仕様

## 概要・禁止事項

全体まとめタスクの内部仕様。対応する要件は [00_requirement/skills/10-task-overall-summary.md](../../00_requirement/skills/10-task-overall-summary.md)。

固定順序（別 issue 起票 → 衝突解消 → 統括レポート → MR 本文の最終化 → HTML 添付 → 片付け → push → draft 解除）で issue の作業を締める。片付けと draft 解除はこのスキルが持つ `finalize.sh` が担い、進行状態を `logs/` に記録する。

禁止事項:

- サブエージェントへの委譲（承認が続けて挟まる。メインエージェント専任）
- 手順の順序の入れ替え、済んだ手順のやり直し（二重起票・二重添付）
- 作業中の issue への書き込み（コメント含む一切。情報は MR 本文と添付で揃える）
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
| フィードバック計画より後の全チケットの作業ログ・レポート、issue の受け入れ条件、各タスクのレビュー結果 | 起票された別 issue（あれば）、衝突解消済みのブランチ、統括レポート（md + HTML）、最終化された MR 本文、先頭コメントへの HTML 添付（可能な環境）、空になった作業領域、draft 解除済みの MR、停止（マージは人間） |

## IN / OUT サンプル

```bash
bash .claude/skills/10-task-overall-summary/scripts/finalize.sh cleanup
# => OK: チケット 0009 を完了し、作業領域 14 ファイルを削除してコミットした
bash .claude/skills/10-task-overall-summary/scripts/finalize.sh ready
# => FN003: draft を解除できない。未充足: origin/main が 2 コミット進んでいる（取り込みが必要）
```

## 処理フロー

1. **着手**: `ticket.sh start` で全体まとめチケットに着手する（宣言: レポート・チケット・`wip/tmp/` と、別 issue 起票・添付・衝突取り込み・push・draft 解除）
2. **別 issue 起票**: フィードバック計画より後のタスクの作業ログ・レポートから反映すべき内容（改善候補・スコープ外の気づき）を集め、あれば本文案の承認を得て `20-common-step-issue` で起票する。無ければ「追加の反映なし」と確認範囲を統括レポートに書く
3. **衝突解消**: `git fetch origin` して default との衝突を確認する。無ければ承認なしで次へ。あれば衝突ファイルと解消方針を提示して承認を得てから `git merge origin/<default>` で取り込み、解消してコミットする（方針が一意でなければ両側の意図を要約して判断を仰ぐ）
4. **統括レポート**: `wip/30_reports/` に md + HTML（report-view の手順）で 1 つ作る。内容: 受け入れ条件との対応（どのタスク・テストで満たしたか）/ 各タスクのレビュー結果（省略はその旨）/ フィードバック計画の対応（この MR / 別 issue / 対応しない）/ 残課題
5. **MR 本文の最終化**: 統括レポートの要約（受け入れ条件との対応・残課題・別 issue 一覧）を MR 本文に書き写す。GitHub は `gh pr edit --body-file`、GitLab は issue 仕様「GitLab の長文送信」の API 経由（`wip/` 配下のパスを恒久参照として書かない）
6. **HTML 添付**: 環境判定の上、作業領域の全 HTML レポートを MR の先頭コメントに添付する:
   - GitLab: `glab api "projects/:id/uploads" --form "file=@<ファイル>"` でアップロードし、返された markdown リンクを列挙したコメントを先頭コメントとして投稿する
   - GitHub: PR コメントへのファイル添付を CLI / API から行う手段が無いため「添付できない環境」と判定し、省略の事実と本文の要約で代替していることを MR 本文に書く
7. **（レビュー要の場合のみ）** ここで push してレビューを依頼し、完了連絡（未解決スレッドの確認込み）を受けてから次へ
8. **片付け**: `finalize.sh cleanup` を実行する（下記）
9. **push**: `push.sh` で push する（チケットが無い状態でも拒否されない）
10. **draft 解除**: `finalize.sh ready` を実行し（下記）、結果（issue・MR 番号、別 issue 一覧、衝突解消の有無、片付けの件数）を報告して停止する。マージしない

## OUT ひな形

- 統括レポート: report-view のレポートテンプレートを使う（節は処理フロー 4 の内容）
- 先頭コメント: `assets/attachment-comment.template.md`（添付の一覧と各レポートの 1 行説明）

## 参照ナレッジ

- 片付けが消す範囲と logs/ の記録: DDR `i0001-22`・`i0001-28`、`20-common-step-ticket` 仕様（完了の内包）
- 衝突解消・ベース追従の方針: DDR `i0001-25`（draft 解除直前の最終ゲート）
- MR 本文の長文送信・`--paginate`: `10_spec/skills/20-common-step-issue.md`

## Script 処理

`scripts/finalize.sh <subcommand>`。進行状態は `logs/merge-state.json`（`{"issue": N, "mr": M, "state": "cleaned" | "ready", "cleaned_at": ..., "ready_at": ...}`）に記録し、直接編集はフックが拒否する。終了コード: 成功 0 / 未充足 1 / 引数・環境 2。ログ: すべてのサブコマンドは共通 logger（`10_spec/lib/logger.md`）を source し、受け付けた操作・判定結果・拒否理由を INFO で、判定材料の詳細を DEBUG で `logs/sh/` に記録する。標準出力には出さない。

### cleanup

1. 前提を検査し、未充足を全件列挙して FN001 で拒否する: 全体まとめチケットが作業中 / それ以外に未着手・作業中のチケットが無い / 統括レポートの md + HTML が存在する / MR 本文の最終化が済んでいる（本文に統括の節がある）
2. 全体まとめチケットの完了検査（`ticket.sh complete` と同じ検査。DoD・作業ログ・根拠欄）を行い、未充足は FN002 で拒否する
3. 完了時刻を記録し、作業領域（`wip/` 配下の全成果物: 全体計画書・チケット・計画書・レポート・ブランチ内の進行状態・`wip/tmp/` の中身。`.gitkeep` は残す）を削除して 1 コミットにまとめ、`logs/merge-state.json` を `cleaned` にする
4. 削除した件数と内訳を出力する

### ready

1. 前提を検査し、未充足を全件列挙して FN003 で拒否する: `merge-state` が `cleaned` / `wip/` が空（`.gitkeep` 除く）/ 未コミットの変更なし / push 済み（HEAD が origin と一致）/ `git fetch` して origin/<default> に対する遅れ・衝突なし（draft 解除直前の最終ゲート）
2. `gh pr ready <M>` / `glab mr update <M> --ready` を実行し、`merge-state` を `ready` にする
3. 解除した MR の番号と URL を出力する

### エラー識別子

| ID | 条件 | メッセージに含める内容 |
|----|------|----------------------|
| FN001 | cleanup の前提未充足 | 未充足の全件と、戻るべき手順（チケットの継続・レポート作成・本文最終化） |
| FN002 | 全体まとめチケットの完了検査未充足 | ticket 仕様 TK003 と同じ列挙 |
| FN003 | ready の前提未充足 | 未充足の全件。ベースの遅れ・衝突なら処理フロー 3 に戻ること |

### テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| FN-T01 | 正常系 | cleanup がチケット完了を内包し wip/ を空にして 1 コミットにする |
| FN-T02 | 異常系 | 他のチケットが残っている cleanup が FN001 |
| FN-T03 | 異常系 | DoD 未充足の cleanup が FN002 |
| FN-T04 | 異常系 | cleaned でない・wip 非空・未 push・base 遅れの ready が FN003 で全件列挙 |
| FN-T05 | 正常系 | ready 後の merge-state が ready になり再実行が冪等 |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: メインエージェント専任 | 禁止事項・呼出条件 |
| メイン: 着手と固定順序 | 処理フロー 1〜10、禁止事項（順序） |
| メイン: 別 issue 起票（承認 → 起票） | 処理フロー 2 |
| メイン: 衝突確認・承認 → merge・rebase 禁止 | 処理フロー 3、禁止事項 |
| メイン: 統括レポート（md + HTML・内容 4 点） | 処理フロー 4 |
| メイン: MR 本文の最終化（書き写し） | 処理フロー 5 |
| メイン: HTML 添付 | 処理フロー 6（GitLab uploads / GitHub 不可判定） |
| メイン: 作業中 issue へ書き込まない | 禁止事項 |
| メイン: 書き写しは MR 本文と添付に限る・未反映は別 issue | 処理フロー 2・5、禁止事項 |
| メイン: 片付け（提供コマンド・完了内包・logs は対象外） | finalize.sh cleanup |
| メイン: 片付け後の push・draft 解除・再宣言不要 | 処理フロー 9・10（entry / guard の継続判定は logs/ の記録） |
| メイン: draft 解除直前の再確認 | finalize.sh ready 1（最終ゲート） |
| メイン: 結果報告と停止・マージしない | 処理フロー 10、禁止事項 |
| 代替: 反映なし・再開・添付不可・draft のまま | 処理フロー 2・呼出条件（logs から再開）・処理フロー 6・ユーザー選択で停止 |
| 代替: レビュー要時の push とレビュー | 処理フロー 7 |
| 例外: 片付け前提未充足・衝突判断・起票/添付失敗 | FN001〜003・処理フロー 3・停止（再試行しない） |
| チケットの扱い（宣言・レビュー既定不要） | 処理フロー 1（宣言）・全体計画の方針 |
| 整合: 提供コマンド経由・進行状態の直接編集禁止 | Script 処理・禁止事項 |
| 整合: draft 解除時の作業領域が空の検査 | finalize.sh ready 1 |
