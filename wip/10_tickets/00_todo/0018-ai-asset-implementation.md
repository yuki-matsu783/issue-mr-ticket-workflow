---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0029"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: [".gitignore"]
  ops: ["hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0018 S1 設定・定義: scope-limits.json と .gitignore、実装結果レポートの起こし

## 目的

実装フェーズの許可範囲を通す設定を先に整え（.gitignore を ai-asset-implementation の allow へ）、.claude/worktrees/ を gitignore して push.sh 項目 1 が落ちない状態にし、以降のチケットが積み上げる実装結果レポートを起こす。

## DoD

- [ ] .claude/hooks/config/scope-limits.json の types["ai-asset-implementation"].allow に .gitignore が入っている（フック共通仕様 §8「上限設定」の .gitattributes と同じ「common.protected を明示で通す」形）（根拠: ）
- [ ] .gitignore に .claude/worktrees/ の行がある（設計計画書 結論方針 P10 後半 / 残課題 R55）（根拠: ）
- [ ] 機械テスト HK-T01 と HK-T02 が通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'）（根拠: ）
- [ ] jq -e . .claude/hooks/config/scope-limits.json が成功する（構文が壊れていない）（根拠: ）
- [ ] 変更直後に wip/tmp/ への Write を 1 回行い WF205 にならないことを確かめた（scope.sh 判定順 (2) を実際に踏む。ロックアウト対策）（根拠: ）
- [ ] 実装結果レポート（wip/30_reports/0018-ai-asset-implementation.md と同名 HTML）があり check-html.sh が通っている（根拠: ）
- [ ] 仕様と食い違った点は仕様を直さずレポートの「仕様からの逸脱」に記録されている（フック共通仕様 §8 の初期値の表に .gitignore の行が無い件を含む）（根拠: ）

## 作業内容

- scope-limits.json → .gitignore の順で編集する（前者が済むまで後者は WF205 で止まる）
- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S1 と「ロックアウト対策」の S1 行に従う

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
