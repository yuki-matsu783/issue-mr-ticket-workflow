---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "フェーズ列・実行者・レビュー要否・やってよいことの方針の合意を PR 上にも残す（初回の切れ目）"}
adversarial_review: {required: false, reason: "合意が本体で成果物は計画書 1 枚"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "remote-write:issue-create", "remote-write:issue-append", "remote-write:mr-create", "remote-write:push"]
started_at: "2026-09-01T00:26:06Z"
completed_at: "2026-09-01T01:04:29Z"
base_sha: "f2ae301"
---

# 0001 全体計画

## 目的

issue #6（自己改善ワークフロー機構の実装 1/3: 基盤）の全体計画書を作り、フェーズ列・実行者・レビュー要否・やってよいことの方針を合意し、最初の計画チケット（調査計画）を起こす。

## DoD

- [x] issue #6・ブランチ・draft PR #7 が存在する（根拠: https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6、`feature-6-workflow-foundation`、https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7）
- [x] 全体計画書 `wip/00_overall_plan/overall-plan.md` があり、種別・フェーズ列・受け入れ条件との対応・方針・保留した点・合意の記録が埋まっている（根拠: 同ファイルの 7 節 + 手作業代替節）
- [x] 承認③（フェーズ列・方針）を得て計画書の「合意の記録」に記した（根拠: AskUserQuestion 2026-09-01「この計画で進める」「全タスクをメインエージェント」。計画書「合意の記録」③ 行）
- [x] 調査計画チケット 1 枚が未着手にあり、DoD が issue の受け入れ条件から導かれている（根拠: `wip/10_tickets/00_todo/0002-investigation-plan.md` DoD 2 項目目が判断点 1〜5 と受け入れ条件 2・5・7 を参照）

## 作業内容

- issue の確定（承認①②）→ ブランチと draft PR → マージ方式の確認 → 種別判定 → フェーズ列 → 方針 → 計画書と承認③ → 調査計画チケットの作成 → 完了

## 作業ログ

### 現在地

- 完了（未完了の項目なし）

### うまくいったこと

- 承認①②③を 2 回の AskUserQuestion にまとめ、issue → ブランチ → PR → 計画 → 最初のチケットまで往復 2 回で通った
### うまくいかなかったこと

### 仕様からの逸脱

- 提供コマンド（ticket.sh / commit.sh / push.sh / boundary.sh）が未実装のため、チケットの作成・着手・完了を手作業（Write + git mv）で行った。時刻と base_sha も手で記入。計画書「機構未実装期間の手作業代替」に範囲を明記

### 判断と根拠

- 実装を 3 分割（基盤 / フック / スキル）にした。1 PR で 80 ファイル超 + テストになりレビュー不能なため。1/3 は後続がすべて依存する層
- 実行者をすべてメインエージェントにした（既定はサブエージェント）。提供コマンド未実装の間はサブエージェントに手作業の状態遷移を教えることになるため

### 拒否・確認・迂回の記録

- 承認①②を AskUserQuestion で取得（2026-09-01）: 3 分割の 1/3 を新規 issue、本文・ブランチ名・PR タイトル案どおり
- 承認③を AskUserQuestion で取得（2026-09-01）: 計画どおり。実行者は全タスクをメインエージェント
- 完了検査（DoD 全チェック・根拠あり・現在地消込・反映すべき内容あり・チケット以外の未コミットなし）を手作業で確認した（ticket.sh 未実装）

### 使った AI アセットと効き目

- `00-workflow-issue-mr-driven` SKILL.md（旧参考実装版）: 承認ポイントの順序は足りた。参照先（work-boundary.sh / 10-work-*）が存在せず、実際の手順は `10_spec/skills/10-task-overall-plan.md` と `00-workflow-issue-mr-driven.md` 仕様を直接読んで進めた
- `10_spec/skills/20-common-step-ticket.md`・フック共通仕様 §9: チケットの frontmatter と作業ログ見出しの正として足りた。テンプレート実体が無いので要件書の見出し一覧から起こした

### スコープ外で見つけたこと

- 旧 SKILL.md（`00-workflow-*`）の参照先が新仕様と食い違う（3/3 で置き換え予定）
- `20-task-gh-issue` の issue テンプレートが存在しないため、issue 本文は #4 の形式を踏襲した

### AI アセットに反映すべき内容

- チケットテンプレートに `adversarial_review` の欄が要る（ワークフロー仕様 手順 2a は「人間レビュー要否と同じ欄の隣に書かれる敵対的レビュー要否」を参照するが、共通仕様 §9 の frontmatter 例に無い）。実装計画で `20-common-step-ticket` の assets と §9 の整合を確認する項目に入れる

### 備考

