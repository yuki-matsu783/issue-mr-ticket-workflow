---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0026"]
executor: main
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: [".claude/settings.json"]
  ops: ["hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0027 S10 並列実施の発効の可否の判定（実効性の確認）

## 目的

DDR i0050-08 の解禁の条件 1・2 を実測で突き合わせ、並列実施を発効させるか保留を据え置くかを判定する。判定が肯定のときだけ .claude/settings.json に worktree.baseRef を残す。.claude/docs/ は触らず、結果は実装結果レポートに書く。

## DoD

- [ ] 解禁の条件 2（割り付けた作業ツリーの中の書き込みに workflow-guard の判定が効くことを機械テストで固定した）が WG-T19・WG-T20・DC-T08・DC-T09・SA-T10・SP-T09 の PASS で満たされていることが根拠付きで示されている（根拠: ）
- [ ] 解禁の条件 1 の実測を行い、3 点（分岐元が呼び出し元の HEAD か / ブランチ名の規約 / 成果を載せたまま作業ツリーが消えないか）それぞれの観測結果がレポートに書かれている（実測は捨ててよい成果 = wip/tmp/ への 1 ファイルで行い、本 issue の実チケットを使わない）（根拠: ）
- [ ] 判定（発効する / 保留を据え置く）とその根拠がレポートに書かれ、否定なら .claude/settings.json の worktree.baseRef が置かれていない（置いた場合は取り除いた）（根拠: ）
- [ ] 機械テスト HK-T01 が通る（run-tests.sh --filter '*config_integrity*'。settings.json の hooks 登録が変わっていない）（根拠: ）
- [ ] settings.json に触った直後に通常のツール呼び出しを 1 回行い、フックが起動することを確かめた（ロックアウト対策。機構が無音になっていない）（根拠: ）
- [ ] .claude/docs/ を 1 ファイルも変更していない（DDR i0050-08 の書き換えは設計反映フェーズ。実装フェーズは deny）（根拠: ）
- [ ] 判定の結果として設計文書に反映すべきことが、実装結果レポートの「仕様からの逸脱」または残課題として次フェーズへ渡る形で記録されている（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S10 と「ロックアウト対策」の S10 行に従う
- 実行者をメインエージェントに外す理由: 条件 1 の確認にサブエージェントの起動が要り、サブエージェントは入れ子にできない（task-executor の禁止事項）。work-defaults.md の ai-asset-implementation 行に実行者の調整条件は無いので、基準に無い調整として記録する

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
