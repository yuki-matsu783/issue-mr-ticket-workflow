---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0013"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-shell-script/**", ".claude/hooks/tests/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0014 AI アセット実装 S2-1・S3-1: shell-script の scripts（test-lib / logger / 雛形 / frontmatter / run-tests）と HK-T02

## 目的

テストの道具（`test-lib.sh`）と共通 logger・雛形・`frontmatter.sh`・`run-tests.sh` を仕様どおりに作り、以降のすべての sh がこの上に乗れる状態にする。S1 の 3 データ整合テスト（HK-T02）もここで書く。

## DoD

- [ ] `scripts/test-lib.sh` が仕様 OUT ひな形の関数（`assert_eq` / `assert_exit` / `assert_contains` / `assert_not_contains` / `run_cmd` / 一時リポジトリ / `finish`）を持ち、`PASS <ID>` / `FAIL <ID>: ` を出す（根拠: ）
- [ ] `scripts/logger.sh` が仕様「logger.sh」のとおり（`LOGGER_ROOT` 基準・レベル・行フォーマット・`printf` の時刻とコロン挿入・黙殺）で、LG-T01〜05 が通る（根拠: ）
- [ ] `assets/script.template.sh` / `assets/test.template.sh` が OUT ひな形のとおりで、読み込み行が `<lib>` と失敗時ポリシーを取り、SS-T01〜04 が通る（根拠: ）
- [ ] `scripts/frontmatter.sh` が仕様「frontmatter.sh」の 4 関数を純 bash で実装し、FR-T01〜05 が通る（根拠: ）
- [ ] `scripts/run-tests.sh` が仕様「run-tests.sh」の 5 手順・TR001〜006 を実装し、TR-T01〜05 が通る（根拠: ）
- [ ] `.claude/hooks/tests/test_config_integrity.sh` で HK-T02（tsv × json × work-defaults の type 集合・件数）が通る（根拠: ）
- [ ] すべての sh が `bash -n` を通り、logger を通したログが `logs/sh/` に書かれ stdout に混ざらない（受け入れ条件 6）（根拠: ）
- [ ] プレースホルダ（`{{ }}`・`TODO`・`TBD`）と frontmatter の検査が 0 件（根拠: ）
- [ ] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ）
- [ ] `git diff --stat <base_sha>` が許可範囲内（根拠: ）

## 作業内容

- 順: test-lib → logger → 雛形 2 本 → frontmatter → run-tests → HK-T02。各 sh はテスト先行（失敗確認 → 実装 → 成功）
- run-tests.sh 完成後は `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids` で全件を回し、ID 一覧を仕様の表と突合して作業ログに残す
- Windows 対策（H6）は test-lib と logger に集約する

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
