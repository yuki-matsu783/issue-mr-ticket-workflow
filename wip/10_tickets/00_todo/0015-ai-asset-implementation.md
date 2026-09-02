---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0014"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズ 3 の敵対的レビューの指摘対応であり、対応そのものは再レビューしない"}
allow:
  write: [".claude/rules/**", ".claude/evals/**", ".claude/skills/**", ".claude/hooks/config/scope-limits.json", ".claude/hooks/lib/tests/**", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0015 実装: 敵対的レビュー（フェーズ3）の指摘のうち本体に当たる 6 件を直す

## 目的

0014 で直した正史に合わせてルール本体・スキル・eval・許可範囲設定・テストを直す

## DoD

- [ ] ai-asset-design-docs.md に「issue の受け入れ条件との対応」の規定が入り、design-docs.md と同文になっている（根拠: ）
- [ ] design-docs.md の要件書の形が ai-asset-design-docs.md と同じ細目（図の 1 行 1 辺・ラベル・外部依存なし / 定型章の項目数と行数の目安）を持つ（根拠: ）
- [ ] evals/design-docs.md の 1:1:1・1 アセット の語がアプリの語彙（1 アプリ 1 対象・要件と仕様の同名 1:1）に直っている（根拠: ）
- [ ] 20-common-step-spec/SKILL.md の手順の番号が仕様の処理フローと 1:1 で対応し、アプリの「なし」の規定が 10 節すべてに一般化されている（根拠: ）
- [ ] scope-limits.json が 0014 で直した §8 の初期値の表と一致し、implementation から apl/<アプリ名>/CLAUDE.md・.gitattributes が無確認で書けない（根拠: ）
- [ ] 出荷設定を当てるアサーションが HK-T02 のテストへ移り、common.file_granular の apl/*/package.json・tsconfig.json・README.md を固定するアサーションがある（根拠: ）
- [ ] run-tests.sh --ids が全通過し、変更前に落ちて変更後に通ることを確かめた結果を作業ログに残した（根拠: ）

## 作業内容

- 0014 の正史を読み、指摘ごとに本体を直す。設定の変更はテストを先に落としてから行う

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
