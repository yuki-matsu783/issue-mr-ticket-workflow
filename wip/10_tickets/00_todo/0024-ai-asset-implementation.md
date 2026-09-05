---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0023"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: [".claude/skills/**"]
  ops: ["hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0024 S7 提供コマンド b: ticket.sh の TK009・push.sh の項目 5・boundary.sh の切れ目判定

## 目的

チケットの採番と push を本流に一本化し（DDR i0050-05）、切れ目の判定を全作業ツリーで行い last_task を既出の切れ目の補集合で決める（DDR i0050-09・i0050-10）。変更後の自分のコマンドで自分をコミット・完了させる並びを守る。

## DoD

- [ ] ticket.sh の create が仕様書 10_spec/skills/20-common-step-ticket.md の TK009 のとおりになっている（作業ツリーでの create は終了 1 でチケットを 1 枚も作らない。本流かどうかの判定は 20-common-step-worktree 仕様のものを共有し、作り直さない）（根拠: ）
- [ ] push.sh の push 前チェックに項目 5（本流でのみ push する。スキップ不可）が入っている（仕様書 10_spec/skills/20-common-step-commit-push.md）（根拠: ）
- [ ] boundary.sh の last_task が既出の切れ目の補集合で決まり（DDR i0050-10）、at_boundary がすべての作業ツリーを見る（管理対象の作業ツリーが 0 なら worktree.sh を呼ばない）（根拠: ）
- [ ] 機械テスト TICKET-T13 が通る（run-tests.sh --filter '*test_ticket*'）。負のコントロール（同じ引数を本流で実行すれば作られる）を含む（根拠: ）
- [ ] 機械テスト CP-T12 が通る（run-tests.sh --filter '*test_push*'）。wip/push-check-skip.md に項目 5 を書いても飛ばせない（根拠: ）
- [ ] 機械テスト BD-T20 と BD-T21 が通る（run-tests.sh --filter '*test_boundary*'）。BD-T21 は worktree.sh の呼び出し回数 0 を make_counting_path で確かめる（根拠: ）
- [ ] 既存の TICKET-T01〜T12・CP-T01〜T11・BD-T01〜T19 が引き続き通る（回帰）（根拠: ）
- [ ] 変更 → commit.sh で自分をコミット（この 1 回目が検証を兼ねる）→ ticket.sh complete の並びで本チケットを閉じた。start / complete の経路に create の分岐を足していない（根拠: ）
- [ ] 実装結果レポートに本チケットの節が追記され、completed_at を持たないチケットの last_task の扱い（R59。仕様に記述が無い）が「仕様からの逸脱」ではなく残課題として記録されている（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S7 と「ロックアウト対策」の S7 行に従う
- ticket.sh が壊れるとチケットを完了させる手段が無くなる。壊れたら Edit ツールで基準点（base_sha）の内容に戻す

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
