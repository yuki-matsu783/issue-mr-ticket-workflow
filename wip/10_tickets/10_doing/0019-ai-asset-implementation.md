---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0013"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズ 4 の敵対的レビューは 0017 の完了後にまとめて 1 回実施する"}
allow:
  write: [".claude/hooks/config/scope-limits.json", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-02T11:02:05+00:00"
completed_at: ""
base_sha: "9e68c8b"
---

# 0019 実装: commands.build-test に拡張のテストコマンドを列挙する

## 目的

npm test が判定順の分類で build-test になり、実装チケットから実行できるようにする（0016 の再起票）

## DoD

- [ ] scope-limits.json の commands.build-test に npm test と npm --prefix apl/vscode-ticket-board test が入り、jq で構文が通る（根拠: ）
- [ ] test_config_integrity.sh に commands.build-test の中身を固定するアサーションがあり、変更前に落ちて変更後に通ることを確かめた（根拠: ）
- [ ] run-tests.sh --ids が 14 本すべて PASS する（根拠: ）

## 作業内容

- テストを先に書いて落としてから設定を直す

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
