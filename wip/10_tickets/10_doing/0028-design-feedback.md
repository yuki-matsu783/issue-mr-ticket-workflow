---
type: ticket
ticket_type: design-feedback
predecessors: ["0026"]
executor: main
human_review: {required: true, reason: "正史（要件・仕様）の変更"}
adversarial_review: {required: true, reason: "フェーズ 6 の敵対的レビューをこのフェーズの実施チケット群の完了後に 1 回実施する"}
allow:
  write: ["apl/*/docs/**", "docs/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T11:28:13+00:00"
completed_at: ""
base_sha: "af98b4d"
---

# 0028 設計反映: 拡張の設計文書を apl/vscode-ticket-board/docs/ へ移し、配置図・DDR の状態・節名を揃える

## 目的

F1・F2・F3・F5a を実施し、設計文書の置き場と記述を実体に一致させる

## DoD

- [ ] apl/vscode-ticket-board/docs/ に 7 ファイルがあり、docs/ が消えている（V1・V2）（根拠: ）
- [ ] 仕様書 28 行目の配置図の頂点が apl/vscode-ticket-board/ になっている（V3）（根拠: ）
- [ ] 仕様書の 7 番目の節が「画面・出力の構造」になっている（V4）（根拠: ）
- [ ] 節名の変更の経緯が新しい DDR i0020-04 に残り、i0013-02 の frontmatter に置き換え先が書かれている（根拠: ）
- [ ] DDR i0013-01 の frontmatter が置き換え済みになり、置き換え先が i0020-01 を指している（本文は変えていない）（根拠: ）

## 作業内容

- git mv で移す。仕様書の 2 か所を直す。DDR を 1 件起こし、2 件の frontmatter を直す

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
