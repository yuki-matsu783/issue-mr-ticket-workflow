---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0020"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: true, reason: "実装の切れ目。差分全体（0013〜0021）を対象に 1 回"}
allow:
  write: [".claude/rules/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0021 AI アセット実装 S4-3・S5-1: ルール 3 本（logger / design-docs / ai-asset-design-docs）と参照更新・HTML 遡及

## 目的

成果物ルール 3 本を要件と章スキーマどおりに書き、参照更新一覧の再検索と既存計画書・レポートの HTML 遡及作成で本 issue の実装を閉じる。

## DoD

- [ ] `.claude/rules/{logger,design-docs,ai-asset-design-docs}.md` が各要件の「ルールが定める内容」を満たし、7 章固定・該当なしは根拠 1 行・`paths` を frontmatter に持つ（根拠: ）
- [ ] 参照更新一覧の検索語を再実行し、件数が計画書の記録から増えていない（根拠: ）
- [ ] `wip/20_plans/*.md`・`wip/30_reports/*.md`（付録を除く）に同名の HTML があり、全件 `check-html.sh` で `OK:`。`wip/push-check-skip.md` を削除した（根拠: ）
- [ ] `run-tests.sh --ids` が全通過し、ID 一覧が各仕様の「テスト観点」と一致する（根拠: ）
- [ ] AI アセット実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md`（+ HTML）が exec 仕様 OUT ひな形の節（アセット一覧と仕様の節・テスト結果（機械 / eval 未実行）・検査結果・逸脱一覧・想定と異なった点・残課題）を持つ（根拠: ）
- [ ] プレースホルダ（`{{ }}`・`TODO`・`TBD`）と frontmatter の検査が 0 件（根拠: ）
- [ ] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ）
- [ ] `git diff --stat <base_sha>` が許可範囲内（根拠: ）

## 作業内容

- 順: ルール 3 本 → 再検索 → HTML 遡及 → skip 削除 → 全テスト → 結果レポート
- 結果レポートには 0013〜0021 の作業ログ「仕様からの逸脱」を集約し、0022 の入力にする

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
