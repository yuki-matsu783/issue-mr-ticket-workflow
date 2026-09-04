---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0053"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まず、全件テストで機械的に確かめられる"}
allow:
  write: [".claude/skills/**", ".claude/rules/**", "wip/**", "logs/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-04T17:50:01+09:00"
completed_at: ""
base_sha: "1728adc"
---

# 0054 参照更新と全件テスト（S5）

## 目的

件数・文言の追随を検索で洗い出して直し、全件テストで回帰を確かめる

## DoD

- [ ] 計画書の参照更新一覧 7 行それぞれについて、検索語・実際の出力・期待値（残るもの）が作業ログに記録され、期待どおりになっている（根拠: ）
- [ ] grep -rn '14 項目' .claude/skills/ が 0 件、grep -rn 'cp .claude/skills/20-common-step-report-view/assets' .claude/skills/ が 0 件、grep -rn '承認が欲しい' .claude/skills/ が 0 件（根拠: ）
- [ ] 旧名の検索（10-work- / 20-task- / work-boundary / merge-prep。DDR を除く）が .claude/ と CLAUDE.md で 0 件（根拠: ）
- [ ] プレースホルダの検索（grep -rn '{{' .claude/skills/*/SKILL.md .claude/rules/）が 0 件（根拠: ）
- [ ] 全件テストが通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --timeout 300 を背景で実行し、ファイル数・テスト ID 数・アサーション数を記録する）（根拠: ）
- [ ] 実装結果レポートに S5 の節と、受け入れ条件との対応（A1: SKILL.md が仕様と 1:1）が書かれ、check-html.sh が通っている（根拠: ）

## 作業内容

- 参照更新一覧の 7 行を順に確かめて直し、最後に全件テストを実行する

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
