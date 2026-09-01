---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0014"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-commit-push/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0016 AI アセット実装 S2-3: commit.sh / push.sh / exclude-patterns.txt（切り替え境目 A）

## 目的

`commit.sh` / `push.sh` を仕様どおりに作り、このチケットの完了コミット以降のコミット・push を提供コマンドに切り替える。

## DoD

- [ ] `assets/exclude-patterns.txt` が仕様の除外パターン（最小）を持ち、`commit.sh` がそれを読む（根拠: ）
- [ ] `scripts/commit.sh` が仕様「commit.sh」の 1〜6（メッセージ規約 CP002・対象指定 CP001・除外 CP003・差分なし CP004・フック失敗時の出力・SHA と一覧の出力）を実装し、CP-T01〜04 が通る（根拠: ）
- [ ] `scripts/push.sh` が仕様「push.sh」の 1〜4（4 項目の全件検査 CP005・`wip/push-check-skip.md` による項目 1〜3 のスキップと項目 4 の非スキップ・`--set-upstream`・CP006・push 範囲の出力）を実装し、CP-T05〜07 が通る。項目 3 は `*-appendix-*.md` を対の対象外にする（根拠: ）
- [ ] `wip/push-check-skip.md` に項目 3 のスキップ理由（`check-html.sh` 未完成。0021 で遡及作成）が書かれコミットされている（根拠: ）
- [ ] このチケットの完了コミットが `commit.sh` で行われ、最終行 `OK:` を作業ログに残している（境目 A の確認）（根拠: ）
- [ ] プレースホルダ（`{{ }}`・`TODO`・`TBD`）と frontmatter の検査が 0 件（根拠: ）
- [ ] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ）
- [ ] `git diff --stat <base_sha>` が許可範囲内（根拠: ）

## 作業内容

- 順: exclude-patterns → commit.sh → push.sh。テストは一時リポジトリ + bare リモートで実物の git を使う
- 完了前に `wip/push-check-skip.md` を作り、完了コミットを `commit.sh` で行う。止まったら計画書「ロックアウト対策」境目 A の手順

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
