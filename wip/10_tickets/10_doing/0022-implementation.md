---
type: ticket
ticket_type: implementation
predecessors: ["0021"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: false, reason: "テスト 1 件の追加とコメントの訂正で、機械テストが全通過なら足りる（基準の調整条件に該当）"}
allow:
  write: ["src/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: "2026-09-02T07:27:03+00:00"
completed_at: ""
base_sha: "6d14f6d"
---

# 0022 種類不明・実行者不明のテスト追加とコード内の仕様参照の訂正

## 目的

仕様に書いた「種類不明」「実行者不明」の表示を機械テストで守り、コード内の仕様参照の手順番号を直す

## DoD

- [ ] test/render.test.ts の TB-T14 に、ticket_type と executor が未設定のカードに「種類不明」「実行者不明」が出ることを確かめるテストがある（根拠: ）
- [ ] src/core/ticket.ts の仕様参照コメントが手順 6 を指している（根拠: ）
- [ ] npm test が全通過する（根拠: ）

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
