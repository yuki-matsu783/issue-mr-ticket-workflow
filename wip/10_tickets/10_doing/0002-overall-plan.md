---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "フェーズ列・実行者・やってよいことの合意は人間が行う"}
adversarial_review: {required: false, reason: "基準どおり（work-defaults.md）"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "remote-write:issue-create", "remote-write:issue-append", "remote-write:mr-create", "remote-write:push"]
started_at: "2026-09-04T22:00:52+09:00"
completed_at: ""
base_sha: "7d5983b"
---

# 0002 全体計画: git worktree による同一フェーズのチケット並列実行と開始時の worktree 分離

## 目的

1 issue の中でも git worktree を使い、同じフェーズの互いに依存しないチケットを並列に実施できるようにする。あわせて issue-MR 駆動に入った時点で worktree を切り、同じ clone で並行する他セッションの調査作業と干渉しないようにする。この 2 点について issue を確定し、ブランチと draft MR を作り、フェーズ列と実行者・レビュー要否の方針を人間と合意する。

## DoD

- [ ] 起点となる issue が確定し、番号と URL が記録されている（根拠: ）
- [ ] feature ブランチと draft MR が作られ、logs/mr.json に記録されている（根拠: ）
- [ ] 種別とフェーズ列・各タスクの実行者・人間レビュー要否・敵対的レビュー要否の方針が全体計画書に書かれ、ユーザーの承認を得ている（根拠: ）
- [ ] 最初の計画チケット（調査計画）が 1 枚作られている（根拠: ）

## 作業内容

- issue を検索し、無ければ本文案を承認のうえ起票する
- ブランチ名と MR タイトルを承認のうえ、20-common-step-feature-mr で feature ブランチと draft MR を作る
- work-defaults.md を基準にフェーズ列・実行者・レビュー要否を組み立て、差分を理由付きで提案して承認を得る
- 全体計画書を wip/00_overall_plan/ に書き、調査計画チケットを 1 枚作る

## 作業ログ

### 現在地

- 完了。issue #50・ブランチ `feature-50-worktree-parallel-tickets`・draft PR #51・全体計画書・調査計画チケット 0003 まで揃った

### うまくいったこと

- 類似 issue の検索から起票まで一直線に進んだ。worktree / 並列を扱う既存 issue は open 19 件・closed 検索とも 0 件で、重複の判断が早く付いた
- 全体計画書の「方針」を `work-defaults.md` との差分だけで書けたため、合意の対象が 3 件の差分に絞れた

### うまくいかなかったこと

- 機構の不具合を 5 件踏み、そのうち 3 件は AI 側で回避できずユーザーの手作業を要した（詳細は「スコープ外で見つけたこと」）
- `ticket.sh create` の `--allow-ops` を省略したため既定の `read` だけになり、issue 起票が WF206 で拒否された。チケットを取り消して作り直した（0001 → 0002）

### 仕様からの逸脱

- `20-common-step-feature-mr` 手順 3 の `git checkout --no-track -b` を AI が実行できず、ユーザーに実行してもらった。手順の意図（`--no-track` で作成元を `origin/<default>` に固定する）は満たしている

### 判断と根拠

- (A) 同一フェーズの並列実行と (B) 開始時の worktree 分離を 1 issue にまとめた。どちらも worktree という同じ機構の上に乗り、要件・仕様を分けて書くと整合を取る手間が利得を上回るため
- DDR i0001-23（並列実施の廃止）は「覆す前提」ではなく「調査で費用対効果を測って決める」扱いにした。i0001-23 が却下した案が worktree による分離そのものであり、却下理由（統合コストが利得を上回る）が今も成り立つかは実測でしか分からないため
- 調査の実行者を基準の sonnet から opus に上げた。読む対象が `scope.sh` の分類・`workflow-guard` の判定順・状態ファイルの相互作用で、読み違えが設計全体の前提を壊すため
- 人間レビューを全フェーズで不要とし、代わりに全フェーズへ `claude-fable-5-1` の敵対的レビューを 1 回ずつ入れた（ユーザーの明示指示）

### 拒否・確認・迂回の記録

- WF204（`cd`）: `cd` が分類に無い。作業ディレクトリは既にリポジトリルートなので `cd` を外して再実行した
- WF206（`issue-create`）: チケットの `allow.ops` に無い。迂回せず 0001 を取り消し、`allow.ops` を宣言した 0002 を作り直した
- WF204（`git checkout -b`）: 分類に無く、宣言でも通せない。ユーザーの承認を得たうえで、ユーザー自身に実行してもらった
- WF205（`cat > wip/tmp/...`）: コマンドでの書き込みを拒否されたので Write ツールに切り替えた
- CP005 項目 4（push）: 前 issue の `merge-state` 残留。状態ファイルの直接編集はせず、ユーザーに削除してもらった

### 使った AI アセットと効き目

| アセット | 観点 | 類型 | 候補 |
|---|---|---|---|
| `00-workflow-quick-request` | 問題なし | - | - |
| `00-workflow-issue-mr-driven` | 問題なし | - | - |
| `10-task-overall-plan` | 問題なし | - | - |
| `20-common-step-feature-mr` | あったが誤っていた | (b) | 手順 3 が `git checkout -b` を求めるが、機構がその操作を拒否する。手順と機構が噛み合っていない |
| `20-common-step-ticket` | あったが罠が書かれていなかった | (c) | `--allow-ops` を省くと既定の `read` だけになり、後続の操作が拒否される。呼び出し側の手順に既定値の注意が無い |
| `workflow-guard` フック | 足りなかった | (a) | git のブランチ・worktree 操作を表す分類が無い |
| `push.sh` | あったが誤っていた | (b) | 項目 4 が `merge-state` の `.branch` を見ない |

### スコープ外で見つけたこと

本チケットの実施中に見つかった機構の不具合 5 件。いずれも issue #50 の本題とは別で、全体まとめで別 issue として起票する（保留 P2）。

1. `scope.sh` の git 分類に `checkout` / `switch` / `worktree` が無く、WF204 で拒否される。どの `allow.ops` を宣言しても通らないため、AI が feature ブランチを作れない。新しい issue のたびに必ず止まる（受け入れ条件 A1 の一部として本 issue で直す）
2. `ticket.sh cancel` が default ブランチ上でもコミットする。`create` / `start` は overall-plan で commit しない扱いなのに `cancel` だけ例外が漏れており、DDR i0004-04 に反して default が汚れる
3. `logs/` の進行状態 3 点（`mr.json` / `review-state.json` / `merge-state.json`）が issue をまたいで残る。新しい issue の開始時に誰もリセットしないため、`push.sh` 項目 4 が前 issue の `ready` を見て永久に止まり、`boundary.sh` が前 issue の MR 番号を掴み続ける
4. `push.sh` が CP005 で止まっても push 検知フックが成功として報告し、工数集計とリンクを出す。設計上の割り切り（DDR i0009-07）だが失敗時は誤報になる
5. `logs/mr.json` の `issue` フィールドを書く実装がどこにも無い。`write_mr_json` は既存値を引き継ぐだけで、常に null のままになる

### AI アセットに反映すべき内容

- `20-common-step-feature-mr` の手順 3 と `scope.sh` の git 分類を噛み合わせる（本 issue の受け入れ条件 A1）
- `00-workflow-issue-mr-driven` 手順 1 の全体計画チケット作成に、`--allow-ops` の具体値を明記する
- 新しい issue の開始時に `logs/` の進行状態をリセットする手順または提供コマンドを設ける

### 備考

- 取り消した 0001 のコミット `a390a84` は default ブランチ上に作られたが、feature ブランチは `origin/main` から切ったため履歴には入っていない。ローカル main もユーザーが `origin/main` に戻し済み
