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
