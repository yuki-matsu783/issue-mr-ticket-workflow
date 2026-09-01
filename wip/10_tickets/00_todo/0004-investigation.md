---
type: ticket
ticket_type: investigation
predecessors: ["0002"]
executor: main
human_review: {required: true, reason: "テスト方式と HTML テンプレートの土台が実装計画を左右する（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "調査結果は次の計画で検証される"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0004 調査実施 — Q2 テストの実行方式 / Q5 HTML テンプレートの土台

## 目的

参考実装のテストを読んで 1 本動かし、採用するテスト方式（ヘルパ・置き場・実行コマンド）を決める材料を出す。HTML テンプレートの土台と `check-html.sh` の検査に必要な構造を確認する。

## DoD

- [ ] 観点 Q2「テストをどう実行するか」への答えが調査結果レポート `wip/30_reports/0003-investigation.md` にあり、Git Bash での実行結果（コマンドと要約）と bats の要否の判断が書かれている（根拠: ）
- [ ] 観点 Q5「HTML テンプレートの土台と check-html.sh の検査に必要な構造」への答えが同レポートにあり、土台のパス・節構成・`data-required` 候補・外部依存の有無が書かれている（根拠: ）
- [ ] 各答えに根拠（ファイル・行・コマンドの出力）が添えられている（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）

## 作業内容

- 調査計画書「対象と方法」Q2・Q5 のとおり読み、参考実装のテストを 1 本実行する（書き込みは一時ディレクトリと `wip/tmp/` のみ）
- レポートに Q2・Q5 の節を追記する

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
