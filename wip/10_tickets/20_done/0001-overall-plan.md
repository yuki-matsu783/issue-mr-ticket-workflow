---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "フェーズ列・実行者・やってよいことの合意は人間が行う"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: "2026-09-02T07:23:50+00:00"
completed_at: "2026-09-02T07:26:28+00:00"
base_sha: "3591f3a"
---

# 0001 全体計画: 要件定義書の型の改訂 (#17)

## 目的

issue #17 のフェーズ列・チケット構成・実行者・レビュー要否を決めて全体計画書に残し、後続のチケットを起こす

## DoD

- [x] 全体計画書が wip/00_overall_plan/ にある（HTML ビューは全体計画書には作らない）（根拠: wip/00_overall_plan/0001-overall-plan.md。report-view スキルにより全体計画書に HTML ビューは作らない）
- [x] issue #17 の受け入れ条件 9 件が全体計画書の「受け入れ条件との対応」に全件写され、担当チケットが割り当たっている（根拠: 全体計画書「受け入れ条件との対応」の表に 9 行）
- [x] 後続チケット（investigation / ai-asset-design / ai-asset-implementation / overall-summary）が 00_todo に作成されている（根拠: 0002-investigation / 0003-ai-asset-design / 0004-ai-asset-implementation / 0005-overall-summary を 00_todo に作成）
- [x] work-defaults の基準との差分（計画チケットの省略・実行者をメインエージェントに）が理由付きで全体計画書に書かれている（根拠: 全体計画書「方針（work-defaults の基準との差分）」の表と「機構の未整備による運用上の差分」）

## 作業内容

- issue #17 と PR #18 の文脈を全体計画書の冒頭に書く
- フェーズ列とチケット構成を決め、scope-limits の書き込み許可と整合させる
- 後続チケットを ticket.sh create で起こす

## 作業ログ

### 現在地

- 全体計画の作成と後続チケットの起票は済。次は 0002-investigation の着手（レビュー完了の連絡後）

### うまくいったこと

- issue #17 の受け入れ条件 9 件を、そのままチケットの DoD に落とせる粒度で書けた
- scope-limits.json の許可範囲を先に読んだことで、見本の書き直し（`.claude/docs/**`）が ai-asset-implementation では拒否され ai-asset-design に属すると気づけた

### うまくいかなかったこと

- `ticket.sh create` の `--dod` は根拠欄を自動で付けるため、こちらで「（根拠: ）」を書くと二重になる。0001 で発生し手で直した
- feature ブランチ作成時に upstream が origin/main に自動設定され、push.sh が CP006 で拒否された。`git branch --unset-upstream` で解消した

### 仕様からの逸脱

- ワークフローが指す `10-task-*` スキル・`work-boundary.sh`・`merge-prep.sh` が未実装のため、ワーク境界の判定と完了処理を手動で代替する。全体計画書「機構の未整備による運用上の差分」に記録
- `gh` CLI が環境に無いため GitHub 操作は GitHub MCP で代替した

### 判断と根拠

- 計画チケット（*-plan）4 種を省略した。調査の問いと設計対象が issue の受け入れ条件から一意に決まり、計画書を挟む往復に見合う不確実性が無いため
- 敵対的レビューを設計・実装で省略した。ユーザーが実行体制として「メインが実施し人間レビュー」を選んだため
- 見本の書き直しを ai-asset-design に置いた。対象が `.claude/docs/**` で scope-limits の許可範囲が一致し、型を決めた直後に成立を検証できるため

### 拒否・確認・迂回の記録

- push.sh が CP006（リモート拒否）。force はせず upstream の設定を直して再実行した
- 承認①（新規 issue を作る）・承認②（本文とブランチ名）・全体計画の承認をユーザーから取得済み

### 使った AI アセットと効き目

- `00-workflow-issue-mr-driven`: 承認ポイントの順序が明確で、issue → ブランチ → PR → 計画の流れを迷わず進められた。ただし前提とする `10-task-*` と各フックが未実装で、手順 5 のワークループがそのままでは実行できない
- `20-common-step-feature-mr`: 「CLI 未導入なら停止」とあるが、CLAUDE.md は MCP での代替を認めており食い違う
- `20-common-step-ticket`: `create` / `start` は問題なく動いた

### スコープ外で見つけたこと

- `20-common-step-feature-mr` の手順 4 は `wip/` の持ち越しを開始コミットに載せるとあるが、この時点では全体計画チケットがまだ無く空コミットになる。順序の記述が実態と合っていない
- 要件書は 45 件あり、issue #8 の本文の「40 件超」と整合する

### AI アセットに反映すべき内容

- `20-common-step-ticket`: `--dod` の根拠欄が自動付与されることを SKILL.md の手順 2 に明記する（現状は「DoD の各項目には根拠欄が付く」とあるが、呼び出し側が書くと二重になる点が読み取れない）
- `20-common-step-feature-mr`: 「CLI 未導入・未認証」の対処を、CLAUDE.md の MCP 代替と揃える
- `00-workflow-issue-mr-driven`: 参照先の `10-task-*` スキルとフックが未実装のときの縮退運用を、エラーハンドリング表に 1 行足す

### 備考

- 本チケットは overall-plan のため ticket.sh が状態変更をコミットしない。成果物は commit.sh でコミットする
