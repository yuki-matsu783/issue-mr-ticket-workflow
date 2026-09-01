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
started_at: "2026-09-01T03:42:05Z"
completed_at: "2026-09-01T03:44:07Z"
base_sha: "cd1c283"
---

# 0013 AI アセット実装 S1: .gitattributes・task-types.tsv・scope-limits.json・work-defaults.md

## 目的

実装の前提になる設定・定義（S1-1〜S1-3）を置く。以降の sh が LF で保存され、`next` と scope 判定が読む 2 つの設定と、HK-T02 の 3 つ目のデータ（`work-defaults.md`）が揃った状態にする。

## DoD

- [x] `.gitattributes` が `*.sh` `*.tsv` `*.json` `*.html` に `text eol=lf` を宣言し、追加後の `git status` に既存ファイルの再正規化が出ない（根拠: `.gitattributes` 4 行。追加後の `git status --short` は新規ファイルと 0013 の移動のみ）
- [x] `.claude/hooks/config/task-types.tsv` が `00-workflow-issue-mr-driven` 仕様 OUT ひな形の 6 列・対応表の 15 行と一致している（根拠: `awk -F'\t' '{print NF}'` が全行 6、`grep -v '^#' | wc -l` = 15、type 列が `00-workflow-issue-mr-driven.md` 65〜81 行の対応表と同順）
- [x] `.claude/hooks/config/scope-limits.json` がフック共通仕様 §8 の構造（`common` 5 キー・`types` 15 種すべてに `ops`・`commands`）と初期値表のとおりで、`jq .` を通る（根拠: `jq '.types | keys | length'` = 15、`.common | keys` = allow confirm file_granular protected state_files、`[.types[] | has("ops")] | all` = true）
- [x] `.claude/rules/work-defaults.md` が要件 `rules/work-defaults.md` の必須項目（15 種 × 既定の実行者・人間レビュー・敵対的レビュー・理由・調整条件。1 type 1 行）を持ち、行動ルールとして frontmatter に効くタイミングを宣言している（根拠: `.claude/rules/work-defaults.md` 既定値表 15 行、frontmatter `category: behavior` / `applies_when`。3 データの type 集合を `diff` で照合し一致（jq 出力の CR を除去して比較 — H6 のとおり Windows jq は CRLF を出す））
- [x] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` を exec 仕様 OUT ひな形の節で作成し、S1 の節を書いた（HTML は境目 C 以降、0021 で遡及）（根拠: `wip/30_reports/0013-ai-asset-implementation.md` の「作成・更新したアセット」「テスト結果」「検査結果」「仕様からの逸脱」の 0013 節）
- [x] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: `grep -nE '\{\{|TODO|TBD'` 4 ファイルで 0 件、CR 0 件）
- [x] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: 新規 4 ファイルに計画書の検索語 5 語のヒットなし）
- [x] `git diff --stat <base_sha>` が許可範囲内（根拠: 変更は `.gitattributes`・`.claude/hooks/config/`・`.claude/rules/work-defaults.md`・`wip/` のみ）

## 作業内容

- 計画書 S1。`.gitattributes` → 設定 2 本（`commands.build-test` は空配列）→ `work-defaults.md`（15 行）→ 実装結果レポートの作成 の順
- `work-defaults.md` の初期値は計画書の案。タスク種の文言は対応表と同じ
- HK-T02 の機械テストは 0014（test-lib 完成後）。ここでは `jq` と目視で 3 データの type 集合が一致することを確認して作業ログに残す

## 作業ログ

### 現在地

- 済: `.gitattributes`、`task-types.tsv` / `scope-limits.json`、`work-defaults.md`、実装結果レポート（S1 節）、完了

### うまくいったこと

- 3 データの type 集合の照合を先に手で行い、HK-T02 のテストの形（tsv 2 列目 / json keys / md の表 1 列目を sort して diff）が固まった

### うまくいかなかったこと

- Windows ネイティブ jq の出力に CR が付き、最初の `diff` が全行不一致に見えた（`tr -d '\r'` で解消。H6 の再確認）

### 仕様からの逸脱

- 行動ルールの効くタイミングを frontmatter `applies_when` で宣言（キー名を定める仕様が未作成）— レポート D-1
- `task-types.tsv` の 1 行目を `#` 始まりのヘッダにした — レポート D-2

### 判断と根拠

- `.gitattributes` に `*.md` を含めない: 既存 md の再正規化で差分が膨らむのを避ける。sh・tsv・json・html は LF が前提
- `commands.build-test` は空配列: 提供コマンドは分類を問わず許可されるため列挙不要（計画書の保留欄）
- `work-defaults` の `ai-asset-implementation` の既定実行者は opus（中核を含む場合）。中核を含まなければ sonnet に下げる条件を書いた

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- 無し（設定・定義の作成のみ）

### スコープ外で見つけたこと

- 無し

### AI アセットに反映すべき内容

- HK-T02 の実装（0014）: jq の出力は必ず CR を除去してから比較する（`hook_jq` 相当をテスト側にも置く）

### 備考

- 無し
