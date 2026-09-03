---
type: spec
title: 20-common-step-shell-script スキル 仕様
description: sh ファイル作成の共通ステップの内部仕様。雛形（script / test）の構成、作成手順と検査、共通 logger（scripts/logger.sh）の関数 API・行フォーマット・出力先・レベル制御・失敗時の黙殺、読み込み行の解決順、終了コードの規約、frontmatter 読み取りライブラリ（frontmatter.sh）、テスト補助（test-lib.sh）とテストランナー（run-tests.sh）、テスト観点を定める
tags: [spec, skill, common-step]
keywords: [shell-script, logger.sh, log_info, log_debug, LOG_LEVEL, logs/sh, 行フォーマット, 雛形, bash -n, shellcheck, テスト, frontmatter.sh, test-lib.sh, run-tests.sh, 読み込み行, 終了コード, TR0xx, FR-T, TR-T]
---

# 20-common-step-shell-script スキル 仕様

## 概要・禁止事項

シェルスクリプト作成の共通ステップの内部仕様。対応する要件は [00_requirement/skills/20-common-step-shell-script.md](../../00_requirement/skills/20-common-step-shell-script.md)。

共通 logger の実体は `.claude/skills/20-common-step-shell-script/scripts/logger.sh`。**logger の内部仕様（関数 API・行フォーマット・出力先・失敗時の振る舞い）はこの仕様が正**で、`rules/logger.md` は sh を書く AI 向けの要点（使用義務・使い方・レベルの使い分け・禁止事項）を持つ。同じ `scripts/` に、チケット frontmatter の読み取りライブラリ `frontmatter.sh`（`source` 専用。フックと提供コマンドが共用）、テスト補助 `test-lib.sh`（`source` 専用）、テストランナー `run-tests.sh`（提供コマンド）を置く。いずれもこのスキルの配下だけに実体を持ち、他のスキル・フックは重複して持たない。

禁止事項:

- 白紙からの sh 作成（雛形をコピーする）
- logger のコピーや独自ログ方式（source して使う）
- ログの標準出力・標準エラーへの出力（logger はファイルにのみ書く）
- テストの無効化・期待値の書き換えによる合格
- 利用中の logger の変更（AI アセットのフェーズで、全利用者の回帰テストとともに行う）

## 呼出条件

- `20-common-step-ai-asset-creator` がスクリプト・フックを含むアセットを作成・変更するとき
- フックの実装、既存スクリプトの変更のとき

## IN / OUT

| IN | OUT |
|----|----|
| 対象スクリプトの仕様書（インターフェース・判定順・エラー識別子・テスト観点）、置き場所（スキルの `scripts/` またはフックのイベントディレクトリ） | 雛形由来の sh、対応するテスト（`scripts/tests/` またはフックのテストディレクトリ）、検査結果とテスト結果（作業ログ） |

## IN / OUT サンプル

```bash
# 雛形から作成
cp .claude/skills/20-common-step-shell-script/assets/script.template.sh .claude/skills/20-common-step-ticket/scripts/ticket.sh
cp .claude/skills/20-common-step-shell-script/assets/test.template.sh  .claude/skills/20-common-step-ticket/scripts/tests/test_ticket.sh

# 作成した sh の冒頭（雛形に含まれる読み込み行。1 行で、ルートの解決順は Script 処理「読み込み行」が正。行の中身を自作しない）
source "<リポジトリルート>/.claude/skills/20-common-step-shell-script/scripts/logger.sh"
log_info "start 0003 を受け付けた"
log_debug "HEAD=5c19f25 doing=empty"   # LOG_LEVEL=DEBUG のときだけ書かれる

# logs/sh/ticket.log
2026-09-01T14:03:12+09:00 [INFO] [ticket] [pid:4172] start 0003 を受け付けた
2026-09-01T14:03:12+09:00 [DEBUG] [ticket] [pid:4172] HEAD=5c19f25 doing=empty
```

## 処理フロー

1. 対象の仕様書を読み、インターフェース・判定順・エラー識別子・テスト観点を確認する（無ければ設計が先として返す）
2. `assets/script.template.sh` を置き場所へコピーし、雛形の `{{名前}}` を埋める（雛形は shebang・`set -euo pipefail`・logger の読み込み行・引数解析の骨格・`OK:` / `<ID>:` の結果出力の型・終了コードの規約を含む）。フックのスクリプトも同じ雛形から作る（結果出力の型は使わず、フック共通仕様の制御方式に従う）
3. bash 規約（`rules/` bash-script）と logger ルールに従って実装する。ログはレベルの使い分けに従う
4. `assets/test.template.sh` からテストを作り、仕様書のテスト ID ごとにケースを書く（正常系・境界・異常系。`test-lib.sh` の assert の第 1 引数にテスト ID を渡し、出力は `PASS <ID>` / `FAIL <ID>: <理由>` の 1 行 1 ケース）。実行して結果を作業ログに残す。既存テストは `run-tests.sh` で回帰させる
5. 検査: `bash -n` による構文検査、`shellcheck` が導入されていれば静的検査。結果を作業ログに残す（shellcheck 不在なら省略の事実を記録）。**`shellcheck` は CI で回さず、`run-tests.sh` にも組み込まない**（テストランナーは振る舞いを見るもので、静的検査は別軸。CI 設定の変更はリポジトリ設定の変更に当たりこの機構のスコープ外 — DDR i0009-19）。記録は省略できない（「実行した / 不在で省略した」のどちらかを必ず作業ログに書く）
6. 既存 sh の変更では 2 を行わず、既存構成に合わせて差分を小さくする

## OUT ひな形

- `assets/script.template.sh`: shebang（`#!/usr/bin/env bash`）、`set -euo pipefail`、logger の読み込み行（リポジトリルートの解決を含む 1 行。Script 処理「読み込み行」）、`usage` 関数、サブコマンド／オプションの解析骨格（順不同）、結果出力の型（成功 `OK: ...` / 失敗 `<接頭辞><番号>: ...` を最終行に）、終了コードの規約（0 / 1 / 2。Script 処理「終了コード」）
- `assets/test.template.sh`: `test-lib.sh` を `source` する 20 行程度の骨格（一時ディレクトリの用意と後始末、ケース関数の型、`finish` による集計と非 0 終了）。assert の実装は持たない（`test-lib.sh` に集約）
- `scripts/test-lib.sh`（`source` 専用）: `assert_eq <ID> <expected> <actual>` / `assert_exit <ID> <expected_code>` / `assert_contains <ID> <needle>` / `assert_not_contains <ID> <needle>`（直前の `run_cmd` の出力に対して）/ `run_cmd <cmd...>`（`R_EXIT` / `R_OUT` / `R_ERR` に格納。`set -e` の影響を受けない）/ `make_tmp_repo`（`mktemp -d` + `git init -q -b main` + user 設定 + `trap` による後始末。パスに非 ASCII を含めない）/ `make_tmp_dir`（git なしの一時ディレクトリ）/ `make_restricted_path <cmd...>`（挙げたコマンドだけを持つ PATH を `RESTRICTED_PATH` に作る。symlink ではなくラッパースクリプト）/ `make_counting_path <cmd...>`（挙げたコマンドの呼び出しを記録するラッパーだけを持つ PATH を `COUNTING_PATH` に、記録先を `COUNTING_LOG` に作る。fork ゼロ・呼び出し回数の約束を回数で検査するためのもの）/ `counted_calls [cmd]`（記録された呼び出し回数を返す）/ `hook_payload <event> <tool_name> [--session <id>] <json-fields...>`（`jq -nc --arg` でフック入力 JSON を組む。`session_id` は既定 `testsession` で、`--session` で変える）/ `finish`（`PASS`/`FAIL` の集計行 `passed=N failures=N` を出し、失敗があれば非 0）。テストは `set -uo pipefail`（`-e` なし）で書き、終了コードは `run_cmd` が取る。Windows 対策はここに集約する: PATH を絞るときは symlink ではなくラッパースクリプトを生成、jq 出力の CR 除去、性能閾値は `TEST_SKIP_PERF=1` で無効化
- `scripts/run-tests.sh`（提供コマンド）: 2 つの置き場（`.claude/hooks/**/tests/test_*.sh`・`.claude/skills/*/scripts/tests/test_*.sh`）のテストを列挙して実行する。Script 処理「run-tests.sh」
- `scripts/frontmatter.sh`（`source` 専用）: チケット等の Markdown frontmatter を読む純 bash ライブラリ。Script 処理「frontmatter.sh」

## 参照ナレッジ

- bash 規約の中身: `rules/`（bash-script ルール）
- ログの規約（使用義務・使い分け・禁止）: `rules/logger.md`
- `logs/` の位置づけ: DDR `i0001-28`
- 呼び出し元の手順: `10_spec/skills/20-common-step-ai-asset-creator.md`

## Script 処理

### 読み込み行（雛形の 1 行。logger と frontmatter.sh に共通）

雛形が持つ読み込み行は `<lib>`（`logger` / `frontmatter` / `test-lib`）と失敗時ポリシー（`nop` / `fatal` / `deny`）を引数に取る 1 行で、リポジトリルートを次の順で解決して `<ルート>/.claude/skills/20-common-step-shell-script/scripts/<lib>.sh` を `source` する。解決したルートは `LOGGER_ROOT` に置き、logger と `frontmatter.sh` はこれを基準に `logs/` やパスを解決する。各スクリプトはこの行をコピーして引数だけを変え、中身を自作・改変しない（行の実体は `assets/script.template.sh` が正）。

1. `${BASH_SOURCE[0]%/*}` を起点に、`.claude` ディレクトリを持つ親を上向きに探す（パラメータ展開だけで fork なし。スキルの `scripts/`・フックのイベントディレクトリ・両者の `tests/` のどの深さでも同じ行で動く。相対パスで起動されて親に登れないときは次へ）
2. `CLAUDE_PROJECT_DIR`（Claude Code がフックに渡す。`\` は `/` に正規化）
3. `git rev-parse --show-toplevel`（空文字なら不採用。`source "/.claude/..."` にしない）
4. すべて失敗したとき（またはライブラリファイルが無いとき）の振る舞いは失敗時ポリシーによる:

| 呼び手 | lib | ポリシー | 失敗時 |
|---|---|---|---|
| 提供コマンド・フック・テスト | `logger` | `nop` | 4 関数を no-op で定義して続行（ログ機構の失敗が本体を止めない — `rules/logger.md`）。`LOGGER_ROOT` は解決できた値（できなければ `$PWD`）を必ず設定する（呼び手が直後に `cd "$LOGGER_ROOT"` するため。未設定だと `set -u` で本体が落ちる） |
| 提供コマンド | `frontmatter` | `fatal` | 環境の誤りとして最終行 `FATAL: <理由>` を出し終了コード 2（判定に使う値が読めないまま続行しない）。共有の 1 行は呼び手の識別子を知らないので `<接頭辞><番号>:` の形は取らない |
| フック（拒否側） | `frontmatter` | `deny` | フック共通仕様 §3「判定できなければ拒否側に倒す」に従い `WFx09` の deny JSON を出して終了 0。識別子は呼び手が読み込み行より前に `HOOK_DENY_ID` で設定する（未設定なら `WF009`。番号はフックごとの仕様が決める） |
| フック（案内側） | `frontmatter` | `nop` | 何も出さずに通す（§3 の案内側の原則） |
| 共有ライブラリ（`.claude/hooks/lib/scope.sh`） | `frontmatter` | `nop` | **`scope.sh` 自身は何も出力しない**。失敗をどう扱うかは呼び手のフックが決める（拒否側は自分で deny に倒し、案内側は通す）。ライブラリが一律のポリシーを持つと、同じ `scope.sh` を使う拒否側と案内側のどちらかで §3 の原則に反する（フック共通仕様 §12 T8・DDR i0009-14） |
| テスト | `test-lib` | `fatal` | テスト自身が理由を出して非 0 で終了 |

`nop` で `frontmatter` を読めなかったときは、`fm_extract` / `fm_get` / `fm_list` / `fm_has` を**出力なし・戻り値 2** のスタブとして定義し、`FM_AVAILABLE=0` を設定する（読めたときは `FM_AVAILABLE=1`）。戻り値で 3 つの状態を区別する（DDR i0009-16）:

| 戻り値 | 意味 | 拒否側フックの扱い |
|---|---|---|
| 0 | 値を読めた | 判定を続ける |
| 1 | frontmatter は読めたがキーが無い・対象外の形 | **チケットの記載不正 → WF211**（復旧は記載の修正・`ticket.sh cancel`） |
| 2 | ライブラリを読み込めていない（スタブ） | **機構の破損 → WFx09**（`workflow-guard` なら WF209。復旧は `.claude/` の状態確認とユーザーへの報告） |

**`FM_AVAILABLE` を設定するのは読み込み行**（読めたら 1、`nop` でフォールバックしたら 0）。`frontmatter.sh` 自身は設定しない（読み込めていないときに実行されるのはスタブの側なので、ライブラリに設定を任せられない）。

**呼び出し規約**（`set -euo pipefail` の下で戻り値 1 / 2 を潰さないための書き方。DDR i0009-35）:

- `local` と代入を**同じ行に書かない**。`local v=$(fm_get "$f" k)` は bash の仕様上 `local` の終了ステータス（常に 0）が返り、**戻り値が黙って失われる**。`local v; v="$(fm_get "$f" k)" || rc=$?` と 2 行に分ける
- **`|| true` を使わない**。`set -e` で落ちないようにするためだけの `|| true` は戻り値を捨てる。`|| rc=$?` で受けて分岐する
- 戻り値を使わない呼び出し（値が空でも困らない場面）でも `|| rc=$?` で受け、`rc` を無視すると決めたことがコードから読めるようにする
- パイプやコマンド置換の中で `fm_*` を呼ばない（`$(...)` の中の非 0 は `set -e` の対象外になり、判定が静かに変わる）

`scope.sh` は `fm_*` の戻り値 2 を `scope_load_ticket` の戻り値 2 としてそのまま呼び手に返す（1 と 2 を潰さない）。案内側のフックは 1 と 2 のどちらでも何も出さずに通すので区別を使わないが、区別できる形にしておくのは記録（`decisions.jsonl` の `note`）で原因を書き分けるため。

`git rev-parse` だけに頼らないのは、フックが毎ツール呼び出しで git を起動することになる（Git Bash で約 95 ms/回）ことと、git 不在・リポジトリ外で `set -e` により即死することを避けるため。

### ライブラリの責務の境界（分類まで / 照合は呼び手）

`source` 専用のライブラリと `.claude/hooks/lib/` の共有ライブラリは、**入力を機械的に分類するところまで**を担い、「その値がプロジェクトの規約に照らして正しいか」の照合は呼び手が行う。同じ規約が 2 か所に書かれると、片方だけ更新されて食い違うため（DDR i0009-17）。

| ライブラリの関数 | やること（分類） | やらないこと（照合。呼び手の責務） |
|---|---|---|
| `hook-common.sh` の `tool_class` | ツール名から種類（書き込み / 実行 / 読み取り / プランモード / 起動 / 宣言）を返す。`Skill` は `tool_input.skill` の値を見ずに**常に「宣言」**に分類する | 「その名前が振り分けスキルか」の照合。正は `.claude/hooks/config/entry-skills.txt` で、照合するのは `workflow-entry`（`00-workflow-` の接頭辞判定をライブラリに持たせない） |
| `cmdpos.sh` | コマンド列を実行位置のセグメントに分け、実行体・第 1 サブコマンド・**オプションを除いた位置引数**（`cmdpos_operands <i>`）を返す | 「そのコマンドを許してよいか」の判断（`workflow-guard` / `block-*` が行う）。「その位置引数が削除対象か宛先か」の解釈も呼び手（`workflow-state-guard` の WF302 / WF303）が行う |
| `scope.sh` の `scope_classify` | 操作の分類（`read` / `build-test` / `hook-test` / `remote-read` / `remote-write:*` / `merge-base` / `web` / `provided`。**分類の正は `フック共通仕様` §8** で、この表は責務の境界を示すための要約）を返す | 「その分類がチケットに宣言されているか」の判断（呼び手が `allow.ops` と突き合わせる） |
| `frontmatter.sh` | frontmatter の値を返す（戻り値で「読めた / 無い / ライブラリ不在」を区別） | 値が仕様どおりかの検証（`ticket_type` が `types` にあるか等） |

### 終了コード

- 提供コマンド（`ticket.sh` / `commit.sh` / `push.sh` / `check-html.sh` / `run-tests.sh` / `finalize.sh` / `boundary.sh`）: 成功 0 / 検査・前提未充足 1 / 引数や環境の誤り 2。最終行は `OK:` または `<接頭辞><番号>:`
- フック: 判定結果は stdout の JSON（`permissionDecision` 等）で伝え、**終了コードは常に 0**。`exit 2` + stderr によるブロック（Claude Code のもう 1 つの契約）は使わない（JSON 経路と混在させない — フック共通仕様 §3・§12 T6）。フック自身の異常終了はフック共通仕様の `trap ERR` と登録ラッパーが deny に倒す
- `source` 専用のライブラリ（`logger.sh` / `frontmatter.sh` / `test-lib.sh`）: 直接実行しても何もしない（終了 0）

### frontmatter.sh（source 専用）

`.claude/skills/20-common-step-shell-script/scripts/frontmatter.sh`。Markdown 先頭の frontmatter（1 行目 `---` から次の `---` まで）を純 bash（外部プロセスなし。`jq` / `yq` / `sed` を使わない）で読む。フック共通仕様 §9 のチケット形式（フラットなスカラー・フロー配列 `["a", "b"]`・入れ子のマッピング・インラインマップ `{k: v, k2: "v2"}`）を対象にし、汎用 YAML パーサではない（ブロック配列 `- a` と複数行スカラーは対象外。現れたら空として扱い戻り値 1）。

| 関数 | 入出力 |
|------|--------|
| `fm_extract <file>` | frontmatter 本文を `FM_BLOCK` に格納（CR 除去済み）。frontmatter が無ければ空で戻り値 1 |
| `fm_get <file> <key>` | スカラー値を標準出力に返す。`key` は `ticket_type` のようなトップレベルか、`human_review.required` / `allow.write` のようなドット区切り（入れ子マッピング・インラインマップの両方を同じキーで引く）。クォートは外す。無ければ空で戻り値 1。フロー配列（`predecessors`）とインラインマップ（`human_review`）のキーを指定したときは生の文字列（`["a", "b"]` / `{required: true, ...}`）を返す（呼び手が形を確かめる用途）。ブロックマッピングのキー（`allow`）は値を持たないので空で戻り値 1 |
| `fm_list <file> <key>` | フロー配列の要素を 1 行 1 要素で返す（クォート除去）。無ければ空で戻り値 1 |
| `fm_has <file> <key>` | 存在すれば 0 |

- 行末の CR、キーの前後の空白、`#` 以降のコメント（クォート外）を無視する。値の中の `:` はクォートの内側なら区切りにしない
- 同じファイルを繰り返し読むときは `fm_extract` を 1 回だけ行い、`FM_BLOCK` を各関数が使う（`fm_get` は未抽出なら内部で抽出する）
- 利用側は `frontmatter.sh` だけを通してチケットを読み、`sed -n '2,/^---/...'` のような自前解析を持たない（規則の複製禁止。DDR i0006-01）

### run-tests.sh（提供コマンド）

`bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh [--filter <glob>] [--ids] [--timeout <秒>]`

1. 作業中チケット（`wip/10_tickets/10_doing/` の `.md` を名前順に並べた **1 枚目**。複数枚あっても件数では止めない — 「作業中は 1 枚」を前提に動き、2 枚以上の検知は `workflow-guard` の WF207 が担う。DDR i0009-18）があれば、その `allow.ops` に `build-test`（対象に `.claude/hooks/**` のテストを含むなら `hook-test` も）が無ければ TR006 で拒否する（提供コマンドは分類を問わずフックが許可するため、宣言の検査をコマンド側で行う — フック共通仕様 §8）。作業中チケットが無いとき（切れ目・実装計画外の実行）は検査しない
2. `.claude/hooks/**/tests/test_*.sh` と `.claude/skills/*/scripts/tests/test_*.sh` を列挙する（`--filter` で絞る）。0 本なら TR001
3. 各テストを `timeout`（既定 120 秒。**1 本あたりの上限で、全件の合計ではない**）付きで `bash <test>` として実行し、最終行（集計行）と終了コードを集める。`PASS <ID>` / `FAIL <ID>: ...` 行から ID を抽出する。**抽出は `^(PASS|FAIL) ([A-Z]{2,6}-[TE][0-9]{2}[a-z]?)` に一致する行だけ**を対象にする（一致しない行は本文の一部として読み飛ばす）。この形に合わない ID を仕様のテスト観点に書くと、テストが通っていても `--ids` に現れず突合できないので、**新しい接頭辞は必ずこの形に合わせる**（接頭辞は大文字 2〜6 文字、続くセグメントは `T`（機械テスト）か `E`（eval）で始まり 2 桁 + 任意の小文字 1 文字）。`session-start` のテスト ID が `SS-H` から `SE-T` に変わったのはこの制約による（DDR i0009-08）
4. ファイルごとの結果（PASS / FAIL / TIMEOUT）を表で出し、`--ids` なら PASS / FAIL した ID の一覧も出す（仕様書の「テスト観点」表との突合用。同じ ID が複数のテストに現れたら重複として報告する）
5. すべて PASS なら `OK: <N> 本 / <ID 数> 件` で 0。FAIL があれば TR002、TIMEOUT があれば TR003（両方あれば両方列挙）で 1。宣言不足は TR006 で 1。引数不正は TR004、`timeout` コマンド不在等の環境不備は TR005 で **2**（引数・環境の誤り。Script 処理「終了コード」の規約）

| ID | 条件 |
|----|------|
| TR001 | 対象のテストが 0 本 |
| TR002 | FAIL したテストがある（ファイルと ID を列挙） |
| TR003 | タイムアウトしたテストがある |
| TR004 | 引数の誤り（終了 2） |
| TR005 | 実行環境の不備（bash / timeout / jq の不在。終了 2） |
| TR006 | 作業中チケットの `allow.ops` に `build-test`（必要なら `hook-test`）が無い |

**上限（120 秒）に収まらないテストの扱い**: 既定値を上げず、テスト側で上限を宣言する仕組みも設けない。TR003（TIMEOUT）が出たときの手順は次の順で、上限の引き上げ（`--timeout`）は原因を切り分けるための一時的な手段にとどめる。

1. **同時実行を疑う**: `run-tests.sh` を 2 本以上並行させると、互いに CPU とファイルを奪い合って無関係なテストまで TIMEOUT する。全件は 1 本ずつ走らせ、前の実行の子プロセス（`timeout` / `bash`）が残っていないことを確かめてから回し直す
2. **静かな状態で測り直す**: 全件（2026-09-03 時点で 25 本）は Windows の Git Bash で 10 分前後かかるが、**1 本ずつなら既定 120 秒にすべて収まる**（いちばん重い `test_workflow_guard` で 1 分 47 秒）。競合下で測った時間を性能の結論にしない
3. **それでも 1 本で超えるならテストを直す**: ケースを分割して 1 ファイルを小さくするか、重い経路（実プロセスの起動・繰り返し回数）を減らす。上限を上げるとテストが遅くなったこと自体が見えなくなるため、120 秒は「1 本のテストが重くなりすぎた」ことを知らせる装置として据え置く

### logger.sh（source 専用）

`.claude/skills/20-common-step-shell-script/scripts/logger.sh`。実行しても何もしない。

1. **初期化（source 時）**: リポジトリルート（読み込み行が解決したもの。`LOGGER_ROOT` で渡され、無ければ `git rev-parse --show-toplevel`）を基準に `logs/sh/` を `mkdir -p` する（失敗は無視）。`LOGGER_NAME` があればそれを、無ければ `$0` の basename（拡張子なし）を出どころとする。`LOG_LEVEL` を読み、無効値・未設定は `INFO` に正規化する
2. **提供する関数**: `log_debug` / `log_info` / `log_warn` / `log_error`（各 1 引数。複数引数はスペース連結）
3. **レベル判定**: DEBUG(10) < INFO(20) < WARN(30) < ERROR(40)。現在のレベル未満の呼び出しは何もせず 0 を返す
4. **行フォーマット**: `<ISO 8601 タイムスタンプ（秒・タイムゾーン付き。例 2026-09-01T14:03:12+09:00）> [<LEVEL>] [<出どころ>] [pid:<PID>] <メッセージ>`。改行を含むメッセージは 1 行に畳む（改行を `\n` リテラルに置換）。時刻は bash 組み込みの `printf '%(...)T'` で取り（`date` を fork しない）、`%z` の `+0900` にコロンを挿して `+09:00` にする（bash の `%:z` は使えない）
5. **書き込み**: `logs/sh/<出どころ>.log` へ追記する。書き込みの失敗（権限・ディスク・ディレクトリ不在）はすべて握りつぶし、関数は常に 0 を返す（`set -e` の利用側を巻き込まない）。標準出力・標準エラーには何も出さない
6. ローテーションは持たない（`logs/` はローカル限りで、必要なら人間が消す。肥大が問題になったら日付別ファイルへの変更をこの仕様で決める）

### テストの書き方（規約）

仕様書のテスト観点をテストに落とすときの規約。各スクリプトのテストと、レビューでテストの穴を探すときの基準として使う。

- **表は全要素を踏む**: 語彙表・分類表・判定順のように仕様が表で定めるものは、代表例ではなく表の全要素をループで検査する（表に足した要素がテストされないまま残らない）
- **負のケースに正の期待値を添える**: 「一致しない」「拒否されない」だけの assert は、抽出の故障でも通る。何として解析・判定されたか（セグメント数・実行体・判定段階・識別子）を併記する
- **回数の約束は数える**: fork ゼロ・`jq` 1 回のような性能や実装の約束は、`make_counting_path` で呼び出し回数を数えて検査する。stderr が空・`PATH=""` で動く、では `2>/dev/null` 付きの fork を素通しする。数える経路が実際に呼ばれる正のコントロール（1 回以上）を同じテストに置く
- **契約を exact に固定する**: 最終行（`OK:` / `<接頭辞><番号>:`）と終了コード（0 / 1 / 2）は `assert_eq` で一致を見る（`assert_contains` で済ませない）
- **秘密の実例を置かない**: テストデータに実在の秘密と同じ形（`AKIA` + 16 文字の実例・40 文字の 16 進など、リモートの push 保護が拒否する形）を置かない。マスク対象の検査は形を崩した値（長さや文字種だけ合わせる）で行う
- **一時リポジトリで実行する**: 提供コマンド・フックのテストは `make_tmp_repo` の中で行い、作業中のリポジトリの状態（チケット・`logs/`）に依存しない
- **1 本を `run-tests.sh` の上限（既定 120 秒）に収める**: 超えたらケースを分割するか重い経路を減らす（上限は上げない。Script 処理「run-tests.sh」）

### テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| LG-T01 | 正常系 | 既定（LOG_LEVEL 未設定）で INFO が書かれ DEBUG が書かれない |
| LG-T02 | 正常系 | LOG_LEVEL=DEBUG で DEBUG も書かれ、行フォーマット（時刻・レベル・出どころ・pid）が一致する |
| LG-T03 | 異常系 | logs/ が作成不能でも source と関数呼び出しが成功し（終了コード 0）、標準出力・標準エラーに何も出ない |
| LG-T04 | 境界 | 無効な LOG_LEVEL が INFO に正規化される。改行入りメッセージが 1 行になる |
| LG-T05 | 正常系 | LOGGER_NAME による出どころの上書き |
| SS-T01 | 正常系 | 雛形からコピーした sh が `bash -n` を通り、logger を source して結果出力の型で終了する |
| SS-T02 | 異常系 | テスト雛形が失敗ケースを検出して非 0 で終了する |
| SS-T03 | 正常系 | 読み込み行が、スキルの `scripts/`・フックのイベントディレクトリ・両者の `tests/` の 4 通りの深さから logger を解決する（fork なしの経路） |
| SS-T04 | 異常系 | git 不在・リポジトリ外・`CLAUDE_PROJECT_DIR` 未設定でも読み込み行が失敗せず、logger が no-op になって本体が続行する。`nop` でも `LOGGER_ROOT` が設定される。`fatal` の最終行は `FATAL: <理由>` で終了 2、`deny` は `HOOK_DENY_ID`（未設定なら `WF009`。台帳の持ち主は共通ライブラリの読み込み行 — フック共通仕様 §6・DDR i0009-15）の deny JSON で終了 0。`frontmatter` の `nop` は `FM_AVAILABLE=0` とスタブ（出力なし・**戻り値 2**）を定義し、キー不在の戻り値 1 と区別できる |
| SS-T05 | 正常系 | **読み込み行のコピーが雛形と一致する**: リポジトリ内のすべての `.sh`（`.claude/hooks/**` と `.claude/skills/*/scripts/**`）の `^__ss_load() {` から始まる行が、`assets/script.template.sh` のそれと**バイト一致**する。1 か所でも違えば失敗し、違うファイルを列挙する（読み込み行は 20 本以上に逐語コピーされており、雛形だけ直すと本番経路が旧仕様のまま残る。DDR i0009-36） |
| FR-T01 | 正常系 | フラットなスカラーとフロー配列（`ticket_type` / `predecessors`）を読める |
| FR-T02 | 正常系 | 入れ子マッピング（`allow.write` / `allow.ops`）をドット区切りで読める |
| FR-T03 | 正常系 | インラインマップ（`human_review.required` / `.reason`）をドット区切りで読める。クォート内の `:` と `,` を区切りにしない |
| FR-T04 | 境界 | CRLF のファイル・キー前後の空白・行末コメントを無視する |
| FR-T05 | 異常系 | frontmatter 無し・キー無し・対象外の形（ブロック配列）で空 + 戻り値 1。外部プロセスを起動しない（呼び出しを数える PATH で 0 回）。マッピング・配列のキーへの `fm_get` は生の文字列を返す |
| TR-T01 | 正常系 | 2 つの置き場のテストを列挙し、全 PASS で `OK:` と ID 数 |
| TR-T02 | 異常系 | FAIL を含むテストで TR002 とファイル・ID の列挙、非 0 |
| TR-T03 | 異常系 | 無限ループするテストが TR003 で止まる |
| TR-T04 | 境界 | `--filter` の絞り込みと 0 本のときの TR001、`--ids` の一覧と重複 ID の報告。不明な引数が TR004・終了 2、`timeout` 不在が TR005・終了 2 |
| TR-T05 | 異常系 | `allow.ops` に `build-test` の無い作業中チケットがあるときは TR006 で実行しない。作業中チケットが無ければ実行する。作業中チケットが 2 枚あっても件数では止めず、名前順の 1 枚目の `allow.ops` で判定する |
| TR-T06 | 境界 | ID の抽出が `^(PASS\|FAIL) ([A-Z]{2,6}-[TE][0-9]{2}[a-z]?)` に一致する行だけを拾い、一致しない行（`PASS ss-h01` / `PASS SS-X01` / 本文中の `PASS` を含む行）を ID として数えない。`SE-T01` のような新しい接頭辞は拾う |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 雛形から作る・白紙禁止 | 処理フロー 2、OUT ひな形、禁止事項 |
| メイン: 規約と logger ルールに従い共通 logger を読み込む | 処理フロー 3、logger.sh |
| メイン: テストの作成・実行・記録 | 処理フロー 4、OUT ひな形（test.template）、Script 処理「テストの書き方（規約）」 |
| メイン: 機械的な検査と記録 | 処理フロー 5 |
| メイン: logger の読み込みは 1 行・コピー禁止 | サンプル、禁止事項、Script 処理「読み込み行」 |
| 代替: 既存 sh は差分小さく・逸脱は直すか記録 | 処理フロー 6 |
| 代替: 静的検査ツール不在は省略を記録 | 処理フロー 5 |
| 例外: テスト失敗は直すか仕様の誤りとして返す | 禁止事項 |
| 例外: 仕様書・テスト観点が無ければ作らない | 処理フロー 1 |
| logger の提供: 実体と雛形はこのスキル配下・重複禁止 | 概要（パス）、OUT ひな形 |
| 共通ライブラリの提供: frontmatter 読み取り・テスト補助・テストランナーはこのスキル配下・重複禁止 | 概要、OUT ひな形、Script 処理（frontmatter.sh / run-tests.sh） |
| logger の提供: 利用中に変更しない・回帰 | 禁止事項 |
| 整合: ai-asset-creator からの利用・手順の再掲禁止 | 呼出条件、参照ナレッジ |
