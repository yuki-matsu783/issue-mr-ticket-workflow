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
started_at: "2026-09-01T02:12:40Z"
completed_at: "2026-09-01T02:14:21Z"
base_sha: "e31970b"
---

# 0005 調査実施 — Q3 TBD T5（PowerShell ツールのフック入力）

## 目的

PowerShell ツールの PreToolUse フック入力が Bash と同じ `tool_input.command` かを確定し、共通仕様 §12 T5 の結論（前提どおり / 縮退）を出す。外部技術調査（Claude Code 公式ドキュメント）。

## DoD

- [x] 観点 Q3「PowerShell ツールのフック入力は Bash と同じ `tool_input.command` か」への答えが調査結果レポート `wip/30_reports/0003-investigation.md` にあり、`tool_name` と `tool_input` のキーが出典付きで書かれている（根拠: レポート「Q3」節。出典 https://code.claude.com/docs/en/tools-reference.md「PowerShell Tool Reference」、hooks-guide「Common Input Fields」）
- [x] T5 の結論（前提どおり / 縮退が必要）と、仕様（§12・`hook-common.sh` / `cmdpos.sh`）への反映内容が書かれている（根拠: レポート「Q3」節: 前提どおり、§12 の T5 行を「確認済み（出典付き）」に更新、登録表は既に `Bash|PowerShell` で差分なし（D6））
- [x] 一時フックを使った場合、`.claude/settings.json` が元に戻っていることを `git status` / `git diff` で確認し、コマンドと結果を作業ログに残している（使わなかった場合はその旨）（根拠: 一時登録そのものが auto モードの分類器に拒否され（Bash・Edit とも）、`settings.json` は一度も変更されていない。`git status --short` に `.claude/settings.json` は現れない — 作業ログ「拒否・確認・迂回の記録」）
- [x] 答えが出なかった問いは理由付きで残課題に残っている（根拠: レポート「残課題」に T5 の実機確認（未実施の理由と 2/3 での確認方法）を記載）

## 作業内容

- `claude-code-guide` エージェントで公式ドキュメント（hooks の PreToolUse 入力・PowerShell ツール）を確認する
- 確定できなければ一時フック（`wip/tmp/` に配置、`logs/` へ stdin を記録）を `settings.json` に一時登録して PowerShell ツールを 1 回実行する。反映に再起動が要るなら残課題にしてドキュメントの答えを採る。完了時に `settings.json` を戻す
- レポートに Q3 の節を追記する

## 作業ログ

### 現在地

- 完了（未完了の項目なし）

### うまくいったこと

- `claude-code-guide` エージェントで公式ドキュメントの該当節と URL が取れ、T5 だけでなく T3（ヘッドレス判別フィールドなし）・`agent_id` / `agent_type` の存在・`permissionDecision` の 4 値・settings.json の即時反映まで一度に確定した
### うまくいかなかったこと

- 一時フックの登録（`.claude/settings.json` の変更）が auto モードの分類器に拒否され、実機の JSON を取れなかった
### 仕様からの逸脱

- 手作業代替（ticket.sh 未実装）
- 調査計画の「確定できなければ一時フック」の手順は実行できず、ドキュメントの答えを採った（計画に書いた縮退どおり）
### 判断と根拠

- 分類器の拒否を迂回しない（`WORKFLOW_ENTRY_ENFORCE=0` と同様、権限の緩和はユーザーの明示があるときだけ）。ドキュメントの記述が明確で、2/3 のフック登録時に実機確認が自然に得られるため、本 issue で無理に確認する価値は低い
### 拒否・確認・迂回の記録

- Bash `jq … > .claude/settings.json` → 「Permission for this action was denied by the Claude Code auto mode classifier」
- Edit `.claude/settings.json`（hooks 追加）→ 同上。迂回せず中止
### 使った AI アセットと効き目

- `claude-code-guide` エージェント: 足りた（出典 URL 付き）
- 共通仕様 §12（TBD 表）: 検証項目が明確で足りた
### スコープ外で見つけたこと

- auto モードでは AI が `settings.json` を書けない → 2/3 のフック登録ステップは人間の適用または権限ルールの明示が要る（2/3 の計画に入れる）
- `permissionDecision: "defer"` の存在（`-p` で SDK が入力を集めて再開）。ヘッドレス設計（§10）の将来の選択肢
### AI アセットに反映すべき内容

- 共通仕様 §12 の T5 を確認済みにし、T3 も出典付きで補強する（D6）。§12 に D5（deny の JSON 経路）を 1 行追加
- 2/3 の全体計画へ: settings.json の適用は人間の操作として計画に組み込む
### 備考
