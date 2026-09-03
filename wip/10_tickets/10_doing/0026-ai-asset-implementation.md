---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0025"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "中核の提供コマンドで、ticket.sh の切り出しが壊れると全チケットの状態遷移が止まる"}
allow:
  write: [".claude/skills/10-task-overall-summary/**", ".claude/skills/20-common-step-ticket/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T05:26:29+09:00"
completed_at: ""
base_sha: "fb8b80a"
---

# 0026 S3 中核: finalize.sh とそのテスト（FN-T01〜09）・完了検査の共有

## 目的

全体まとめの片付けから draft 解除までを 8 段階の 1 コマンドにまとめ、完了検査を ticket.sh と共有して二重実装を避ける

## DoD

- [ ] bash .claude/skills/10-task-overall-summary/scripts/finalize.sh release が 8 段階（前提検査 / 完了検査 / 完了検査の書き出しと push / SHA の確定とリンク一覧 / 片付け / push / 最終ゲートと draft 解除 / 出力）を順に実行し、logs/merge-state.json の state を started → recorded → linked → cleaned → pushed → ready に進める（根拠: ）
- [ ] 機械テスト FN-T01〜FN-T09 の 9 件が通る（run-tests.sh --filter finalize）。FN-T08（空の表が linked にならない）と FN-T09（本文書き換えが添付を残す）を含む（根拠: ）
- [ ] ticket.sh の完了検査が ticket_check_completion として切り出され、finalize.sh が source して使っている（二重実装が無い）。切り出し後に ticket.sh next が JSON を返すことを確かめている（根拠: ）
- [ ] 値の往復の両側が同じチケットに入っている: 切り出す側（ticket.sh）・使う側（finalize.sh）・両者を確かめるテスト（test_ticket.sh の TICKET-T02〜T04・T07 が通る）（根拠: ）
- [ ] 本文のリンク一覧の書き込みが固定マーカー <!-- finalize:linked <sha> --> を残し、再導出が表の有無ではなくマーカーで linked を判定している（根拠: ）
- [ ] CLI が使えない環境の --external（段階 4 と 7 の代行）が実装され、logs/merge-state.json に via: external を残す（根拠: ）

## 作業内容

- ticket.sh から完了検査を関数として切り出す
- finalize.sh を書き、テストを --filter で実行する

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
