---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "フェーズ列・実行者・やってよいことの合意は人間が行う（work-defaults 基準どおり）"}
adversarial_review: {required: false, reason: "基準どおり。合意の場であり成果物の検証ではない"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "remote-write:issue-append", "remote-write:mr-create", "remote-write:push"]
started_at: "2026-09-03T12:35:52+09:00"
completed_at: "2026-09-03T13:45:31+09:00"
base_sha: "36fd9a0"
---

# 0001 issue #10 全体計画 — 自己改善ワークフロー機構の実装 3/3（タスク／ワークフロースキル・エージェント・提供コマンド）

## 目的

issue #10 の種別・フェーズ列・タスク種類ごとの実行者とレビュー要否・許可範囲の方針をユーザーと合意し、全体計画書に残して最初の計画チケットを起こす

## DoD

- [x] 全体計画書 wip/00_overall_plan/overall-plan.md に、対象・種別・フェーズ列・受け入れ条件との対応・方針・保留した点・合意の記録の 7 節が揃っている（根拠: wip/00_overall_plan/overall-plan.md の見出し「対象」「種別」「フェーズ列」「受け入れ条件との対応」「方針」「保留した点」「合意の記録」）
- [x] issue #10 の受け入れ条件 9 件（本文 5 件 + 2026-09-02 追記 4 件）が「受け入れ条件との対応」表で 1 件残らずフェーズに割り付いている（根拠: 同計画書「受け入れ条件との対応」の A1〜A5・B1〜B4 の 9 行）
- [x] タスクの種類ごとの実行者・人間レビュー要否・敵対的レビュー要否が rules/work-defaults.md との差分として理由付きで書かれている（根拠: 同計画書「方針」の 9 行の表と注釈 ※1・※2）
- [x] この issue 固有の制約（タスクスキルとエージェントと提供コマンドが未作成のため、機構自身を作りながら使うこと）への対処が方針に書かれている（根拠: 同計画書「機構自身を作りながら使う（この issue 固有の制約）」の 4 項目）
- [x] 承認③の合意内容（誰が・いつ・何に）が合意の記録に書かれている（根拠: 同計画書「合意の記録」の①②③の 3 行）
- [x] 最初の計画チケット（investigation-plan）が未着手に 1 枚だけ作られている（根拠: wip/10_tickets/00_todo/0002-investigation-plan.md。00_todo は他に無し）

## 作業内容

- issue #10 の本文と追記から受け入れ条件を全件書き出す
- リポジトリの現状（既存スキル・仕様書 15 本・未作成のエージェントと提供コマンド）を確認して種別を判定する
- フェーズ列をテンプレートから決め、差分があれば理由を書く
- work-defaults.md を基準に方針を組み、差分を理由付きで書く
- 全体計画書を書いて承認③を取り、合意を記録する
- 調査計画チケットを 1 枚作る

## 作業ログ

### 現在地

- 完了。全体計画書を合意し、調査計画チケット 0002 を起票した

### うまくいったこと

- issue #10 が依頼文とタイトル完全一致で open のまま残っていたので、追記なしでそのまま使えた
- 前 issue（#9 / PR #12）の作業領域が main に残っていたことを、ブランチ作成前に気づいて開始コミット 36fd9a0 で片付けられた（103 ファイル削除）。着手後だと `overall-plan` の許可範囲では消せない
- 実装済みフック（`workflow-state-guard` / `session-start`）が 3/3 の提供コマンドを名指しで待っている状態だったので、置き場の食い違い（P1）を計画の段階で保留として立てられた

### うまくいかなかったこと

- `git checkout -b <branch> origin/main` が上流を `origin/main` に設定するため、`push.sh` が CP006（リモートに拒否された。feature → origin/main）で止まった。`git branch --unset-upstream` してから再実行して通した。`20-common-step-feature-mr` 手順 4 は「上流は自動で設定される」と書いているが、手順 3 の `git checkout -b <ブランチ名> origin/<default>` と組み合わせると成立しない
- チケット着手後に `bash wip/tmp/<script>.sh` の形で提供コマンドを呼ぼうとして WF204（bash はどの分類にも当たらない）で拒否された。提供コマンドは 1 コマンドで直接呼ぶ必要がある

### 仕様からの逸脱

- `10-task-overall-plan` の SKILL.md が未作成のため、仕様書 `.claude/docs/10_spec/skills/10-task-overall-plan.md` の処理フローを直接読んで実施した（この issue で作るものなので、全体計画書「機構自身を作りながら使う」1 に段取りとして書いた）
- `assets/overall-plan.template.md`（全体計画書のテンプレート実体）も未作成のため、仕様の「OUT ひな形」の節構成と #9 の全体計画書を土台に書いた

### 判断と根拠

- 種別を AI アセットと判定した。根拠: 変更対象が `.claude/skills/**`・`.claude/agents/**`・提供コマンド 2 本・`.claude/evals/**`・`CLAUDE.md`・`.claude/docs/` で、`apl/` を含まない
- フェーズ列はテンプレートどおり省略なし。調査で答えを出す問い（作るものの一覧・仕様の食い違い・旧名の残存・申し送りの割り付け）が実装の前に要るため、調査を省けない
- 実行者を全種類メインエージェントに倒した。根拠: `task-executor` エージェントがこの issue の成果物であり、作りながらそれに実行を依存させると失敗の切り分けができない（#9 と同じ判断）
- 人間レビューは fable のサブエージェントによる敵対的レビューで代替し、1 フェーズ最大 2 回で打ち切る。根拠: ユーザーの指示（2026-09-03）。上限に達した後の指摘はフィードバック計画へ集約するので取りこぼさない

### 拒否・確認・迂回の記録

- WF204: 着手後に `bash wip/tmp/mk-0002.sh`（`ticket.sh create` のラッパー）を実行しようとして拒否された。迂回せず、`ticket.sh create` を直接 1 コマンドで実行して通した
- 拒否ではないが CP006（push.sh）を 1 回受けた。force はせず、上流の設定を直して再実行した

### 使った AI アセットと効き目

- `00-workflow-issue-mr-driven`（旧版）: 承認①②の取り方と手順 0 の状態確認は有効だった。ただし手順 5 が指す `10-work-*` スキルと `work-boundary.sh` はどちらも存在せず、この issue の参照更新の対象そのものだった
- `20-common-step-feature-mr`: ブランチと draft MR の作成に使えた。上流設定の穴（上記）を除いて手順どおり
- `20-common-step-ticket` / `20-common-step-commit-push`: `ticket.sh` / `commit.sh` / `push.sh` はいずれも想定どおり動いた

### スコープ外で見つけたこと

- `wip/00_overall_plan/` に `.gitkeep` が無かった（他の 5 ディレクトリにはある）。片付けで全体計画書を消すとディレクトリごと消えるため、開始コミットで `.gitkeep` を追加した。`finalize.sh` の片付け仕様（「`.gitkeep` は残す」）とも整合する
- PR #12 が片付けなしでマージされたため main に前 issue の作業領域が残っていた。`finalize.sh` が未実装で手作業代替だったことが原因と見られる。3/3 で解消する

### AI アセットに反映すべき内容

- `20-common-step-feature-mr` 手順 3〜4: `git checkout -b <branch> origin/<default>` は上流を `origin/<default>` に設定するので、`push.sh` の前に `git branch --unset-upstream` するか `git checkout -b` に `--no-track` を付ける旨を書く（この issue の参照更新フェーズで扱えるか、フィードバック計画で判断する）
- `10-task-overall-plan` 仕様: 「前 issue の作業領域が default ブランチに残っている場合の扱い」が処理フローに無い。ブランチ作成前に片付けるのが唯一の機会（着手後は `overall-plan` の許可範囲外）なので、手順 4 の前に確認を置くとよい

### 備考

- 承認①②③はいずれも 2026-09-03 にユーザーから取得。内容は全体計画書「合意の記録」に転記した
