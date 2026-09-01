---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0035"]
executor: main
human_review: {required: true, reason: "SKILL.md の指示文の変更（work-defaults の既定）。承認④により切れ目で opus 自己レビューに代替"}
adversarial_review: {required: true, reason: "切れ目で 1 回（実装 4 枚をまとめて）"}
allow:
  write: [".claude/skills/20-common-step-commit-push/SKILL.md", ".claude/skills/20-common-step-ticket/SKILL.md", ".claude/skills/20-common-step-report-view/SKILL.md", ".claude/skills/20-common-step-shell-script/SKILL.md", ".claude/skills/20-common-step-spec/SKILL.md", ".claude/skills/20-common-step-ai-asset-creator/SKILL.md", ".claude/skills/20-common-step-feature-mr/SKILL.md", ".claude/evals/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0036 AI アセット実装: SKILL.md 7 本のエラー表と eval ID の範囲・eval 2 本（SC-E / AC-E04）・参照更新と全件テスト（wip/20_plans/0031-ai-asset-implementation-plan.md の S4・S5）

## 目的

計画 wip/20_plans/0031-ai-asset-implementation-plan.md の S4 / S5: commit-push / ticket / report-view / shell-script の SKILL.md を仕様の識別子表・処理フロー・test-lib の関数一覧に合わせ（CP001 のディレクトリ、CP003 の 2 条件、CP004 は差分なしだけ、CP006 から環境の誤りを除く、CP007 / CP008 / TK008 / RV008 の行、手順 2 のファイル単位、スキップ記録は HEAD の版、complete の検査 3 条件、make_counting_path 等、テストの書き方（規約）への参照）、spec / ai-asset-creator / feature-mr の SKILL.md の eval ID の範囲（SP-E01〜03 → SC-E01〜03、AC-E01〜03 → 04）と push.sh の識別子（CP007 の追記）を直し、eval 定義の SP-E01〜03 を SC-E01〜03 に改名し AC-E04 を追加する。参照更新一覧の検索を再実行して 0 件を記録し、全件テストと実装結果レポートの完成（HTML）を行う

## DoD

- [ ] SKILL.md 7 本が各仕様のエラー識別子表・処理フロー・OUT ひな形・eval ID の範囲のとおりになっていて、仕様の行 × SKILL.md の行の対応表が作業ログにある（受け入れ条件 4）（根拠: ）
- [ ] eval SC-E01〜03（改名。本文の参照を含む）と AC-E04（新）が定義されている（実行しない）。frontmatter は type: eval のまま（根拠: ）
- [ ] 参照更新の検索が計画の参照更新一覧の期待値どおり: SP-E 0 件（evals + spec/SKILL.md）、AC-E01〜03 0 件、SKILL.md の旧範囲表記（CP001〜006 / TK001〜007 / RV001〜007）と CP004 のコミット失敗の記述と feature-mr の CP005: CP006: が 0 件、HK-T11 は 21 件（DDR・用語辞書は対象外）（根拠: ）
- [ ] run-tests.sh --ids が全件 PASS（既存 14 本 / 55 件 + 追加分）で、結果（本数・ID 数）が作業ログにある（根拠: ）
- [ ] プレースホルダ（{{名前}}・TODO・TBD。assets/*.template.* は対象外）と frontmatter の検査が 0 件で、結果がコマンドと件数で作業ログにある（根拠: ）
- [ ] 実装結果レポート wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）が完成している: 全チケット（0033〜0036）の節、受け入れ条件 3〜7 との対応（テスト ID）、逸脱一覧、想定と異なった点、残課題（3/3 と 2/3 への申し送り、別 issue 候補）（根拠: ）

## 作業内容

- 計画の変更対象 A9・A10 と仕様の該当節を読み、20-common-step-ai-asset-creator の手順で変更する（既存の表の形に合わせる）
- S5: 計画の参照更新一覧の検索語 7 種を再実行し、件数を作業ログとレポートに残す

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
