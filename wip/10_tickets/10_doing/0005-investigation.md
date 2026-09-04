---
type: ticket
ticket_type: investigation
predecessors: ["0004"]
executor: opus
human_review: {required: false, reason: "全体計画書の差分 3（人間レビューを敵対的レビューに置き換える）"}
adversarial_review: {required: true, reason: "全体計画書の差分 3。フェーズごとに 1 回、claude-fable-5-1 で実施する"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T23:07:31+09:00"
completed_at: ""
base_sha: "719c098"
---

# 0005 調査: 提供コマンドと logs/ 状態ファイルの worktree 分離

## 目的

調査計画書の観点 B に答える。提供コマンド 5 本（ticket.sh / commit.sh / push.sh / boundary.sh / finalize.sh）と logs/ 配下の状態ファイルが worktree ごとに分かれるか、logs/ が .gitignore で worktree に存在しない状態で各コマンドがどう振る舞うかを確かめる。受け入れ条件 A1 と A5、全体計画書の保留 P1 に効く。

## DoD

- [ ] 観点 B『提供コマンドと logs/ 配下の状態ファイルは worktree ごとに分かれるか』への答えが wip/30_reports/0004-investigation.md に書かれている（根拠: ）
- [ ] 『提供コマンド × 依存する状態ファイル × 無いときの振る舞い（既定値 / 警告 / 停止）』の表が 5 コマンド分あり、各セルにファイル・行の根拠が添えられている（根拠: ）
- [ ] __ss_load の探索順（BASH_SOURCE 上向き → CLAUDE_PROJECT_DIR → git rev-parse）に相対パス起動と本流の絶対パス起動を当てはめた解決先の対応表があり、LOGGER_ROOT が worktree とずれる条件が特定されている（根拠: ）
- [ ] logs/ が存在しない worktree で最初に壊れるコマンドと、その症状が特定されている（壊れないなら壊れないと根拠付きで書く）（根拠: ）
- [ ] 残余について、そのまま貼れるコマンド列と予測を対にした実測手順が書かれている（実行は人間、結果は wip/tmp/worktree-probe/）（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）

## 作業内容

- 各提供コマンドの __ss_load 行と LOGGER_ROOT の利用箇所を grep で全件抜く
- grep -n 'logs/' を 5 本のコマンドに当て、依存する状態ファイル（mr.json / review-state.json / push-state.json / merge-state.json / sessions/ / locks/）を洗い出す
- .gitignore の logs/ 行と logs/ 配下の実ファイル一覧を突き合わせ、worktree に複製されないものを確定する
- 各コマンドの仕様書を読み、状態ファイルが無いときの規定の振る舞いが決まっているかを確かめる
- 実測手順（worktree で ticket.sh next / boundary.sh / push.sh を空打ちする手順と予測）を書く

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
