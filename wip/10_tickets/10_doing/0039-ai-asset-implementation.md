---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0038"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "実装フェーズの敵対的レビューは上限 2 回に達している"}
allow:
  write: [".claude/skills/10-task-overall-summary/**", ".claude/skills/00-workflow-issue-mr-driven/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T14:10:31+09:00"
completed_at: ""
base_sha: "44bee00"
---

# 0039 S14 提供コマンドの残り 4 件（敵対的レビュー 2 回目の指摘）

## 目的

finalize.sh の GitLab 経路の draft 判定・merge-state の branch・porcelain のクォート、test_boundary の TZ 依存を直す

## DoD

- [ ] GitLab の is_draft が draft:false を「draft でない」（戻り 1）として返す。jq の // が false を右辺に倒す形を使わない（根拠: ）（根拠: ）
- [ ] finalize.sh の write_state が branch を書き、boundary.sh の merge-state の突き合わせ（.branch）が実際に効く。仕様のスキーマとの差は逸脱として記録する（根拠: ）（根拠: ）
- [ ] BD-T18 に mr.json の番号が一致するとき・しないときのケースが足され、.mr の比較分岐が実際に踏まれる（根拠: ）（根拠: ）
- [ ] 片付けの再実行が git status --porcelain の引用付きパスで壊れない（空白や日本語を含むファイル名で FN002 にならない）（根拠: ）（根拠: ）
- [ ] BD-T14 が実行環境のタイムゾーンに依存しない。date -d が無い環境では pass ではなく skip として数える（根拠: ）（根拠: ）
- [ ] run-tests.sh --filter で test_finalize と test_boundary が全通過（根拠: ）（根拠: ）

## 作業内容

- DoD の各項目を順に満たす

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
