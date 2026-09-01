---
type: ticket
ticket_type: investigation
predecessors: ["0002"]
executor: main
human_review: {required: true, reason: "流用可否と logger の置き場が実装計画を左右する（全体計画の方針: 調査実施は要。承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "調査結果は次の計画で検証される"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0003 調査実施 — Q1 参考実装の流用範囲 / Q4 logger と redact

## 目的

参考実装 2 系統のスクリプトを仕様（フック共通仕様・common-step 仕様）の機能単位で突き合わせ、流用 / 改変 / 新規を確定する。logger と redact の置き場・読み込み方を決める材料を出す。

## DoD

- [ ] 観点 Q1「参考実装のうち仕様にそのまま合う部分・書き直す部分」への答えが調査結果レポート `wip/30_reports/0003-investigation.md` に機能単位の表（流用 / 改変 / 新規）で書かれている（根拠: ）
- [ ] 観点 Q4「logger と redact の置き場と読み込み方」への答えが同レポートにあり、仕様との差分が表になっている（根拠: ）
- [ ] 各答えに根拠（ファイル・行・仕様書の節）が添えられている（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）

## 作業内容

- 調査計画書「対象と方法」Q1・Q4 のとおり読む（参考ディレクトリは読み取りのみ）
- レポートに Q1・Q4 の節を書く

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
