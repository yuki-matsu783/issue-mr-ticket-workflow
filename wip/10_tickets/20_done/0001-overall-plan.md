---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "フェーズ列・実行者・やってよいことの合意は人間が行う"}
adversarial_review: {required: false, reason: "計画の合意は人間レビューで足りる"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T09:13:13+00:00"
completed_at: "2026-09-02T09:14:09+00:00"
base_sha: "c2cdd8c"
---

# 0001 全体計画: 設計文書スキルをアプリ（apl/ 配下）に対応させる

## 目的

issue #20 のフェーズ列・実行者・レビュー要否・許可範囲を決めて合意し、最初の計画チケットを起こす

## DoD

- [x] 全体計画書 wip/00_overall_plan/overall-plan.md がある（根拠: 同ファイル 114 行。対象 / 種別 / フェーズ列 / 受け入れ条件との対応 / 方針 / 保留した点 / 合意の記録の 7 節）
- [x] 承認①②③が合意の記録に残っている（根拠: overall-plan.md「合意の記録」表の 3 行）
- [x] 調査計画チケットが未着手で 1 枚ある（根拠: wip/10_tickets/00_todo/0002-investigation-plan.md）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。issue #20 への追記、ブランチと draft PR #25 の作成、全体計画の合意、調査計画チケット 0002 の起票まで済み

### うまくいったこと

- 依頼が既存 issue #20 とほぼ一致していたため、新規起票せず追記 1 回で経緯を 1 本にまとめられた
- 置き場の構成を先にユーザーに確認したので、apl/ 直下集約かアプリごとかで手戻りが出なかった

### うまくいかなかったこと

- 10-task-* のスキル本体が未作成のため、10-task-overall-plan の仕様書を読んでメインエージェントが代行した。スキルの手順書が無い分、承認ポイントの取りこぼしを自分で検算する必要があった
- gh CLI がこの実行環境に無く、マージ方式の確認（処理フロー 3）ができなかった。保留に回した

### 仕様からの逸脱

- ブランチ名がスキルの命名規約（`feature-20-<slug>`）ではなく `claude/design-docs-app-support-6a9cyj`。セッションの指定ブランチに従った
- 全体計画書のテンプレート `assets/overall-plan.template.md` が存在しないため、仕様書「OUT ひな形」の節の表から起こした
- 処理フロー 3（squash merge の可否の確認）を未実施。gh CLI 不在のため保留に記録した

### 判断と根拠

- 種別を「AI アセット」1 つにした。変更の重心が `.claude/` にあり、apl/ への移動は新しい置き場定義に従属する中身を変えない作業のため
- 実装・テストフェーズを追加した。既存ファイルの移動は `apl/**` への書き込みで、ai-asset-implementation の許可範囲に入らない
- AI アセット実装を実装・テストより前に置いた。`scope-limits.json` に `apl/**` が入る前に移動すると許可範囲外になる
- 実行者を全種類メインエージェントに倒した。サブエージェントに渡す手順書（10-task-* スキル本体）が無いため

### 拒否・確認・迂回の記録

- gh CLI 不在のため GitHub 操作を MCP（issue_write / create_pull_request）で代替した。CLAUDE.md「環境と制約」の指示どおり
- work-boundary.sh / merge-prep.sh が未作成のため、ワーク境界のレビュー依頼は PR コメントで代替する方針を全体計画に明記した

### 使った AI アセットと効き目

- `00-workflow-issue-mr-driven`: 承認ポイントの順序は明確だったが、参照先スキル名が `10-work-*` で、仕様書・task-types.tsv の `10-task-*` と食い違っている
- `20-common-step-ticket` の ticket.sh: create / start は問題なく動いた
- `20-common-step-commit-push` の commit.sh / push.sh: 空コミットと push 前チェック 4 項目とも通った

### スコープ外で見つけたこと

- `00-workflow-issue-mr-driven/SKILL.md` が参照するスキル名 `10-work-<phase>-plan` / `10-work-<phase>-exec` と、`task-types.tsv` および仕様書の `10-task-*` が食い違う。どちらかに寄せる必要がある（issue #10 の範囲か別 issue か要判断）
- 同スキルの承認ポイント表の③がマージ前作業の承認になっており、`10-task-overall-plan` 仕様書の③（全体計画の合意）と番号が衝突している
- `.claude/skills/00-workflow-issue-mr-driven/assets/` に `pr.template.md` が無く、実体は `20-common-step-feature-mr/assets/mr-body.template.md`。SKILL.md 手順 4-5 と 5-3 の参照先が実在しない

### AI アセットに反映すべき内容

- 上記「スコープ外で見つけたこと」の 3 件は本 issue の範囲外。フィードバック計画で別 issue の要否を判断する

### 備考
