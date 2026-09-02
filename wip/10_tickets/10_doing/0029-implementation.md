---
type: ticket
ticket_type: implementation
predecessors: ["0028"]
executor: main
human_review: {required: true, reason: "利用者が読む文書の変更"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューでまとめて見る"}
allow:
  write: ["apl/**"]
  ops: ["read", "build-test", "remote-read"]
started_at: "2026-09-02T11:31:21+00:00"
completed_at: ""
base_sha: "c7b725d"
---

# 0029 実装: README の暫定の 1 行を落とす

## 目的

設計文書の移動が済んだので、宙ぶらりんを説明していた断り書きを現状に合わせる

## DoD

- [ ] README の参照がアプリルート相対であることは残り、「まだリポジトリ直下の docs/ にある」の記述が消えている（根拠: ）
- [ ] npm test が 47 件 pass する（根拠: ）

## 作業内容

- README の 1 行を書き換える

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
