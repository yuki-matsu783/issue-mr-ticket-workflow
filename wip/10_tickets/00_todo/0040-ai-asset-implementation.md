---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0039"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "実装フェーズの敵対的レビューは上限 2 回に達している（その指摘への対応そのもの）"}
allow:
  write: [".claude/skills/10-task-feedback-plan/**", ".claude/skills/10-task-design-plan/**", ".claude/skills/10-task-design-exec/**", ".claude/skills/10-task-design-feedback-plan/**", ".claude/skills/10-task-design-feedback-exec/**", ".claude/skills/10-task-implementation-plan/**", ".claude/skills/10-task-implementation-exec/**", ".claude/skills/10-task-ai-asset-design-plan/**", ".claude/skills/10-task-ai-asset-design-exec/**", ".claude/skills/10-task-ai-asset-implementation-plan/**", ".claude/skills/10-task-ai-asset-implementation-exec/**", ".claude/skills/00-workflow-quick-request/**", ".claude/skills/20-common-step-issue/**", ".claude/agents/**", ".claude/rules/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0040 S15 文書側の指摘 8 件（敵対的レビュー 2 回目）

## 目的

スキル・エージェント・ルール・レポートの文言と参照の食い違いを直し、正が 2 つに見える状態を消す

## DoD

- [ ] 10-task-feedback-plan の類型の文言が機構の定義（00_requirement/自己改善ワークフロー機構.md）と 00-workflow-quick-request と同一になっている（根拠: ）（根拠: ）
- [ ] 10 本のスキルの冒頭が共通手順の禁止事項を部分再掲せず、正への参照だけになっている（根拠: ）（根拠: ）
- [ ] 移設した issue-triage.md を指す参照が .claude/ 配下にある（20-common-step-issue の参照節）（根拠: ）（根拠: ）
- [ ] task-executor の手順に「文脈が足りなければ推測せず結果報告に書いて終える」が書かれている（eval TXE-E02 と整合）（根拠: ）（根拠: ）
- [ ] work-defaults の frontmatter（description・applies_when・keywords）が敵対的レビュアーのモデルの節を含んでいる（根拠: ）（根拠: ）
- [ ] 00-workflow-quick-request のヘッドレス節が仕様の手順番号に依存しない書き方になっている（根拠: ）（根拠: ）
- [ ] 実装結果レポートの対象チケットが実体（0024〜0032・0035〜0039）に直り、0034 の取り消しと 0037 への置き換えが 1 行書かれている（md と HTML の両方）（根拠: ）（根拠: ）
- [ ] 実装結果レポートの HTML が md と同じ内容を言っている（e9 の解消済みの一文を含む）。check-html.sh が通る（根拠: ）（根拠: ）

## 作業内容

- DoD の各項目を順に満たす

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
