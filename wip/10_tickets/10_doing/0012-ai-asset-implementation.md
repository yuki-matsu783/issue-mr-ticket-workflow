---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0011"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズの敵対的レビューは 0011〜0012 をまとめて 1 回実施する"}
allow:
  write: [".claude/skills/**", ".claude/hooks/config/scope-limits.json", ".claude/hooks/lib/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-02T10:28:20+00:00"
completed_at: ""
base_sha: "e418747"
---

# 0012 実装: 共通ステップスキル 2 本・テンプレートと許可範囲設定

## 目的

20-common-step-requirement / -spec の SKILL.md と要件書テンプレートを仕様どおりに直し、scope-limits.json とそのテストを新しい許可範囲に合わせる

## DoD

- [ ] 20-common-step-requirement の SKILL.md が 14 手順・セルフレビュー 14 項目・置き場の一般化を反映している（根拠: ）
- [ ] requirements.template.md の概要章に「issue の受け入れ条件との対応」の小節がある（根拠: ）
- [ ] 20-common-step-spec の SKILL.md の種別表にアプリの行（10 節固定）とアプリの識別子の採番規則がある（根拠: ）
- [ ] scope-limits.json がフック共通仕様の初期値と一致し、jq で構文が通る（根拠: ）
- [ ] test_scope.sh にアプリルート直下・apl/*/docs/** ・入れ子 .gitignore・旧置き場の deny のアサーションがあり、変更前に落ちて変更後に通ることを確かめた（根拠: ）
- [ ] run-tests.sh --ids が全通過し、結果を作業ログに残した（根拠: ）

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
