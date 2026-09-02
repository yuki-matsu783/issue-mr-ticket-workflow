---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0032"]
executor: main
human_review: {required: true, reason: "中核（テスト）を含む"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューの指摘対応"}
allow:
  write: [".claude/rules/**", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0033 実装: ルール本体に DDR の状態の語彙を反映し、テストの deny の網羅を戻す

## 目的

0032 の正史をルール本体に落とし、アサーションの入れ替えで失われた deny の固定を回復する

## DoD

- [ ] 両ルール本体の DDR の記述が 0032 の許容値と一致し、2 本で文言が揃っている（根拠: ）
- [ ] test_config_integrity.sh が計画・調査 7 type すべてについて apl/** の deny を固定している（根拠: ）
- [ ] 変更前に落ちて変更後に通ることを確かめ、run-tests.sh --ids が 14 本すべて PASS する（根拠: ）

## 作業内容

- テストを先に書いて落としてから直す

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
