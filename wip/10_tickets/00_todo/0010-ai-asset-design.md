---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0008", "0009"]
executor: main
human_review: {required: true, reason: "タスク仕様の変更と DDR。承認④により opus 自己レビューで代替"}
adversarial_review: {required: true, reason: "仕様は正史。設計実施の切れ目で 1 回（全体計画の方針）"}
allow:
  write: [".claude/docs/00_requirement/**", ".claude/docs/10_spec/**", ".claude/docs/20_ddr/**", ".claude/docs/90_glossary/**", "wip/**"]
  ops: ["read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0010 AI アセット設計実施 — タスク仕様（調査）・eval ID 5 本・DDR・横断整合

## 目的

設計計画 0006 の採否表のうち、`10-task-investigation-plan` / `-exec`（D20・D21。要件側に同じ禁止があれば要件も）、テスト ID の無い共通ステップ仕様 5 本の eval ID、`20-common-step-ai-asset-creator` の eval 形式、DDR `i0006-01〜05`、横断文書・用語集・`20-common-step-spec` の整合を反映する。

## DoD

- [ ] investigation-plan / exec の仕様（と必要なら要件）が D20（計画チケットの `allow.ops` 宣言があるときだけテスト実行可。既定は禁止）・D21（`.claude/**` の一時変更を計画しない）のとおりで、§8 初期値（0008）と整合している（根拠: ）
- [ ] `ai-asset-creator` / `feature-mr` / `issue` / `requirement` / `spec` の仕様に「テスト観点」表（eval ID、入力・期待する振る舞い・判定方法）があり、接頭辞が §6 台帳（0008）と一致している（根拠: ）
- [ ] `ai-asset-creator` 仕様に eval テンプレートの形式（参考 `evals.json` の項目を md 表に）がある（根拠: ）
- [ ] DDR `i0006-01〜05`（frontmatter パーサと置き場 / ticket.sh のコミット経路 / 必須節の格上げ / テスト方式 / 調査でのテスト実行）が DDR のフォーマットで作成され、採らなかった案と理由がある（根拠: ）
- [ ] 横断文書（`自己改善ワークフロー機構.md`・`ルール体系.md`）と用語集、`20-common-step-spec.md` の eval ID 記法を確認し、必要な箇所だけ更新されている（変更なしの場合は確認した旨が作業ログにある）（根拠: ）
- [ ] 各文書の「要件との対応」表・用語の整合が崩れておらず、プレースホルダ 0 件（根拠: ）

## 作業内容

- 0008・0009 の作業ログ「判断と根拠」を DDR の材料にする
- 計画書 0006 の骨子に従い該当節を Edit で書き換え、DDR を新規作成する

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
