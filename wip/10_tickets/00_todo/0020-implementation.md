---
type: ticket
ticket_type: implementation
predecessors: ["0018"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: false, reason: "未使用の引数 1 つの削除で、機械テストが全通過なら足りる（基準の調整条件に該当）"}
allow:
  write: ["src/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0020 使われていない RenderOptions.cspSource を型から削る

## 目的

設計反映で「型から削る」と決めた F07 を実装に反映し、仕様書と実装を一致させる

## DoD

- [ ] core/render.ts の RenderOptions から cspSource が消え、board-panel.ts が渡していない（根拠: ）
- [ ] test/render.test.ts の OPTIONS から cspSource が消えている（根拠: ）
- [ ] npm test が全通過する（根拠: ）

## 作業内容

- 仕様書「データの形」「表示と更新 4」の記述どおりに src/ を直す

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
