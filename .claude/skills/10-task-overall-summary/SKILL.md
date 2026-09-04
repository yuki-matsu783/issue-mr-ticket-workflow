---
name: 10-task-overall-summary
description: >
  全体まとめタスク。別 issue の起票 → 衝突解消 → 統括レポート → MR 本文の最終化 → push → レビューまでを固定順で行い、
  完了検査から draft 解除までを finalize.sh release の 1 コマンド（8 段階・再実行で続きから）に任せて停止する。
  マージはしない。GitHub への HTML 添付は AI が行わない。
  Use when ticket.sh next returns type "overall-summary" (the last task of an issue), or when resuming from
  logs/merge-state.json after a finalize.sh release failed partway.
---

# 10-task-overall-summary — issue の作業を締めて draft を解除する

サブエージェントに委譲しない（承認が続けて挟まるのでメインエージェント専任）。手順の順序を入れ替えず、済んだ手順をやり直さない（二重起票・二重添付を防ぐ）。作業中の issue に書き込まない（コメントを含む一切。情報は MR 本文で揃える）。成果物のリンクを列挙した**通常コメントを投稿しない**（本文の `## 統括` 配下に置く）。**GitHub への HTML 添付を AI が行わない**（`uploads.github.com` への `curl`、web ルートの再現を含む）。rebase・片側丸ごと採用の衝突解消をせず、承認なしで衝突を解消しない。MR をマージせず、`gh pr ready` / `glab mr update --ready` を直接実行しない（`finalize.sh release` の段階 7 経由のみ）。ソースコード・設計文書・`.claude/` 配下に書き込まない（衝突解消の取り込みで生じる変更を除く）。進行状態（`logs/` のファイル）を直接編集しない。`.claude/docs/` へ書き写さない（残すべき内容が未反映なら別 issue 起票に回す）。

## 目的

issue の作業をたたんで、成果物が後から辿れる形にしてから draft を解除する。マージは人間が行う。

- 要件: `.claude/docs/00_requirement/skills/10-task-overall-summary.md`
- 仕様（正。処理フロー 1〜10・`finalize.sh release` の 8 段階・FN001〜FN003）: `.claude/docs/10_spec/skills/10-task-overall-summary.md`

## 手順

1. **着手**: `bash .claude/skills/20-common-step-ticket/scripts/ticket.sh start <番号>`（宣言はレポート・チケット・`wip/tmp/` と、別 issue 起票・衝突取り込み・push・MR 本文の編集・draft 解除。GitHub での HTML 添付は AI が行わないので宣言に含めない）
2. **別 issue 起票**: フィードバック計画より後のタスクの作業ログ・レポートから反映すべき内容（改善候補・スコープ外の気づき）を集める。あれば本文案の承認を得て `20-common-step-issue` で起票する。無ければ「追加の反映なし」と確認範囲を統括レポートに書く
   - **承認は候補の一覧を 1 回**で取る（1 件ずつ聞かない）。一覧には各候補の「タイトル案・1 行の要旨・出どころ（チケット番号と作業ログの節）」を並べ、「全部起票 / 一部だけ（番号を指定）/ 起票しない」から選んでもらう
   - **ヘッドレス実行では起票せず**、候補の一覧を統括レポートに書いて次の手順へ進む（承認が要る外部への副作用を無断で起こさない）
3. **衝突解消**: `git fetch origin` して default との衝突を確認する。無ければ承認なしで次へ。あれば衝突ファイルと解消方針を提示して承認を得てから `git merge origin/<default>` で取り込み、解消してコミットする（方針が一意でなければ両側の意図を要約して判断を仰ぐ）
4. **統括レポート**: `wip/30_reports/` に md + HTML（`20-common-step-report-view` の手順）で 1 つ作る。内容は 受け入れ条件との対応（どのタスク・テストで満たしたか）/ 各タスクのレビュー結果（省略はその旨）/ フィードバック計画の対応（この MR / 別 issue / 対応しない）/ 残課題
5. **MR 本文の最終化**: 統括レポートの要約（受け入れ条件との対応・残課題・別 issue 一覧）を、MR 本文の見出し `## 統括` の節として書き写す。GitHub は `gh pr edit --body-file`、GitLab は `20-common-step-issue` の「GitLab の長文送信」の API 経由。`wip/` 配下のパスを恒久参照として書かない
6. **成果物のリンク一覧と HTML 添付**: 成果物の所在は**通常コメントではなく MR 本文**で辿れるようにする
   - **リンク一覧（必須）**: `wip/30_reports/` の HTML レポートへのリンクを `## 統括` 配下の**表**（レポート名 / 1 行説明 / リンク）に置く。リンクは片付け直前の SHA に固定した blob URL を使うため、**書き込みは `finalize.sh release` の段階 4 が行う**。手順 5 と 6 では本文の要約だけを書き、リンク一覧の場所を空けておく
   - **HTML の添付（任意。GitHub）**: 添付は**人間がブラウザで MR 本文に対して行う**。**AI はこの手順で何もしない**（待たない・催促しない・URL を受け取る手続きも持たない）。GitHub の API は `.html` を受け付けず、ブラウザ側の経路はセッション Cookie と CSRF トークンを要求するため API トークンでは再現できない
   - **HTML の添付（任意。GitLab）**: `glab api "projects/:id/uploads" --form "file=@<ファイル>"` は公式の API なので、AI が添付して返された markdown リンクを本文に書いてよい
   - 添付が無くてもリンク一覧が本文にある以上、成果物は辿れる。**添付の有無で分岐しない**
7. **push**: `bash .claude/skills/20-common-step-commit-push/scripts/push.sh` で push し、統括レポートを履歴に載せる（片付けで消える前に、リンク一覧が指す先を実在させるため）
8. **レビュー（要の場合のみ）**: `boundary.sh request --final` で依頼し（全体まとめチケットは作業中のままなので `--final` が要る）、完了連絡を受けて `boundary.sh complete --final` が通ってから次へ。レビュー不要なら `boundary.sh skip --final --reason <理由>`
9. **完了検査から draft 解除まで**: `bash .claude/skills/10-task-overall-summary/scripts/finalize.sh release` を実行する。前提検査 → 完了検査 → 完了検査の書き出しと push → SHA の確定と本文のリンク一覧の更新 → 片付け → push → 最終ゲート → draft 解除 を 1 コマンドで連続実行する。途中で失敗したら**同じコマンドの再実行**で続きから進む
10. **報告**: 結果（issue・MR 番号、別 issue 一覧、衝突解消の有無、片付けの件数）と、`pre_cleanup_sha` から組み立てた作業領域リンクを報告して**停止する**。マージしない

再開時は `logs/merge-state.json` の `state`（`started` → `recorded` → `linked` → `cleaned` → `pushed` → `ready`）から続きを行う。記録が無い・壊れている場合は `release` が実態から再導出して書き戻す。

### CLI が使えない環境

`gh` / `glab` のどちらも使えないときは、段階 4（本文のリンク一覧）と段階 7（draft 解除）だけを呼び出し元が代行する。

- 段階 4: `release --external --pr <M> --body-file <path>` でリンク一覧と固定マーカーを `<path>` に書き出す。MCP ツールで本文を更新したあと `release --external --pr <M> --linked` で再開する
- 段階 7: MCP ツールで draft を解除したうえで `release --external --pr <M>` を実行すると、最終ゲートの検査だけを行って `ready` にする
- `--external` は `via: "external"` を残す。`gh` 自身が確認する強度より劣ることを統括レポートに明記する。`curl` / `WebFetch` へ落とさない

### 全体まとめチケットの DoD の型

全体まとめチケットは `ticket.sh complete` を通れない（TK005）。DoD は `finalize.sh release` の段階 2 が検査し、結果を統括レポートの「完了検査」節へ書き出す。

- 「別 issue に起票すべき内容を確認し、起票したか『追加の反映なし』を統括レポートに書いた」
- 「default ブランチとの衝突を確認し、あれば承認を得て解消した」
- 「統括レポート（md + HTML）があり、受け入れ条件との対応・各タスクのレビュー結果・フィードバック計画の対応・残課題の 4 つが埋まっている」
- 「MR 本文の `## 統括` 節に統括レポートの要約が書き写されている」
- 「issue の受け入れ条件 {{X}} が、どのタスク・どのテスト ID で満たされたかを根拠付きで示している」
- 「作業領域に残る成果物のうち、`.claude/docs/` に残すべきものが無いことを確認した（あれば別 issue の起票に回した）」

根拠欄には**チケット番号・レポートの節・テスト ID**を書く。`wip/` 配下のパスは片付けで消えるので恒久参照として書かない。

## OUT ひな形

- 統括レポート: `20-common-step-report-view` のレポートテンプレート（節は手順 4 の内容 + 「完了検査」節。後者は release の段階 2・3 が書き出す）
- 本文の `## 統括` 節: `assets/summary-section.template.md`（受け入れ条件との対応の表 / 残課題 / 別 issue 一覧 / 成果物のリンク一覧の表。表の中身は release の段階 4 が埋める）
- 添付コメントのテンプレートは持たない（リンク一覧は本文に置き、コメントは投稿しない）

## 参照

- 提供コマンド: `scripts/finalize.sh`（このスキルが所有する。進行状態は `logs/merge-state.json`。直接編集はフックが拒否する）
- チケット操作・完了検査: `20-common-step-ticket`
- レポートの HTML と検査: `20-common-step-report-view`
- コミットと push: `20-common-step-commit-push`
- issue の起票・GitLab の長文送信: `20-common-step-issue`
- レビュー依頼と完了確認: `00-workflow-issue-mr-driven` の `boundary.sh`（`--final`）

## エラー時の対処

| 状況 | 対処 |
|------|------|
| `finalize.sh` が `FN001`（前提未充足） | 列挙された未充足を解消する（チケットの継続・レポート作成・本文の最終化・push）。状態ファイルを直さない |
| `finalize.sh` が `FN002`（完了検査未充足） | 全体まとめチケットの DoD・作業ログ・根拠欄を埋めてから再実行する |
| `finalize.sh` が `FN003`（最終ゲート未充足） | 手順 3 の要領で承認を得て `git merge origin/<default>` し、`release` を再実行する。統括レポート・本文はやり直さない |
| 途中で失敗した | 同じ `release` を再実行する。記録済みの段階は飛ばして続きから進む |
| GitHub に HTML を添付したい | AI は行わない。人間がブラウザで本文に添付する。API での添付を試みない |
| ヘッドレスで別 issue の承認が取れない | 起票しない。候補の一覧を統括レポートに書いて次の手順へ進む |
| `gh` / `glab` が使えない | 段階 4 と段階 7 を `--external` で呼び出し元に代行させる。`curl` / `WebFetch` へ落とさない |
| draft を解除したくなった | `gh pr ready` を直接実行しない（フックが拒否する）。`finalize.sh release` の段階 7 経由のみ |
