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
started_at: ""
completed_at: ""
base_sha: ""
---

# 0030 S7 ワークフロースキル 2 本の SKILL.md 改訂（旧名 83 件）

## 目的

旧 00-workflow-* 2 本を新仕様に書き換え、その中で旧名 83 件を置換する

## DoD

- [ ] .claude/skills/00-workflow-issue-mr-driven/SKILL.md が新仕様（タスクの種類の対応表・切れ目の処理・boundary.sh の手順）のとおりに書き換わっている（根拠: ）
- [ ] .claude/skills/00-workflow-quick-request/SKILL.md が新仕様のとおりに書き換わっている（根拠: ）
- [ ] この 2 本の旧名 83 件（前者 77・後者 6）が置換され、置換先の無い 20-task-gh-install の 3 件は文ごと落ちている（根拠: ）
- [ ] 10-work-ticket-driven の 6 件が行ごとの参照先（20-common-step-ticket / boundary.sh / 10-task-investigation-plan / 10-task-investigation-exec / 10-task-feedback-plan）に振り分けられている（根拠: ）
- [ ] retrospective の 6 件が 10-task-feedback-plan の振り返りへの参照になっている（根拠: ）
- [ ] 2 本の SKILL.md に対する旧名の検索（0005 の c5 の検索コマンド）の出力が空になっている（コマンドと出力を根拠に貼る）（根拠: ）

## 作業内容

- ワークフロースキル 2 本を新仕様に書き換える
- 旧名 83 件を置換し、置換先の無いものは文を落とす

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
