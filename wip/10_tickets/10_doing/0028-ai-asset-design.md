---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0026"]
executor: main
human_review: {required: true, reason: "正史（仕様）の変更。承認④により opus 自己レビューで代替（切れ目 1 回）"}
adversarial_review: {required: true, reason: "正史の変更で差分が 1 文書・50 行を超える（切れ目 1 回）"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T16:39:32+09:00"
completed_at: ""
base_sha: "e2e6f38"
---

# 0028 AI アセット設計: フック共通仕様と post-push 2 仕様への書き戻し（wip/20_plans/0026-ai-asset-design-plan.md の 0028）

## 目的

計画書 wip/20_plans/0026-ai-asset-design-plan.md「文書一覧と骨子」のフック共通仕様（§1 lib 一覧の HK-Txx / §3 redact の注記 / §6 に CP007・RV008・TK008 と eval 接頭辞 SP-E → SC-E / §7 cmdpos の出力の形と gitlike / §8 tsv ヘッダ・commands.build-test・build-test と hook-test の判定順・read と remote-read は常に可・承認単位の例外 / §9 cancelled_at・cancel_reason / §11 HK-T15 / §12 tool_response と案内側の読み込みポリシーの TBD / H6 jq 1.6）と post-push-usage-report（last_offset の単位）・post-push-compact-prompt（終了コードの読み方と未確認の明記）を更新し、DDR i0006-07（承認単位）・08（redact の除外条件）・09（read / remote-read 常に可）・12（引数・環境の誤りの識別子の新設）を作る

## DoD

- [ ] 担当の要件定義書・仕様書が 20-common-step-requirement / -spec のテンプレートと固定節構成に沿って更新され、履歴（以前は〜）を書かず現在の正史だけになっている（フック共通仕様 §1・§3・§6・§7・§8・§9・§11・§12・H6、post-push-usage-report、post-push-compact-prompt）（根拠: ）
- [ ] 受け入れ条件 2（hooks/lib 5 本とテスト）が §11 のテスト観点に落ちている: HK-T15（scope の判定順・宣言の絞り込み・ops 分類・設定検査）が追加され、HK-T05 / HK-T10 / HK-T11 に 0025 で固定した観点（gitlike の負のケース・redact の除外・承認単位）が書かれている（根拠: ）
- [ ] 台帳 §6 に CP007 / RV008 / TK008（引数・環境の誤り）が条件付きで登録され、eval 接頭辞が SC-E に改名されて既存接頭辞と重複しない（根拠: ）
- [ ] 横断文書（自己改善ワークフロー機構.md・rules/ルール体系.md・90_glossary）と用語が食い違っていない（変更なしならその確認を根拠に書く）（根拠: ）
- [ ] 決定の経緯と却下案が担当の DDR に残り、DDR から仕様を参照している（仕様から DDR を参照しない）（i0006-07・08・09・12）（根拠: ）
- [ ] ヘッドレス実行の帰結（止まる / 既定で進む）が変更ごとに仕様に書かれている（根拠: ）

## 作業内容

- 計画書の対応表と骨子（フック共通・post-push 2 仕様・DDR 4 件）を読み、レポート 0013 の逸脱 D-2・D-4・D-6・D-12・D-22〜D-27・D-33・D-34 とレビュー F-7・F-10・F-12・F-13・F-15・F-19 の根拠を仕様の文言に写す
- 20-common-step-spec / -requirement の手順で更新し、DDR は既存 i0006-01〜06 の形に合わせる

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
