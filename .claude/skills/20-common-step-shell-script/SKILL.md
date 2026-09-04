---
name: 20-common-step-shell-script
description: >
  シェルスクリプト（提供コマンド・フック・テスト）を雛形からコピーして作り、共通 logger を読み込み、
  テストヘルパ test-lib.sh でテストを書き、run-tests.sh で実行して検査（bash -n・shellcheck）を残す共通ステップ。
  frontmatter.sh（チケットの frontmatter 読み取り）と run-tests.sh（テストランナー）の使い方もここが正。
  Use when creating or changing any .sh under .claude/ (scripts/, hooks/, tests/), when writing a test for a
  provided command or hook, when running the test suite ("テストを回して", "run-tests"), or when a script needs
  to read a ticket's frontmatter or write logs.
---

# 20-common-step-shell-script — sh を雛形から作り、logger とテストで守る

sh は白紙から書かず、このスキルの雛形をコピーして作る。ログは共通 logger、テストは `test-lib.sh` + `run-tests.sh`、チケットの frontmatter は `frontmatter.sh` で読む。

- 要件: `.claude/docs/00_requirement/skills/20-common-step-shell-script.md`
- 仕様（正。読み込み行・終了コード・各ライブラリのインターフェース・テスト ID）: `.claude/docs/10_spec/skills/20-common-step-shell-script.md`

## 手順

1. **仕様を読む**: 対象の仕様書のインターフェース・判定順・エラー識別子・テスト観点を確認する。無ければ設計が先として呼び出し元に返す
2. **雛形をコピーする**: `assets/script.template.sh` を置き場所（スキルなら `scripts/`、フックならイベントディレクトリ）へコピーし、`{{名前}}` を埋める。雛形は shebang・`set -euo pipefail`・共通ライブラリの読み込み行・引数解析の骨格・結果出力の型（`OK:` / `<接頭辞><番号>:`）・終了コードの規約（0 / 1 / 2）を含む。フックも同じ雛形から作る（結果出力の型は使わず、フック共通仕様の制御方式に従う）
   - 読み込み行は `__ss_load <lib> <policy>` の 1 行。`<lib>` = `logger` / `frontmatter` / `test-lib`、`<policy>` = `nop` / `fatal` / `deny`。引数だけを変え、行の中身を改変しない。呼び手ごとのポリシーは仕様「読み込み行」の表が正（提供コマンドは `logger nop` + `frontmatter fatal`、拒否側フックは `frontmatter deny`（先に `HOOK_DENY_ID=WFx09` を設定）、テストは `test-lib fatal`）
3. **実装する**: bash 規約（`rules/` の bash-script）と logger ルール（`.claude/rules/logger.md`）に従う。ログは `log_debug` / `log_info` / `log_warn` / `log_error`（ファイルにのみ書かれ、stdout / stderr には出ない）。frontmatter は `fm_get` / `fm_list` / `fm_has` で読み、自前の解析を持たない。Windows（Git Bash）対策は `test-lib.sh` と共通ライブラリに集約されているので個別に書かない
4. **テストを書く**: `assets/test.template.sh` から `scripts/tests/test_<名前>.sh`（フックは `<イベントディレクトリ>/tests/test_<名前>.sh`）を作り、仕様のテスト ID ごとにケースを書く。assert の第 1 引数にテスト ID を渡す（`assert_eq` / `assert_exit` / `assert_contains` / `assert_not_contains`。直前の `run_cmd` の `R_EXIT` / `R_OUT` / `R_ERR` に対して）。一時リポジトリは `make_tmp_repo`（`TMP_REPO`）、git 無しなら `make_tmp_dir`（`TMP_DIR`）、PATH を絞るなら `make_restricted_path`（`RESTRICTED_PATH`）、fork ゼロ・呼び出し回数の約束は `make_counting_path` + `counted_calls`（`COUNTING_PATH` / `COUNTING_LOG`）で数える、フック入力 JSON は `hook_payload <event> <tool> [--session <id>] key=value...`（`session_id` の既定は `testsession`）、jq の出力は `tl_jq`（CR 除去）。テストは `set -uo pipefail`（`-e` なし）で書き、`finish` で締める。テストは失敗を先に確認してから実装する。書き方は仕様「テストの書き方（規約）」に従う（表は全要素を踏む / 負のケースに正の期待値 / 回数は数える / 最終行と終了コードは exact / 秘密の実例を置かない / 一時リポジトリで実行）
   - **1 本を `run-tests.sh` の上限（既定 120 秒）に収める**。**ケースごとに git のコミットをしない**（1 コミットが数百ミリ秒かかるので、ケースの数だけ積むと 1 本で上限に届く。固定の状態は `make_tmp_repo` の中で 1 回だけ作り、ケースごとの差分は作業ツリーの書き換えで用意する）。**1 回の実行で外部プロセスを何十回も起動しない**（`jq` / `git` / `grep` をループで回すと Windows では起動コストが効く。1 回でまとめて取る形に直す）
   - **負のコントロールは環境が変わっても落ちるか確かめる**。タイムゾーン・ロケール・改行コードを変えても同じように失敗するかを見る。実行環境の既定にたまたま依存していると、環境が変わった瞬間に「失敗するはずのケースが通る」形で壊れ、しかもテストは緑のままになる。時刻を含む比較は両側を固定値で与える
   - **他の提供コマンドの出力を `jq` に渡す前に JSON かどうかを検査する**。提供コマンドは失敗すると最終行に `<接頭辞><番号>:` を出すので、そのまま渡すと `parse error` になって本当の原因が消える。`jq -e . >/dev/null` で受けてから使い、JSON でなければ受け取った文字列をエラーメッセージに載せる
   - **複数の値を 1 回の `jq` で受けるときは 1 行 1 値にする**。`@tsv` を `IFS` 付きの `read` で受けると空のフィールドが畳まれて値が 1 つずれる。`| .[]` で 1 行 1 値にして `mapfile` で配列に受ける
5. **実行する**: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids`（`--filter '<glob>'` で絞る（glob はルート相対パスに当たる。例 `'*check_html*'`。ファイル名だけの `test_x*` は 0 本 = TR001）、`--timeout <秒>`）。作業中チケットの `allow.ops` に `build-test`（`.claude/hooks/**` のテストを含むなら `hook-test` も）が無いと TR006 で止まる — 計画で宣言してから実行する。結果（`OK: N 本 / M 件` と PASS ID の一覧）を作業ログに残し、ID を仕様の「テスト観点」表と突合する
6. **検査する**: `bash -n <file>` を全 sh に行う。`shellcheck` があれば静的検査、無ければ省略の事実を作業ログに書く
7. 既存 sh の変更では 2 を行わず、既存の構成に合わせて差分を小さくする

## 参照

- 雛形: `assets/script.template.sh`（スクリプト）、`assets/test.template.sh`（テスト）
- ライブラリ（`source` 専用。直接実行しても何もしない）: `scripts/logger.sh`、`scripts/frontmatter.sh`、`scripts/test-lib.sh`
- 提供コマンド: `scripts/run-tests.sh`（テストランナー。エラー識別子 TR001〜006）
- bash 規約の中身: `rules/`（bash-script ルール）/ ログの規約: `.claude/rules/logger.md` / `logs/` の位置づけ: DDR `i0001-28`
- 呼び出し元の手順: `20-common-step-ai-asset-creator`

## エラー時の対処

| 状況 | 対処 |
|------|------|
| `FATAL: 共通ライブラリ … を読み込めない` | リポジトリルートを解決できていない。`.claude/skills/20-common-step-shell-script/scripts/` が存在するリポジトリ内で、ルート相対のパスで起動しているか確認する |
| `TR006:` 宣言不足 | 作業中チケットの `allow.ops` に `build-test` / `hook-test` が無い。計画（実装計画書とチケット）で宣言する。作業中チケットの frontmatter を手で書き換えない |
| `TR002:` FAIL がある | 列挙されたファイルと ID を直す。`bash <test>` を直接実行して詳細を見る |
| `TR003:` タイムアウト | 無限ループか外部待ち。`--timeout` を伸ばす前にテストを直す |
| `TR001:` 対象 0 本 | 置き場（`.claude/hooks/**/tests/test_*.sh`・`.claude/skills/*/scripts/tests/test_*.sh`）と `--filter` を確認する |
| `TR004:` / `TR005:`（終了 2） | 引数の誤り（`usage` を見る）/ `timeout`・`jq` の不在。呼び方か環境を直す |
| ログが書かれない | `logs/sh/<出どころ>.log`（出どころは `$0` の basename か `LOGGER_NAME`）。`LOG_LEVEL=DEBUG` で DEBUG も出る。書けなくても本体は止まらない設計 |
