---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0031"]
executor: main
human_review: {required: true, reason: "正史（要件）の変更"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューの指摘対応"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0032 設計: DDR の置き換えを表す frontmatter のキーと値を定義する

## 目的

status / superseded_by / supersedes の名前・許容値・値の形を正史に定め、部分置き換えを表せるようにする

## DoD

- [ ] 両ルールの要件書に、DDR の状態の許容値（置き換え済み / 一部置き換え済み / 廃止）と、一部置き換え済みのときに範囲を書く場所が定義されている（根拠: ）
- [ ] superseded_by と supersedes の値の形（パスのみ。散文を混ぜない）と、双方向に付けるかどうかが定義されている（根拠: ）
- [ ] .claude/docs/20_ddr/i0020-01 が新しい定義に従っている（i0013-01 を置き換えた側の supersedes）（根拠: ）
- [ ] design-docs と ai-asset-design-docs の要件書で、この規定の内容が食い違っていない（根拠: ）

## 作業内容

- 要件書 2 本に規定を足し、i0020-01 の frontmatter を合わせる

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
