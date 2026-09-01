---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0019"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-ai-asset-creator/**", ".claude/skills/20-common-step-feature-mr/**", ".claude/skills/20-common-step-issue/**", ".claude/skills/20-common-step-requirement/**", ".claude/skills/20-common-step-spec/**", ".claude/evals/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T13:36:42+09:00"
completed_at: ""
base_sha: "71956c3"
---

# 0020 AI アセット実装 S4-2: SKILL.md 5 本と assets 6 本・eval 定義 5 本

## 目的

スクリプトを持たない共通ステップスキル 5 本の SKILL.md・テンプレートと、その eval 定義を仕様どおりに作る。eval は定義まで。

## DoD

- [ ] 5 本の SKILL.md が各仕様の処理フロー・参照ナレッジと 1:1 で、対応表が作業ログにある（根拠: ）
- [ ] assets（`mr-body.template.md` / `issue.template.md` / `issue-addendum.template.md` / `requirements.template.md`。`skill.template.md` / `eval.template.md` は 0019 で作成済み）が各仕様 OUT ひな形のとおりで、テンプレートが完成形として正しい frontmatter を持つ（根拠: ）
- [ ] `.claude/evals/20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}.md` が `eval.template.md` から作られ、AC-E / FM-E / IS-E / RQ-E / SP-E の各 3 件を定義し、未実行を明記している（根拠: ）
- [ ] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: ）
- [ ] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ）
- [ ] `git diff --stat <base_sha>` が許可範囲内（根拠: ）
- [ ] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: ）

## 作業内容

- 順: ai-asset-creator の SKILL.md → 他 4 本の SKILL.md と assets → eval 定義 5 本（`eval.template.md` から）
- 参考実装の `evals/evals.json` の形は取り込まず、`eval.template.md` の md 形式に揃える

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
