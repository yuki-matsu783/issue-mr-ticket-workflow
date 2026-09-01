---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0017", "0018"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-ai-asset-creator/assets/**", ".claude/skills/20-common-step-shell-script/**", ".claude/skills/20-common-step-ticket/**", ".claude/skills/20-common-step-commit-push/**", ".claude/skills/20-common-step-report-view/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T13:32:56+09:00"
completed_at: ""
base_sha: "fa273a4"
---

# 0019 AI アセット実装 S4-1: SKILL.md 4 本（shell-script / ticket / commit-push / report-view）

## 目的

スクリプトを持つ共通ステップスキル 4 本の SKILL.md を仕様の処理フロー・参照ナレッジと 1:1 で書く。規約の再掲はしない。

## DoD

- [ ] `20-common-step-ai-asset-creator/assets/skill.template.md` / `eval.template.md` が同仕様 OUT ひな形のとおりで、SKILL.md 4 本はこの雛形から作られている（根拠: ）
- [ ] 4 本の SKILL.md が frontmatter（name / description に発火条件）と本文（目的 / 手順 / 参照 / エラー時の対処）を持ち、各仕様の「処理フロー」「OUT ひな形」「参照ナレッジ」との対応表が作業ログにある（根拠: ）
- [ ] 提供コマンドの起動はすべてルート相対表記（`bash .claude/skills/.../scripts/x.sh`）で書かれている（共通仕様 §7-8）（根拠: ）
- [ ] 各 SKILL.md が Read の上限を超えない長さで、規約（bash・logger・frontmatter）を再掲せず参照している（根拠: ）
- [ ] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: ）
- [ ] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ）
- [ ] `git diff --stat <base_sha>` が許可範囲内（根拠: ）
- [ ] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: ）

## 作業内容

- 順: `skill.template.md` / `eval.template.md` → SKILL.md 4 本。土台は参考実装の対応スキル（Q6）。新仕様の要求差分を仕様から埋める
- 完了は `ticket.sh complete`（境目 B 以降）

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
