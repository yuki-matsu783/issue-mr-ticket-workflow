---
type: report
title: 調査 C 付録 — テストの実行方式と HTML テンプレートの土台（生データ）
description: チケット 0004 の Q2（テストの実行方式）と Q5（HTML テンプレートの土台）の調査結果の生データ。参考実装のテスト構造と Git Bash での実行結果、推奨案、HTML テンプレート一覧と節構成、data-required 案、削るべき固有記述。要約は 0003-investigation.md
tags: [report, investigation, issue-6, appendix]
keywords: [テスト, bash, bats, assert, ランナー, Git Bash, WSL, HTML テンプレート, reports-clean.template.html, plans.template.html, data-required, check-html.sh, RV006]
---

# 調査 C: テストの実行方式（Q2）と HTML テンプレートの土台（Q5）

調査日: 2026-09-01。環境: Windows 10 Pro / Git Bash（MSYS2 bash 5.2.12）。比較用に WSL Ubuntu（bash 5.0.17）でも一部を実行した。
パスはリポジトリルート（`c:\Users\taniyama\Desktop\git\issue-mr-ticket-workflow`）からの相対。`参考/` は `参考ディレクトリ/` の略。

---

## Q2 テストの実行方式

### 答え（要約）

- 参考実装 2 つとも **bats 等のフレームワークを使わない素の bash** で、ファイルごとに `assert_eq` / `check` を自前定義し、最終行に集計（`passed=N failures=N` または `結果: PASS=N FAIL=N`）を出して失敗があれば非 0 で終わる。全テストを回すランナーは**どちらにも無い**（ドキュメント上は `for t in .claude/scripts/test/test_*.sh; do bash "$t"; done` / `bash .claude/hooks/tests/*.sh` と書かれているだけ。CI 定義も無い）。
- Git Bash で実行した結果: agent-workflow 6 本中 4 本が全通過、2 本は **Windows 起因**（symlink で組んだ gh 不在 PATH が MSYS で動かない）で全滅。MR-driven 26 本中 19 本が全通過、残りは性能閾値（Windows の fork 遅延）・日本語パス × native jq・symlink PATH・`.git` 不在・Python 不在・タイムアウト。**同じ性能テストは WSL では 2.3 秒で全通過**（Windows では 13 秒で閾値超過）。
- 環境: bats **無し**、shellcheck **無し**、bash 5.2.12(msys)、jq 1.6（Windows native）、perl 5.36(msys)。
- 推奨: **素の bash を踏襲**し、共通ヘルパ（`assert_*` と `run_*`）を `20-common-step-shell-script/scripts/test-lib.sh` のような 1 か所に置いて `source` させ、2 つの置き場を glob する**ランナー sh を 1 本**足す。bats は導入しない。

### 1. テストの構造

#### MR-driven-workflow（`参考/MR-driven-workflow/.claude/scripts/test/test_*.sh`、26 本・計 11,935 行）

規約の正は `参考/MR-driven-workflow/.claude/rules/shell-script-style.md` の「テスト」節。要点:

| 観点 | 書き方 | 根拠 |
|---|---|---|
| 先頭 | `set -euo pipefail`、`script_dir` → `repo_root` を `cd ../../..` で解決 | `test_command_position.sh:8-12` |
| 対象の読み込み | 対象スクリプトを `source` して純粋関数を直接呼ぶ。対象側は本体を `main` にまとめ `if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main; fi` のガードを置く（無いと source 時に stdin 待ちでハング） | `shell-script-style.md`「テスト」、`test_block_direct_git_commit.sh:19-23` |
| assert | `assert_eq name expected actual`。不一致なら `FAIL: name` と `expected:` / `actual:` を 3 行で出し `failures` を加算 | `test_command_position.sh:20-30` |
| 終了コードの検査 | `set -e` 配下ではコマンド置換で `$?` が取れないため、`if func; then printf hit; else printf miss; fi` のラッパーで文字列化してから `assert_eq` | `test_command_position.sh:32-40`、`test_check_base_sync.sh:36-37` |
| 複数戻り値 | 関数は `REPLY_*` グローバルへ返す（`run_with_stub_jq_to_reply` → `REPLY_EXIT` / `REPLY_JQ_CALLED`） | `test_block_direct_git_commit.sh:86-104` |
| フックへの stdin JSON | `jq -nc --arg tn "$1" --arg cmd "$2" '{tool_name:$tn, tool_input:{command:$cmd}}'` でペイロードを組み、`printf '%s' "$payload" \| bash "$hook"` で子プロセスとして起動 | `test_block_direct_git_commit.sh:106-116`、`test_post_issue_create_notice.sh:170,212` |
| 外部コマンドのスタブ | `mktemp -d` に偽 `jq` を置き `PATH="$stub_dir:$PATH"` で前置。「呼ばれたか」はマーカーファイルで判定（時間計測ではなく呼び出し有無） | `test_block_direct_git_commit.sh:72-84` |
| 一時 git リポジトリ | `make_repo` 関数: `mktemp -d` → `git -C "$dir" init -q -b main` → user.name/email 設定 → コミット。`trap 'rm -rf …' EXIT` で後始末 | `test_check_base_sync.sh:136-164`、`test_cleanup_task.sh:192` |
| フィクスチャ | `fixtures/<対象名>/*.fixture` と `*.expected`（ゴールデン比較）。使っているのは `test_sync_gemini_assets.sh` のみ | `scripts/test/fixtures/sync-gemini-assets/` |
| 負のコントロール | 「出力なし＝合格」の検査には意図的に壊したコピーで検出できることを別ケースで確認 | `test_report_templates.sh` T4b・T5 |
| 集計と終了 | `echo "passed=$passed failures=$failures"; [[ "$failures" -eq 0 ]]` | `test_command_position.sh` 末尾 |
| テスト ID | **正式な ID 体系は無い**。`assert_eq` の第 1 引数が日本語の説明文。ファイルによっては `# --- T1: … ---` のコメント区切り（`test_report_templates.sh` T1〜T7、`test_sync_gemini_assets.sh` T9 など）。仕様書側の ID と機械的に対応付ける仕組みは無い | `grep -hoE "^# --- T[0-9]+"` の集計 |
| perl 部分 | `hooks/otel/test/*.pl` は `Test::More` の TAP 出力（`ok N - 説明` … `1..N`）。`perl <file>` で単独実行、`prove` の言及は無し。規約で「perl 常駐プロセスのテストは TAP でよく、置き場はそのプロセス配下」と明記 | `shell-script-style.md`「テスト」、`hooks/otel/test/test_otel_registry.pl:1-10` |
| ランナー | 無し。`resolve-conflict/SKILL.md:309` に `for t in .claude/scripts/test/test_*.sh; do bash "$t"; done` と書かれているのみ。`.github/` には issue/PR テンプレートしか無い | `find . -path '*/.github/*'` |
| Windows 配慮 | 32 本中多数が `tr -d '\r'`（native jq の CR 付与対策）を含む。CR 検査に `grep -c $'\r'` を使わない（空パターン化する）等の注意が規約にある | `shell-script-style.md`「テスト」 |

#### agent-workflow（`参考/agent-workflow/.claude/hooks/tests/test-*.sh`、6 本）

| 観点 | 書き方 | 根拠 |
|---|---|---|
| 先頭 | `set -uo pipefail`（`-e` は付けない。失敗を数えて続行するため） | `test-workflow-entry.sh:12` |
| 対象の差し替え | `ENTRY="${WF_ENTRY_SCRIPT:-…/workflow-entry.sh}"` で環境変数から対象を差し替え可能（新版を本番に置く前に検証する用途） | `test-workflow-entry.sh:15-16` |
| 一時プロジェクト | `TMP=$(mktemp -d)` に `.claude/hooks` と `wip/10_tickets/{00_todo,10_doing,20_done}` を作り、`CLAUDE_PROJECT_DIR` に渡す。**Windows では `cygpath -m` で `C:/…` 形式に変換**して渡す | `test-workflow-entry.sh:19-30` |
| stdin JSON | `prompt_json` / `skill_json` / `tool_json` を `jq -n --arg …` で定義。プロンプトが `/` で始まると MSYS がパス変換するため `MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"` を前置 | `test-workflow-entry.sh:35-38` |
| 実行 | `run <mode> <json>`: `bash "$ENTRY" "$1" 2>"$ERRF" <<<"$2"` を環境変数（`CLAUDE_PROJECT_DIR`, `WORKFLOW_ENFORCE`, `WORKFLOW_ENTRY_ENFORCE`）付きで実行し `R_EXIT` / `R_OUT` / `R_ERR` に格納 | `test-workflow-entry.sh:41-46` |
| check | `check <ID> <期待exit> [含む文字列] [含まない文字列]`。stdout+stderr を連結して `grep -q` で検査。**`PASS <ID>` / `FAIL <ID>: 理由` を 1 行ずつ出力** | `test-workflow-entry.sh:48-64` |
| テスト ID | `TE001`〜`TE017`（枝番 `TE002b` など）。**仕様書 `10_spec/ワークフロー振り分け実施済み判定.md:150` の「テストシナリオ」表（ID / シナリオ / 期待）と 1:1**。他ファイルも `TG0xx`（guard）、`TC0xx`（ticket）、`MF0x` / `TF0x`（fallback）で、仕様書の表を ID で引ける | 同ファイル、`10_spec/skill-work-ticket-driven.md:992-993` |
| 状態の直接検査 | 状態ファイルの中身を `grep -q '^prompt_seq=1$'` で直接見る | `test-workflow-entry.sh:71` |
| gh 不在の再現 | 必要なコマンドだけを `ln -sf` で `TMP/.bin` に集めて `PATH` を差し替える（**Windows で壊れる。後述**） | `test-merge-prep-fallback.sh:27-34` |
| 集計 | `echo "結果: PASS=${PASS} FAIL=${FAIL}"; [ "${FAIL}" -eq 0 ]` | 末尾 |
| ランナー | 無し。`work-ai-asset-implementation-exec/SKILL.md:57` に「`bash .claude/hooks/tests/<name>.sh`。リダイレクトやパイプは付けない」（フックのコマンド制限のため） | 同ファイル |

#### 2 つの違い（新機構への示唆）

- ID 付き `check`（agent-workflow）のほうが仕様書との対応付けが機械的（`PASS TE012` を grep すれば仕様表とのカバレッジが取れる）。MR-driven は説明文が豊かだが ID が無い。
- MR-driven の `source` + 純粋関数テスト、スタブ PATH、`REPLY_*`、負のコントロールは新機構の仕様（RV007 等）と相性がよい。
- MR-driven は `set -e` で書き、終了コードを `if` で受ける流儀。agent-workflow は `-e` 無しで `$?` を直接読む。**どちらかに統一する必要がある**（ヘルパを共通化するなら後者のほうが `run` 関数を書きやすい）。

### 2. 実行結果（Git Bash）

コマンドはすべてリポジトリルートの `参考ディレクトリ/` 配下で `bash <path>` として実行。

| テスト | 結果 | 所要 | 失敗の原因 / Windows 起因か |
|---|---|---|---|
| `bash MR-driven-workflow/.claude/scripts/test/test_command_position.sh` | `passed=117 failures=1`（exit 1） | 13.2 s（sys 7 s） | `FAIL: 大きなヒアドキュメントの判定が遅すぎる（8251ms - 54ms / 10回）`。3 回再実行しても 7.0〜8.3 秒で再現。閾値は 2000 ms。**同じファイルを WSL Ubuntu で実行すると `passed=118 failures=0`、real 2.3 s** → **Windows（MSYS の fork / サブシェル遅延）起因**。ロジックの不具合ではない |
| `bash agent-workflow/.claude/hooks/tests/test-workflow-entry.sh` | `結果: PASS=45 FAIL=0`（exit 0） | 28.6 s | 通過。cygpath / MSYS_NO_PATHCONV の配慮が効いている |
| `test_report_templates.sh` | `passed=8 failures=0` | — | 通過（perl・md5sum・sed のみ） |
| `hooks/otel/test/test_otel_registry.pl` / `test_session_id_finder.pl` | `1..12` / `1..7` 全 ok | — | 通過（msys perl の Test::More） |
| agent-workflow 残り 4 本 | `test-json-syntax` PASS=24、`test-work-boundary` PASS=13、`test-workflow-guard` PASS=19、**`test-merge-prep-fallback` PASS=0 FAIL=11、`test-work-boundary-fallback` PASS=0 FAIL=13** | — | fallback 2 本は `ln: failed to create symbolic link '…/.bin/printf'`（`command -v printf` が組込みなので絶対パスが返らない）と `…/.bin/bash: error while loading shared libraries`（MSYS の bash.exe は同ディレクトリの `msys-2.0.dll` を要求するため symlink 先から起動できない）→ **Windows 起因** |
| MR-driven 残り 25 本（`timeout 90` 付き） | 19 本全通過（vcs_provider 249、usage_tracking 120、update_handoff_progress 118、search_frontmatter 114、push_checklist 97、harvest_from_projects 91、cleanup_task 79、block_unchecked_push 56、check_base_sync 55、generate_ddr_list 52、check_doc_references 49、post_issue_create_notice 38、select_adversarial_findings 34、extract_frontmatter 32、check_base_conflicts 31、post_push_next_checklist 30、collect_review_points 27、adversarial_review_count 22、report_templates 8） | — | — |
| 〃 失敗分 | `test_session_start.sh`: `jq.exe: Could not open …/参考ディレクト�` | | **Windows 起因**（native jq に日本語を含むパスを渡すと開けない。`参考ディレクトリ/` という置き場所の問題） |
| | `test_sync_gemini_assets.sh`: `ln: … /bin/printf` → T9 ゴールデン比較 FAIL | | **Windows 起因**（上と同じ symlink PATH 方式） |
| | `test_check_dist_coverage.sh`: `cp: cannot stat '.git/index'` | | 環境起因（`参考ディレクトリ/` は `.git` を持たないコピー）。Windows 無関係 |
| | `test_json_to_pptx.sh`: `Python` のみ出力し exit 49 | | 環境起因（`python3` が Windows Store のスタブ、python-pptx 無し） |
| | `test_install_to_project.sh`: 90 秒でタイムアウト | | 未確認（推測: 多数の cp / git 実行が MSYS で遅い） |
| | `test_block_direct_git_commit.sh`: `passed=26 failures=1`（`com\<改行>mit … 精密判定まで到達しブロックされる`） | | **未確認**（推測: native jq の CR 付与か JSON エスケープの差） |

補足: WSL では `jq` が入っていなかったため、WSL 側で走らせたのは jq 不要な `test_command_position.sh` のみ。

### 3. ツールの有無

```
$ command -v bats            → bats: not found（where.exe bats も無し）
$ bash --version | head -1   → GNU bash, version 5.2.12(1)-release (x86_64-pc-msys)
$ jq --version               → jq-1.6（C:\Program Files\jq\jq.exe、Windows native）
$ shellcheck --version       → command not found（where.exe shellcheck も無し）
$ perl -v | head -2          → This is perl 5, version 36, subversion 0 (v5.36.0) built for x86_64-msys-thread-multi
（参考）git 2.39.2.windows.1、timeout / mktemp / realpath / date +%s%3N あり、WSL: Ubuntu（bash 5.0.17、jq 無し）
```

### 4. 新機構での推奨案

**推奨: 素の bash を踏襲（フレームワーク非導入）+ 共通ヘルパ 1 ファイル + ランナー 1 本。**

判断材料:

| 材料 | 素の bash 踏襲 | bats 導入 |
|---|---|---|
| Windows Git Bash / Linux CI 両対応 | bash 5 と jq があれば動く。参考実装の 2 つとも実績あり（Windows で落ちたのは symlink PATH・日本語パス・性能閾値で、方式の問題ではない） | bats-core は MSYS でも動くが**未インストール**（`git clone` か npm で導入が要る）。MSYS ではテストごとの fork が多く遅い（推測。bats は 1 ケースごとにサブシェルを立てる） |
| 依存の追加 | 無し。要件書（`20-common-step-shell-script.md`）が「静的検査ツールが無ければ省略を記録」としているのと同じ思想で、テスト実行に外部ツールを要求しない | bats-core 本体 + bats-support / bats-assert が実質必須。導入先プロジェクト（`.claude/` を配布する前提）にも要求することになる |
| 既存の仕様との整合 | 仕様 `10_spec/skills/20-common-step-shell-script.md`「OUT ひな形」が **`assets/test.template.sh`（`assert_eq` / `assert_exit` の最小ヘルパ・一時ディレクトリ・集計と非 0 終了）** を既に定めている → そのまま | `.bats` 拡張子・`@test` 記法になり、仕様の雛形・フックの許可 glob（後述）を書き換える必要がある |
| テスト ID の対応付け | agent-workflow 方式を採る: `check <ID> …` / `assert_eq <ID> …` の**第 1 引数を仕様書の ID**（`TICKET-T01`, `HK-T02`, `CP-T03`, `RV-T04`）にし、`PASS RV-T01` / `FAIL RV-T01: …` を 1 行で出す。1 つの ID に複数ケースがあるときは `RV-T02a` `RV-T02b` の枝番（agent-workflow の `TE002b` と同じ）。ランナーが出力から `^(PASS|FAIL) ([A-Z]+-T[0-9]+)` を集めれば、仕様書の「テスト観点」表とのカバレッジ突合が grep だけでできる | `@test "RV-T01 正常系: …"` と名前に ID を書けば TAP 出力に載る。同等だが `--filter` の恩恵がある程度 |
| 2 置き場（`.claude/hooks/<NN-Event>/tests/` と `.claude/skills/*/scripts/tests/`） | 仕様で既に決まっている（`10_spec/フック共通仕様.md:15`、`10_spec/skills/20-common-step-shell-script.md:34`）。フックの許可分類 `hook-test` も `.claude/hooks/**/tests/*.sh`・`.claude/skills/*/scripts/tests/*.sh` の 2 glob で定義済み（`フック共通仕様.md:188`）。ランナーは同じ 2 glob を回すだけ | `.bats` を許可 glob に足す変更が要る |
| 全テストを 1 コマンドで | **無いので新設する**: 例 `.claude/skills/20-common-step-shell-script/scripts/run-tests.sh`。2 glob を列挙 → 各 `test_*.sh` を `timeout` 付きで実行 → ファイルごとの最終行と exit を表にして総合 exit を返す。`--filter <glob>` と `--ids`（PASS/FAIL 行から ID を抽出して一覧）を付けると仕様突合に使える | `bats -r .claude` で一発。ここだけは bats が楽 |
| 出力形式 | 参考実装と同じ「1 行 1 ケース + 集計行 + 非 0 終了」。フックが `bash <test>` をそのまま許可する（パイプ禁止）前提でも読める | TAP。人間には少し読みにくいが CI 連携は容易 |

推奨の具体形（設計への入力。推測を含む）:

1. **共通ヘルパ** `.claude/skills/20-common-step-shell-script/scripts/test-lib.sh`（仮）を 1 つ置き、`assert_eq ID expected actual`、`assert_exit ID expected_code`、`assert_contains ID needle` / `assert_not_contains`、`run_cmd …`（`R_EXIT` / `R_OUT` / `R_ERR` に格納。agent-workflow の `run` 相当）、`make_tmp_repo`（`mktemp -d` + `git init -q -b main` + user 設定、`trap` 登録）、`hook_payload`（`jq -nc --arg` で PreToolUse / PostToolUse / UserPromptSubmit の JSON を組む）、`finish`（集計行と exit）を提供する。`test.template.sh` はこれを `source` する 20 行程度にする。参考実装のようにファイルごとに `assert_eq` を複製しない（DRY）。
2. **`set -uo pipefail`（`-e` 無し）** で統一し、終了コードは `run_cmd` が取る（MR-driven の `if` ラッパーは `-e` を使うための回避策で、ヘルパ化するなら不要）。
3. **Windows で確実に動く書き方をヘルパ側で吸収**: `CLAUDE_PROJECT_DIR` は `cygpath -m` があれば変換、`/` 始まりの文字列を jq に渡すときは `MSYS_NO_PATHCONV=1`、jq 出力は `tr -d '\r'`、**PATH を絞るときは symlink ではなくラッパースクリプト（`exec /usr/bin/git "$@"`）を生成**する、性能閾値は「空関数との差」ではなく**環境変数で無効化できる**か WSL/CI 限定にする、日本語を含む一時パスを避ける（`mktemp -d` は `/tmp` なので通常問題ない）。
4. **ランナー** `run-tests.sh` を上記 2 glob で回し、`--filter` と ID 一覧を持たせる。CI（GitHub Actions / GitLab CI）ではこの 1 コマンドを叩くだけにする。
5. perl を使う場合のみ `Test::More`（TAP）を許容する例外を規約に残す（参考実装と同じ）。今のところ新機構の仕様に perl 実装は無いので当面不要。

bats を選ぶべき条件（参考）: テストが数百ファイル規模になり `--filter` / 並列実行 / TAP 連携が欲しくなったとき。現時点の仕様の規模（テスト観点は 20 接頭辞・数十 ID）では過剰。

### 答えが出なかった点

- `test_block_direct_git_commit.sh` の 1 件失敗（`com\<改行>mit`）の根本原因は未調査（推測: Windows native jq のエスケープ差）。
- `test_install_to_project.sh` のタイムアウトが単なる遅さか無限待ちかは未確認。
- bats を MSYS 上で実際に動かした計測はしていない（未インストールのため）。「遅い」は推測。

---

## Q5 HTML テンプレートの土台

### 答え（要約）

- 参考実装で HTML テンプレートを持つのは **MR-driven-workflow だけ**（agent-workflow は md テンプレートのみ）。候補は `issue-mr-flow/assets/` の **`reports-clean.template.html`（レポート用の土台。DDR `i0001-05` が名指し）** と **`plans.template.html`（計画書用の土台）**。`html-slides` と `canvas-report` は script / CDN 依存があり対象外。
- 参考実装の機械検査は (a) 成果物向けの手順 6 項目（`references/deliverables.md`、手で叩く grep 群）と (b) テンプレート本体向けの `test_report_templates.sh`（T1〜T7、4 本の `<style>` 以外の同一性など）。新仕様の RV001〜RV007 は (a) を 1 スクリプト化し、**RV006（`data-required` の導出）が新規**、RV004（リンク破断）と RV007（空振りガード）は (a) の検査 2 と「空振りガード」に相当する。
- `data-required` を付ける節（レポート）: 対象 issue / MR（サイドバーのメタ）、サマリ（`#overview`。重点レビュー依頼の 3 枠を含む）、確かめられなかったこと（`#unverified`）、実施した内容と結果（`#findings`）、設計への反映（`#next`）。参考実装で任意の「想定と異なった点」（`#surprises`）「残課題」（`#todo`）は、新機構の実施タスク 6 種すべてがレポートに含めると定めているので**必須に格上げが妥当**（判断点）。
- 削るべき参考実装固有の記述: `wip/reports` / `wip/plans` のパス、flow-id（`2-6` `5-4` 等）、`issue-mr-flow` / `deliverables.md` / `docs-workflow.md` / `REVIEW-POINTS.md` / `canvas-report` への参照、issue #54 / #186 / #203 の経緯、「統括レポート（5-4）では…」の読み替え、冒頭コメント内の検査手順 6 項目（`check-html.sh` 参照に置換）、計画書テンプレートの「全体作業計画のみ必須」節（フェーズ2〈調査〉/ フェーズ4〈反映〉。全体計画書は HTML を持たない）。

### 1. 参考実装の HTML テンプレート一覧

`find 参考ディレクトリ -name '*.html'` の結果は 16 件。うち `.gemini/skills/` 配下 8 件は `.claude/skills/` の**同期コピー**（`sync-gemini-assets.sh` の出力）なので実体は 8 件。agent-workflow には HTML が無い（`*.template.md` のみ。`work-ticket-driven/assets/report.template.md` / `plan.template.md`）。

| パス（`参考/MR-driven-workflow/.claude/skills/` 以下） | 用途 | 行数 / バイト | 外部参照 | インライン CSS / JS | プレースホルダ |
|---|---|---|---|---|---|
| `issue-mr-flow/assets/reports-clean.template.html` | レポート HTML ビュー（既定デザイン「クリーン・ライト」。ライト / ダーク両対応） | 565 / 34,694 | **無し**（`grep -nE "(src\|href)=['\"]?(https?:)?//"` はコメント中の検査コマンド例 2 行に当たるだけ。実参照 0） | `<style>` 1 つ（169 行、CSS 変数 20 個、`prefers-color-scheme` 1 箇所）。`<script>` 0、`style=` 属性 0 | `<!-- ここに書く: 説明 -->` 形式 27 件 + 各節直前の `<!-- [必須] … -->` / `<!-- [任意] … -->` コメント |
| `issue-mr-flow/assets/reports-{neobrutal,mono,paper}.template.html` | 同上の別デザイン 3 本。**`<style>` 以外はバイト単位で clean と同一**（`test_report_templates.sh` T3 で固定） | 各 ≒565 行 | 無し | neobrutal / paper は `prefers-color-scheme` 無し（ライト単一）。paper は印刷向け | 同上 |
| `issue-mr-flow/assets/reports.template.html` | 旧レポートテンプレート（移行期のみ。`deliverables.md:65`） | 439 / 26,771 | 無し | `<style>` 1 つ、ヘッダ帯 `header.band` レイアウト | 同形式 25 件 |
| `issue-mr-flow/assets/plans.template.html` | 計画書 HTML ビュー（個別計画既定。全体作業計画にも読み替えで使う） | 334 / 18,123 | 無し | `<style>` 1 つ（93 行）、`prefers-color-scheme` 1 箇所、`<script>` 0 | 同形式 21 件 + `[必須]` / `[任意]` / `[全体作業計画のみ必須]` |
| `html-slides/assets/slides.template.html` | スライド（`data-type` 付き `section.slide` 8 種の見本） | 339 / 14,919 | 無し | `<style>` 1 + **`<script>` 1（キー操作）** | 同形式 26 件 |
| `canvas-report/assets/canvas-report.html` | 依存グラフを描く対話キャンバス | 1,542 / 71,554 | **`<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js">`**（31 行目） | `<style>` 1 + `<script>` 4、`style=` 属性 1 | 無し（テンプレートではなくアプリ） |

#### 節構成（見出し・id）

`reports-clean.template.html`（`grep -nE "\[必須\]|\[任意\]|<section id="` の結果。行番号は同ファイル）:

| 位置 | 要素 / id | 必須 / 任意（参考実装） | 中身 |
|---|---|---|---|
| 337 | `aside.sidebar` | 必須 | `p.kind`（種別 / フェーズ）、`h1`（題名）、`p.counts`（◎良 / △注意 / ✕問題 のチップ）、`nav.toc`（`ol` + 章の `ol.toc-sub`）、`dl.meta`（issue / ブランチ / PR / push回数 / 作成日 / 正文） |
| 392 | `section#overview` | 必須 | `p.lead`（1〜3 文の総括）、`ul.kpis`（件数タイル）、`div.focuses` に `focus.must`（◆特に見てほしい）/ `focus.want`（◇承認が欲しい）/ `focus.skip`（・細かいレビューは不要）の 3 枠 |
| 438 | `section#unverified` | 必須 | `div.box.warn` の 1 行 1 件リスト。各行から章へリンク |
| 453 | `section#conditions` | 任意（実測を含むなら必須） | `h2 実施条件（測った対象・環境）` |
| 469 | `section#findings` | 必須 | `h2 実施した内容と結果`、タイムライン `.tl` の中に `h3#f1`（連番 id）+ `.chip` + `.basis`。callout `.box.warn.unverified-detail` |
| 508 | `section#verified` | 任意 | `h2 検証の結果`（表） |
| 524 | `section#next` | 必須 | `h2 設計への反映` |
| 534 | `section#surprises` | 任意 | `h2 想定と異なった点`（計画時の見込み / 実際 / どう扱ったか の表） |
| 550 | `section#todo` | 任意 | `h2 残課題` |
| 559 | `footer` | — | `issue #NN / PR #NN — 結果の正文は同名の .md …` |

`plans.template.html`:

| 位置 | 要素 / id | 必須 / 任意 | 中身 |
|---|---|---|---|
| 165 | `header.band` | 必須 | `div.kind`、`h1`、`p.lead`、`ul.meta`（issue / ブランチ / PR / フェーズ flow-id / push回数 / 作成日 / 正文） |
| 189 | `nav.toc` | 任意（節 5 未満なら削除可） | `h2 目次` |
| 206 | `section#premise` | 任意 | 前提（合意状況） |
| 217 | `section#goal` | 必須 | この計画で何をするか |
| 224 | `section#target` | 必須 | 変更対象 |
| 239 | `section#approach` | 必須 | 方針（置換前後の `.box` を含む） |
| 255 / 266 | `section#phase-research` / `#phase-apply` | 全体作業計画のみ必須 | フェーズ2〈調査〉/ フェーズ4〈反映〉 |
| 276 | `section#out-of-scope` | 必須 | やらないこと（スコープ外） |
| 289 | `section#verify` | 必須 | 検証 |
| 300 | `section#criteria` | 任意 | issue の受け入れ条件との対応 |
| 315 | `section#options` | 任意 | 比較検討した案 |
| 330 | `footer` | — | |

視覚語彙の実装（両テンプレート共通の CSS トークン）: `--good/--good-soft`（青 = 良）、`--warn/--warn-soft`（黄 = 注意）、`--stop/--stop-soft`（赤 = 問題）、`--ok/--ok-soft`（緑 = 決めたこと専用）、`--accent/--accent-soft`（◆◇の枠。色相を使わず濃度で表す）、`--bg --panel --ink --muted --line --code-bg --hl-bg --card-border --radius --shadow`。設計判断の経緯は `docs/ddr/i0186-01-…md`（性質と重みで軸を分ける）と `i0203-01-…md`（共通 DOM + 4 スタイル）。

### 2. 参考実装の HTML 機械検査

(a) **成果物向け**（`参考/MR-driven-workflow/.claude/skills/issue-mr-flow/references/deliverables.md:78-150`「検査手順の正はこの節にある」。スクリプト化されておらず、grep を手で叩く）:

| # | 検査 | 合格条件 | 新仕様との対応 |
|---|---|---|---|
| 1 | プレースホルダ `grep -c '<!-- ここに書く'` | 成果物 0 / テンプレート本体は 0 でない | RV001（ただし新仕様は `{{名前}}` 形式） |
| 2 | リンク破断: `href="#…"` 集合 − `id="…"` 集合 | 0 行 | RV004 |
| 3 | 重複 ID: id 集合の `uniq -d` | 出力なし | RV003 |
| 4 | 外部依存 `(src\|href)=['"]?(https?:)?//` | 0 件 | RV002（新仕様は `<a href>` を除外する点が異なる） |
| 5 | 外部依存 `(url\(\|@import\s+)['"]?(https?:)?//` | 0 件 | RV002 |
| 6 | `<style` / `</style>` が**コメント除去後**（`perl -0pe 's/<!--.*?-->//gs'`）にそれぞれ 1 | 1 / 1 | RV005 |
| — | 空振りガード（拾えた href / id の件数を出す） | 0 件なら抽出の故障 | RV007 |
| — | 一般則 3: 負のコントロール（`id="f1"` を `overview` に変えると 2 と 3 が反応する） | — | RV-T02 / RV-T04 のテスト観点 |

(b) **テンプレート本体向け** `参考/MR-driven-workflow/.claude/scripts/test/test_report_templates.sh`（Git Bash で `passed=8 failures=0`）: T1 4 本の存在 / T2 `<style>` 除去後が 100 行以上（空振りガード）/ T3 除去後の md5 が 1 種類（DOM 同一性）/ T4 `<style>` が各 1（コメント除去後）/ T4b 負のコントロール（`<style>` 追加で open=2）/ T5 負のコントロール（1 本壊すと md5 が 2 種類）/ T6 外部依存 0 / T7 テンプレート本体はプレースホルダを持つ。
新機構で複数デザインを持たないなら T3 / T5 は不要だが、**T4b / T5 の「検査自身が壊れていないことを別ケースで確かめる」型は RV-T02〜T04 の書き方として流用できる**。

(c) `check-doc-references.sh` は HTML を検査対象外にしている（`docs/spec/check-doc-references.md:56`）。

### 3. 新機構のテンプレートの土台と `data-required`

#### 土台の候補

| 新機構 | 土台 | 理由 |
|---|---|---|
| `report.template.html` | `reports-clean.template.html` | DDR `.claude/docs/20_ddr/i0001-05-…md`「影響」に「初版は `reports-clean.template.html` を土台に、参考実装固有の記述（flow-id 等）を除いて作る」と明記。節順（サマリ → 確かめられなかったこと → 実施した内容と結果 → 設計への反映 → 想定と異なった点 → 残課題）が新仕様 `10_spec/skills/20-common-step-report-view.md`「OUT ひな形」と一致。外部依存なし・`<style>` 1・ライト / ダーク対応を既に満たす |
| `plan.template.html` | `plans.template.html` | 参考実装で唯一の計画書テンプレート。同じ CSS トークン体系で外部依存なし。ただしレイアウトがヘッダ帯型で、レポート（サイドバー型）と見た目が揃わない。**推測**: 見た目を揃えるなら reports-clean の骨格（sidebar + main）に計画書の節を載せ直す案もあるが、DDR は計画書の土台を名指ししていないので判断点 |

#### レポートの `data-required`（案）

仕様 `20-common-step-report-view.md`「OUT ひな形」の節順と、実施タスク 6 種 + 統括の仕様（`10_spec/skills/10-task-*-exec.md`「OUT ひな形」、`10-task-overall-summary.md` 処理フロー 4）を突き合わせた結果:

| テンプレートの要素 | 新仕様での位置づけ | `data-required` | 根拠 |
|---|---|---|---|
| `aside.sidebar` の `dl.meta`（issue / MR）と `h1` | 対象 issue / MR、題名 | **付ける**（サイドバー全体 or `dl.meta`） | `10-task-investigation-exec.md:70`「対象 issue と MR を冒頭に明記する」。目次 `nav.toc` は RV007 の前提（リンクが 0 件にならない）でもある |
| `section#overview`（総括 + 件数タイル + 重点レビュー依頼 3 枠） | サマリ | **付ける** | 仕様の節順 1 番目。参考実装も必須。◆◇・の 3 枠は視覚語彙の規約（要件「見た目と構成の規約」） |
| `section#unverified` | 確かめられなかったこと | **付ける** | 節順 2 番目。実施タスクの結果報告項目「確かめられなかったこと」（`10-task-investigation-exec.md:51`）と対応 |
| `section#conditions` | （仕様に無い） | 付けない（任意のまま） | 実測を含む調査だけが使う |
| `section#findings`（`h3#fN` 連番） | 実施した内容と結果 | **付ける** | 節順 3 番目。調査は観点ごとの小節、実装は「変更ファイル一覧 / テスト結果 / 逸脱一覧」、AI アセット実装は「アセット一覧 / テスト結果 / 検査結果 / 逸脱」、統括は「受け入れ条件との対応 / 各タスクのレビュー結果 / フィードバック計画の対応」をここに収める |
| `section#verified` | （仕様に無い） | 付けない | findings 内で示せるなら重複。実装・AI アセット実装の「テスト結果（テスト ID × 結果）」の表の置き場としては使える |
| `section#next` | 設計への反映 | **付ける** | 節順 4 番目 |
| `section#surprises` | 想定と異なった点 | **付ける（格上げ。判断点）** | 参考実装は任意だが、新仕様は節順に含め、6 種の exec 仕様がすべて「想定と異なった点」をレポートに含めると定める。無いときは「無し」と 1 行書く運用（参考実装の「無い」と「書き忘れ」を区別する思想と同じ） |
| `section#todo` | 残課題 | **付ける（格上げ。判断点）** | 同上。6 種の exec 仕様 + 統括（残課題）すべてに登場 |
| `footer` | issue / MR、正文は md | 付けない | 内容はメタと重複 |

#### 計画書の `data-required`（案）

計画タスク 7 種の仕様（`10_spec/skills/10-task-{investigation,design,implementation,design-feedback,ai-asset-design,ai-asset-implementation,feedback}-plan.md`「OUT ひな形」）の md 節を `plans.template.html` の節に当てはめると:

| テンプレートの要素 | md 側の共通節 | `data-required` | 備考 |
|---|---|---|---|
| `header.band`（`h1`、`ul.meta` の issue / MR / ブランチ） | 対象（全 7 種の先頭節） | **付ける** | `push回数` `フェーズ flow-id` は削る |
| `section#goal` | （各仕様の目的。md 節としては明示無し） | **付ける** | 参考実装で必須。「この計画で何をするか」は全種に共通して書ける |
| `section#target` | 変更対象（implementation / ai-asset-implementation）、設計書の一覧（design）、文書一覧と骨子（ai-asset-design）、対象と方法（investigation）、差分一覧（design-feedback） | **付ける** | 名称を「対象と方法 / 変更対象」のように広げるか判断点 |
| `section#approach` | 判断点の結論方針 / 結論方針 / 書き戻し方針 / テスト方針 / 調査観点 | **付ける** | |
| `section#out-of-scope` | （md 側に対応節が無い） | 判断点 | 参考実装では必須。新仕様の md 節に無いので、任意にするか md テンプレートにも足すか |
| `section#verify` | 検証方法（implementation）、成果物の形（investigation）、受け入れ条件の確認（design-feedback） | **付ける** | |
| `section#criteria` | 受け入れ条件との対応（design / ai-asset-design / overall-plan）、テスト ID × ステップ | 任意のまま | |
| `section#options` | 比較検討した案 | 任意のまま | |
| **無い節（新設が要る）** | **チケット**（調査チケット / 設計チケット / ステップ / 設計反映チケット — 全 7 種にある）、**保留した点 / 対象なし**（6 種にある）、許可範囲案・リスク・ロックアウト対策（実装系）、改善候補の一覧・合意・起票した issue・後続フェーズの決定（feedback） | チケット節と保留節は **新設して必須**が妥当（判断点） | 参考実装の `[全体作業計画のみ必須]` 2 節（`#phase-research` / `#phase-apply`）は **削除**（全体計画書は HTML を持たない） |

#### 削らないといけない参考実装固有の記述（`reports-clean.template.html` / `plans.template.html`。`grep -nE "flow-id|wip/reports|wip/plans|issue-mr-flow|REVIEW-POINTS|docs-workflow|canvas-report|issue #[0-9]+"` の結果）

| 種類 | 箇所（reports-clean） | 箇所（plans） | 置き換え |
|---|---|---|---|
| 成果物のパス `wip/reports/` `wip/plans/`、ファイル命名（`日付_<全体計画名>_…`、`【種別】タスク内容`） | 2, 12-13, 133, 138 | 2, 7-8, 50 | `wip/30_reports/<連番>-<種類>.html` / `wip/20_plans/<連番>-<種類>.html` |
| flow-id（`2-6` `3-6` `4-6` `5-4` `1-4` `N-N`） | 13, 120-124, 391, 437 | 37-48, 178, 205-212, 283 | チケット連番 / タスク種別（`10-task-*`）に読み替え。「統括レポート（5-4）では…」の読み替え注記は `10-task-overall-summary` に |
| 他スキル・文書への参照（`issue-mr-flow/SKILL.md`、`references/deliverables.md`、`.claude/rules/docs-workflow.md`、`canvas-report/SKILL.md`、`references/planning.md`） | 3, 91, 107-108, 133, 142, 146 | 3, 21-22, 27, 41, 51 | `20-common-step-report-view` の SKILL / 仕様書 |
| `wip/reports/REVIEW-POINTS.md` `wip/plans/REVIEW-POINTS.md`（DDR `i0001-19` で廃止済み） | 138, 450, 522 | 205, 247 | 成果物ルールの観点章へ |
| issue 番号の経緯（#54 / #186 / #203）と「テンプレートは 5 本あり…」 | 4, 101, 108, 158 | 3, 22, 30, 66 | 削除（経緯は DDR） |
| 冒頭コメント内の検査手順 6 項目と `grep -c '<!-- ここに書く'` の説明 | 60-115 付近 | 13-31 | `bash …/scripts/check-html.sh <file>` の 1 行に置換 |
| 恒久知見の反映先 `.claude/docs/spec/ .claude/docs/ddr/` | 528 付近（`#next` のコメント） | — | `.claude/docs/10_spec/` `20_ddr/` |
| `PR` の語、`push回数` メタ | 559 (footer), `dl.meta` | `ul.meta` | MR（GitHub では PR）に統一。push 回数は新機構に該当する概念があるか要確認 |
| `[必須]` / `[任意]` の HTML コメント | 各節直前 | 各節直前 | **`data-required` 属性に置き換える**（仕様「必須節には `data-required` 属性を付け、検査の対象にする」「検査 6 の必須節一覧はテンプレート自身から導出する」）。任意の説明コメントは残してよい |
| プレースホルダ `<!-- ここに書く: … -->` | 27 件 | 21 件 | 仕様は `{{名前}}` 形式（RV001）。**判断点**: HTML コメントの中に `{{summary}}` を置くか、要素の中身として `{{summary}}` を置くか（後者はプレースホルダを消し忘れるとブラウザに見えるので気づきやすい。前者は説明文を添えられる） |
| `.tl-item` の「サブエージェント」等の語は無し。`h3#f1` 連番の規約は流用可 | — | — | — |

### 答えが出なかった点

- 4 デザインとも**ブラウザでの実表示は参考実装側でも未確認**（DDR `i0203-01`「未確認事項」、`i0186-01`「限定」）。新機構でも初版作成時に目視が要る。
- 計画書テンプレートのレイアウトを reports-clean（サイドバー型）に揃えるか `plans.template.html`（ヘッダ帯型）のままにするかは DDR に記述が無く判断点。
- `{{名前}}` プレースホルダを HTML コメント内に置くか要素内容に置くか、`data-required` を `<section>` だけに付けるか `aside.sidebar` / `nav.toc` / `header.band` にも付けるか（RV006 の抽出対象の定義）は仕様に明記が無い。
- 「想定と異なった点」「残課題」「保留した点」「チケット」節の必須化は仕様と参考実装で食い違うため、設計での決定が要る。
