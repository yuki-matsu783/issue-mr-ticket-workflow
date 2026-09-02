---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0027"]
executor: main
human_review: {required: true, reason: "基準どおり（登録は人間の操作で、結果が後続 4 本の書き方を決める）"}
adversarial_review: {required: false, reason: "中核を含まず判定が 1 つで、根拠が実測そのもののため（work-defaults.md の調整条件の趣旨に沿う）"}
allow:
  write: [".claude/hooks/**", ".claude/settings.json"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0028 ⓪ block-chmod の単独登録と T6（deny の効き方）の先行確認

## 目的

permissionDecision + 終了 0 の deny が実際に効くかを、フック 11 本を書き切る前に 1 本だけで確かめる。外れたときの手戻りを hook-common.sh の出力ヘルパと 1 本に閉じる

## DoD

- [ ] 登録前に人間が .claude/settings.json のバックアップを取ったことを確認し、その旨を作業ログに記録した（根拠: ）
- [ ] AI が提示した JSON 1 行分（matcher Bash|PowerShell、command は bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/20-PreToolUse/block-chmod.sh"。fail-closed ラッパーを付けない）で人間が登録し、AI が commit.sh .claude/settings.json でコミットした（根拠: ）
- [ ] 新しいセッションで chmod +x を試し、permissionDecision: deny + 終了 0 で拒否されるかの結果が作業ログにある。logs/hooks/decisions.jsonl に記録が残ったかも書いた（根拠: ）
- [ ] T6 の結論（効いた / 効かない）が書かれ、効かない場合は exit 2 + stderr への切り替えを hook-common.sh の出力ヘルパと block-chmod に反映し、仕様（§3）との食い違いを作業ログ「仕様からの逸脱」に書いた（根拠: ）
- [ ] 同じ登録で確かめられる範囲の記録（decisions.jsonl の項目名・session_id）を作業ログに残し、0031 の実測（T2）の下地にした（根拠: ）
- [ ] ロックアウトが起きた場合は WORKFLOW_BLOCK_CHMOD_ENFORCE=0 の新セッションで復旧し、経緯を作業ログ「拒否・確認・迂回の記録」に書いた（起きなければ「なし」）（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 2 に従う
- ラッパーを付けないのは、本体の不調と登録方式の不調を区別するためと、ラッパーが環境変数を見ないため（§4）。ラッパーは 0031 の ② で足す
- 登録は人間の操作。AI は settings.json を Edit / Write で書かない
- settings.json は common.confirm なので登録後のコミットで WF203 の確認が出る（この段ではまだ workflow-guard が未登録なので出ない見込み。出た場合は人間が承認する）

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
