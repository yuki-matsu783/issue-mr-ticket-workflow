---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0035"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "workflow-guard は中核で、緩めすぎると許可範囲の統制が効かなくなる"}
allow:
  write: [".claude/hooks/20-PreToolUse/**", ".claude/skills/00-workflow-issue-mr-driven/**", ".claude/skills/00-workflow-quick-request/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T13:18:38+09:00"
completed_at: ""
base_sha: "e1b2ee1"
---

# 0036 S12 中核: 許可範囲内のファイル削除を通す（WF205）と旧資産の削除

## 目的

AI がチケットの許可範囲内で .claude/ 配下のファイルを削除できるようにし、0031 で消せなかった旧資産を実際に消す

## DoD

- [ ] workflow-guard の WF205 が、削除だけを行うコマンド（rm / git rm）の対象がチケットの allow.write に収まっているときは拒否しない。作成・更新（cp / tee / sed -i など）の扱いは変えない（根拠: ）
- [ ] 許可範囲外の削除は今までどおり WF205 で拒否される（負のコントロール）（根拠: ）
- [ ] 作業中チケットが無いとき（allow.write が無いとき）の削除は今までどおり拒否される（根拠: ）
- [ ] test_workflow_guard.sh に上記 3 件の再現テストが足され、run-tests.sh --filter で全件通る（根拠: ）
- [ ] .claude/skills/00-workflow-issue-mr-driven/assets/issue-addendum.template.md と issue-notify.template.md が消えている（削除の前提確認は 0031 で済んでいる）（根拠: ）
- [ ] .claude/skills/00-workflow-issue-mr-driven/references/issue-triage.md が消え、20-common-step-issue/references/ 側だけが残っている（根拠: ）
- [ ] .claude/skills/00-workflow-issue-mr-driven/evals/evals.json と 00-workflow-quick-request/evals/evals.json が消えている（移行先は .claude/evals/ の 2 本。0031 で作成済み）（根拠: ）
- [ ] WF205 の判定を変えたことが仕様（10_spec/hooks/20-PreToolUse/workflow-guard.md）と食い違う場合は、逸脱として作業ログに記録し設計反映へ送っている（根拠: ）

## 作業内容

- workflow-guard の書き込み宛先の検査に、削除のみのコマンドを allow.write で判定する分岐を足す
- テストを足してから旧資産 3 種 5 ファイルを削除し、commit.sh でコミットする

## 経緯

0031（S8）で旧資産の削除に着手したところ、WF205 が `rm` / `mv` / `git rm` を一律に拒否し、コマンドで書いてよいのは `wip/tmp/**` と `logs/**` だけだった。Edit / Write ツールにファイルを消す手段は無いため、AI は `.claude/` 配下のアセットを削除できない。一方で AI アセット実装計画の仕様は変更対象に「削除」を含めており、機構と設計が食い違っている。ユーザーの判断（2026-09-04）で、機構側を直してから削除を行うことにした。

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
