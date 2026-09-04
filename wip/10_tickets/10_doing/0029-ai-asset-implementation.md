---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0028"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まず、実装フェーズの敵対的レビュー 2 回は中核（0025〜0027）と総仕上げ（0032）に割り当てる"}
allow:
  write: [".claude/skills/**", ".claude/agents/**", "wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T12:00:20+09:00"
completed_at: ""
base_sha: "1ad6389"
---

# 0029 S6 スキル・エージェント: タスクスキル 15 本 + エージェント 2 本

## 目的

各仕様の OUT ひな形・定義ひな形から SKILL.md 15 本とエージェント定義 2 本を作り、機構が type からスキルを引ける状態にする

## DoD

- [ ] 10-task-* の SKILL.md 15 本が .claude/skills/<スキル名>/SKILL.md に作成され、対応する仕様書の処理フロー・OUT ひな形・参照ナレッジと 1:1 で対応している（根拠: ）
- [ ] エージェント定義 2 本（task-executor / adversarial-reviewer）が .claude/agents/ に作成され、仕様の定義ひな形（model・tools・プロンプト）のとおりになっている（根拠: ）
- [ ] 各 SKILL.md の frontmatter（name・description）が ai-asset-authoring ルールに従い、description が呼び出しの判断に足りる語を含んでいる（根拠: ）
- [ ] 共通手順を持つスキルが手順を再掲せず、正（10-task-investigation-plan / 10-task-investigation-exec）を参照している（0003 の a9）（根拠: ）
- [ ] task-types.tsv のスキル名列 15 行すべてに対応するディレクトリが存在する（ls での突合の出力を根拠に貼る）（根拠: ）
- [ ] 分量が 1 枚に収まらないと判断して 2 枚に割った場合、計画書 0017 のステップ表を同じチケットの中で書き直している（記述順と実行順の一致）（根拠: ）

## 作業内容

- タスクスキル 15 本の SKILL.md を作る
- エージェント定義 2 本を作る

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
