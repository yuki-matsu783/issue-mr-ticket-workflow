---
type: ticket
ticket_type: investigation-plan
predecessors: []
executor: main
human_review: {required: false, reason: "基準どおり（計画書は調査結果と一緒に見れば足りる）"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0002 TBD T1〜T4 と実物の形の調査計画

## 目的

フック本体の実装前に確かめる問い（§12 の T1〜T4、tool_response の終了コードのフィールド名、agent_type / model、web の強制、defer、クォート付き git のサブコマンド判定）を、プローブフックで実測できる形の調査チケットに割り付ける

## DoD

- [ ] 全体計画「判断が必要になりそうな点」の 7 項目が、調査チケットのいずれかの問いに漏れなく割り付けられている（根拠: ）
- [ ] 各問いについて、確かめ方（プローブフックの置き場・登録する settings.json の断片・実行する操作・記録の読み方）と、外れたときの縮退の判断材料が計画書に書かれている（根拠: ）
- [ ] プローブフックの settings.json への一時登録・撤去が人間の操作であることと、その依頼文（貼り付ける JSON と手順）を用意する段取りが計画書にある（根拠: ）
- [ ] 調査チケット（investigation）を必要枚数だけ未着手に作成し、次の計画チケット（ai-asset-design-plan）も 1 枚起こした（根拠: ）
- [ ] 計画書 wip/20_plans/0002-investigation-plan.md と HTML ビューを作り、check-html.sh が OK を返した（根拠: ）

## 作業内容

- 全体計画の「判断が必要になりそうな点」7 項目とフック共通仕様 §12 の TBD 表を突き合わせ、問いの一覧を作る
- 問いごとに、1 回のプローブ登録でまとめて取れるもの（フック入力の実物）と、個別の操作が要るもの（T1 の届き方・defer の挙動）に分ける
- プローブフックの仕様（stdin の JSON をそのまま logs/probe/ に落とし、何も出力せず終了 0）と、登録用 JSON の断片を決める
- 調査チケットの枚数・順序・DoD を決め、ticket.sh create で起こす

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
