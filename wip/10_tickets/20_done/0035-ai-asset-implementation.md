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
completed_at: "2026-09-01T19:21:50+09:00"
base_sha: "bef95e5"
---

# 0035 AI アセット実装: check-html.sh の RV008・test-lib の hook_payload --session・HK-T15 の付番と RV-T07（wip/20_plans/0031-ai-asset-implementation-plan.md の S2-3・S3-3）

## 目的

計画 wip/20_plans/0031-ai-asset-implementation-plan.md の S2-3 / S3-3: check-html.sh の引数・ファイル不正の最終行を RV008: に（4 か所）、test-lib.sh の hook_payload に --session <id>（既定 testsession）を足し、test_scope.sh の glob 以外 5 ケース関数（93 assert）の ID を HK-T11 → HK-T15 に付け替え（冒頭コメントは両 ID に）、test_hook_common.sh のセッション状態のケースで --session を使い、設計が仕様に足した SS-T04（読み込み行の 3 ポリシー）・TR-T04（timeout 不在 → TR005 終了 2）・FR-T05（計数 PATH で 0 回・list / inline キーの生文字列）を test_templates.sh / test_run_tests.sh / test_frontmatter.sh に追記する。テスト先行で RV-T07 を新設する。run-tests.sh --ids の全件と、実装結果レポートの HTML を新版の check-html.sh に通すのが最初の実機確認

## DoD

- [x] check-html.sh が仕様 Script 処理のとおり（RV008 は引数・ファイル不正で終了 2・最終行 RV008:、導出元テンプレート不明は RV006 終了 1）、test-lib.sh が仕様 OUT ひな形のとおり（hook_payload <event> <tool_name> [--session <id>] <json-fields...>）になっている（根拠: check-html.sh: result_ng2 の 4 呼び出しを RV008: に（引数の数・ルートに移動できない・ファイルが無い・.html 以外。終了 2）、ログの二重 prefix を解消。テンプレート不明は従来どおり検査 6 の RV006（終了 1）。計画外・性能のみ: strip_comments を awk の index 走査に（出力は 4 本の HTML で一致。1 検査 7.0 → 3.1 秒。逸脱 D2-4）。test-lib.sh: hook_payload <event> <tool_name> [--session <id>] [key=value ...]（第 3 引数の位置でだけ解釈、既定 testsession）。bash -n OK）
- [x] 機械テスト RV-T07（新）が通り、test_scope.sh の付け替えで run-tests.sh --ids に HK-T15 が現れ grep -c HK-T11 が 21（case_glob 20 + コメント 1）になり、test_hook_common.sh の HK-T07 / T08 で --session の 2 セッションが区別され、SS-T04 / TR-T04 / FR-T05 の追記分が通る（実行方法: run-tests.sh --ids）。テスト先行の記録が作業ログにある（根拠: テスト先行: 6 本を先に変更し旧実装で実行 → test_check_html.sh FAIL 4（RV-T07）、test_hook_common.sh FAIL 7（HK-T07 / T08。旧 hook_payload が --session を key=value と誤解釈）。test_scope.sh の付け替えと SS-T04 / TR-T04 / FR-T05 の追記は既存の振る舞いの追認で旧実装でも PASS。実装後: test_check_html 51・test_hook_common 108 とも全 PASS。run-tests.sh --ids の一覧に HK-T15 が現れ、grep -c HK-T11 = 21、HK-T07 / T08 で sessA / sessB / sessC / sessH が区別される）
- [x] run-tests.sh --ids が全件 PASS（既存 14 本 / 55 件 + 追加分）で、結果（本数・ID 数）が作業ログにある（根拠: run-tests.sh --ids → OK: 14 本 / 59 件（前回 57 件 + RV-T07 + HK-T15。PASS ID の一覧に RV-T07 / HK-T15 / HK-T11 が各 1 回）。FAIL / TIMEOUT なし。重複 ID の報告: CP-T08（test_commit.sh と test_push.sh — 0033 で仕様の 1 行を 2 スクリプトに付けたもの。ランナーは不合格にしない。0033 / 0034 のレポートの「重複 ID なし」を訂正）。個別実行（timeout 150 付き）でも 14 本すべて PASS（wip/tmp/p35-each.log））
- [x] プレースホルダ（{{名前}}・TODO・TBD。assets/*.template.* は対象外）と frontmatter の検査が 0 件で、結果がコマンドと件数で作業ログにある（根拠: grep -c '{{' → check-html.sh 1（検査 1 のメッセージ）、test_check_html.sh 3（RV001 の fixture）、test_templates.sh 4（雛形を埋める sed）、他 5 本 0 — いずれも置換対象の名前を文字列として扱うもので検査の除外。TODO / TBD 0 件（8 本）。frontmatter の検査対象は変更なし）
- [x] 参照更新の検索で旧記述が 0 件: check-html.sh の "RV: 、test_scope.sh の HK-T11 は 21 件（case_glob 20 + 冒頭コメント 1）だけ（根拠: grep -c '"RV: ' check-html.sh = 0、grep -c HK-T11 test_scope.sh = 21（case_glob 20 + 冒頭コメント 1）、grep -c HK-T15 = 93）
- [x] 実装結果レポートの HTML を変更後の check-html.sh で検査して OK（ロックアウト対策の最初の操作）（根拠: 変更後の check-html.sh で wip/30_reports/0033-ai-asset-implementation.html → OK: 検査 7 項目すべて通過（id 16 件 / リンク 9 件）。引数なし → RV008: 引数は HTML ファイル 1 つ（終了 2）、存在しないファイル → RV008: ファイルが無い（終了 2）。0035 の節を追記した後の HTML も同じコマンドで OK）
- [x] 実装結果レポート wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）にこのチケットの節（作成・更新したアセット × 仕様の節 / テスト結果 / 検査結果 / 仕様からの逸脱）がある（根拠: wip/30_reports/0033-ai-asset-implementation.md + .html に 0035 の節を追記（作成・更新したアセット 8 本 × 仕様の節 / テスト結果 / 検査結果 / 逸脱 D2-2 の送り先の変更 / 想定と異なった点 / 残課題）。check-html OK）

## 作業内容

- 計画の変更対象 A6・A7・A8 と仕様の該当節を読み、20-common-step-shell-script の手順で変更する。--session は第 3 引数位置に限定し key=value の解析と衝突させない
- テスト先行: RV-T07 を先に書いて失敗を確認 → 実装 → 付け替え → SS-T04 / TR-T04 / FR-T05 の追記 → 全件。push は完了コミット直後（doing 空）に

## 作業ログ

### 現在地

- 済: 計画の A6・A7・A8・テスト方針・判断点（--session は第 3 引数位置）を読む → 6 本のテストを先に変更して FAIL 4 + 7 を確認 → check-html.sh と test-lib.sh を変更 → 該当 2 本 全 PASS → 全件 → 新版 check-html.sh でレポート HTML を検査（最初の実機確認）→ 検査 → レポートに 0035 の節 → このチケットの記入
- 完了: commit.sh で成果物をコミット → ticket.sh complete 0035 → push.sh → 0036 へ

### うまくいったこと

- テスト先行が 2 本で計 11 の FAIL を出し、実装後に一度で全 PASS。--session を第 3 引数の位置に限った判断点のとおり、key=value の解析に触れずに済んだ
- 計画の HK-T15 の範囲（case_order〜case_load_errors = 93）が実測と一致し、index 範囲の一括置換で済んだ

### うまくいかなかったこと

- 0034 から申し送られた frontmatter.sh のアンエスケープは実行できなかった。読み手を直すと TICKET-T05（test_ticket.sh）の期待値も変わるが、test_ticket.sh は 0035 の許可範囲に無い。書き手（0034）と読み手（0035）で許可範囲が割れているため、3/3 に送った（D2-2 の送り先を変更）
- run-tests.sh --ids の全件が 400 秒の呼び出し上限で終わらなかった。個別実行で test_check_html.sh が 121 秒（run-tests.sh の 1 本あたり上限 120 秒の際）と分かり、bash -x に時刻を付けて check-html.sh の strip_comments（${s%%<!--*} が 1 回 0.2〜0.4 秒）を特定。awk の index 走査に置き換えて 1 検査 7.0 → 3.1 秒、test_check_html.sh 121 → 41 秒（出力は 4 本の HTML で一致）。計画外の変更なので D2-4 として記録。以前から上限の際にあった（RV-T07 の追加分は 1〜2 秒）ので、全件の所要時間をテスト方針で見ておくべきだった

### 仕様からの逸脱

- D2-2 の送り先を 0035 → 3/3 に変更（理由は上）
- D2-4: 計画の変更対象 A6 に無い strip_comments の置き換え（性能のみ、振る舞い不変）
- 人間レビュー・敵対的レビューは実装 4 枚の切れ目で 1 回（承認④により opus 代替）。実行者 main

### 判断と根拠

- 計画外の strip_comments の置き換えは、DoD「run-tests.sh --ids が全件 PASS」を満たすために必要（test_check_html.sh が上限 120 秒の際にあった）で、許可範囲の内側・仕様の振る舞い不変・出力一致を確認した上で行った。逸脱 D2-4 としてレポートに記録
- result_ng2 のログは "RV: RV008: …" の二重にせず、メッセージそのものを log_warn に渡す（run-tests.sh の result_ng と同じ形）
- SS-T04 の 3 ポリシーは雛形の読み込み行そのもの（grep で取り出す）で検査し、テスト内に読み込み行の写しを持たない（読み込み行が変わったら追随するため）
- TR-T04 の timeout 不在は make_restricted_path で bash / jq を残して timeout だけ外す（TR005 のメッセージが timeout だけを挙げ、TR004 を含まないことまで見る）
- FR-T05 の計数 PATH は fm_get / fm_list / fm_has を 1 プロセスで通し、正のコントロール（同じ PATH で cat 1 回）を同じテストに置く（仕様「回数の約束は数える」）

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 10-task-ai-asset-implementation-exec 仕様（完了前の検査）・20-common-step-shell-script（test-lib の make_restricted_path / make_counting_path・run-tests.sh）・20-common-step-report-view（check-html.sh）・計画 0031 の変更対象 A6〜A8 とテスト方針

### スコープ外で見つけたこと

- run-tests.sh --ids は `.claude/hooks/tests/test_config_integrity.sh` も拾う（計画の「14 本」は lib と skills の 13 本 + これ）。本数の表記は 0037 の統括で揃える
- 書き手と読み手にまたがる修正は許可範囲を同じチケットに置かないとどちらでも直せない（計画スキルの確認事項に）

### AI アセットに反映すべき内容

- 10-task-ai-asset-implementation-plan 仕様: 「値の往復（書く側と読む側）が要る修正は両側の許可範囲を同じチケットに置く」→ 3/3
- 20-common-step-shell-script SKILL.md: test-lib の hook_payload --session と make_counting_path / counted_calls を提供一覧に → 0036（計画 S4 の対象）

### 備考

- スクリプト: wip/tmp/p35-tests.pl / p35-impl.pl、個別実行のログ wip/tmp/p35-each.log
