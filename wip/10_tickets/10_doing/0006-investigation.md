---
type: ticket
ticket_type: investigation
predecessors: ["0002"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは fable の敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "調査フェーズの切れ目で 4 枚まとめて 1 回行う（全体計画「敵対的レビューの回し方」）"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "build-test"]
started_at: "2026-09-03T14:31:18+09:00"
completed_at: ""
base_sha: "ae2ef79"
---

# 0006 観点 D: 申し送りの反映先の割り付けと fm_get / TICKET-T05 の現状

## 目的

issue #10 の申し送りを反映先の仕様書と節に割り付け、この issue で扱う分と扱わない分の線引きの材料を設計計画に渡す

## DoD

- [ ] 観点『申し送りの各項目はどの仕様書のどの節に落ちるか。反映済みはどれか。fm_get と TICKET-T05 は現在どちらの形か』への答えが wip/30_reports/0006-investigation.md に書かれている（根拠: ）
- [ ] 申し送り × 反映先の対応表が「項目 / 反映先の仕様書と節 / 反映済みか / この issue で扱えるか」で全件挙がっている（根拠: ）
- [ ] 反映済みと判定したものに根拠（ファイル:行）が添えられている（根拠: ）
- [ ] fm_get のエスケープ解除と TICKET-T05 の期待値の現在の形が、run-tests.sh --ids TICKET-T05 の実行出力を添えて書かれている（根拠: ）
- [ ] 扱う / 扱わないの最終判断は設計へ回すと明示され、答えが出なかった問いは理由付きで残課題に残っている（根拠: ）
- [ ] md と同名の HTML があり check-html.sh が通っている（根拠: ）

## 作業内容

- issue #10 本文の「#6 からの申し送り」を 1 行 1 件に分解する
- 各項目の反映先の仕様書と節を割り当て、既に書かれているものを根拠付きで識別する
- run-tests.sh --ids TICKET-T05 を実行して現在の期待値の形を確かめる
- 対応表を作り、レポートと HTML を書く

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
