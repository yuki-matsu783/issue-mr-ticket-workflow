---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0023", "0024"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/skills/**", ".claude/agents/**", ".claude/rules/**", ".claude/evals/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0025 S8 スキル・ルール・エージェントと eval 定義

## 目的

設計が確定させた運用（並列実施の発効の保留・切れ目での合流・採番と push の本流限定・並列区間のレポート追記規約・並列してよいタスクの種類）を、スキル本体・ルール・エージェント定義と eval 定義に落とす。

## DoD

- [ ] 00-workflow-issue-mr-driven/SKILL.md が仕様書 10_spec/skills/00-workflow-issue-mr-driven.md の概要・手順 2b（発効の保留と解禁の条件）・手順 2c（切れ目での合流）・手順 3-0・参照ナレッジのとおりになっている（根拠: ）
- [ ] 20-common-step-ticket/SKILL.md と 20-common-step-commit-push/SKILL.md が採番の本流一本化・push の本流限定を案内している（各仕様）（根拠: ）
- [ ] 10-task-investigation-exec/SKILL.md が並列区間のレポート追記規約・訂正の節・作業ディレクトリの決まりを持っている（仕様書 10_spec/skills/10-task-investigation-exec.md）（根拠: ）
- [ ] .claude/agents/task-executor.md が仕様書 10_spec/agents/task-executor.md のとおりになっている（並列時の前提・isolation は成果を残す作業に使わない・作業している場所が渡された作業ツリーでなければ始めずに返す）（根拠: ）
- [ ] .claude/rules/work-defaults.md の表に「並列してよいか」の列があり、計画タスクは常に直列・実施タスクは依存しないチケットどうしなら並列可・既定は並列にしない が明示されている（要件 00_requirement/rules/work-defaults.md メインフロー）（根拠: ）
- [ ] eval WFD-E07・WFD-E08・WFD-E09・WFD-E10 が .claude/evals/00-workflow-issue-mr-driven.md に定義されている（実行しない）（根拠: ）
- [ ] eval TXE-E02・TXE-E07・TXE-E08・TXE-E09 が .claude/evals/task-executor.md に定義されている（実行しない）（根拠: ）
- [ ] eval IVE-E05・IVE-E06 が .claude/evals/10-task-investigation-exec.md に定義されている（実行しない）（根拠: ）
- [ ] 機械テスト HK-T02 が通る（run-tests.sh --filter '*config_integrity*'。work-defaults.md に列を足した直後に回す）（根拠: ）
- [ ] 変更したスキルを Skill ツールで 1 回読み込めることを確かめた（frontmatter の破損検出。ロックアウト対策）（根拠: ）
- [ ] プレースホルダ（{{ }} / TODO / TBD）が変更した全ファイルで 0 件で、frontmatter が種別ごとの必須項目を満たす（根拠: ）
- [ ] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S8 と「ロックアウト対策」の S8 行に従う
- 復旧は git checkout を使わない（checkout は _SC_GIT_READ_SUBCMDS に無く unknown → WF204）。git show <base_sha>:<パス> で内容を取り、Write ツールで書き戻す。書き戻し先（.claude/skills/** / .claude/agents/** / .claude/rules/** / .claude/evals/**）は本チケットの allow.write に入っている

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
