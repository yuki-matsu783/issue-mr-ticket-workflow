---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0049"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まず、機械テストで固定できる範囲の変更のため基準を不要に倒す"}
allow:
  write: [".claude/skills/20-common-step-report-view/assets/**", ".claude/skills/10-task-feedback-plan/assets/**", "wip/**", "logs/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0050 テンプレート 3 件を仕様に追随させる（S1）

## 目的

視覚語彙の ◇ の見出しと、フィードバック計画のひな形の消し込み表を仕様どおりにする

## DoD

- [ ] report.template.html と report.template.md の ◇ の欄が「判断が欲しい」になっている（20-common-step-report-view 仕様 OUT ひな形の視覚語彙のとおり）（根拠: ）
- [ ] feedback-plan.template.md に「消し込み表」の節があり、走査した記録 1 件ごとに抽出した項目とその行き先を書く形になっている（10-task-feedback-plan 仕様 OUT ひな形のとおり）（根拠: ）
- [ ] grep -rn '承認が欲しい' .claude/skills/ が 0 件（根拠: ）
- [ ] テンプレートを使って作った HTML が check-html.sh を通る（RV-T01 から RV-T08 の回帰。bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_check_html*'）（根拠: ）
- [ ] 実装結果レポート（md + HTML）があり check-html.sh が通っている（根拠: ）
- [ ] プレースホルダ・frontmatter の検査が 0 件（根拠: ）

## 作業内容

- テンプレート 3 件を直し、レポートを作る

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
