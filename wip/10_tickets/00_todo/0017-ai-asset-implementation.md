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
started_at: ""
completed_at: ""
base_sha: ""
---

# 0017 AI アセット実装 S2-4: ticket.sh と ticket.template.md（切り替え境目 B）

## 目的

`ticket.sh`（create / start / complete / cancel / next）とチケットテンプレートを仕様どおりに作り、以降のチケット操作を提供コマンドに切り替える。

## DoD

- [ ] `assets/ticket.template.md` が仕様 OUT ひな形（frontmatter の全項目・目的・DoD・作業内容・作業ログ 10 見出し・備考。`{{名前}}` 形式）のとおり（根拠: ）
- [ ] `scripts/ticket.sh` の create / start / complete / cancel / next が仕様「Script 処理」の各手順・TK001〜007・`commit.sh` 経由のコミット・拒否時の巻き戻し（移動・作成・記載事項を残さない）を実装している（根拠: ）
- [ ] TICKET-T01〜11 が通る（T10 は `commit.sh` 実物の拒否で確認、T11 はファイル名と `ticket_type` の食い違い）（根拠: ）
- [ ] `next` が `task-types.tsv` を読んでスキル名を解決し、一時リポジトリのテスト（TICKET-T06・T08）で先行未完了の飛ばしまで確認した。実リポジトリでの `ticket.sh next` の実行結果（0018 が返ること）は完了後に作業ログへ追記する境目 B の確認項目で、このチケットの DoD ではない（根拠: ）
- [ ] `complete` の検査を 0012 相当のチケットのコピーに対して一時リポジトリで試し、通ることを確認した（既存チケットの形との整合）（根拠: ）
- [ ] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: ）
- [ ] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ）
- [ ] `git diff --stat <base_sha>` が許可範囲内（根拠: ）
- [ ] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: ）

## 作業内容

- 順: テンプレート → create → next → start → complete → cancel（テスト先行）
- 完了は `ticket.sh complete 0017` で行う（成果物を先に `commit.sh` でコミットしておけば「チケット以外の未コミットなし」の検査は通る）。通らなければ報告して停止し、同チケット内で `ticket.sh` を直す。手作業で移動しない
- 完了後に `ticket.sh next` を実行して 0018 が返ることを確認し、結果を 0018 の作業ログ冒頭に残す
- 以降のチケット（0018〜）は `ticket.sh start/complete` を使う

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
