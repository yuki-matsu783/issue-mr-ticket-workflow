---
type: ticket
ticket_type: implementation
predecessors: ["0021"]
executor: main
human_review: {required: true, reason: "利用者が読む文書の変更"}
adversarial_review: {required: false, reason: "フェーズ 4 の敵対的レビューの指摘対応"}
allow:
  write: ["apl/**"]
  ops: ["read", "build-test", "remote-read"]
started_at: "2026-09-02T11:20:46+00:00"
completed_at: ""
base_sha: "bba859b"
---

# 0024 実装: README の設計文書への参照がどこからの相対かを明示する

## 目的

移動後に README とソースのヘッダの参照が宙ぶらりんになっているのを、読み手が判断できる状態にする

## DoD

- [ ] apl/vscode-ticket-board/README.md の要件・仕様への参照が、アプリルート相対であることと移動がフェーズ 6 であることを読み取れる（根拠: ）
- [ ] npm test が 47 件 pass する（参照の変更でテストが壊れていない）（根拠: ）

## 作業内容

- README に 1 行足す。ソースのヘッダコメントは同じ基準（アプリルート相対）なので触らない

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
