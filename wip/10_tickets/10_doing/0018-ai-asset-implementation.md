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
completed_at: ""
base_sha: "b0ac4f0"
---

# 0018 AI アセット実装 S2-5: check-html.sh と report / plan テンプレート（切り替え境目 C）

## 目的

HTML テンプレート 2 本と `check-html.sh` を仕様どおりに作り、以降の計画書・レポートを md + HTML の対で出せる状態にする。

## DoD

- [ ] `assets/report.template.html` / `assets/plan.template.html` が OUT ひな形の規約（自己完結・`<style>` 1 つ・両テーマ・視覚語彙・`{{名前}}` を要素内容として・必須節は `data-required`）を満たし、`reports-clean.template.html` を土台にサイドバー型で統一され、参考固有の記述（Q5「削るべき固有記述」）が無い（根拠: ）
- [ ] 計画書テンプレートの必須節が計画タスク共通の節（対象・チケット・保留した点 / 対象なし）を含む（Q5 の案）（根拠: ）
- [ ] `scripts/check-html.sh` が RV001〜007 を全項目実行して列挙し、RV006 の必須節一覧をテンプレートから導出し、RV002 が `<a href>`・`#` アンカー・`data:` を除外する（H4・H5）（根拠: ）
- [ ] RV-T01〜06 が通る（根拠: ）
- [ ] 0003 のレポートと 0011 の計画書を試し埋めした HTML が `check-html.sh` で `OK:` になる（境目 C の確認。ファイルは 0021 で正式に作るため `wip/tmp/` に置く）（根拠: ）
- [ ] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: ）
- [ ] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ）
- [ ] `git diff --stat <base_sha>` が許可範囲内（根拠: ）
- [ ] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: ）

## 作業内容

- 順: report テンプレート → plan テンプレート → check-html.sh（テスト先行）→ 試し埋め
- テンプレートはブラウザでの目視も行い、結果を作業ログに残す（調査の残課題）

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
