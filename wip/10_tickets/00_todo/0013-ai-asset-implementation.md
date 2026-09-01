---
type: ticket
ticket_type: ai-asset-implementation
predecessors: []
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "設定・定義のみ。敵対的レビューは実装の切れ目で 1 回"}
allow:
  write: [".gitattributes", ".claude/hooks/config/**", ".claude/rules/work-defaults.md", "wip/**"]
  ops: ["read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0013 AI アセット実装 S1: .gitattributes・task-types.tsv・scope-limits.json・work-defaults.md

## 目的

実装の前提になる設定・定義（S1-1〜S1-3）を置く。以降の sh が LF で保存され、`next` と scope 判定が読む 2 つの設定と、HK-T02 の 3 つ目のデータ（`work-defaults.md`）が揃った状態にする。

## DoD

- [ ] `.gitattributes` が `*.sh` `*.tsv` `*.json` `*.html` に `text eol=lf` を宣言し、追加後の `git status` に既存ファイルの再正規化が出ない（根拠: ）
- [ ] `.claude/hooks/config/task-types.tsv` が `00-workflow-issue-mr-driven` 仕様 OUT ひな形の 6 列・対応表の 15 行と一致している（根拠: ）
- [ ] `.claude/hooks/config/scope-limits.json` がフック共通仕様 §8 の構造（`common` 5 キー・`types` 15 種すべてに `ops`・`commands`）と初期値表のとおりで、`jq .` を通る（根拠: ）
- [ ] `.claude/rules/work-defaults.md` が要件 `rules/work-defaults.md` の必須項目（15 種 × 既定の実行者・人間レビュー・敵対的レビュー・理由・調整条件。1 type 1 行）を持ち、行動ルールとして frontmatter に効くタイミングを宣言している（根拠: ）
- [ ] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` を exec 仕様 OUT ひな形の節で作成し、S1 の節を書いた（HTML は境目 C 以降、0021 で遡及）（根拠: ）
- [ ] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: ）
- [ ] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ）
- [ ] `git diff --stat <base_sha>` が許可範囲内（根拠: ）

## 作業内容

- 計画書 S1。`.gitattributes` → 設定 2 本（`commands.build-test` は空配列）→ `work-defaults.md`（15 行）→ 実装結果レポートの作成 の順
- `work-defaults.md` の初期値は計画書の案。タスク種の文言は対応表と同じ
- HK-T02 の機械テストは 0014（test-lib 完成後）。ここでは `jq` と目視で 3 データの type 集合が一致することを確認して作業ログに残す

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
