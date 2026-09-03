---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0048"]
executor: main
human_review: {required: true, reason: "テストの追加は機構の締まりに効く（work-defaults の ai-asset-implementation は人間レビュー要）"}
adversarial_review: {required: false, reason: "全体計画の方針どおり、敵対的レビューは人間レビューに統合する"}
allow:
  write: ["wip/**"]
  ops: ["hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0051 shlex 据え置きの決定を実装に反映しテストで固定する

## 目的

決定「外部の字句解析器を使わない」に沿って cmdpos.sh が据え置きであることを示し、決定の根拠のうちテストで固定されていない 1 件を足したうえで、既存テストが同じ検査 ID・同じ結果で通ることを確かめる（0049 の後継。allow.ops に build-test を足した）

## DoD

- [ ] cmdpos.sh が origin/main から変わっていない（根拠: )（根拠: ）
- [ ] test_cmdpos.sh の HK-T05 に cat <<EOF / EOF / git push の入力が足され、2 段で exe=git sub=push を検出することを固定している（根拠: )（根拠: ）
- [ ] run-tests.sh --ids が全体で通り、検査 ID の集合が 0045 時点と同じである（根拠: )（根拠: ）
- [ ] HK-T05 / HK-T12 / HK-T02 / HK-T15 / HK-T16 が PASS しており、失敗が 0 件である（根拠: )（根拠: ）
- [ ] 参照更新一覧の 4 つの検索が実施され、更新箇所が無いことが記録されている（根拠: )（根拠: ）
- [ ] 実装結果レポート wip/30_reports/0051-ai-asset-implementation.md と対の HTML があり、issue #15 の受け入れ条件 5 との対応が書かれている（根拠: )（根拠: ）

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
