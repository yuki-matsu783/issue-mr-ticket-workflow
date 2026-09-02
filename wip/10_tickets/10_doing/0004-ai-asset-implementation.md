---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0003"]
executor: main
human_review: {required: true, reason: "書き手の振る舞いが変わる"}
adversarial_review: {required: false, reason: "中核（フック・settings.json）を含まず、ユーザー合意により人間レビューのみ"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: "2026-09-02T08:05:52+00:00"
completed_at: ""
base_sha: "d7a60e6"
---

# 0004 テンプレート・SKILL.md・ai-asset-design-docs ルールへの反映と eval 定義

## 目的

0003 で決めた型を、書き手が実際に使うアセット（テンプレート・スキル手順・ルール）に反映し、機械検証できない規約は eval 定義に落とす

## DoD

- [ ] assets/requirements.template.md に mermaid メインフローの記入例が入り、埋めるだけで新しい型に沿う（根拠: ）
- [ ] 20-common-step-requirement の SKILL.md の手順とセルフレビュー項目が改訂後の仕様と一致している（根拠: ）
- [ ] .claude/rules/ai-asset-design-docs.md の「要件書の形」が改訂内容と矛盾しない（根拠: ）
- [ ] 追加した規約の eval 定義が作られている（実行はしない）（根拠: ）
- [ ] 要件書・仕様書・SKILL.md・テンプレート・ルールの 5 者に矛盾が無いことを突き合わせて確認している（根拠: ）

## 作業内容

- テンプレートに記入例と各章のガイドコメントを反映する
- SKILL.md の手順 3・手順 7 を改訂する
- ai-asset-design-docs ルールの該当箇所を改訂する
- eval 定義を 20-common-step-ai-asset-creator の作法で作る

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
