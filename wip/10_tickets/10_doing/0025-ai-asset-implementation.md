---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0024"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "中核の提供コマンドで、機構自身を止め得る（work-defaults の基準どおり要）"}
allow:
  write: [".claude/skills/00-workflow-issue-mr-driven/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T04:26:21+09:00"
completed_at: ""
base_sha: "509240b"
---

# 0025 S2 中核: boundary.sh とそのテスト（BD-T01〜13）

## 目的

タスクの切れ目の判定・レビュー依頼・完了確認を担う提供コマンドを作り、logs/review-state.json を書き換える唯一の経路にする

## DoD

- [ ] bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh が 5 サブコマンド（status / note / request / skip / complete）を持ち、00-workflow-issue-mr-driven 仕様の Script 処理のとおりになっている（根拠: ）
- [ ] 機械テスト BD-T01〜BD-T13 の 13 件が通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter boundary）（根拠: ）
- [ ] 終了コードが 成功 0 / 前提・状態の未充足 1 / 引数・環境の誤り 2 で、最終行が OK: または BDxxx: になっている（根拠: ）
- [ ] 共通 logger を読み込み logs/sh/ に実行ログを残している（rules/logger.md の使い分け）（根拠: ）
- [ ] 書いた直後の 1 回目を commit.sh で自分をコミットして検証し、失敗時に戻す基準点（base_sha）を作業ログに記録している（根拠: ）
- [ ] このチケットの間 boundary.sh を自分の切れ目の手順に組み込んでいない（保留 P2 の判断。実運用は次の issue から）（根拠: ）

## 作業内容

- boundary.sh を書く
- テストを書いて --filter で実行する

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
