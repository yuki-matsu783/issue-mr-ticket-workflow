---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0025"]
executor: sub-opus
human_review: {required: true, reason: "正史（要件・仕様）の変更（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（正史の変更）"}
allow:
  write: [".claude/docs/**", "wip/30_reports/**", "wip/00_overall_plan/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T11:16:30+09:00"
completed_at: ""
base_sha: "076c7ae"
---

# 0026 レビュー指摘: 記録・削除・要件・表の整合の掃き残し（A6〜A10・B6・B9・B10・B14・B16・B17）

## 目的

2 巡目の低〜中の指摘をまとめて片付ける。いずれも同じ事実が 2 か所にあって片方だけ直っている型

## DoD

- [ ] workflow-state-guard の呼出条件から「置き場宛の書き込み」が消えて制御方式 4 と揃い、制御方式 4 の理由が「file_path も command も持たない」の断定から将来の再点検条件付きの表現に緩んでいる（A6）（根拠: ）
- [ ] hc_lock に陳腐化したロックの回収経路（作成時刻での強制解放）があり、打ち切りで残置しても次の実行が回復する。HK-T17 にそのケースがある（A7）（根拠: ）
- [ ] 削除・移動の元の判定が置き場ディレクトリ自身とその祖先（wip/10_tickets・wip）の削除も拾い、SG-T02 に rm -rf wip/10_tickets/20_done と rm -rf wip のケース（wip/tmp は通る負のコントロール付き）がある（A8）（根拠: ）
- [ ] 要件の例外フローと非機能（可用性）に、i0009-29 が作った例外（設定が読めなくても既定値で判定を続ける仕組みは拒否に倒さない）が反映され、i0009-29 の影響に要件書が加わっている（A9）（根拠: ）
- [ ] 0020 結果報告（md と html）の公式引用の行番号 :988 が :989 に直っている（A10）（根拠: ）
- [ ] post-push-usage-report の --accumulate と既定の usage/<branch>.json への加算に hc_lock による直列化と 2 秒で諦める規則が書かれ、i0009-23 の影響の記述と一致している（B6）（根拠: ）
- [ ] workflow-state-guard の「要件との対応」表の制御方式の番号が繰り下げ後の実体と一致し、MCP の分岐を指す行がある（B9）（根拠: ）
- [ ] workflow-state-guard の記録節に制御方式 0 の notify が加わり、制御方式 0 が停止中の判定より後に評価されることが明記されている（B10）（根拠: ）
- [ ] 20-common-step-shell-script のテスト観点表で SS-T05 が SS-T04 の後ろに並んでいる（B14）（根拠: ）
- [ ] §8 判定順 (1) の「workflow-state-guard が先に拒否するので」が並列実行の前提に合う表現に直っている（B16）（根拠: ）
- [ ] 全体計画の保留した点の D5・D6 の行が i0009-19 による決定済みに更新されている（B17）（根拠: ）
- [ ] 決定の経緯が DDR i0009-59〜62 の範囲に残っている（決定を伴わない字句の是正は DDR を作らない）（根拠: ）

## 作業内容

- 指摘の原文は wip/30_reports/0022-ai-asset-design-appendix-A.md を参照する
- A10 と B14 と B17 は字句・並びの是正で DDR は不要。A7・A8・B6・B10 は決定を伴うので DDR を作る

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
