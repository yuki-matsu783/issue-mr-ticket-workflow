---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0016"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-ticket/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T04:03:03Z"
completed_at: "2026-09-01T13:15:59+09:00"
base_sha: "9990794"
---

# 0017 AI アセット実装 S2-4: ticket.sh と ticket.template.md（切り替え境目 B）

## 目的

`ticket.sh`（create / start / complete / cancel / next）とチケットテンプレートを仕様どおりに作り、以降のチケット操作を提供コマンドに切り替える。

## DoD

- [x] `assets/ticket.template.md` が仕様 OUT ひな形（frontmatter の全項目・目的・DoD・作業内容・作業ログ 10 見出し・備考。`{{名前}}` 形式）のとおり（根拠: `assets/ticket.template.md`。TICKET-T01 で create が全プレースホルダを埋める）
- [x] `scripts/ticket.sh` の create / start / complete / cancel / next が仕様「Script 処理」の各手順・TK001〜007・`commit.sh` 経由のコミット・拒否時の巻き戻し（移動・作成・記載事項を残さない）を実装している（根拠: `scripts/ticket.sh` cmd_create / cmd_start / cmd_complete / cmd_cancel / cmd_next、do_commit の失敗経路（作業ツリー復元 + `git reset`））
- [x] TICKET-T01〜11 が通る（T10 は `commit.sh` 実物の拒否で確認、T11 はファイル名と `ticket_type` の食い違い）（根拠: `run-tests.sh --ids` の PASS ID に TICKET-T01〜11、`test_ticket.sh` 79 assert 全 PASS）
- [x] `next` が `task-types.tsv` を読んでスキル名を解決し、一時リポジトリのテスト（TICKET-T06・T08）で先行未完了の飛ばしまで確認した。実リポジトリでの `ticket.sh next` の実行結果（0018 が返ること）は完了後に作業ログへ追記する境目 B の確認項目で、このチケットの DoD ではない（根拠: TICKET-T06（JSON の形と null）・T08（先行未完了の飛ばしと blocked）・T11（frontmatter の type で解決）が PASS）
- [x] `complete` の検査を 0012 相当のチケットのコピーに対して一時リポジトリで試し、通ることを確認した（既存チケットの形との整合）（根拠: TICKET-T11 の末尾で 0012 相当の手書きチケット（overall-plan）を start。complete の検査はこのチケット 0017 自身（手作りチケット）で実施 — 境目 B）
- [x] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: `grep -nE '\{\{|TODO|TBD'` ticket.sh・test_ticket.sh で 0 件）
- [x] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: 新規 3 ファイルに検索語 5 語のヒットなし）
- [x] `git diff --stat <base_sha>` が許可範囲内（根拠: 変更は `.claude/skills/20-common-step-ticket/`・`wip/` のみ）
- [x] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: レポートの 0017 節（アセット表・テスト結果・検査結果・D-10〜D-15））

## 作業内容

- 順: テンプレート → create → next → start → complete → cancel（テスト先行）
- 完了は `ticket.sh complete 0017` で行う（成果物を先に `commit.sh` でコミットしておけば「チケット以外の未コミットなし」の検査は通る）。通らなければ報告して停止し、同チケット内で `ticket.sh` を直す。手作業で移動しない
- 完了後に `ticket.sh next` を実行して 0018 が返ることを確認し、結果を 0018 の作業ログ冒頭に残す
- 以降のチケット（0018〜）は `ticket.sh start/complete` を使う

## 作業ログ

### 現在地

- 済: テンプレート、ticket.sh（5 サブコマンド）、テスト TICKET-T01〜11（79 assert 全 PASS）、全体回帰、レポート追記。完了は `ticket.sh complete 0017` で行う

### うまくいったこと

- TICKET-T10（commit.sh の拒否時の巻き戻し）が index にステージが残る実装バグを捕まえた
- `git commit -- <paths>`（commit.sh）と `frontmatter.sh` を組み合わせ、ticket.sh は自前の解析・ステージ操作を持たずに済んだ

### うまくいかなかったこと

- 一時リポジトリで `logs/` を gitignore し忘れ、完了検査が全滅した（テスト側の前提漏れ）

### 仕様からの逸脱

- D-10〜D-15（レポート「仕様からの逸脱」）

### 判断と根拠

- 拒否時の復元は「作業ツリーを元の内容で書き戻す + index を `git reset -- <paths>`」の 2 段（commit.sh が `git add` 済みで失敗するため）
- 旧パスが未追跡（overall-plan の持ち越し等）なら commit.sh に渡さない（`git add` が失敗するため）
- `next` は JSON のみを出す（IN/OUT サンプルに合わせ、`OK:` 行を付けない）

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `commit.sh`（状態変更のコミット。拒否の最終行をそのまま返せた）、`frontmatter.sh`、`script.template.sh` / `test.template.sh`

### スコープ外で見つけたこと

- 0013〜0016 の着手は手作業の `mv` で、追跡パスが todo のまま doing 期間を過ごした（0017 から着手の移動もコミット）。ticket.sh 導入後は起きない

### AI アセットに反映すべき内容

- ticket 仕様 Script 処理に create のオプション名・cancel の記録項目・現在地の判定語・commit 拒否時の index 復元を書き足す（0022 の入力）

### 備考

- 境目 B 以降: チケット操作は `bash .claude/skills/20-common-step-ticket/scripts/ticket.sh <sub>`
