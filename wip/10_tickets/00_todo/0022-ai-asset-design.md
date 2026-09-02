---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0021"]
executor: main
human_review: {required: true, reason: "正史（仕様）の変更"}
adversarial_review: {required: false, reason: "フェーズ 4 の敵対的レビューの指摘対応であり、対応そのものは再レビューしない"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0022 設計: 敵対的レビュー（フェーズ4）の指摘のうち正史に当たる 3 件を直す

## 目的

commands.build-test に何を列挙するかの方針と、旧置き場 src/** の片付けの担い先をフック共通仕様に書く

## DoD

- [ ] フック共通仕様 §8 に commands.build-test の方針（依存導入とコンパイルを含める / npm install を含めない理由 / アプリごとに --prefix 形も併記）が書かれている（根拠: ）
- [ ] §8 の旧置き場の段落が、src/** の移行は完了済みで削除はフェーズ 6 で docs/** とまとめて行う、と担い先を明示している（根拠: ）
- [ ] §8 に、裸の npm test は cwd を見ないためリポジトリ全域に効くという範囲の判断が記録されている（根拠: ）
- [ ] 指摘 3 件それぞれについて直した箇所を作業ログに書いた（根拠: ）

## 作業内容

- 指摘ごとに §8 の該当箇所を直す

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
