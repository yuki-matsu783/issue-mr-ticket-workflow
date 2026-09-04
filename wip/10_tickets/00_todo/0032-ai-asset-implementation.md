---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0031", "0035", "0036", "0037"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "実装フェーズの総仕上げで、受け入れ条件の充足をここで確かめる（実装フェーズの 2 回目）"}
allow:
  write: [".claude/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0032 S9 参照更新の総仕上げと 0 件判定

## 目的

残った旧名を片付け、受け入れ条件 A3（旧名 0 件）と A2（テストが通る）を検索とテストの実行で確かめる

## DoD

- [ ] 0005 の c5 の検索コマンド（前置 (^|[^0-9-]) の訂正版）の出力が空になっている（コマンドと出力を根拠に貼る）（根拠: ）
- [ ] 期待値が「残るもの」で確かめられている: ls -d .claude/skills/*/ | wc -l が 26、entry-skills.txt の非コメント行が 2 行、.claude/evals/ が 28 本（根拠: ）
- [ ] 10_spec/skills/00-workflow-quick-request.md に残っていた旧名 1 件が扱われている（移行の説明として引用しているため、引用と分かる形にするか書き換えるかを判断して理由を作業ログに残す）（根拠: ）
- [ ] run-tests.sh --ids で 198 件が PASS し、重複 ID の報告が 0 件（実行の出力を根拠に貼る）（根拠: ）
- [ ] 実装結果レポート wip/30_reports/0024-ai-asset-implementation.md に全ステップの節が揃い、check-html.sh が通っている（根拠: ）
- [ ] この issue の受け入れ条件 A1〜A5・B1〜B4 と成果物の対応表が実装結果レポートにある（根拠: ）

## 作業内容

- 残った旧名を片付ける
- 0 件判定と全件テストを実行し、実装結果レポートを締める

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
