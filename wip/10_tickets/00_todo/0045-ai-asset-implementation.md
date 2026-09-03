---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0041"]
executor: main
human_review: {required: true, reason: "許可範囲の緩和は機構の締まりに直に効く（work-defaults の ai-asset-implementation は人間レビュー要）"}
adversarial_review: {required: false, reason: "全体計画の方針どおり、敵対的レビューは人間レビューに統合する"}
allow:
  write: [".claude/hooks/config/**", ".claude/docs/20_ddr/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0045 scope-limits.json の commands.build-test に計測コマンドを足す

## 目的

調査フェーズが wip/tmp/ に置いた計測スクリプトを実行できるよう、build-test の分類に python3 と bash の実行を加える。現状は分類外として WF204 で既定拒否される

## DoD

- [ ] commands.build-test に wip/tmp/ 配下を対象とする python3 と bash の項目が追加されている（根拠: ）
- [ ] 追加した項目が wip/tmp/ 配下に限られており、任意のパスの python3 実行を通さないことを、scope.sh の前方一致の判定で確認している（根拠: ）
- [ ] .claude/hooks/tests/ と .claude/hooks/lib/tests/ の既存テストが全通過している（根拠: ）
- [ ] 変更の理由が DDR として残っている（既定拒否の設計を緩めるため）（根拠: ）

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
