---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0014"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-report-view/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T13:16:22+09:00"
completed_at: "2026-09-01T13:32:18+09:00"
base_sha: "b0ac4f0"
---

# 0018 AI アセット実装 S2-5: check-html.sh と report / plan テンプレート（切り替え境目 C）

## 目的

HTML テンプレート 2 本と `check-html.sh` を仕様どおりに作り、以降の計画書・レポートを md + HTML の対で出せる状態にする。

## DoD

- [x] `assets/report.template.html` / `assets/plan.template.html` が OUT ひな形の規約（自己完結・`<style>` 1 つ・両テーマ・視覚語彙・`{{名前}}` を要素内容として・必須節は `data-required`）を満たし、`reports-clean.template.html` を土台にサイドバー型で統一され、参考固有の記述（Q5「削るべき固有記述」）が無い（根拠: `assets/report.template.html` / `assets/plan.template.html`。`grep -c 'wip/reports\|flow-id\|issue-mr-flow\|deliverables.md\|REVIEW-POINTS\|canvas-report'` 0 件、`<style>` 1 つ、`prefers-color-scheme` あり、RV-T01 で埋めた HTML が OK）
- [x] 計画書テンプレートの必須節が計画タスク共通の節（対象・チケット・保留した点 / 対象なし）を含む（Q5 の案）（根拠: `plan.template.html` の `dl#meta`（対象）・`#tickets`・`#pending` に `data-required`）
- [x] `scripts/check-html.sh` が RV001〜007 を全項目実行して列挙し、RV006 の必須節一覧をテンプレートから導出し、RV002 が `<a href>`・`#` アンカー・`data:` を除外する（H4・H5）（根拠: `scripts/check-html.sh` 検査 1〜7、RV-T02（全件列挙）・RV-T05（除外）・RV-T06（導出））
- [x] RV-T01〜06 が通る（根拠: `run-tests.sh --ids` の PASS ID に RV-T01〜06。36 assert）
- [x] 0003 のレポートと 0011 の計画書を試し埋めした HTML が `check-html.sh` で `OK:` になる（境目 C の確認。ファイルは 0021 で正式に作るため `wip/tmp/` に置く）（根拠: `wip/tmp/trial/0011-ai-asset-implementation-plan.html` = OK（id 15 / リンク 8）、`wip/tmp/trial/0003-investigation.html` = OK（id 16 / リンク 9））
- [x] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: `grep -nE '\{\{|TODO|TBD'` check-html.sh・test_check_html.sh で 0 件）
- [x] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: 新規 4 ファイルに検索語 5 語のヒットなし）
- [x] `git diff --stat <base_sha>` が許可範囲内（根拠: 変更は `.claude/skills/20-common-step-report-view/`・`wip/` のみ）
- [x] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: レポートの 0018 節（アセット表・テスト結果・検査結果・D-16〜D-18・確かめられなかったこと））

## 作業内容

- 順: report テンプレート → plan テンプレート → check-html.sh（テスト先行）→ 試し埋め
- テンプレートはブラウザでの目視も行い、結果を作業ログに残す（調査の残課題）

## 作業ログ

### 現在地

- 済: 着手（`ticket.sh start 0018`。直前の `ticket.sh next` は `{"current":null,"next":"0018","type":"ai-asset-implementation","skill":"10-task-ai-asset-implementation-exec"}` を返した — 境目 B の確認）
- 済: テンプレート 2 本、check-html.sh、テスト RV-T01〜06（36 assert 全 PASS）、試し埋め 2 本 OK、レポート追記。完了は `ticket.sh complete 0018`

### うまくいったこと

- RV-T04（負のコントロール）が、負のコントロール経路自体の `pipefail` バグを捕まえた
- 必須節をテンプレートの `data-required` から導出する方式で、テンプレートと検査の二重管理を避けられた

### うまくいかなかったこと

- テンプレートの説明コメントに `{{名前}}` の語を書き、RV001（コメント内も数える）に自分で当たった
- ブラウザでの目視ができない（環境）

### 仕様からの逸脱

- D-16〜D-18（レポート「仕様からの逸脱」）

### 判断と根拠

- RV001 はコメント内のプレースホルダも数える（雛形の痕跡を残さない要件。地の文で触れたいときは表記を変える）
- 計画書テンプレートの必須節は Q5 の案 + 計画タスク共通節（チケット・保留した点 / 対象なし）。リスク・スコープ外は任意
- テンプレート種別は `<body data-template>` で持たせる（置き場に依存しない。試し埋めを `wip/tmp/` に置いても検査できる）

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `script.template.sh` / `test.template.sh` / `run-tests.sh`（型どおり）。参考 `reports-clean.template.html`（CSS と DOM の土台）

### スコープ外で見つけたこと

- 無し

### AI アセットに反映すべき内容

- report-view 仕様に `data-template` 属性と計画書の節構成を書き足し、必須節の判断を DDR に残す（0022 の入力）

### 備考

- 境目 C 以降: 計画書・レポートは md + HTML の対で作り `check-html.sh` を通す。既存分は 0021 で遡及
