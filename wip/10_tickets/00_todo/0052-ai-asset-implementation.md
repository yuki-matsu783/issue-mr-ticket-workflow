---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0051"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まない文書の追随で、機械テストの対象ではない（eval の定義は既存のまま）"}
allow:
  write: ["wip/**"]
  ops: ["remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0052 ワークフロー・タスクスキル 8 本の SKILL.md を仕様に追随させる（S3）

## 目的

設計フェーズが仕様に足した手順・規約の要約を、対応する SKILL.md に写す

## DoD

- [ ] 00-workflow-issue-mr-driven/SKILL.md に、敵対的レビュアーの起動にブランチ名を渡すこと・観点に必須節の実在を含めること・既定のモデルが使えないときの代替・BD006 の案内がある（根拠: ）
- [ ] 10-task-investigation-plan/SKILL.md に、DoD に書くコマンドの形を確かめることと保留の書き方 2 項目がある（根拠: ）
- [ ] 10-task-investigation-exec/SKILL.md に、過去の節を書き換えないこと・表に載せきれない対象は表に行を足すこと・成果物の形を読み返すことがある（根拠: ）
- [ ] 10-task-ai-asset-design-exec/SKILL.md に、着手時に ai-asset-design-docs を読むこと・採番と観点の定義を同じチケットで済ませること・旧名のセルフレビューがある（根拠: ）
- [ ] 10-task-ai-asset-implementation-plan/SKILL.md に、削除対象を allow.write に含めること・run-tests.sh --filter のグロブの形・実測値は調査フェーズの値を使うこと・ロックアウト対策が変更箇所を踏むことがある（根拠: ）
- [ ] 10-task-overall-plan/SKILL.md に前 issue の作業領域が default に残っている場合の扱いがあり、10-task-overall-summary/SKILL.md に進行状態の branch・--linked の前提・draft の 3 値・FN004 がある（根拠: ）
- [ ] 10-task-feedback-plan/SKILL.md の類型の文言が機構の定義と同一で、消し込み表の記載がある（根拠: ）
- [ ] 8 本それぞれについて、仕様書の該当節と 1:1 で対応することを根拠（仕様のファイルと節）付きで示している（根拠: ）
- [ ] プレースホルダ・frontmatter の検査が 0 件。実装結果レポートに S3 の節が追記されている（根拠: ）

## 作業内容

- 8 本の SKILL.md を順に直す

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
