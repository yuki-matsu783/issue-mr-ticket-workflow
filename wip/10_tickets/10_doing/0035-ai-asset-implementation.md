---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0034"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる（work-defaults の既定）。承認④により切れ目で opus 自己レビューに代替"}
adversarial_review: {required: true, reason: "振る舞いが変わる（work-defaults の既定）。切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-report-view/scripts/**", ".claude/skills/20-common-step-shell-script/scripts/**", ".claude/hooks/lib/tests/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T18:54:34+09:00"
completed_at: ""
base_sha: "bef95e5"
---

# 0035 AI アセット実装: check-html.sh の RV008・test-lib の hook_payload --session・HK-T15 の付番と RV-T07（wip/20_plans/0031-ai-asset-implementation-plan.md の S2-3・S3-3）

## 目的

計画 wip/20_plans/0031-ai-asset-implementation-plan.md の S2-3 / S3-3: check-html.sh の引数・ファイル不正の最終行を RV008: に（4 か所）、test-lib.sh の hook_payload に --session <id>（既定 testsession）を足し、test_scope.sh の glob 以外 5 ケース関数（93 assert）の ID を HK-T11 → HK-T15 に付け替え（冒頭コメントは両 ID に）、test_hook_common.sh のセッション状態のケースで --session を使い、設計が仕様に足した SS-T04（読み込み行の 3 ポリシー）・TR-T04（timeout 不在 → TR005 終了 2）・FR-T05（計数 PATH で 0 回・list / inline キーの生文字列）を test_templates.sh / test_run_tests.sh / test_frontmatter.sh に追記する。テスト先行で RV-T07 を新設する。run-tests.sh --ids の全件と、実装結果レポートの HTML を新版の check-html.sh に通すのが最初の実機確認

## DoD

- [ ] check-html.sh が仕様 Script 処理のとおり（RV008 は引数・ファイル不正で終了 2・最終行 RV008:、導出元テンプレート不明は RV006 終了 1）、test-lib.sh が仕様 OUT ひな形のとおり（hook_payload <event> <tool_name> [--session <id>] <json-fields...>）になっている（根拠: ）
- [ ] 機械テスト RV-T07（新）が通り、test_scope.sh の付け替えで run-tests.sh --ids に HK-T15 が現れ grep -c HK-T11 が 21（case_glob 20 + コメント 1）になり、test_hook_common.sh の HK-T07 / T08 で --session の 2 セッションが区別され、SS-T04 / TR-T04 / FR-T05 の追記分が通る（実行方法: run-tests.sh --ids）。テスト先行の記録が作業ログにある（根拠: ）
- [ ] run-tests.sh --ids が全件 PASS（既存 14 本 / 55 件 + 追加分）で、結果（本数・ID 数）が作業ログにある（根拠: ）
- [ ] プレースホルダ（{{名前}}・TODO・TBD。assets/*.template.* は対象外）と frontmatter の検査が 0 件で、結果がコマンドと件数で作業ログにある（根拠: ）
- [ ] 参照更新の検索で旧記述が 0 件: check-html.sh の "RV: 、test_scope.sh の HK-T11 は 21 件（case_glob 20 + 冒頭コメント 1）だけ（根拠: ）
- [ ] 実装結果レポートの HTML を変更後の check-html.sh で検査して OK（ロックアウト対策の最初の操作）（根拠: ）
- [ ] 実装結果レポート wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）にこのチケットの節（作成・更新したアセット × 仕様の節 / テスト結果 / 検査結果 / 仕様からの逸脱）がある（根拠: ）

## 作業内容

- 計画の変更対象 A6・A7・A8 と仕様の該当節を読み、20-common-step-shell-script の手順で変更する。--session は第 3 引数位置に限定し key=value の解析と衝突させない
- テスト先行: RV-T07 を先に書いて失敗を確認 → 実装 → 付け替え → SS-T04 / TR-T04 / FR-T05 の追記 → 全件。push は完了コミット直後（doing 空）に

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
