---
type: ticket
ticket_type: investigation
predecessors: ["0002"]
executor: main
human_review: {required: true, reason: "結論が後続の計画を左右する（敵対的レビューで代替）"}
adversarial_review: {required: true, reason: "フェーズごとに 1 回の敵対的レビューを人間レビューの代替とする委任による"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T09:24:15+00:00"
completed_at: ""
base_sha: "8097a60"
---

# 0003 調査実施: 置き場依存箇所と issue #20 の 5 論点の現状（Q1〜Q9）

## 目的

調査計画 0002 の問い Q1〜Q9 に答え、フェーズ 2 が推測なしに設計を書ける材料をそろえる

## DoD

- [ ] Q1 の書き換え対象一覧（ファイル・行・現在の記述）がある（根拠: ）
- [ ] Q2〜Q5・Q7 に行番号つきの結論がある（根拠: ）
- [ ] Q6 に今回入れるか issue #24 に寄せるかの推奨と理由がある（根拠: ）
- [ ] Q8・Q9 に移動で壊れる設定の一覧、または壊れない根拠がある（根拠: ）
- [ ] 結果レポート wip/30_reports/0003-investigation.md と HTML ビューがあり check-html.sh を通る（根拠: ）

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
