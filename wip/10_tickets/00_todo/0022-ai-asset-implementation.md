---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0019", "0020"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: [".claude/hooks/**"]
  ops: ["hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0022 S5 中核 d: 案内側フック 4 本と post-push-* の共有ルート参照、A5 を閉じる機械テスト

## 目的

差分の基準点・対象チケットを採る作業ツリー・実行者照合・現在地の 4 つを作業ツリーごとに一意にし、受け入れ条件 A5 を機械テストで閉じる。あわせて post-push-* の進行状態の参照先を共有ルートへ移す。

## DoD

- [ ] workflow-diff-check.sh が仕様書 10_spec/hooks/22-PostToolUse/workflow-diff-check.md 制御方式 0・1 のとおりになっている（差分の基準点は作業ツリーごとに一意 / 判定できないときは WF605 で通知）（根拠: ）
- [ ] subagent-start-check.sh が仕様書 10_spec/hooks/12-SubagentStart/subagent-start-check.md「対象チケットを採る作業ツリー」の表のとおりになっている（代用しない。確定できないときは WF804 で要点を注入しない）（根拠: ）
- [ ] subagent-stop-check.sh が仕様書 10_spec/hooks/13-SubagentStop/subagent-stop-check.md 経路の表・制御方式 2 のとおりになっている（実行者照合は呼び出し元の作業ツリーのチケットで行い、確定できないときは WF815）（根拠: ）
- [ ] session-start.sh が仕様書 10_spec/hooks/00-SessionStart/session-start.md のとおりになっている（logs/mr.json が読めないとき現在地を断定せず WF705 で不明と根拠付きの推定を出す）（根拠: ）
- [ ] post-push-compact-prompt.sh の logs/push-state.json と post-push-usage-report.sh の logs/usage/ が共有ルート（HOOK_SHARED_ROOT）を指している（フック共通仕様 §5 の根の列）（根拠: ）
- [ ] 機械テスト DC-T08 と DC-T09 が通る（run-tests.sh --filter '*test_workflow_diff_check*'）。DC-T09 は負のコントロールで、枚数をテスト自身が assert する（根拠: ）
- [ ] 機械テスト SA-T10・SA-T11 が通る（run-tests.sh --filter '*test_subagent_start_check*'）（根拠: ）
- [ ] 機械テスト SP-T05・SP-T08・SP-T09 が通る（run-tests.sh --filter '*test_subagent_stop_check*'）。SP-T09 が A5 の実行者照合を閉じる（根拠: ）
- [ ] 機械テスト SE-T11 が通る（run-tests.sh --filter '*test_session_start*'）。4 つの状態を同じ作業領域で切り替えて固定する（根拠: ）
- [ ] post-push-* の既存テストが通る（run-tests.sh --filter '*test_post_push*'）（根拠: ）
- [ ] 変更直後に Write を 1 回行い、logs/hooks/decisions.jsonl に WF605 の誤爆が無いことを確かめた（ロックアウト対策）（根拠: ）
- [ ] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S5 と「ロックアウト対策」の S5 行に従う

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
