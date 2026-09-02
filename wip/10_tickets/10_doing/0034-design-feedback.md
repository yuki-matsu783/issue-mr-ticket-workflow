---
type: ticket
ticket_type: design-feedback
predecessors: ["0033"]
executor: main
human_review: {required: true, reason: "正史（仕様）の変更"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューの指摘対応"}
allow:
  write: ["apl/*/docs/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T11:47:11+00:00"
completed_at: ""
base_sha: "2a4f05b"
---

# 0034 設計反映: 節名の改名の波及を仕様書と DDR に反映する

## 目的

改名で切れた仕様書内の自己参照 6 か所を直し、DDR i0020-04 の影響を実測に合わせ、frontmatter を新しい定義に揃える

## DoD

- [ ] 仕様書の「要件との対応」表の実現箇所欄に「HTML の構造」が 0 件で、「画面・出力の構造」になっている（根拠: ）
- [ ] DDR i0020-04 の影響が実測（仕様書 6 行と render.ts 1 か所）を書いており、事実と食い違う断言が無い（根拠: ）
- [ ] i0013-02 と i0020-04 の frontmatter が 0032 の定義に従っている（値はパスのみ、範囲は別キー）（根拠: ）

## 作業内容

- 仕様書 6 行・DDR の影響・frontmatter 2 件を直す

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
