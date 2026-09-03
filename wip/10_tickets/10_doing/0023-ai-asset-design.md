---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0017"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "設計フェーズの敵対的レビューは上限 2 回に達した（全体計画）"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T03:57:24+09:00"
completed_at: ""
base_sha: "4e31be2"
---

# 0023 19 アセットの仕様書に eval ID の表を書く

## 目的

受け入れ条件 A1 が求める eval 定義の前提となるテスト観点の表が 19 本すべてに無い。接頭辞は台帳にあるので、各仕様書に <接頭辞>-E<2 桁> の表を書いて実装が定義を落とせる状態にする

## DoD

- [ ] 00-workflow-* 2 本・10-task-* 15 本・agents/* 2 本の仕様書すべてに「テスト観点」節があり、eval ID の表（入力・期待する振る舞い・判定方法）が入っている（根拠: ）
- [ ] eval ID の接頭辞が フック共通仕様 §6 の「eval ID の接頭辞」に登録された 19 種と一致している（アセットごとに 1 つ）（根拠: ）
- [ ] eval ID が run-tests.sh の抽出規則 [A-Z]{2,6}-[TE][0-9]{2}[a-z]? に合っている（根拠: ）
- [ ] 他のアセットのテスト ID の接頭辞と重なっていない（grep で突合した出力を根拠に貼る）（根拠: ）
- [ ] 20-common-step-spec 仕様の節構成（スキルは Script 処理の後に独立した「テスト観点」節、エージェントは参照ナレッジの後）に従っている（根拠: ）
- [ ] 結果報告 wip/30_reports/0011-ai-asset-design.md に節を追加し、check-html.sh が通っている（根拠: ）

## 作業内容

- 19 本の仕様書に eval ID の表を書く
- 接頭辞の重複と抽出規則への適合を検索で確かめる

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
