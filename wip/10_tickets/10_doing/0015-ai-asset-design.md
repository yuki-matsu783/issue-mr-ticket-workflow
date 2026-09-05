---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0012", "0013", "0014"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-05T13:57:46+09:00"
completed_at: ""
base_sha: "0d12e2f"
---

# 0015 AI アセット設計: 並列実施の運用・入口・エージェント定義と、横断文書・用語辞書の整合

## 目的

設計計画書（wip/20_plans/0010-ai-asset-design-plan.md）の結論方針 P2・P4a・P11 と受け入れ条件 A2・A3・A4 の運用面を .claude/docs/ の正史へ落とす。並列実施の起動と切れ目での合流を issue-MR 駆動の手順に足し、worktree を切る既定（切らない）と 1 ホップの参照を置き、task-executor の隔離条件とレポート追記規約を定めて、横断文書と用語辞書の整合を取る。

## DoD

- [ ] 00-workflow-issue-mr-driven の要件・仕様に、開始時に worktree を切る既定（切らない）と手順、並列実施の起動、切れ目での合流、scan_tickets が ticket_type のまとまりでタスクを切ることが書かれている（A2）（根拠: ）
- [ ] 20-common-step-worktree への参照が 00-workflow-issue-mr-driven に置かれ、並行作業の手段が振り分けスキルから 1 ホップで辿れる（A3）。CLAUDE.md は触らない（根拠: ）
- [ ] agents/task-executor の要件・仕様に、並列で起動されたときの前提（自分の作業ツリーの中だけで作業する / チケットを新規作成しない / push しない / 合流しない）と、isolation を使う条件（worktree.baseRef が設定されていること。無い環境では使わない）が書かれている（根拠: ）
- [ ] 10-task-investigation-exec の要件・仕様に、並列区間でのレポート追記規約（自分の節だけを追記し共通部の更新は合流側で 1 回）と、完了済みチケットの作業ログの誤りはレポートの訂正節に書くことが足されている。他の 10-task-*-exec からの参照が生きていることを確認した（根拠: ）
- [ ] rules/work-defaults.md に並列してよいタスクの種類が足され、rules/ルール体系.md の索引が更新され、定義が二重に置かれていない（根拠: ）
- [ ] 90_glossary/ワークフロー用語.md に 作業ツリー / 本流 / 共有ルート / 合流 / 並列実施 / 並列区間 が追加され、90_glossary/スキル名.md に 20-common-step-worktree が追加されている（根拠: ）
- [ ] フック共通仕様 §1 に settings.json の worktree.baseRef が登録されている（根拠: ）
- [ ] DDR i0050-06（開始時に worktree を切る既定は切らない）が作られ、却下した案（常に切る）と理由を持つ（根拠: ）
- [ ] 束 1 由来の記述（レポート追記規約・baseRef・並列の起動）は「並列実施を行う場合」の条件付きで書かれている（根拠: ）
- [ ] ヘッドレス実行の帰結（既定は切らない・並列にしない。合流は切れ目で行い衝突で止まったら人に返す）が要件定義書に書かれている（根拠: ）
- [ ] 0012・0013・0014 が更新した文書を読み直したうえで書かれ、受け入れ条件 A1〜A6 が設計計画書の対応表どおり全件どこかの文書に落ちている（根拠: ）

## 作業内容

- 設計計画書の結論方針 P2・P4a・P11、横断整合、ヘッドレス実行の帰結を読む
- 調査結果レポートの e17〜e24・e31〜e33・e52・設計への反映 17〜21・24・27・45〜47 を根拠として読む
- 20-common-step-requirement / 20-common-step-spec の作法で書く（アセット本体・settings.json・.gitignore は触らない）

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
