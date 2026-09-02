---
type: ticket
ticket_type: ai-asset-implementation-plan
predecessors: ["0008"]
executor: main
human_review: {required: true, reason: "許可範囲とロックアウト対策を実装前に見る（中核 scope-limits.json を含む）"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0009 AI アセット実装計画: ルール本体・スキル本体・scope-limits.json

## 目的

レビュー済みの設計から、ルール本体・共通ステップスキル本体・テンプレート・scope-limits.json・eval 定義の変更範囲とテスト、ロックアウト対策を決める

## DoD

- [ ] 実装計画書と HTML ビューが wip/20_plans/ にある（根拠: ）
- [ ] 変更するアセットとテスト（run-tests.sh の対象 ID）が一覧化されている（根拠: ）
- [ ] scope-limits.json の変更でロックアウトが起きないことの確認手順がある（根拠: ）
- [ ] 実装チケットと次の計画チケット（implementation-plan）が起票されている（根拠: ）

## 作業内容

- DoD の各項目を順に満たす

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
