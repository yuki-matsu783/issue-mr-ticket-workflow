---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0023"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "実装フェーズの敵対的レビュー 2 回は中核のステップ（0025〜0027）と総仕上げ（0032）に割り当てる"}
allow:
  write: [".claude/skills/**", "wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T04:13:32+09:00"
completed_at: ""
base_sha: "9ec55d0"
---

# 0024 S1 設定・定義: テンプレート実体 15 件

## 目的

仕様の OUT ひな形が名前とパスで指定しているテンプレート 13 件と、レポート・計画書の md 共通テンプレート 2 件を作る

## DoD

- [ ] assets/ のテンプレート 13 件が 0003 の a2 の表のパスに作成され、各仕様の OUT ひな形の節と対応している（根拠: 一覧と仕様の節）（根拠: ）
- [ ] md の共通テンプレート 2 件（report.template.md / plan.template.md）が 20-common-step-report-view の assets/ に作成されている（残課題 R6）（根拠: ）
- [ ] 全 15 件にプレースホルダ（{{名前}}）の説明があり、frontmatter を持つものは markdown-docs ルールの項目に従っている（根拠: ）
- [ ] 実装結果レポート wip/30_reports/0024-ai-asset-implementation.md と同名 HTML があり、check-html.sh が通っている（最初の実装チケットの DoD）（根拠: ）
- [ ] テンプレートを使う側の仕様（各タスクスキルの OUT ひな形）と名前・パスが 1 件も食い違っていない（検索の出力を根拠に貼る）（根拠: ）

## 作業内容

- テンプレート実体 15 件を作る
- 実装結果レポートを作る（以降のチケットはここに節を足す）

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
