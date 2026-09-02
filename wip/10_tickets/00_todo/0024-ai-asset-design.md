---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0023"]
executor: sub-opus
human_review: {required: true, reason: "正史（要件・仕様）の変更（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（中核の定義に触る）"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0024 レビュー指摘: サブエージェントは既定で background という前提の反映（B1・B15・B2・B3・B4・B5）

## 目的

公式は「subagents run in the background by default」と定め、PostToolUse Agent は起動直後に発火する。この前提で WF801 と WF811〜813 の到達を決め直す

## DoD

- [ ] サブエージェントが既定で background で走り、PostToolUse Agent が起動直後に status: async_launched で発火する事実（hooks.md:1701・:1711）が共通仕様に書かれ、subagent-start-check の WF801 と subagent-stop-check の WF811〜813 の到達がこの前提で成立している（B1）（根拠: ）
- [ ] tool_response のフィールド名が agentId（イベント入力側は agent_id）に直り、subagent-stop-check の照合が名前の取り違えで常に縮退扱いにならない（B15）（根拠: ）
- [ ] WF801 の再掲の条件が論理的に成立している。縮退時にこのフックが自分で判定するなら制御方式と入出力に手順と参照先があり、記録の有無で判定するなら subagent-start-check が skip も記録する（B2）（根拠: ）
- [ ] §6 の採番台帳の WF801 の行が「事後の保険」から i0009-31 の決定（縮退時だけ再掲）に直り、i0009-31 の影響に §6 が加わっている（B3）（根拠: ）
- [ ] §12 T4 の「残る検証」と縮退が i0009-26（7 行目の根拠は systemMessage）と整合し、systemMessage がユーザーに表示されるかの実測が §12 と全体計画のフェーズ 4c の表の両方に登録されている（B4）（根拠: ）
- [ ] i0009-32（WF801 を task-executor に絞る）が subagent-start-check の要件書の Shall not に反映され、i0009-32 の影響に要件書が加わっている（B5）（根拠: ）
- [ ] 決定の経緯が DDR i0009-50〜54 の範囲に残っている（根拠: ）

## 作業内容

- 指摘の原文は wip/30_reports/0022-ai-asset-design-appendix-A.md を参照する
- 公式の原文は wip/tmp/hooks.md を grep -n で読む（WebFetch を使わない）。:1697-1713 が Agent の tool_response の節
- background 既定は WF801 にとっては有利（起動直後に届く）だが、subagent-stop-check の事後検査にとっては前提が崩れる。2 つを分けて考える

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
