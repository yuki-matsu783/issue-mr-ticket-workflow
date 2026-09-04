---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0050"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "提供コマンド 2 本は中核で、壊れると切れ目の判定と片付けが止まる"}
allow:
  write: ["logs/**"]
  ops: ["hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0051 提供コマンド 2 本の引数・環境の誤りの識別子を分ける（S2・中核）

## 目的

boundary.sh と finalize.sh が終了 2 のときに前提未充足と同じ番号を返している状態を、BD006 / FN004 に分ける

## DoD

- [ ] boundary.sh の arg_ng が BD006 を終了コード 2 で返す（00-workflow-issue-mr-driven 仕様 エラー識別子）。前提未充足は BD001 と終了 1 のまま（根拠: ）
- [ ] finalize.sh の arg_ng が FN004 を終了コード 2 で返す（10-task-overall-summary 仕様 エラー識別子）。前提未充足は FN001 と終了 1 のまま（根拠: ）
- [ ] 機械テスト BD-T19 と FN-T18 が通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_boundary*' と --filter '*test_finalize*'）（根拠: ）
- [ ] 既存の BD-T03 / BD-T09 / BD-T16 / FN-T02 / FN-T10 が期待値を変えずに通る（いずれも終了 1 の前提未充足）（根拠: ）
- [ ] 変更の直後に commit.sh で自分をコミットし、boundary.sh status が JSON を返すことを確かめている（ロックアウト対策。踏む経路と結果を作業ログに書く）（根拠: ）
- [ ] 実装結果レポートに S2 の節が追記されている（根拠: ）

## 作業内容

- boundary.sh と finalize.sh の arg_ng を直し、テストを足して実行する

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
