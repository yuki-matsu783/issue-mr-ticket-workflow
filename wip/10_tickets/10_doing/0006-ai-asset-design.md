---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0004"]
executor: main
human_review: {required: true, reason: "正史（.claude/docs/）の変更（敵対的レビューで代替）"}
adversarial_review: {required: true, reason: "フェーズごとに 1 回の敵対的レビューをこのチケット群の代表として実施する"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T09:49:52+00:00"
completed_at: ""
base_sha: "b4cd926"
---

# 0006 設計: ルールの要件書 3 本と置き場の DDR

## 目的

design-docs / ai-asset-design-docs / ルール体系 の要件書を apl/ の置き場に合わせ、Q7 の 4 規定を design-docs に足し、置き場の変更を DDR に残す

## DoD

- [ ] design-docs の要件書の適用範囲が apl/** になり、置き場が apl/<アプリ名>/docs/ の 4 ディレクトリで書かれている（根拠: ）
- [ ] design-docs の要件書に Q7 の 4 規定（要件書の形 / 仕様書は要件書より先に変えない / 要件との対応表の全件カバー / 横断文書と正の指し先）が受け入れ基準として入り、ai-asset-design-docs と文言が食い違わない（根拠: ）
- [ ] ai-asset-design-docs とルール体系の相互参照が apl/** に揃っている（根拠: ）
- [ ] DDR i0020-01（置き場を apl 配下にする）があり、却下した案と i0013-01 への影響が書かれている（根拠: ）
- [ ] 用語辞書に「アプリルート」が定義されている（根拠: ）
- [ ] 20-common-step-requirement のセルフレビュー 13 項目を全件確認した（根拠: ）

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
