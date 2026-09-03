---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0027"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "既存の提供コマンドの小さな修正で中核を含まず、機械テストが判定する"}
allow:
  write: [".claude/skills/20-common-step-report-view/**", ".claude/skills/20-common-step-commit-push/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0028 S5 check-html.sh の RV009 と CP-T08 の振り直し

## 目的

1 つの識別子が 2 つの原因を指している状態（RV008）と、1 つのテスト ID が 2 ファイルにある状態（CP-T08）を解消する

## DoD

- [ ] check-html.sh が awk の存在を確かめ、無ければ検査を縮退させず RV009・終了 2 で止まる（RV008 の判定の後、検査に入る前）（根拠: ）
- [ ] 機械テスト RV-T08 が通る: PATH から awk を外した状態で、正しい引数の正しい HTML を渡しても RV009・終了 2 になる（縮退して OK を返さない）（根拠: ）
- [ ] test_push.sh 側の CP-T08 が CP-T11 に振り直され、run-tests.sh --ids で重複 ID の報告が 0 件になる（根拠: ）
- [ ] run-tests.sh --filter で check-html と push を実行し、全件通る（根拠: ）
- [ ] フック共通仕様 §6 の RV の範囲（RV001–009）と check-html.sh の実装が一致している（根拠: ）

## 作業内容

- check-html.sh に awk の存在確認と RV009 を入れる
- test_push.sh の CP-T08 を CP-T11 に振り直す

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
