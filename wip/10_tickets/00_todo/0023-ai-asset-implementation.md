---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0022"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズ 4 の敵対的レビューの指摘対応"}
allow:
  write: [".claude/hooks/config/scope-limits.json", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0023 実装: commands.build-test の列挙を増やし、分類を実際に走らせるテストにする

## 目的

クリーンな作業ツリーでアプリのテスト手順が通るようにし、テストが文字列一致でなく分類の振る舞いを固定するようにする

## DoD

- [ ] commands.build-test に npm ci / npm run compile と、それぞれの npm --prefix 形が入っている（npm install は入れない）（根拠: ）
- [ ] test_config_integrity.sh のアサーションが scope_classify を実際に呼び、列挙した形が build-test に、列挙に無い npm install が unknown になることを固定している（根拠: ）
- [ ] 列挙の検査が配列の完全一致でなく「必要な形が含まれていること」になっている（根拠: ）
- [ ] 変更前に落ちて変更後に通ることを確かめ、run-tests.sh --ids が 14 本すべて PASS する（根拠: ）

## 作業内容

- テストを先に書いて落としてから設定を直す

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
