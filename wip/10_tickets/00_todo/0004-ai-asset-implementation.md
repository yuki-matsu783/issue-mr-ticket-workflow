---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0001"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる。提供コマンドの中核"}
adversarial_review: {required: false, reason: "敵対的レビューエージェントが未作成。機械テストで代替する"}
allow:
  write: [".claude/skills/20-common-step-commit-push/scripts/commit.sh", ".claude/skills/20-common-step-commit-push/scripts/tests/test_commit.sh", ".claude/skills/20-common-step-ticket/scripts/ticket.sh", "wip/**"]
  ops: ["read", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0004 commit.sh をステージ済みの削除に対応させ、テストを追加する

## 目的

レビュー済みの仕様どおりに commit.sh を直し、削除の 3 経路と混在ケース・誤り経路をテストで固定する

## DoD

- [ ] rm のみ / rm + git add / git rm の 3 経路で削除だけのコミットが成功し、コミットに削除が記録される（根拠: ）
- [ ] 削除と追加・変更の混在を 1 回で渡してもコミットできる（根拠: ）
- [ ] 実在しないパスと .gitignore 対象は CP001 で止まり、メッセージがステージ済みの削除と区別できる（根拠: ）
- [ ] 除外パターンの検査が削除対象にも効くことがテストで固定されている（根拠: ）
- [ ] test_commit.sh に CP-T09 と CP-T10 のテストが追加され、run-tests.sh が全通過する（根拠: ）
- [ ] ticket.sh の do_commit の回避が不要かを確認し、判断と根拠を作業ログに残している（根拠: ）

## 作業内容

- 20-common-step-ai-asset-creator と 20-common-step-shell-script に従って実装とテストを行う
- run-tests.sh でスクリプト全体のテストを回し、bash -n と shellcheck の結果を残す

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
