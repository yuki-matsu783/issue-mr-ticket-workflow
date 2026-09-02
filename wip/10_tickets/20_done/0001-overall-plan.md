---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "フェーズ列・実行者・やってよいことの合意は人間が行う"}
adversarial_review: {required: false, reason: "基準どおり（work-defaults.md）"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: "2026-09-02T05:18:02+00:00"
completed_at: "2026-09-02T05:20:42+00:00"
base_sha: "1a16ceb"
---

# 0001 VS Code チケットボード拡張の全体計画

## 目的

issue #13 の受け入れ条件を満たすためのフェーズ列・実行者・レビュー要否・やってよいことの方針を決め、人間の合意を得て最初の計画チケットを起こす

## DoD

- [x] wip/00_overall_plan/overall-plan.md が仕様の節構成（対象・種別・フェーズ列・受け入れ条件との対応・方針・保留した点・合意の記録）で書かれている（根拠: wip/00_overall_plan/overall-plan.md の 7 節。10_spec/skills/10-task-overall-plan.md「OUT ひな形」の節と一致）
- [x] フェーズ列と方針について承認を得て、その内容と日時が計画書に記録されている（根拠: 「この内容で合意」を取得。overall-plan.md「合意の記録」の承認③行に記録）
- [x] 最初の計画チケット（investigation-plan）が未着手で 1 枚だけ作られている（根拠: wip/10_tickets/00_todo/0002-investigation-plan.md のみ。コミット 25e840d）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。全体計画書を書き、承認③を得て、0002-investigation-plan を起票した

### うまくいったこと

- 類似 issue の検索が 0 件で、issue #13 を新規に起票できた。ブランチ #14 の draft PR まで一直線に進んだ
- 依頼の曖昧点（ビュー形式・操作範囲・issue の扱い）を 1 回の AskUserQuestion にまとめられた。往復が 1 回で済んだ

### うまくいかなかったこと

- ワークフローの委譲先である `10-task-*` スキルが `.claude/skills/` に存在せず、スキルの手順どおりに委譲できなかった。仕様書 `.claude/docs/10_spec/skills/10-task-*.md` を手順書として読み替えて進めた
- `work-boundary.sh` / `merge-prep.sh` も無く、ワーク境界とマージ前作業の状態管理を機械に任せられない
- `gh` CLI が実行環境に無い。issue と PR の操作は GitHub MCP で代替した。`gh repo view` に相当するリポジトリ設定の読み取り手段が MCP に無く、squash merge の可否は確認できなかった

### 仕様からの逸脱

- ブランチ名が命名規約 `feature-<N>-<slug>` から外れ `claude/vscode-ticket-visualization-ci8etr` になっている。実行環境がこの指定ブランチ以外への push を禁じているため。PR 本文と全体計画書に理由を記載した
- 実行者を全タスクでメインエージェントにした（work-defaults.md の基準はサブエージェント）。委譲先スキルとエージェント定義が無いため。全体計画書「方針」の差分 1 に記載
- `10-task-overall-plan` 手順 3（マージ方式の確認）を実施できていない。保留事項として計画書に記載した

### 判断と根拠

- 種別を「アプリ」とした。主目的が `tools/vscode-ticket-board/` へのコード追加であり、`.claude/` 配下の機構本体を変更しないため（判定基準の正は 10_spec/skills/00-workflow-issue-mr-driven.md のフェーズ列テンプレート表）
- フェーズを削らずテンプレートどおり 7 フェーズを採用した。規模は小さいが、調査で frontmatter の実形と壊れ方を押さえないと受け入れ条件 2 と 7 の設計ができないため
- 拡張を読み取り専用にした。状態遷移の唯一の経路が ticket.sh である前提を、外から書き込む経路を作って壊さないため（ユーザーも読み取り専用を選択）

### 拒否・確認・迂回の記録

- 拒否はなし。`.claude/hooks/20-PreToolUse/` が空でフックによる強制が効いていないため、ブロックは一度も発生していない
- 確認: 承認①（新規 issue）・承認②（本文・ブランチ名・PR タイトル）・承認③（フェーズ列と方針）をいずれも AskUserQuestion で取得した

### 使った AI アセットと効き目

- `00-workflow-issue-mr-driven`: 順序と承認ポイントの規定として有効。ただし委譲先の `10-work-*` / `10-task-*` が実在せず、手順 5 のワークループがそのままでは実行できない
- `20-common-step-ticket` の ticket.sh: create / start が仕様どおり動いた。overall-plan をコミットしない分岐も期待どおり
- `20-common-step-commit-push` の commit.sh / push.sh: メッセージ規約の検査と push 前 4 項目の検査が通り、そのまま使えた

### スコープ外で見つけたこと

- `.claude/agents/` が空。work-defaults.md が前提にする敵対的レビューエージェントが存在しない
- 読み込まれたスキル `00-workflow-issue-mr-driven` の本文はタスク名を `10-work-*` と書き、`overall-summary` の代わりに `retrospective` を挙げているが、仕様書と `.claude/hooks/config/task-types.tsv` は `10-task-*` / `overall-summary` である。スキル本文と仕様が drift している（issue #3 の「スキル名.md が要件書ディレクトリと drift する」と同種）

### AI アセットに反映すべき内容

- 読み込まれるスキル `00-workflow-issue-mr-driven/SKILL.md` の本文と、仕様書 `10_spec/skills/00-workflow-issue-mr-driven.md`・`task-types.tsv` の間で、タスク名（`10-work-*` vs `10-task-*`）と最終フェーズ名（`retrospective` vs `overall-summary`）が食い違っている。委譲先を選べなくなるので揃える必要がある。本 issue のスコープ外なので、フィードバック計画で別 issue に切り出すか判断する
- `00-workflow-issue-mr-driven` は `gh` 不在時のフォールバックを表に書いているが、その前提である `work-boundary.sh` / `merge-prep.sh` 自体が未実装のため機能しない。未実装の機構に依存する記述の扱い（実装済みかを手順 0 で検査する等）を検討する余地がある

### 備考

- 未実装分は open issue #9（フック本体と settings.json 登録）と #10（タスク／ワークフロースキル・エージェント・finalize.sh / boundary.sh）に対応する
