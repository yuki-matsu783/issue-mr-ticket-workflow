---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0028", "0029"]
executor: main
human_review: {required: true, reason: "正史（要件・仕様）の変更。承認④により opus 自己レビューで代替（切れ目 1 回）"}
adversarial_review: {required: true, reason: "正史の変更で差分が 1 文書・50 行を超える（切れ目 1 回）"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0030 AI アセット設計: requirement / issue / feature-mr / spec 仕様・ルール体系要件・要件 4 本の節順と横断整合（wip/20_plans/0026-ai-asset-design-plan.md の 0030）

## 目的

計画書 wip/20_plans/0026-ai-asset-design-plan.md「文書一覧と骨子」のうち、20-common-step-requirement（type: requirement、章名の統一）・-issue（追記の受け入れ条件）・-feature-mr（glab api + ファイル渡し + Draft: 接頭辞）・-spec（eval ID を SC-E）、計画タスク仕様のプレースホルダ表記 {{名前}} の統一（該当箇所を grep で一覧化して置換）、rules/ルール体系.md（frontmatter の category / paths / applies_when、本数、logger の glob）、要件 4 本（rules/design-docs・rules/ai-asset-design-docs・skills/10-task-overall-plan・自己改善ワークフロー機構）の受け入れ基準の節順と、自己改善ワークフロー機構.md のルールが禁じる「関連するドキュメント」節の削除、横断整合（自己改善ワークフロー機構.md・用語辞書・20-common-step-spec の節構成）の確認を行う

## DoD

- [ ] 担当の要件定義書・仕様書が 20-common-step-requirement / -spec のテンプレートと固定節構成に沿って更新され、履歴（以前は〜）を書かず現在の正史だけになっている（requirement / issue / feature-mr / spec 仕様、計画タスク仕様の該当箇所、rules/ルール体系.md、要件 4 本）（根拠: ）
- [ ] 受け入れ条件 4（共通ステップ 9 本の SKILL.md と assets）が仕様のテスト観点に落ちている: SC-E01〜03 への改名、feature-mr の処理フロー 5 と FM-E の整合、issue の OUT ひな形と IS-E の整合（根拠: ）
- [ ] プレースホルダ表記 <...> を使う箇所の一覧（ファイル・件数）が作業ログにあり、{{名前}} に統一されている（機械的な置換が危険な箇所は理由付きで残す）（根拠: ）
- [ ] 要件 4 本の受け入れ基準の節が「メインフロー → 代替フロー → 例外フロー」の順・この文言になり、自己改善ワークフロー機構.md の「関連するドキュメント」節が削られ、内容は変わっていない（diff で確認）（根拠: ）
- [ ] 横断文書（自己改善ワークフロー機構.md・rules/ルール体系.md・90_glossary）と用語が食い違っていない（変更なしならその確認を根拠に書く）（自己改善ワークフロー機構.md の変更要否、用語「承認単位」「自己強制」の追加要否を判断して記録）（根拠: ）
- [ ] ヘッドレス実行の帰結（止まる / 既定で進む）が変更ごとに仕様に書かれている（根拠: ）
- [ ] 他チケットの担当文書のうち参照先（台帳の番号・テスト ID・節名）を再読して文言が一致している（0028 の接頭辞 SC-E、0029 の節構成の判断）（根拠: ）

## 作業内容

- 計画書の対応表（A1・A7・B1・B3・B5・G3・G4）とレポート 0013 の D-1・D-19〜D-21・D-28、レビュー F-16・F-23(a) の根拠を要件・仕様の文言に写す
- 20-common-step-requirement / -spec の手順で更新し、要件 4 本の節順は内容を変えずに並べ替える

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
