---
type: ticket
ticket_type: investigation
predecessors: []
executor: opus
human_review: {required: false, reason: "全体計画書の差分 3（人間レビューを敵対的レビューに置き換える）"}
adversarial_review: {required: true, reason: "全体計画書の差分 3。フェーズごとに 1 回、claude-fable-5-1 で実施する"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "web"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0006 調査: サブエージェントを呼び出し元と別の worktree で動かせるか

## 目的

調査計画書の観点 C に答える。Agent ツールに作業ディレクトリ／worktree を指定する手段があるか、subagent-start-check がサブエージェント側の cwd を見るのかを、公式ドキュメントと実装から確定する。動かせないなら 1 プロセス内での並列は成立せず、受け入れ条件 A4 の採否がその時点で決まる。

## DoD

- [ ] 観点 C『サブエージェントを呼び出し元と別の worktree で動かせるか』への答え（可否）が wip/30_reports/0004-investigation.md に書かれている（根拠: ）
- [ ] 公式ドキュメントの URL・引用文・取得日が添えられている。取得できなかった場合は『不明』と明記し、その理由と実測手順が書かれている（根拠: ）
- [ ] subagent-start-check.sh が読む cwd が呼び出し元のものかサブエージェント側のものかの結論と、根拠（ファイル・行、または logs/hooks/decisions.jsonl の実レコード件数付き）が添えられている（根拠: ）
- [ ] 動かせない場合の代替（人間が別セッション・別 clone を開く等）が成立する条件が書かれている（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）

## 作業内容

- Claude Code の Agent ツール・worktree に関する公式ドキュメントを WebFetch で読み、作業ディレクトリ指定の可否を引用付きで確定する
- .claude/hooks/12-SubagentStart/subagent-start-check.sh と hook-common.sh の HOOK_WORKTREE 解決を読み、サブエージェント起動時にどの cwd が渡るかを追う
- .claude/agents/task-executor.md と 00-workflow-issue-mr-driven/SKILL.md の起動手順・assets/subagent-prompt.template.md を読み、worktree を渡す口があるかを確かめる
- logs/hooks/decisions.jsonl の過去レコードからサブエージェント実行時の cwd の実値を拾い、呼び出し元と一致していたかを件数付きで書く
- 実測手順（人間が worktree を作った状態でサブエージェントを起動し、decisions.jsonl の cwd を見る手順と予測）を書く

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
