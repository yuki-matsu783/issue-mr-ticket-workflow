---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0028"]
executor: main
human_review: {required: true, reason: "正史（仕様）の変更。承認④により opus 自己レビューで代替（切れ目 1 回）"}
adversarial_review: {required: true, reason: "正史の変更で差分が 1 文書・50 行を超える（切れ目 1 回）"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T16:51:56+09:00"
completed_at: ""
base_sha: "139e41c"
---

# 0029 AI アセット設計: 共通ステップ仕様 5 本（shell-script / commit-push / ticket / report-view / ai-asset-creator）への書き戻し（wip/20_plans/0026-ai-asset-design-plan.md の 0029）

## 目的

計画書 wip/20_plans/0026-ai-asset-design-plan.md「文書一覧と骨子」の共通ステップ仕様 5 本を更新する: shell-script（読み込み行の FATAL 行・HOOK_DENY_ID・nop の LOGGER_ROOT、fm_get の戻り、TR004 / TR005 は終了 2、test-lib の make_counting_path / counted_calls と hook_payload の session_id、テスト観点の規約節: 語彙表の全要素・負のケースの正の期待値・計数）、commit-push（CP001 の条件・CP007・push.sh の識別子の整理・スキップ記録の形と HEAD の版・ステージ後の除外の当て直し）、ticket（create のオプション名・next の返却・cancel の記録・TK008・T10 文言・判定語・根拠欄なし・固定見出しの重複・index 復元・YAML エスケープ）、report-view（data-template・計画書の節構成と種類ごとの固有節・RV008）、ai-asset-creator（skill.template の冒頭段落・SKILL.md の frontmatter）。DDR i0006-10（提供コマンドの自己強制）・11（計画書テンプレートの必須節）を作る

## DoD

- [ ] 担当の要件定義書・仕様書が 20-common-step-requirement / -spec のテンプレートと固定節構成に沿って更新され、履歴（以前は〜）を書かず現在の正史だけになっている（20-common-step-shell-script / -commit-push / -ticket / -report-view / -ai-asset-creator）（根拠: ）
- [ ] 受け入れ条件 5（提供コマンド 4 本とテスト）・6（シェルスクリプトの規約）が各仕様のテスト観点に落ちている: CP-T03 / CP-T06 / TICKET-T03 / TICKET-T05 / RV-T02 に 0025 で固定した観点、CP007 / RV008 / TK008 と重複見出しのテスト観点、SS-T / TR-T の計数と語彙の観点が書かれている（根拠: ）
- [ ] テスト観点の規約節（G10）の置き場が 20-common-step-spec の固定節構成と整合している（テスト観点の中か Script 処理のサブ節か。判断を DDR または作業ログに）（根拠: ）
- [ ] 横断文書（自己改善ワークフロー機構.md・rules/ルール体系.md・90_glossary）と用語が食い違っていない（変更なしならその確認を根拠に書く）（根拠: ）
- [ ] 決定の経緯と却下案が担当の DDR に残り、DDR から仕様を参照している（仕様から DDR を参照しない）（i0006-10・11）（根拠: ）
- [ ] ヘッドレス実行の帰結（止まる / 既定で進む）が変更ごとに仕様に書かれている（根拠: ）
- [ ] 他チケットの担当文書のうち参照先（台帳の番号・テスト ID・節名）を再読して文言が一致している（0028 の台帳 CP007 / RV008 / TK008・HK-T15）（根拠: ）

## 作業内容

- 計画書の対応表（A3〜A6・B9・C1・C2・G2・G5・G10〜G12・D-29〜D-32）とレポート 0013 の逸脱表・レビュー F-1〜F-6・F-15・F-17 の根拠を仕様の文言に写す
- 0028 が確定した台帳の番号を参照し、仕様側の識別子表を合わせる

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
