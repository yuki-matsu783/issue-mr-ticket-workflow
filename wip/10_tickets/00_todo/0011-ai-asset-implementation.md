---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0009"]
executor: main
human_review: {required: true, reason: "中核ではないが正史の実装（敵対的レビューで代替）"}
adversarial_review: {required: true, reason: "フェーズごとに 1 回の敵対的レビューをこのチケット群の代表として実施する"}
allow:
  write: [".claude/rules/**", ".claude/evals/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0011 実装: design-docs / ai-asset-design-docs ルール本体と eval 定義

## 目的

レビュー済みの要件書のとおりにルール本体 2 本を書き換え、eval 定義の前提を合わせる

## DoD

- [ ] design-docs.md の paths が apl/** になり、本文が要件書の 3 規約節と対応している（根拠: ）
- [ ] design-docs.md に要件書の形・仕様書の順序・要件との対応表の全件カバーの規定が入り、ai-asset-design-docs と文言が一致している（根拠: ）
- [ ] 両ルールの「処理フロー 12」の参照が「処理フロー 14」になっている（根拠: ）
- [ ] .claude/evals/design-docs.md の前提の paths が apl/** になっている（根拠: ）
- [ ] 要件書の節と本体の節の対応表を作業ログに書いた（根拠: ）

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
