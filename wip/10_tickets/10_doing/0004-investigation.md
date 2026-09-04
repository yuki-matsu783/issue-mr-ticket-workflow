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
started_at: "2026-09-04T22:38:46+09:00"
completed_at: ""
base_sha: "9721416"
---

# 0004 調査: worktree 上でのフックの作業ツリー解決と、WIP・宣言範囲・差分判定の健全性

## 目的

調査計画書（wip/20_plans/0003-investigation-plan.md）の観点 A に答える。Claude が worktree に入ったとき、フックが worktree 側の wip/ と logs/ を見て判定するか（DDR i0009-55 の言う静かな無効化に落ちないか）を、読み取りで確かめられるところまで確かめ、残余を実測手順にする。受け入れ条件 A1 と A5、全体計画書の保留 P1 に効く。

## DoD

- [ ] 観点 A『Claude が worktree に入ったとき、フックは worktree 側の wip/ と logs/ を見て判定するか』への答えが調査結果レポート wip/30_reports/0004-investigation.md に書かれている（根拠: ）
- [ ] grep -rn "HOOK_ROOT|HOOK_WORKTREE" .claude/hooks/ の全参照が、ファイル:行と『スクリプトの置き場（HOOK_ROOT が正）/ 作業ツリーの状態（HOOK_WORKTREE が正）』の判定つきで一覧になっており、総件数と取り違えの件数が書かれている（根拠: ）
- [ ] workflow-guard / workflow-diff-check / workflow-entry / workflow-state-guard / session-start / subagent-stop-check の 6 本それぞれについて、worktree 側で判定されるか本流側で判定されるかの結論と根拠（ファイル・行）が添えられている（根拠: ）
- [ ] .claude/hooks/lib/tests/test_hook_common.sh が検証済みの範囲と、実測でしか確かめられない残余が分けて書かれている（根拠: ）
- [ ] 残余について、そのまま貼れるコマンド列と観点ごとの予測を対にした実測手順がレポートに書かれている（実行は人間が行い、結果は wip/tmp/worktree-probe/ に置く前提を明記する）（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）
- [ ] 調査結果レポートが md と HTML の対で作られ、check-html.sh を通っている（根拠: ）

## 作業内容

- grep -rn "HOOK_ROOT|HOOK_WORKTREE" .claude/hooks/ で全参照を抜き、1 件ずつ判定して表にする
- hook-common.sh の __hc_resolve_worktree / __hc_is_worktree_of を読み、上向き探索と worktree 検証の条件を書き出す
- .claude/docs/10_spec/ のフック共通仕様 §2 と DDR i0009-55 を読み、実装が決定どおりかを突き合わせる
- test_hook_common.sh の worktree 関連ケースを読み、検証済み範囲を特定する
- 実測手順（worktree の作成・確認・片付けのコマンド列と予測）を書く。git worktree add / checkout は AI からは実行できないため、実行は人間に回す

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
