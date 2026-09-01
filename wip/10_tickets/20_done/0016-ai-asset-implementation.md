---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0014"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-commit-push/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T03:56:15Z"
completed_at: "2026-09-01T04:02:39Z"
base_sha: "21d5bec"
---

# 0016 AI アセット実装 S2-3: commit.sh / push.sh / exclude-patterns.txt（切り替え境目 A）

## 目的

`commit.sh` / `push.sh` を仕様どおりに作り、このチケットの完了コミット以降のコミット・push を提供コマンドに切り替える。

## DoD

- [x] `assets/exclude-patterns.txt` が仕様の除外パターン（最小）を持ち、`commit.sh` がそれを読む（根拠: `assets/exclude-patterns.txt`、CP-T03 で `.env` と `*token*` の除外を確認。追跡済みファイルへの誤爆は `wip/tmp/.gitkeep` のみ）
- [x] `scripts/commit.sh` が仕様「commit.sh」の 1〜6（メッセージ規約 CP002・対象指定 CP001・除外 CP003・差分なし CP004・フック失敗時の出力・SHA と一覧の出力）を実装し、CP-T01〜04 が通る（根拠: `scripts/commit.sh`、`run-tests.sh --ids` の PASS ID に CP-T01〜04）
- [x] `scripts/push.sh` が仕様「push.sh」の 1〜4（4 項目の全件検査 CP005・`wip/push-check-skip.md` による項目 1〜3 のスキップと項目 4 の非スキップ・`--set-upstream`・CP006・push 範囲の出力）を実装し、CP-T05〜07 が通る。項目 3 は `*-appendix-*.md` を対の対象外にする（根拠: `scripts/push.sh`、PASS ID に CP-T05〜07。CP-T05 で付録が対の対象外、CP-T06 で項目 4 がスキップ不可）
- [x] `wip/push-check-skip.md` に項目 3 のスキップ理由（`check-html.sh` 未完成。0021 で遡及作成）が書かれコミットされている（根拠: `wip/push-check-skip.md`、このチケットの成果物コミットに含む）
- [x] 完了直前の成果物のコミットを `commit.sh` で行い、最終行 `OK:` と SHA を作業ログに残した（境目 A の確認。以降のコミットは `commit.sh`、push は `push.sh`）（根拠: 成果物コミットの最終行「OK: 7 ファイルをコミットした（7db4bfc）。除外: なし」。チケット完了コミットも commit.sh、push は push.sh）
- [x] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: `grep -nE '\{\{|TODO|TBD'` 5 ファイルで 0 件）
- [x] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: 新規 5 ファイルに検索語 5 語のヒットなし）
- [x] `git diff --stat <base_sha>` が許可範囲内（根拠: 変更は `.claude/skills/20-common-step-commit-push/`・`wip/` のみ）
- [x] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: レポートの 0016 節（アセット表・テスト結果・検査結果・D-7〜D-9））

## 作業内容

- 順: exclude-patterns → commit.sh → push.sh。テストは一時リポジトリ + bare リモートで実物の git を使う
- 完了前に `wip/push-check-skip.md` を作り、成果物のコミットを `commit.sh` で行う。止まったら計画書「ロックアウト対策」境目 A の手順（報告して停止。`git commit` に戻さない）

## 作業ログ

### 現在地

- 済: exclude-patterns、commit.sh、push.sh、テスト CP-T01〜07（全 PASS）、push-check-skip.md、境目 A の確認（成果物コミットを commit.sh で実施）、レポート追記、完了

### うまくいったこと

- `git commit -- <paths>` で「指定パスだけをコミット」を実現し、既にステージされていた無関係な変更を巻き込まない
- 除外パターンを追跡済み全ファイルに当てて誤爆を先に確認した（`wip/tmp/.gitkeep` のみ）

### うまくいかなかったこと

- CP-T05 のテストの検査条件を 2 箇所誤った（`appendix` の語の含有、リモートのコミット判定）。実装側の修正はなし

### 仕様からの逸脱

- D-7〜D-9（レポート「仕様からの逸脱」）

### 判断と根拠

- フッター検出は「Claude」「Anthropic」の語そのものを対象にしない: このリポジトリのコミット件名に「Claude Code」が普通に現れる。フッター形（`Co-Authored-By:` 等）と機械的なモデル名（`claude-opus-4` 等）に限定
- `git add` 失敗は CP001・終了 2（引数の誤り側）
- push 前チェックの項目 4 は `logs/merge-state.json` の `state == ready` を「draft 解除済み」の判定に使う（`10-task-overall-summary` 仕様の状態遷移）

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `script.template.sh` / `test.template.sh`（commit.sh・push.sh・テスト 2 本の骨格）
- `run-tests.sh`（TR006 の宣言検査を通して 7 本を実行）

### スコープ外で見つけたこと

- 無し

### AI アセットに反映すべき内容

- commit-push 仕様に CP007（コミット失敗）とスキップ記録の行の形を書き足す（0022 の入力）

### 備考

- 境目 A 以降: コミットは `bash .claude/skills/20-common-step-commit-push/scripts/commit.sh`、push は `bash .claude/skills/20-common-step-commit-push/scripts/push.sh`
