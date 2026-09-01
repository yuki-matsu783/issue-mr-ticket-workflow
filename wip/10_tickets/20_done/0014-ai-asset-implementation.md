---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0013"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-shell-script/**", ".claude/hooks/tests/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T03:44:26Z"
completed_at: "2026-09-01T03:55:47Z"
base_sha: "29df29c"
---

# 0014 AI アセット実装 S2-1・S3-1: shell-script の scripts（test-lib / logger / 雛形 / frontmatter / run-tests）と HK-T02

## 目的

テストの道具（`test-lib.sh`）と共通 logger・雛形・`frontmatter.sh`・`run-tests.sh` を仕様どおりに作り、以降のすべての sh がこの上に乗れる状態にする。S1 の 3 データ整合テスト（HK-T02）もここで書く。

## DoD

- [x] `scripts/test-lib.sh` が仕様 OUT ひな形の関数（`assert_eq` / `assert_exit` / `assert_contains` / `assert_not_contains` / `run_cmd` / 一時リポジトリ / `finish`）を持ち、`PASS <ID>` / `FAIL <ID>: ` を出す（根拠: `scripts/test-lib.sh`。SS-T02・TR-T01〜05 が使用）
- [x] `scripts/logger.sh` が仕様「logger.sh」のとおり（`LOGGER_ROOT` 基準・レベル・行フォーマット・`printf` の時刻とコロン挿入・黙殺）で、LG-T01〜05 が通る（根拠: `scripts/logger.sh`、`run-tests.sh --ids` の PASS ID に LG-T01〜05）
- [x] `assets/script.template.sh` / `assets/test.template.sh` が OUT ひな形のとおりで、読み込み行が `<lib>` と失敗時ポリシーを取り、SS-T01〜04 が通る（根拠: `assets/script.template.sh` / `assets/test.template.sh`、PASS ID に SS-T01〜04）
- [x] `scripts/frontmatter.sh` が仕様「frontmatter.sh」の 4 関数を純 bash で実装し、FR-T01〜05 が通る（根拠: `scripts/frontmatter.sh`、PASS ID に FR-T01〜05。`PATH=/nonexistent` の bash 内で実行して外部プロセス不使用を確認）
- [x] `scripts/run-tests.sh` が仕様「run-tests.sh」の 5 手順・TR001〜006 を実装し、TR-T01〜05 が通る（根拠: `scripts/run-tests.sh`、PASS ID に TR-T01〜05）
- [x] `.claude/hooks/tests/test_config_integrity.sh` で HK-T02（tsv × json × work-defaults の type 集合・件数）が通る（根拠: `.claude/hooks/tests/test_config_integrity.sh`、PASS ID に HK-T02）
- [x] すべての sh が `bash -n` を通り、logger を通したログが `logs/sh/` に書かれ stdout に混ざらない（受け入れ条件 6）（根拠: `bash -n` 11 ファイル通過、LG-T03（stdout/stderr 空）、SS-T01（`logs/sh/x.log` に OK 行）、TR-T01（最終行 `OK:`）。shellcheck は不在のため省略）
- [x] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: `grep -nE '\{\{|TODO|TBD' scripts/*.sh scripts/tests/*.sh .claude/hooks/tests/*.sh` 0 件）
- [x] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: 新規 11 ファイルに検索語 5 語のヒットなし）
- [x] `git diff --stat <base_sha>` が許可範囲内（根拠: 変更は `.claude/skills/20-common-step-shell-script/`・`.claude/hooks/tests/`・`wip/` のみ）
- [x] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: レポートの 0014 節（アセット表・テスト結果・検査結果・D-3〜D-6・想定と異なった点））

## 作業内容

- 順: 雛形 2 本（`script.template.sh` / `test.template.sh`）→ test-lib → logger → frontmatter → run-tests → HK-T02。以降の sh は雛形からコピーする。各 sh はテスト先行（失敗確認 → 実装 → 成功）
- run-tests.sh 完成後は `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids` で全件を回し、ID 一覧を仕様の表と突合して作業ログに残す
- Windows 対策（H6）は test-lib と logger に集約する

## 作業ログ

### 現在地

- 済: 雛形 2 本、test-lib、logger、frontmatter、run-tests、テスト 5 本（20 ID 全 PASS）、HK-T02、レポート追記、完了

### うまくいったこと

- 読み込み行をルート解決 → source → ポリシー適用の 1 行に閉じ、4 通りの深さ・git 無し・リポジトリ外を SS-T03/04 で固定できた
- `run-tests.sh` の TR006 検査を自分のチケット（build-test + hook-test 宣言）で通して実行した

### うまくいかなかったこと

- 初回実行で 3 ID が FAIL（フィクスチャの先頭空白 / 雛形の assert 数 / 出どころ名の期待）。いずれもテスト側の誤り

### 仕様からの逸脱

- D-3〜D-6（レポート「仕様からの逸脱」）

### 判断と根拠

- 読み込み行の失敗時 `fatal` は `FATAL:` 行 + 終了 2（台帳に共通の識別子が無いため。D-3）
- テストの外部プロセス不使用の確認は `PATH=/nonexistent` の bash で実行して `command not found` が出ないことで代替
- HK-T02 は 1 ID 複数 assert（D-6）

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `script.template.sh` / `test.template.sh`（自作直後だが run-tests.sh とテスト 5 本はこの型で書いた）

### スコープ外で見つけたこと

- 無し

### AI アセットに反映すべき内容

- shell-script 仕様「読み込み行」に、`fatal` の最終行の形と `HOOK_DENY_ID` を書き足す（0022 の入力）

### 備考

- 無し
