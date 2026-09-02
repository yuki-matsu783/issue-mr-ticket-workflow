---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0030"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューでまとめて見る"}
allow:
  write: [".claude/hooks/config/scope-limits.json", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0031 実装: 旧置き場の deny とテストのアサーションを落とす

## 目的

0030 で直した §8 に合わせて設定とテストから旧置き場を外す

## DoD

- [ ] scope-limits.json に src/** と docs/** が 0 件で、apl/** と .claude/** の deny は残っている（V5）（根拠: ）
- [ ] test_config_integrity.sh の旧置き場のアサーション 4 件が、特別扱いが無いこと（判定順 (7) の ask WF202）を見る 2 件に置き換わっている（根拠: ）
- [ ] 計画・調査タスクが apl/** を書けないことがテストで固定されている（根拠: ）
- [ ] 変更前に落ちて変更後に通ることを確かめ、run-tests.sh --ids が 14 本すべて PASS する（V6）（根拠: ）

## 作業内容

- テストを先に直して落としてから設定を直す

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
