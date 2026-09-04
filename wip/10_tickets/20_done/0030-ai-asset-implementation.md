---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0029"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まず、旧名 0 件は検索で機械的に判定できる"}
allow:
  write: [".claude/skills/00-workflow-issue-mr-driven/**", ".claude/skills/00-workflow-quick-request/**", "wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T12:19:21+09:00"
completed_at: "2026-09-04T12:26:02+09:00"
base_sha: "04efe8d"
---

# 0030 S7 ワークフロースキル 2 本の SKILL.md 改訂（旧名 83 件）

## 目的

旧 00-workflow-* 2 本を新仕様に書き換え、その中で旧名 83 件を置換する

## DoD

- [x] .claude/skills/00-workflow-issue-mr-driven/SKILL.md が新仕様（タスクの種類の対応表・切れ目の処理・boundary.sh の手順）のとおりに書き換わっている（根拠: 15 行の対応表とフェーズ列テンプレート 2 行を仕様から転記し、手順 0〜5 と手順 2a（敵対的レビュー）・実行形態ごとの扱い 3 種を仕様の同名節に対応させた。提供コマンドの起動はすべて `bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh <subcommand>` のリポジトリルート相対表記）
- [x] .claude/skills/00-workflow-quick-request/SKILL.md が新仕様のとおりに書き換わっている（根拠: 手順 0〜6 とヘッドレスの扱いを仕様の処理フローに対応させ、判定表 7 行は要件定義書「判定基準」から同一文言で転記した）
- [x] この 2 本の旧名 83 件（前者 77・後者 6）が置換され、置換先の無い 20-task-gh-install の 3 件は文ごと落ちている（根拠: 2 本とも全面書き換えのため旧名は 1 件も持ち越していない。`grep -cE "10-work-|20-task-gh|work-boundary\.sh|merge-prep|retrospective|wip/10_tickets/review-state|wip/merge-prep"` が両ファイルとも 0。`20-task-gh-install` を案内していた「gh 未導入なら install スキルへ」の文は、新仕様のエラー表に置き換え先が無いので落とした）
- [x] 10-work-ticket-driven の 6 件が行ごとの参照先（20-common-step-ticket / boundary.sh / 10-task-investigation-plan / 10-task-investigation-exec / 10-task-feedback-plan）に振り分けられている（根拠: チケット操作は「参照」の `20-common-step-ticket`、切れ目の判定と依頼・完了は `scripts/boundary.sh` の行、タスクの中身は `10-task-*`（計画型の正 `10-task-investigation-plan` / 実施型の正 `10-task-investigation-exec`）の行に分けた。振り返りは `10-task-feedback-plan` が手順 2 の担当表と参照の両方に出る）
- [x] retrospective の 6 件が 10-task-feedback-plan の振り返りへの参照になっている（根拠: 新仕様に `retrospective` という type は無い。振り返りはフィードバック計画タスク（type `feedback-plan`）が担うので、対応表の 8 行目と `00-workflow-quick-request` の手順 5「文言は `10-task-feedback-plan` と同一」に集約した）
- [x] 2 本の SKILL.md に対する旧名の検索（0005 の c5 の検索コマンド）の出力が空になっている（コマンドと出力を根拠に貼る）（根拠: `grep -nE "10-work-|20-task-gh|work-boundary\.sh|merge-prep|ワーク|retrospective|wip/10_tickets/review-state|task-boundary"` のヒットは `ワークスペース外のパス`（仕様の禁止事項の文言そのもの）1 行のみ。`grep -noE "ワーク[^ス]"` は 0 件で、旧語としての「ワーク」は残っていない）

## 作業内容

- ワークフロースキル 2 本を新仕様に書き換える
- 旧名 83 件を置換し、置換先の無いものは文を落とす

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- 旧名 83 件を 1 件ずつ置換するのではなく、2 本とも新仕様から書き起こした。置換だと旧構造（ワークループ・承認①〜⑥の番号体系）が残り、新仕様の手順 0〜5 と対応が取れなくなる。書き起こしたので旧名は 1 件も持ち越していない
- 判定表は要件定義書「判定基準」から同一文言で転記した。仕様が「SKILL.md の手順 0 にはそれを同一文言で転記する」と指定しているので、要件を更新したときの追随先が 1 か所に定まる
- 提供コマンドの起動をすべてリポジトリルート相対の絶対表記（`bash .claude/skills/.../scripts/boundary.sh`）で書いた。フックの提供コマンド識別がこの表記を見るので、短縮形を混ぜると判定が効かなくなる

### うまくいかなかったこと

- なし

### 仕様からの逸脱

- なし

### 判断と根拠

- `20-task-gh-install` を案内していた 3 件は文ごと落とした。新仕様のエラー表に「CLI 未導入」の行はあるが、導入を案内する専用スキルは新体系に存在しない。代わりに `gh auth login` / `glab auth login` を案内する形は各 common-step が持つので、ワークフロー側で重ねて書かない
- `retrospective` という type は新仕様に無い。振り返りはフィードバック計画タスクが担うので、旧 `10-work-ticket-driven` の retrospective 手順への参照は `10-task-feedback-plan` に寄せた
- 冒頭の禁止事項段落を 1 段落に詰めた（仕様の禁止事項 12 項目）。雛形が「3〜5 行」と言うのは行数の目安で、読み手が最初に目にする位置に置くことが本旨だと解釈した

### 拒否・確認・迂回の記録

- なし（このチケットは Write / Edit だけで、コマンド実行は grep と git のみ）

### 使った AI アセットと効き目

- `.claude/docs/10_spec/skills/00-workflow-issue-mr-driven.md` の「処理フロー」節: 手順 0〜5 と 2a がそのまま SKILL.md の節になる粒度で書かれており、要約の判断がほとんど要らなかった
- `20-common-step-ai-asset-creator` の `assets/skill.template.md`: 冒頭段落を禁止事項の要約にする順序が明示されていたので、2 本の形が揃った

### スコープ外で見つけたこと

- `00-workflow-issue-mr-driven/evals/evals.json` にまだ旧名が残っている（`.claude/hooks/work-boundary.sh` など）。0031（S8）が `.claude/evals/00-workflow-issue-mr-driven.md` へ移行する対象なので、このチケットでは触っていない
- `00-workflow-issue-mr-driven/assets/` に旧ワークフロー由来の `issue-addendum.template.md` と `issue-notify.template.md` が残っている。削除は 0031（S8）の担当

### AI アセットに反映すべき内容

- なし

### 備考

- allow.write は `00-workflow-issue-mr-driven/**` / `00-workflow-quick-request/**` / `wip/**`。この範囲だけを触った
