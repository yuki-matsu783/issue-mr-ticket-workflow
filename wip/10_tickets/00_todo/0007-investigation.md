---
type: ticket
ticket_type: investigation
predecessors: ["0004", "0005"]
executor: opus
human_review: {required: false, reason: "全体計画書の差分 3（人間レビューを敵対的レビューに置き換える）"}
adversarial_review: {required: true, reason: "全体計画書の差分 3。フェーズごとに 1 回、claude-fable-5-1 で実施する"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "web"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0007 調査: 1 issue = 1 ブランチとの両立と、並列成果の合流コスト

## 目的

調査計画書の観点 D に答える。git が同じブランチを 2 つの作業ツリーで checkout させない制約のもとで、1 issue = 1 ブランチ = 1 MR を保ったまま複数 worktree を使えるかを選択肢ごとに整理し、合流コスト（特に wip/10_tickets/ のファイル移動による衝突）を過去 issue の実データで見積もる。受け入れ条件 A4・A6 と全体計画書の保留 P1 に効く。

## DoD

- [ ] 観点 D『1 issue = 1 ブランチ = 1 MR を保ったまま複数 worktree を使えるか、合流コストはどれだけか』への答えが wip/30_reports/0004-investigation.md に書かれている（根拠: ）
- [ ] ブランチ構成の選択肢（detached HEAD / サブブランチ + 合流 / --force）ごとに、成立可否・合流手順・衝突の種類を並べた比較表があり、git の同一ブランチ制約の根拠（公式の記述または実測）が添えられている（根拠: ）
- [ ] 衝突件数の見積もりが、過去 issue の実データ（1 チケットあたりの rename 件数・同一レポートへの追記回数）から算出されており、使ったコマンドとその出力が添えられている（根拠: ）
- [ ] wip/10_tickets/ の連番の採番、wip/30_reports/ の同一ファイルへの追記、ticket.sh と commit.sh の状態遷移コミットのそれぞれについて、並列時に衝突するかどうかが根拠付きで判定されている（根拠: ）
- [ ] DDR i0001-23 の却下文『1 issue = 1 ブランチ = 1 MR の原則と衝突し、統合のコストが利得を上回る』を構成する主張それぞれに『今も成り立つ / 成り立たない』の判定と根拠が付いている（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）

## 作業内容

- git worktree の同一ブランチ制約を公式ドキュメントで確かめる
- ticket.sh の採番・ファイル移動・状態遷移コミットの実装を読み、並列時に競合する箇所を特定する
- commit.sh / push.sh の push 前チェック 4 項目と boundary.sh の切れ目判定が、複数 worktree でどう振る舞うかを読む
- git log --diff-filter=R --name-status -- wip/10_tickets/ などで過去 issue の rename 件数を数え、衝突の見積もりを出す
- 実測手順（サブブランチを切って合流させ、衝突の実件数を数える手順と予測）を書く

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
