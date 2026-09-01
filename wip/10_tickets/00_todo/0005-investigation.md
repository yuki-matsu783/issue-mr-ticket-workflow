---
type: ticket
ticket_type: investigation
predecessors: ["0002"]
executor: main
human_review: {required: true, reason: "T5 の結論は仕様の確定事項になる（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "調査結果は次の計画で検証される"}
allow:
  write: ["wip/**", "logs/**", ".claude/settings.json"]
  ops: ["read", "remote-read", "web"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0005 調査実施 — Q3 TBD T5（PowerShell ツールのフック入力）

## 目的

PowerShell ツールの PreToolUse フック入力が Bash と同じ `tool_input.command` かを確定し、共通仕様 §12 T5 の結論（前提どおり / 縮退）を出す。外部技術調査（Claude Code 公式ドキュメント）。

## DoD

- [ ] 観点 Q3「PowerShell ツールのフック入力は Bash と同じ `tool_input.command` か」への答えが調査結果レポート `wip/30_reports/0003-investigation.md` にあり、`tool_name` と `tool_input` のキーが出典付きで書かれている（根拠: ）
- [ ] T5 の結論（前提どおり / 縮退が必要）と、仕様（§12・`hook-common.sh` / `cmdpos.sh`）への反映内容が書かれている（根拠: ）
- [ ] 一時フックを使った場合、`.claude/settings.json` が元に戻っていることを `git status` / `git diff` で確認し、コマンドと結果を作業ログに残している（使わなかった場合はその旨）（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）

## 作業内容

- `claude-code-guide` エージェントで公式ドキュメント（hooks の PreToolUse 入力・PowerShell ツール）を確認する
- 確定できなければ一時フック（`wip/tmp/` に配置、`logs/` へ stdin を記録）を `settings.json` に一時登録して PowerShell ツールを 1 回実行する。反映に再起動が要るなら残課題にしてドキュメントの答えを採る。完了時に `settings.json` を戻す
- レポートに Q3 の節を追記する

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
