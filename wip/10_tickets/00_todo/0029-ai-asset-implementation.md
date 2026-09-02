---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0027"]
executor: main
human_review: {required: true, reason: "基準どおり（振る舞いが変わる。承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（フック本体 6 本の追加）"}
allow:
  write: [".claude/hooks/**"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0029 案内側フック 6 本とテスト

## 目的

登録段階 ① に載る 6 本を書く。案内側はラッパー無しで、失敗しても操作を通す

## DoD

- [ ] session-start.sh があり、boundary.sh status --offline（3/3・未実装）が無ければ何も出さずに終了 0 する。依存する 8 件のテスト観点（SE-T01〜04・07〜09・WE-T10 と SE-T05 / SE-T06 の前半）は書かず、#10 へ送る旨を作業ログに書いた（根拠: ）
- [ ] workflow-diff-check.sh があり、scope.sh の同じ許可範囲 A で範囲外を判定する。テストが通る（根拠: ）
- [ ] post-push-compact-prompt.sh があり、push-detect.sh を状態非依存で使う。テストが通る（根拠: ）
- [ ] post-push-usage-report.sh があり、--accumulate と既定の両方で hc_lock usage-<branch> を取ってから加算し、取れなければ 2 秒で諦めて実行ログに 1 行残して終了 0 する。時刻の変換は自前の暦計算（strptime を使わない）。テストが通る（根拠: ）
- [ ] subagent-start-check.sh があり、PreToolUse Agent（WF801 を systemMessage + additionalContext の 2 経路・WF803 の background 警告）と SubagentStart（要点の注入）の両方の入口を持つ。テストが通る（根拠: ）
- [ ] subagent-stop-check.sh があり、tool_response.status（completed / async_launched）で分岐し agentId（camelCase）を読む。SubagentStop と PostToolUse Agent の両方の入口を持つ。テストが通る（根拠: ）
- [ ] 6 本とも実装の型（HOOK_DENY_ID の代入 → lib の source → hook_init）に従い、bash -n と shellcheck を通り、bash <script> < 入力 JSON の単体実行が終了 0 で通る（根拠: ）
- [ ] 6 本に「4c プローブ」を仕込んだ。環境変数 WORKFLOW_PROBE_4C=1 のときだけ有効で、(a) tool_response.status / agentId / agent_type / model / permission_mode / source / run_in_background の値と、その他のキーの有無と型だけを logs/hooks/probe-4c.jsonl に落とす、(b) subagent-start-check が Agent の呼び出しで無条件に systemMessage を 1 つ出す。既定（環境変数なし）では一切の副作用が無いことをテストで固定した（根拠: ）
- [ ] 4c プローブが rules/logger.md の「値ではなく有無・長さ」からの逸脱であることと、値を落とすのが上記 7 フィールドに限られることを作業ログ「仕様からの逸脱」に書いた（根拠: ）
- [ ] 6 本のテストが `run-tests.sh --filter '<glob>' --ids` で通る（boundary.sh 依存の 10 件を除く。除いた ID を作業ログに列挙した）（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 3 に従う
- 案内側は fail-closed ラッパーを付けない（§3）。失敗は通す
- 重い 2 本（session-start / post-push-usage-report）と軽い 4 本を含む。0006 f5 の分割を案内側 / 拒否側の区切りの内側で満たす
- .claude/docs/** には書かない。決定は作業ログ「判断と根拠」に書く
- 4c プローブが必要な理由: decisions.jsonl は 10 キー固定（§5）で permission_mode / model / tool_response / agent_type を入れる場所が無く、systemMessage を出す WF801 / WF803 は subagent_type が task-executor（.claude/agents/ は空で実装が無い）で executor が main 以外のときにしか発火しないため、そのままでは T9 が測れない
- ⓪ の登録により block-chmod は本番で生きている。chmod を使う作業が出たら WORKFLOW_BLOCK_CHMOD_ENFORCE=0 の新セッションで回避する

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
