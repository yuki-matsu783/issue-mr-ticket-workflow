---
type: ticket
ticket_type: investigation
predecessors: []
executor: opus
human_review: {required: false, reason: "全体計画書の差分 3（人間レビューを敵対的レビューに置き換える）"}
adversarial_review: {required: true, reason: "全体計画書の差分 3。フェーズごとに 1 回、claude-fable-5-1 で実施する"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0008 調査: scope.sh の git 分類の穴と塞ぎ方の選択肢

## 目的

調査計画書の観点 E に答える。scope.sh の scope_classify で checkout / switch / worktree / cd が unknown に落ち WF204 で既定拒否される件について、穴を全件洗い出し、塞ぎ方の案を 2 つ以上出す。受け入れ条件 A1 に効き、AI アセット設計の材料になる。

## DoD

- [ ] 観点 E『scope.sh の git 分類にどれだけ穴があり、どう塞げるか』への答えが wip/30_reports/0004-investigation.md に書かれている（根拠: ）
- [ ] unknown に落ちる git サブコマンドの全件一覧が、git のサブコマンド一覧と _SC_GIT_READ_SUBCMDS の突き合わせとして根拠付きで載っている（checkout / switch / worktree を含む）（根拠: ）
- [ ] _SC_READ_ONLY_CMDS に無いために unknown に落ちる基本コマンドの一覧が載っている（本調査計画の実施中に踏んだ cd を含む）（根拠: ）
- [ ] 塞ぎ方の案が 2 つ以上あり、案ごとに『変更する箇所・block-direct-git.sh との関係・scope-limits.json との整合・影響する既存テスト ID・拒否が緩む範囲』が書かれている（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）

## 作業内容

- scope.sh の scope_classify と _SC_GIT_READ_SUBCMDS / _SC_READ_ONLY_CMDS を読み、分類に落ちない入力を特定する
- git のサブコマンド一覧を取得し、_SC_GIT_READ_SUBCMDS と突き合わせて差分を全件出す
- block-direct-git.sh と workflow-guard.sh の WF204 / WF205 を読み、拒否の経路と識別子を確かめる
- .claude/hooks/config/scope-limits.json と該当仕様を読み、分類の定義がどこで正になっているかを確かめる
- lib/tests/test_scope.sh を読み、案ごとに影響する既存テスト ID を列挙する

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
