---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0029"]
executor: main
human_review: {required: true, reason: "正史（仕様）の変更"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューでまとめて見る"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0030 設計: 旧置き場の記述をフック共通仕様 §8 から落とす

## 目的

src/** と docs/** の移行が完了したので、移行のために置いていた記述を正史から外す

## DoD

- [ ] §8 の「旧置き場」と「現在の状況」の段落が消えている（根拠: ）
- [ ] §8 の初期値の表の計画・調査 7 type の deny から src/** と docs/** が消え、apl/** と .claude/** は残っている（根拠: ）

## 作業内容

- §8 の 2 か所を直す

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
