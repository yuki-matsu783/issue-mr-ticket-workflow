---
type: ticket
ticket_type: overall-summary
predecessors: ["0033", "0034", "0035", "0036"]
executor: main
human_review: {required: true, reason: "片付け・draft 解除の前の最終確認（work-defaults の既定。承認③と⑥は人間）"}
adversarial_review: {required: false, reason: "統括のみ（work-defaults の既定）"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "remote-write:issue-create", "remote-write:mr-edit", "remote-write:mr-comment", "remote-write:attach", "remote-write:push", "remote-write:draft-ready", "merge-base"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0037 全体まとめ: issue #6（実装 1/3）の統括レポート・PR 本文の最終整形・片付け・issue コメント・draft 解除

## 目的

10-task-overall-summary 仕様の処理フロー 2〜9 を、finalize.sh 未作成のため手作業代替で順に行う: 2 別 issue 起票（フィードバック計画 0022 の別 issue 候補 16 件 + 設計・実装の作業ログの「AI アセットに反映すべき内容」から本文案を作り、承認を得て 20-common-step-issue で起票。承認④の範囲外なので本文案を提示して停止する）→ 3 衝突確認（git fetch origin。あれば承認を得て git merge origin/main）→ 4 統括レポート wip/30_reports/0037-overall-summary.md（+ HTML。受け入れ条件 1〜7 との対応、各タスクのレビュー結果、残課題、別 issue 一覧、issue の「ルール 14 本」と要件 15 本の食い違いの注記、このチケットの DoD × 根拠の表）→ 5 PR #7 本文の「## 統括」節 → 6 HTML 添付コメント 1 件と本文への URL 追記（アップロードできなければ片付け前コミットのリンクで代替）→ 7 push → 8 承認③（最終確認: 片付け〜draft 解除に進む）→ 9 片付け（wip/ の .gitkeep 以外を削除しコミット・push）→ 最終ゲート（fetch して遅れ・衝突なし）→ gh pr ready。issue #6 へのコメントは仕様に無いので行わない。マージは人間

## DoD

- [ ] 別 issue の本文案（候補ごとに 1 件、または束ねる理由）を提示して承認を得てから起票し、番号と URL が統括レポートにある。起票しないものは「追加の反映なし」と確認した範囲を統括レポートに書いている（根拠: ）
- [ ] git fetch origin で default（main）との衝突を確認し、結果（無し / 取り込んだ内容）が作業ログと統括レポートにある（根拠: ）
- [ ] 統括レポート wip/30_reports/0037-overall-summary.md（+ HTML、check-html.sh OK）があり、受け入れ条件 1〜7 との対応（タスク・テスト ID）、各タスクのレビュー結果（opus 代替の記録）、残課題（2/3・3/3 への申し送り）、別 issue 一覧、「ルール 14 本」と要件 15 本の注記、このチケットの DoD × 根拠の表が入っていて、push されて履歴に載っている（片付け前のコミットのリンクを控える）（根拠: ）
- [ ] PR #7 の本文に「## 統括」節（統括レポートの要約）があり、HTML 添付のコメント 1 件（または代替のリンク）と本文への URL 追記が済んでいる（根拠: ）
- [ ] 承認③（片付け〜draft 解除に進む）を AskUserQuestion で得てから、wip/ の .gitkeep 以外を削除してコミット・push し、fetch して遅れ・衝突が無いことを確認して gh pr ready を実行した。削除件数と最終ゲートの結果が PR コメントにある。マージは行っていない（根拠: ）

## 作業内容

- 10-task-overall-summary 仕様（処理フロー 2〜9・finalize.sh の手順）と 00-workflow-issue-mr-driven 仕様の完了処理を読み、手作業代替の各手順を順に行う。承認（別 issue 本文・衝突取り込み・③）は AskUserQuestion
- 統括レポートは 20-common-step-report-view の手順で md + HTML。DoD × 根拠の表を写す（片付けでチケットが消えるため）

## 作業ログ

### 現在地

- 未着手

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
