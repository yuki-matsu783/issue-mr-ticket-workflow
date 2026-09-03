---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0026"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "session-start.sh は注入そのものを行う中核で、不在時は無出力で終了 0 に倒れるため壊れても気づきにくい"}
allow:
  write: [".claude/hooks/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0027 S4 中核: フック 3 行の追随とテスト 4 行・注入（SE-T01〜10・WE-T10）

## 目的

提供コマンド 2 本の置き場を仕様側に確定した決定（DDR i0010-01）に実装済みフックを追随させ、boundary.sh 依存で 3/3 へ送られていたテスト 9 件を実装する

## DoD

- [ ] session-start.sh:64 のパスが .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh になっている（中核。ロックアウト対策は SE-T10）（根拠: ）
- [ ] workflow-state-guard.sh:40, 43 の案内文が新しい置き場を指している（根拠: ）
- [ ] 期待値が置き場に依存するテスト 4 行（test_workflow_entry.sh:143, 144 / test_workflow_state_guard.sh:117, 118）が新しいパスに直り、WE-T06・WE-T11・SG-T05 が通る（根拠: ）
- [ ] SE-T10 が通る: 新しい置き場に boundary.sh を置くと注入され、旧い置き場だけに置くと注入されず hook_record skip の理由が「不在」になる（パスを実際に踏む。SE-T05 後半では代えられない）（根拠: ）
- [ ] SE-T01〜SE-T04・SE-T07〜SE-T09 と WE-T10 の 8 件が通る（boundary.sh status --offline に依存していたもの）（根拠: ）
- [ ] SE-T05・SE-T06 の前半（review-state.json 破損時に WF702 を該当行に出して他の行は出す / source=compact でも同じ内容）が実装され、テストの本文が前半と後半の両方の観点を踏んでいる（ID 数には現れない）（根拠: ）
- [ ] run-tests.sh --filter で session-start と workflow-entry と workflow-state-guard を実行し、全件通る（根拠: ）

## 作業内容

- フック 3 行とテスト 4 行を直す
- 注入の残りと boundary.sh 依存テスト 9 件を実装する

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
