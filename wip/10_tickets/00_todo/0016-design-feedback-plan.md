---
type: ticket
ticket_type: design-feedback-plan
predecessors: ["0012"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: false, reason: "基準どおり（計画書は反映結果と一緒に見れば足りる）"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0016 設計反映の計画（実装との差分 A1〜A11 を仕様へ）

## 目的

フィードバック計画が本 issue で直すと決めた 11 件（A1〜A11）を、docs/ の要件・仕様・DDR へ反映する手順とチケットに落とす

## DoD

- [ ] 設計反映計画書が wip/20_plans/ にあり、A1〜A11 のそれぞれについて直す文書と節が特定されている（根拠: ）
- [ ] 計画書の HTML ビューが check-html.sh を通っている（根拠: ）
- [ ] 設計反映の実施チケットが未着手で作られ、その DoD が A1〜A11 と 1 対 1 で対応している（A11 は 3 つに割る）（根拠: ）
- [ ] 全体まとめのチケットの起票時期が計画書に書かれている（根拠: ）

## 作業内容

- wip/20_plans/0012-feedback-plan.md の A の表を入力として、直す文書と節を特定する
- 実施チケットを起こし、DoD を A1〜A11 に 1 対 1 で割り付ける

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
