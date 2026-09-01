---
type: report
title: AI アセット実装 結果報告（2 回目、チケット 0033〜0036）
description: issue #6（実装 1/3）の 2 回目の AI アセット実装。設計 0028〜0032 が仕様に書いた実装 9 件（識別子 CP007 / CP008 / RV008 / TK008、ticket.sh の完了検査と YAML エスケープ、hook_payload --session、HK-T15、SC-E、テンプレート、SKILL.md）とテストの実施結果、逸脱、残課題
tags: [report, ai-asset-implementation, issue-6]
---

# AI アセット実装 結果報告（2 回目）

- 対象 issue: #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6
- PR: #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 対象チケット: 0033（テンプレート 2 本・commit.sh / push.sh・CP-T08）、0034（ticket.sh）、0035（check-html.sh・test-lib・HK-T15）、0036（SKILL.md 7 本・eval・参照更新）
- 計画: `wip/20_plans/0031-ai-asset-implementation-plan.md`（0038 で修正済み）
- 前回の実装結果: `wip/30_reports/0013-ai-asset-implementation.md`（0013〜0021・0025）

## 要約

設計 0028〜0032 が仕様に書き戻した内容のうち実装を伴う 9 件を、計画 0031 の固定順（テンプレート → 中核 → 中核のテスト → スキル・eval → 参照更新）で実装する。各チケットはテストを先に書いて失敗を確認してから実装し、`run-tests.sh --ids` の全件と参照更新の検索で確かめる。「自分が使っている提供コマンドを自分で変える」チケット（0033 commit.sh / push.sh、0034 ticket.sh、0035 check-html.sh / test-lib.sh）は、変更後の自分のコマンドで自分をコミット・完了させることを最初の実機確認にする。

このレポートは 0033 が作り、0034〜0036 が節を追記する。

0036 で 4 チケットすべて完了。実装 9 件（設計 0028〜0032 の反映）はすべて実施し、`run-tests.sh --ids` は 14 本 / 59 件 PASS（前回 55 件 + CP-T08 + TICKET-T12 + RV-T07 + HK-T15）、参照更新の 11 検索語は計画の期待どおり。逸脱は D2-1〜D2-4 の 4 件で、いずれも仕様の振る舞いを変えない（設計への書き戻しは 3/3 へ）。

## 確かめられなかったこと

- shellcheck は環境に無く、静的検査は `bash -n` のみ（前回と同じ）
- `push.sh` の CP007（`git` 不在・detached HEAD・`jq` 不在）はテストの一時リポジトリで確認した。実運用の push は完了コミット直後に行うため、作業中に CP005 の項目 2 で止まる経路は実機では踏んでいない

## 作成・更新したアセット（仕様の節との対応）

### 0033

| アセット | 変更 | 仕様の節 |
|---|---|---|
| `20-common-step-ai-asset-creator/assets/skill.template.md` | 見出し直下に冒頭段落のガイド（禁止事項の要約 3〜5 行、frontmatter は name / description の 2 項目）と、埋め込み箇所を示すプレースホルダ（名前は PROHIBITIONS）、続けて `## 目的` | `ai-asset-creator` 仕様 OUT ひな形 |
| `20-common-step-requirement/assets/requirements.template.md` | 受け入れ基準のガイドに補足の後置と `####` 小節の許容を 1 文 | `requirement` 仕様 処理フロー 3 |
| `20-common-step-commit-push/scripts/commit.sh` | `-m` の値なし・`--amend` / `--no-verify`・不明オプション・ルートに移れない → CP007（4 か所）、`git commit` 自体の失敗 → CP008（2 か所。対処の案内を追記）。冒頭コメントに識別子と終了コードの対応 | 仕様 commit.sh 2・5、識別子表 CP007 / CP008 |
| `20-common-step-commit-push/scripts/push.sh` | 受け付けない引数・`git` 不在・ルートに移れない・detached HEAD・`jq` 不在 → CP007（5 か所）。CP005 は検査未充足、CP006 はリモート拒否だけに | 仕様 push.sh 0、識別子表 |
| `commit-push/scripts/tests/test_commit.sh` | CP-T08（`-m` 値なし・`--foo` → `CP007:` 終了 2 / `--amend` → CP007 / 対象未指定は `CP001:` のまま / pre-commit 失敗 → `CP008:` 終了 1・git の出力・コミット数不変 / logger 退避でも契約）。CP-T04 の `-m` 値なし・`--amend` を CP-T08 に移設 | CP-T08、CP-T04 |
| `commit-push/scripts/tests/test_push.sh` | CP-T08（`--force` → `CP007:` / `git` 不在 → CP007 / `jq` 不在（merge-state あり）→ CP007 / detached HEAD → CP007 / 正のコントロール: 環境が揃えば CP005） | CP-T08 |
| `ticket/scripts/tests/test_ticket.sh` | TICKET-T10 の期待値 `CP004:` → `CP008:`（3 assert） | TICKET-T10 |

### 0034

| アセット | 変更 | 仕様の節 |
|---|---|---|
| `20-common-step-ticket/scripts/ticket.sh` | `yaml_escape` を新設（`\` → `\\`、`"` → `\"`、改行 → 空白）し、`create` の理由 2 つと `json_list` の各要素（`--allow-write` / `--allow-ops` / `--predecessors`）に適用。`sed_escape` は `yaml_escape` + sed メタ文字の 2 段に組み替え（`set_field` / `cancel` の出力は不変） | 仕様 create 3 |
| 同 | TK004 を終了 2 で転用していた 15 か所と TK001 の誤用 1 か所（必須引数の欠落）を TK008 に。TK004 は `find_ticket` 失敗・状態違いの 6 か所（終了 1）だけ | 識別子表 TK004 / TK008、create 1 |
| 同 | `complete` 3 に固定見出しの重複検査（`^### 見出し$` が 2 行以上 → 「見出し「〜」が重複している（N 回）」） | 仕様 complete 3 |
| 同 | `create` / `start` / `complete` / `cancel` の `commit.sh` 拒否時に `git reset -q -- <パス>` で index も戻す | 仕様 Script 処理 冒頭（index にも残さない） |
| `ticket/scripts/tests/test_ticket.sh`（0034） | TICKET-T12（不明サブコマンド・種類不正・必須引数欠落・4 桁でない番号・不明引数 → `TK008:` 終了 2。`complete 9999` は `TK004:` 終了 1 の負のコントロール。拒否された `create` がファイルを残さない）、TICKET-T03（見出し重複 → 未充足 8 件）、TICKET-T05（記号入りの理由と glob の `create` → ファイルは YAML エスケープ済み・`fm_get` / `fm_list` が壊れずに読める・`executor` 不変）、TICKET-T10（拒否後に `git diff --cached` が空）。`frontmatter.sh` を読む読み込み行を追加 | TICKET-T03 / T05 / T10 / T12 |

### 0035

| アセット | 変更 | 仕様の節 |
|---|---|---|
| `20-common-step-report-view/scripts/check-html.sh` | 引数・ファイル不正の最終行 `RV:` → `RV008:`（4 か所: 引数の数・ルートに移動できない・ファイルが無い・`.html` 以外）。`result_ng2` のログを `RV: RV008: …` の二重にしない | report-view 仕様 Script 処理（終了コード）・識別子表 RV008 |
| 同（計画外・性能のみ） | `strip_comments` を bash の `${s%%<!--*}` ループから awk 1 回の index 走査に。振る舞いは同じ（4 本の HTML で出力が一致）。1 検査 7.0 秒 → 3.1 秒、`test_check_html.sh` 121 秒 → 41 秒 | 仕様の変更なし（検査 2〜7 の前処理） |
| `20-common-step-shell-script/scripts/test-lib.sh` | `hook_payload <event> <tool_name> [--session <id>] [key=value ...]`。`--session` は第 3 引数の位置でだけ解釈し、`session_id` の既定は `testsession` のまま。ヘッダの提供一覧に `make_counting_path` / `counted_calls` / `--session` を追記 | shell-script 仕様 OUT ひな形 test-lib.sh |
| `report-view/scripts/tests/test_check_html.sh` | RV-T07（新）: 引数なし・引数 2 つ・存在しないファイル・`.html` 以外 → 最終行 `RV008:` 終了 2。テンプレート不明の HTML は RV006 終了 1 で `RV008` を含まない（負のケースの正の期待値） | RV-T07 |
| `hooks/lib/tests/test_scope.sh` | `case_order`（24）/ `case_declaration`（9）/ `case_ops`（8）/ `case_classify`（41）/ `case_load_errors`（10）= 92 assert を HK-T11 → HK-T15。`case_glob`（20）は HK-T11 のまま。冒頭コメントは両 ID（`grep -c HK-T15` はコメント 1 行を含めて 93） | フック共通仕様 §11 HK-T11 / HK-T15 |
| `hooks/lib/tests/test_hook_common.sh` | HK-T07 の 3 セッション（sessA / sessB / `../evil`）を `hook_payload --session` で組み、`--session` が `tool_input` に入らないこと・既定が `testsession` のままを追加。HK-T08 にヘッドレス deny の決定ログが `--session` の ID で記録されるケース | HK-T07 / HK-T08 |
| `shell-script/scripts/tests/test_templates.sh` | SS-T04 追記: 雛形の読み込み行そのものでルート未解決の場所から `nop`（`LOGGER_ROOT` が設定される）/ `fatal`（最終行 `FATAL: …` 終了 2）/ `deny`（`WF009` の deny JSON 終了 0、`HOOK_DENY_ID=WF777` で差し替わる） | SS-T04 |
| `shell-script/scripts/tests/test_run_tests.sh` | TR-T04 追記: `timeout` を外した PATH で `TR005:` 終了 2（`TR004` を含まず、テストを実行しない） | TR-T04 |
| `shell-script/scripts/tests/test_frontmatter.sh` | FR-T05 追記: 計数 PATH で 4 関数を通して 0 回（正のコントロール `cat` 1 回）。`predecessors` / `human_review` への `fm_get` は生の文字列、`allow` は空で 1 | FR-T05 |

### 0036

仕様の行 × SKILL.md の行の対応表（行番号付き）はチケット 0036 の作業ログ「備考」にある。

| アセット | 変更 | 仕様の節 |
|---|---|---|
| `20-common-step-commit-push/SKILL.md` | 範囲 `CP001〜008`。手順 2 を**ファイル単位**・ディレクトリは CP001・`-m` の値なし / 不明オプションは CP007 に。手順 3 に CP003 の 2 条件（全対象が除外 / ステージ後の実パスに一致）と CP008。push 手順 0（引数・環境の誤り = CP007。スキップ記録では解消しない）。スキップ記録は **`HEAD` にある版**。エラー表: CP001 にディレクトリ・終了 2、CP004 は差分なしだけ、CP006 から環境の誤りを除き、CP007 / CP008 の行を追加 | commit-push 仕様 Script 処理 commit.sh 2〜5・push.sh 0〜2・エラー識別子表 CP001〜008 |
| `20-common-step-ticket/SKILL.md` | 範囲 `TK001〜008`。作成に TK008（不明な引数・種類・必須引数）と記号入りの値の扱い（YAML エスケープはコマンド）。完了検査の 3 条件（行頭 `- 次`・行頭 `- 未着手`・節内の `未着手`）、根拠欄なしの `- [x]`、固定見出しの重複。エラー表に TK008 | ticket 仕様 create 1・3、complete 3、エラー識別子表 TK008 |
| `20-common-step-report-view/SKILL.md` | 範囲 `RV001〜008`（description と仕様参照の 2 か所）。エラー表の最終行に `RV008:`（検査に入る前・終了 2） | report-view 仕様 Script 処理・検査表の `—` 行（RV008） |
| `20-common-step-shell-script/SKILL.md` | 手順 4 に test-lib の関数一覧（`make_tmp_dir` / `make_restricted_path` / `make_counting_path` + `counted_calls` / `hook_payload --session` / `tl_jq`）と「テストの書き方（規約）」6 項目への参照。手順 5 の `--filter` はルート相対パスの glob（例と TR001 の注意）。TR004 / TR005 の行に終了 2 | shell-script 仕様 OUT ひな形 test-lib.sh・テストの書き方（規約）・run-tests.sh・エラー識別子表 TR004 / TR005 |
| `20-common-step-spec/SKILL.md` | eval ID の範囲 `SP-E01〜03` → `SC-E01〜03` | spec 仕様 テスト観点（eval）SC-E01〜03 |
| `20-common-step-ai-asset-creator/SKILL.md` | eval ID の範囲 `AC-E01〜03` → `AC-E01〜04` | ai-asset-creator 仕様 テスト観点（eval）AC-E04 |
| `20-common-step-feature-mr/SKILL.md` | エラー表の `push.sh` の行に `CP007:`（引数・環境の誤り。スキップ記録では解消しない） | commit-push 仕様 エラー識別子表 CP007 |
| `.claude/evals/20-common-step-spec.md` | `SP-E` → `SC-E`（7 か所: 表 3 行 + 行内参照 1 + 判定基準 3）。frontmatter `type: eval` のまま | spec 仕様 SC-E01〜03 |
| `.claude/evals/20-common-step-ai-asset-creator.md` | AC-E04 の行（入力 / 期待 / 判定 / 添付）を AC-E01 の次（仕様の並び）に追加、判定基準に AC-E04 を追加（合格の割合は 0039 で「4 シナリオのうち 2 つ以上」に戻した） | ai-asset-creator 仕様 AC-E04 |

### 0039（切れ目のレビュー I2-1〜I2-22 の反映）

| アセット | 変更 | 仕様の節 / 指摘 |
|---|---|---|
| `20-common-step-shell-script/scripts/frontmatter.sh` | `__fm_clean` / `__fm_split` が二重引用符の中のバックスラッシュで次の 1 文字を逃がす（`\"` でクォートを閉じない・要素を割らない）。`__fm_unquote` が二重引用符スタイルの `\"` → `"`、`\\` → `\` を戻す（未知の `\x` は文字どおり残す） | ticket 仕様 TICKET-T05「`fm_get` で読み戻せる」/ I2-6・I2-7・I2-8 |
| `20-common-step-ticket/scripts/ticket.sh` | `need_val` を新設し、`create` の 12 オプションと `cancel --reason` で値の欠落を TK008・終了 2 に（従来は `set -e` 下の `shift` 失敗で**最終行を出さずに終了 1**）。`--executor` を語彙（`main` / モデル名）で検査。固定見出しの一致を `^### h[[:space:]]*$` に緩和。`do_commit` と重複する `git reset` 4 か所を削除 | ticket 仕様 Script 処理「最終行」・create 1・complete 3 / I2-3・I2-18・I2-14・I2-5 |
| `20-common-step-report-view/scripts/check-html.sh` | 参照の無くなった定数 `SCRIPT_PREFIX` を削除。読めないファイルを `RV008: ファイルを読めない` で拒否（仕様の「読めない」） | report-view 仕様 Script 処理 / I2-12・I2-15 |
| `20-common-step-shell-script/scripts/test-lib.sh` | `hook_payload ... --session` を値なしで呼んでも `$2: unbound variable` で落ちず、既定（`testsession`）のままになる | shell-script 仕様 OUT ひな形 / I2-21 |
| `20-common-step-commit-push/scripts/commit.sh` | 冒頭コメントの終了コードの分類で CP008 を「検査未充足」から分けた | commit-push 仕様 識別子表 CP008 / I2-24 |
| `.claude/evals/20-common-step-ai-asset-creator.md` | 判定基準を「4 シナリオのうち 2 つ以上」に戻した（他の eval と同じ基準。シナリオを増やしても合格の重みを変えない） | I2-20 |
| `ticket/scripts/tests/test_ticket.sh` | TICKET-T05 を実際の往復に（`create` の理由・3 要素の `allow.write`・`cancel` の理由が `fm_get` / `fm_list` で元の値）。TICKET-T10 の index 検査を 4 経路に。TICKET-T12 に値なしオプション 3 件と `--executor` の語彙。TICKET-T03 に末尾空白の見出しと前方一致の別見出し | TICKET-T03 / T05 / T10 / T12 / I2-5・I2-7・I2-8・I2-17 |
| `shell-script/scripts/tests/test_frontmatter.sh` | FR-T03 に二重引用符内のエスケープ（`fm_get` の往復・3 要素のフロー配列・`#` を含む値） | FR-T03 / I2-6 |
| `commit-push/scripts/tests/test_commit.sh` | CP001 の 4 assert を CP-T04 から CP-T03 へ（仕様の帰属）。CP-T08 の logger 不在の経路に最終行の `assert_eq`（成功側 `OK` / 失敗側 `CP002`）と stderr の検査 | CP-T03 / CP-T08 / I2-9・I2-10 |
| `report-view/scripts/tests/test_check_html.sh` | RV-T07 に「読めないファイル」（`chmod` が効く環境でだけ実行する形） | RV-T07 / I2-15 |

## テスト結果

### 0033

- テスト先行: 新しいテストを旧スクリプト（`git checkout 176117d -- commit.sh push.sh`）に対して実行 → `test_commit.sh` FAIL 4（CP-T08）、`test_push.sh` FAIL 4（CP-T08）、`test_ticket.sh` FAIL 3（TICKET-T10）。実装後: 3 本とも全 PASS
- 全件: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids` → `OK: 14 本 / 56 件`（前回 55 件 + CP-T08。assert 数: test_commit 65、test_push 44、test_ticket 80）。重複 ID の報告: CP-T08（`test_commit.sh` と `test_push.sh` の両方。仕様の CP-T08 が commit.sh / push.sh 双方の引数・環境の誤りを 1 行で定めるため、両ファイルに同じ ID を付けた。ランナーは報告するだけで不合格にはしない — 0035 の全件で気づき、ここを訂正）
- `bash -n` OK（commit.sh / push.sh）。shellcheck 不在

### 0034

- テスト先行: テストを先に足して実行 → `test_ticket.sh` FAIL 8（TICKET-T03 / T12）。実装後: 全 PASS（102 assert）
- 全件: `run-tests.sh --ids` → `OK: 14 本 / 57 件`（+ TICKET-T12）。重複 ID の報告は 0033 の CP-T08 と同じ（訂正: 当初「なし」と書いた）。`bash -n` OK
- 途中経過: `yaml_escape` の挿入が 1 回一致せず（perl の `q{}` でバックスラッシュが潰れた）、`create` が未定義関数を呼んで 68 assert が落ちた状態を経て、挿入し直して回復。作業ツリーの `ticket.sh` が壊れていた間は提供コマンドを使っていない

### 0035

- テスト先行: 6 本のテストを先に変更して旧実装で実行 → `test_check_html.sh` FAIL 4（RV-T07: 最終行が `RV:`）、`test_hook_common.sh` FAIL 7（HK-T07 / T08: 旧 `hook_payload` が `--session` を key=value と誤解釈し jq が失敗）。`test_scope.sh`（付け替え）/ `test_templates.sh` / `test_run_tests.sh` / `test_frontmatter.sh` の追記分は既存の振る舞いの確認なので旧実装でも PASS（設計が仕様に足した観点の追認）
- 実装後: `test_check_html.sh` 51 / `test_hook_common.sh` 108 とも全 PASS
- 全件（個別実行、`timeout 150` 付き）: 14 本すべて PASS。所要は cmdpos 24 s / hook_common 22 s / push_detect 17 s / scope 13 s / transcript 6 s / config_integrity 1 s / commit 13 s / push 17 s / **check_html 121 s** / frontmatter 6 s / logger 2 s / run_tests 30 s 前後 / templates 7 s / ticket 69 s
- `test_check_html.sh` が `run-tests.sh` の 1 本あたり上限 120 秒に当たっていた（`run-tests.sh --ids` の 1 回目は 400 秒の呼び出し上限で打ち切り）。原因は `check-html.sh` の `strip_comments`（bash の `${s%%<!--*}` が数十 KB の文字列で 1 回 0.2〜0.4 秒。`bash -x` に時刻を付けて計測）。awk の index 走査に置き換えて 1 検査 7.0 → 3.1 秒、`test_check_html.sh` 121 → 41 秒。置き換え前後で 4 本の HTML（レポート 2・計画 1・雛形 1）の出力が一致
- 全件（`run-tests.sh --ids`、置き換え後）: `OK: 14 本 / 59 件`（前回 57 件 + RV-T07 + HK-T15。一覧に RV-T07 / HK-T15 / HK-T11 が各 1 回）。重複 ID の報告: CP-T08（0033 から。上記の訂正のとおり）。3/3 の設計で「1 つのテスト ID を 2 ファイルに置いてよいか（置くなら CP-T08a/b のように分けるか）」を決める
- `bash -n` OK（check-html.sh / test-lib.sh）

### 0036

- 機械テストの変更なし（SKILL.md と eval だけ）。全件: `run-tests.sh --ids` → `OK: 14 本 / 59 件`。FAIL / TIMEOUT なし。重複 ID の報告は CP-T08 のみ（0033 から）

### 0039

- テスト先行: 4 本のテストを先に変更して実行 → `test_ticket.sh` FAIL 38（TICKET-T03 の末尾空白で 0002 が完了できず以降が連鎖、TICKET-T05 の往復 4 件、TICKET-T12 の値なし・executor 5 件）、`test_frontmatter.sh` FAIL 3（FR-T03 のアンエスケープと 3 要素の分割）。`test_commit.sh` は 68 PASS のまま（CP001 の ID 付け替えと最終行の `assert_eq` は現在の振る舞いを変えない = 固定力の追加）、`test_check_html.sh` は 51 PASS（読めないファイルの検査は本環境で `chmod 000` が効かず実行されない）
- 実装後: `test_ticket.sh` 117 / `test_frontmatter.sh` 41 とも全 PASS
- 全件: `run-tests.sh --ids` → `OK: 14 本 / 59 件`（ID は増えず assert が増えた: test_ticket 102 → 117、test_frontmatter 36 → 41、test_check_html 51、test_commit 68）。FAIL / TIMEOUT なし。重複 ID の報告は CP-T08 のみ
- 実機確認: 一時リポジトリで新旧の `ticket.sh` を切り替えて `create` / `start` / `cancel` の拒否後の `git diff --cached` を比較（どちらも空 → `do_commit` の `git reset` で足りている）。`hook_payload --session`（値なし）→ `testsession`、`--session s9 command=ls` → `s9` / `ls`
- `bash -n` OK（frontmatter.sh / ticket.sh / check-html.sh / test-lib.sh / commit.sh）
- eval 定義: SC-E01〜03（改名。定義済み・未実行）、AC-E04（新。定義済み・未実行）。実行していない
- 全チケットの機械テスト ID × 結果: TICKET-T01〜T12 / CP-T01〜T08 / RV-T01〜T07 / SS-T01〜T04 / TR-T01〜T05 / FR-T01〜T05 / LG-T*（logger）/ HK-T03〜T15（lib 分）/ 設定整合（`test_config_integrity.sh`）— すべて PASS（`run-tests.sh --ids` の PASS ID 一覧）

## 検査結果

### 0033

- プレースホルダ（二重波括弧形式 / TODO / TBD）: 変更したテンプレート以外の 4 ファイルで 0 件（テンプレート 2 本はプレースホルダを持つのが正）
- 参照更新（計画の参照更新一覧）: `result_ng 004 "git commit が失敗` 0 件 / `result_ng 005 "引数` 0 件 / `result_ng 006 "(git が無い|リポジトリルート|現在ブランチ|jq が無い)` 0 件 / `result_ng 001 "(-m に|存在しないオプション|不明なオプション|リポジトリルート)` 0 件。残るもの: CP006 2 件（リモート拒否）、CP001 5 件（対象の指定の誤り）— 計画の期待どおり
- ロックアウト対策の最初の操作: 0033 の成果物を変更後の `commit.sh` でコミットし、`ticket.sh complete 0033`（内部で `commit.sh`）を通す。push は完了コミット直後に `push.sh`

### 0034

- プレースホルダ: `test_ticket.sh` 1 件（既存の fixture）と `ticket.sh` 20 件は、テンプレートの置換対象の名前（`{{TITLE}}` 等）を文字列として持つもので、前回（0017）と同じく検査の除外。TODO / TBD 0 件
- 参照更新: `result_ng 004` は 6 件で終了 2 の行は 0 件（`grep -cE 'result_ng 004 "[^"]*" 2'`）、`result_ng 001` は 1 件（プレースホルダ残存のみ）、`result_ng 008` 16 件 — 計画の期待どおり
- ロックアウト対策の最初の操作: 0034 自身を変更後の `ticket.sh complete 0034` で完了させる（見出し重複検査・TK008 を含む新版）

### 0035

- プレースホルダ: 変更した 8 本のうち `check-html.sh` 1 件（検査 1 のメッセージが二重波括弧を文字として持つ）、`test_check_html.sh` 3 件（RV001 の fixture）、`test_templates.sh` 4 件（雛形の置換対象を埋める sed）— いずれも置換対象の名前を文字列として扱うもので、前回までと同じく検査の除外。TODO / TBD 0 件
- 参照更新: `check-html.sh` の `"RV: ` は 0 件、`test_scope.sh` の `HK-T11` は 21 件（case_glob 20 + 冒頭コメント 1）、`HK-T15` 93 件 — 計画の期待どおり
- ロックアウト対策の最初の操作: 変更後の `check-html.sh` で実装結果レポートの HTML を検査 → `OK: 検査 7 項目すべて通過（id 16 件 / リンク 9 件）`。引数なし → `RV008: 引数は HTML ファイル 1 つ` 終了 2、存在しないファイル → `RV008: ファイルが無い: …` 終了 2

### 0036（S5: 参照更新一覧の再実行）

`grep -rnE "<語>" .claude --include='*.md' --include='*.sh' --exclude-dir=docs` で計画の参照更新一覧を再実行した結果（すべて期待どおり）:

| 検索語 | 件数 | 計画の期待 |
|---|---|---|
| `SP-E` | 0 | 0 |
| `AC-E01〜03` | 0 | 0 |
| `"RV: ` | 0 | 0 |
| `result_ng 001 "(-m に\|.* は存在しないオプション\|不明なオプション\|リポジトリルート)` | 0 | 0 |
| `result_ng 004 "git commit が失敗` | 0 | 0 |
| `result_ng 005 "引数` / `result_ng 006 "(git が無い\|リポジトリルート\|現在ブランチ\|jq が無い)` | 0 / 0 | 0 |
| ticket.sh の `result_ng 004`（全件 / 終了 2 の行） | 6 / 0 | 6 / 0 |
| `result_ng 001 "--title` | 0 | 0 |
| SKILL.md の旧表記 `CP004:\` 差分なし・コミット失敗` / `CP001〜006` / `TK001〜007` / `RV001〜007` / feature-mr の `push.sh\` が \`CP005:\` \`CP006:\` \|` | 0 / 0 / 0 / 0 / 0 | 0 |
| `HK-T11` | 21 | 21 |

- プレースホルダ: 9 本のうち `report-view/SKILL.md` 2・`shell-script/SKILL.md` 1・`ai-asset-creator/SKILL.md` 1 は二重波括弧の表記に言及する既存の指示文（HEAD と同数。変更していない）。TODO / TBD: `spec/SKILL.md` 3・`ai-asset-creator/SKILL.md` 2・`evals/20-common-step-spec.md` 1 は「TBD の明示」の指示文（HEAD と同数）。新たな残存 0 件
- frontmatter: eval 2 本は `type: eval` のまま。SKILL.md 7 本の frontmatter（`name` / `description`）は report-view の description（`RV001〜008`）以外に変更なし

## 切れ目のレビュー（I2-1〜I2-28）への対応

実装 4 枚（0033〜0036）の切れ目で opus の敵対的レビューを 1 回行った（承認④による人間レビューの代替。全文は `wip/tmp/review-impl2-findings.md`）。確度 0.5 以上 22 件・0.5 未満 6 件。

| 指摘 | 確度 | 内容（要約） | 対応 |
|---|---|---|---|
| I2-1 | 0.95 | 0033 の DoD「レポート HTML は check-html.sh OK」が偽（完了コミット `853ff4f` 時点の HTML は `RV001` で落ちる） | 訂正（下記）。恒久対策は「完了検査は完了コミットの直前に、実際に完了させる版で回す」— 3/3 の実施タスク仕様へ |
| I2-2 | 0.90 | その修正 `146f218` が作業中チケット 0 枚の区間で行われ、逸脱にも残課題にも無い | 訂正（下記）に記載 |
| I2-3 | 0.90 | `ticket.sh` の `create` / `cancel` で値を取るオプションが末尾に来ると最終行を出さず終了 1（契約違反） | 0039 で `need_val` を新設し TK008・終了 2。TICKET-T12 に 3 ケース |
| I2-4 | 0.85 | I2-1 の機械置換でレポート正文の日本語が壊れた | 0039 で md / HTML とも文を直した |
| I2-5 | 0.80 | 0034 が足した `git reset` 4 か所は `do_commit` と重複で、テストが新旧を区別しない | 0039 で 4 か所を削除（`do_commit` に集約）。逸脱 D2-7 に記録 |
| I2-6 | 0.80 | `fm_list` がエスケープ付きフロー配列を壊す（3 要素が 2 要素に）。`scope.sh` の `allow.write` / `allow.ops` が通る経路 | 0039 で `__fm_split` / `__fm_clean` をエスケープ認識に。FR-T03 と TICKET-T05 に 3 要素のケース |
| I2-7 | 0.78 | TICKET-T05 が `fm_get` の誤った出力を期待値に固定していた | 0039 で期待値を元の値に戻し、`__fm_unquote` を直した |
| I2-8 | 0.75 | 仕様が求める `cancel` の理由の往復（`fm_get`）が未達・未検証 | 0039 で `fm_get cancel_reason` の assert を追加（実装の修正で通る） |
| I2-9 | 0.75 | 計画が決めた「CP-T04 は差分なし・全除外だけ」に反して CP001 の 4 assert が残り、逸脱に無い | 0039 で CP-T03 へ移設。逸脱 D2-6 に記録 |
| I2-10 | 0.75 | CP-T08 の「logger 不在でも最終行の契約」が `assert_exit` 1 本だけ | 0039 で成功側・失敗側とも最終行の `assert_eq` と stderr の検査を追加 |
| I2-11 | 0.70 | D2-4（awk 化）の「振る舞いは同じ」は不正確（末尾の改行が落ちる） | 訂正（下記）。実 HTML 13 本では出力・終了コードとも一致 |
| I2-12 | 0.70 | `check-html.sh` の `SCRIPT_PREFIX` がどこからも参照されない | 0039 で削除 |
| I2-13 | 0.70 | HK-T15 の assert 数 93 は `grep -c`（冒頭コメント込み）の値で、実際は 92 | 訂正（下記）。アセット表の数値も直した |
| I2-14 | 0.65 | 見出しの存在検査が完全一致に厳格化され、逸脱に無い | 0039 で `[[:space:]]*$` を許す形に。逸脱 D2-5 に記録。TICKET-T03 にケース追加 |
| I2-15 | 0.60 | 仕様が書く「読めない」ファイルの分岐が無い | 0039 で `[ -r ]` を追加。テストは `chmod` が効く環境でだけ走る（本環境では未実行） |
| I2-16 | 0.60 | ひな形に入れた `## 目的` を既存 SKILL.md 9 本が持たず、受け入れ条件 4 の「1:1」は本文構成については未達 | 訂正（下記）。ひな形に合わせるか仕様から落とすかは 3/3 で決める |
| I2-17 | 0.60 | TICKET-T10 の index 検査が `cancel` の 1 か所だけ | 0039 で 4 経路すべてに |
| I2-18 | 0.55 | `--executor` の語彙が検査されず、任意の文字列が無引用符で frontmatter に入る | 0039 で語彙検査（TK008）。TICKET-T12 にケース |
| I2-19 | 0.55 | 仕様 complete 3 に「固定見出しがすべてある」が無い（実装と SKILL.md にはある） | 3/3 の設計へ（仕様の追記） |
| I2-20 | 0.50 | AC-E04 の追加で合格の割合まで引き上げた（計画外） | 0039 で「4 シナリオのうち 2 つ以上」に戻した |
| I2-21 | 0.50 | `hook_payload --session`（値なし）が `unbound variable` で落ちる | 0039 で既定に倒す形に。回帰テストは `test-lib.sh` 自身のテスト ID が無いため置けず、3/3 へ（`--session` の振る舞いは HK-T07 が固定。`hooks/lib/tests/` はこのチケットの許可範囲外） |
| I2-22 | 0.50 | `--reason` の欠落は TK007・終了 1、`--title` の欠落は TK008・終了 2 と扱いが割れる | 3/3 の設計へ（仕様に TK007 の終了コードを明記してから片方に寄せる） |
| I2-23〜I2-28 | 0.30〜0.45 | 0033 / 0034 チケットの DoD 根拠に残る「重複 ID なし」/ `commit.sh` の冒頭コメントの分類 / `RS="\001"` の可搬性 / 全件テストの所要 / md と HTML の節構成の違い / `commit.sh` の `cd` 前のディレクトリ判定 | I2-24 は 0039 で修正。I2-23 は訂正（下記）。I2-25・I2-27・I2-28 は 3/3 の設計へ、I2-26 は別 issue（小改善）へ |

### 訂正（過去の記述の誤りを残す）

| # | 誤り | 正 |
|---|---|---|
| 訂正 1 | 0033 の DoD「実装結果レポート（+ HTML、check-html.sh OK）」の根拠 | 完了コミット `853ff4f` 時点の HTML は `RV001: プレースホルダが残っている: {{PROHIBITIONS}}×2` で落ちる。検査を通したのは次のコミット `146f218`。DoD の根拠は完了時点では成立していなかった（I2-1） |
| 訂正 2 | 0033〜0036 の逸脱は D2-1〜D2-4 の 4 件 | チケット外のコミット `146f218`（0033 完了と 0034 着手の間、作業中チケット 0 枚）が 1 件あった。レポート md / html の修正のみ（I2-2） |
| 訂正 3 | HK-T15 の付け替えは 93 assert | 実際の assert は 92（`case_order` 24 / `case_declaration` 9 / `case_ops` 8 / `case_classify` 41 / `case_load_errors` 10）。93 は冒頭コメント 1 行を含む `grep -c` の値（I2-13） |
| 訂正 4 | D2-4（`strip_comments` の awk 化）は「振る舞いは同じ」 | 末尾の改行が落ちる点だけ異なる（17 パターン中 2 パターン）。検査 1〜7 の結果には影響せず、実 HTML 13 本で出力・終了コードは一致（I2-11） |
| 訂正 5 | 受け入れ条件 4「SKILL.md と assets が仕様と 1:1」 | 識別子表・処理フロー・OUT ひな形の範囲では 1:1。本文構成は未達（ひな形が導入した `## 目的` を既存 SKILL.md 9 本が持たない）。ひな形に合わせるか仕様から落とすかは 3/3（I2-16） |
| 訂正 6 | 0033 / 0034 のチケット DoD 根拠「重複 ID なし」 | CP-T08 を 2 ファイルに置いた 0033 の時点から `重複 ID: CP-T08` が報告されている（完了済みチケットは書き換えないので、この表を正とする。I2-23） |

## 受け入れ条件との対応

issue #6 の受け入れ条件のうち、この実装（2 回目）が担う 3〜7 との対応。1・2 は前回（0013 の結果報告）と 0033〜0036 のテスト全件で変わらず PASS。

| # | 受け入れ条件 | この回の実装 | 根拠（テスト ID・検査） |
|---|---|---|---|
| 3 | `task-types.tsv` / `scope-limits.json` が種別表と一致し、3 データの整合テストが通る | 変更なし | `test_config_integrity.sh`（HK-T02）が全件 PASS に含まれる |
| 4 | 共通ステップスキル 9 本の SKILL.md と assets が仕様と 1:1 | 0033（`skill.template.md` / `requirements.template.md`）、0036（SKILL.md 7 本・eval 2 本） | チケット 0036 作業ログの対応表（仕様の行 × SKILL.md の行）、プレースホルダ・frontmatter 検査（新たな残存 0） |
| 5 | `ticket.sh` / `commit.sh` / `push.sh` / `check-html.sh` が仕様どおりに動き TICKET-T\* / CP-T\* / RV-T\* が通る | 0033（CP007 / CP008、CP-T08）、0034（TK008・`yaml_escape`・見出し重複、TICKET-T12）、0035（RV008、RV-T07） | TICKET-T01〜T12 / CP-T01〜T08 / RV-T01〜T07 全 PASS（`run-tests.sh --ids`） |
| 6 | シェルスクリプトが `20-common-step-shell-script` の規約に従う | 0035（test-lib `--session`、SS-T04 / TR-T04 / FR-T05、HK-T15 の付番） | SS-T01〜T04 / TR-T01〜T05 / FR-T01〜T05 / HK-T15 全 PASS。`bash -n` 全 sh OK（shellcheck 不在） |
| 7 | 仕様との食い違いは仕様書へ書き戻し DDR に残す | 実装フェーズは `.claude/docs/**` に書けないため、逸脱 D2-1〜D2-4 と申し送り（残課題）を 3/3 の設計へ | 「仕様からの逸脱」表・「残課題」 |

## 仕様からの逸脱

| # | チケット | 逸脱 | 理由 | 送り先 |
|---|---|---|---|---|
| D2-1 | 0033 | `skill.template.md` の冒頭段落をプレースホルダ（名前は PROHIBITIONS）として置いた（仕様は「冒頭段落は禁止事項の要約」とだけ書き、名前は定めない） | ひな形は埋める箇所を名前付きで示す規約 | なし（名前は実装の裁量） |
| D2-2 | 0034 | `fm_get` / `fm_list` はクォート内の `\"` / `\\` を解除せず、`create` がエスケープして書いた値はエスケープ済みの形で読み戻される（計画は「元の値を返す」と書いた） | `frontmatter.sh` の「クォートは外す」はエスケープ解除を含まない実装。`frontmatter.sh` は 0034 の許可範囲外、`test_ticket.sh`（TICKET-T05 の期待値）は 0035 の許可範囲外で、書き手と読み手を同じチケットで直せない | 3/3（`frontmatter.sh` のアンエスケープと TICKET-T05 の期待値を同じチケットで。仕様「クォートは外す」にエスケープ解除を含めることを設計で明記） |
| D2-3 | 0034 | TICKET-T12 の負のコントロールを `start 9999` ではなく `complete 9999` にした | `start` は作業中の有無（TK002）を先に見るため、対象不在の TK004 を観測できない | なし（テストの選び方） |
| D2-5 | 0034（0039 で解消） | 見出しの重複検査を足すとき、存在検査を前方一致 `^### h` から完全一致 `^### h$` に変えた（仕様 complete 3 は重複検査しか求めていない。末尾に空白や CR のある見出しが「無い」と誤判定される） | 重複を数えるために `grep -c` へ変えた副作用。逸脱として記録していなかった（レビュー I2-14） | 0039 で `^### h[[:space:]]*$` に緩め、TICKET-T03 に「末尾空白付きの見出しは通る」「`### 現在地の続き` は重複に数えない」を追加 |
| D2-6 | 0033（0039 で解消） | 計画は「CP-T04 は差分なし・全除外だけに」と決めたが、CP001 の 4 assert（未指定・一括・glob・存在しないパス）を CP-T04 のまま残した | 仕様 CP-T03 が CP001（ディレクトリ・シンボリックリンク）を持つことを見落とした。逸脱として記録していなかった（レビュー I2-9） | 0039 で 4 assert を CP-T03 に移し、`assert_contains` を最終行の `assert_eq` に替えた |
| D2-7 | 0034（0039 で解消） | `create` / `start` / `complete` / `cancel` の拒否時に `git reset` を足したが、`do_commit` が同じパスを既に戻しており冗長だった（旧版でも index は空。テストは新旧を区別しない） | 「index にも残らない」を呼び手側で担保しようとしたが、実装済みの経路を確かめていなかった（レビュー I2-5） | 0039 で 4 か所を外し（`do_commit` の 1 か所に集約）、TICKET-T10 の index 検査を 4 経路すべてに置いた |
| D2-4 | 0035 | 計画の変更対象 A6（`RV008:` 4 か所）に無い `strip_comments` の置き換え（bash → awk）を行った。仕様の振る舞いは変えていない | `test_check_html.sh` が `run-tests.sh` の上限 120 秒に当たり、DoD「全件 PASS」を満たせない。許可範囲（`report-view/scripts/**`）の内側で、出力の一致を 4 本で確認 | なし（3/3 の設計で「check-html.sh は awk を使う」を仕様の前提に足すか判断） |

## 想定と異なった点

- （0033）`run-tests.sh --filter` は「ファイル名」ではなくルート相対パスの glob で、`test_commit*` では 0 本（TR001）になる。`'*test_commit*'` で絞る。SKILL.md の例を確認する（0036 の対象外なら 3/3）
- （0034）`create` の値の往復（書いて読む）は `frontmatter.sh` のアンエスケープが無いと成立しない。計画は書き手（`ticket.sh`）だけを見ていた
- （0034）`start` は TK002（作業中あり）を TK004 より先に判定するので、作業中チケットがある状態では「対象不在」の負のコントロールに使えない
- （0035）0034 の申し送り「`frontmatter.sh` のアンエスケープは 0035 で」は実行できなかった。読み手を直すと TICKET-T05（`test_ticket.sh`、0035 の許可範囲外）の期待値も変えねばならず、許可範囲が書き手と読み手で別チケットに割れている（D2-2 の送り先を 3/3 に改めた）
- （0035）`run-tests.sh --ids` の全件が 1 回の呼び出し（上限 400 秒）で終わらなかった。`test_check_html.sh` が 121 秒で 1 本あたりの上限 120 秒に当たっていた（RV-T07 の追加分は 1〜2 秒で、以前から上限の際にあった）。`check-html.sh` の `strip_comments` を awk に置き換えて解消（計画外の性能修正。テスト結果 0035 に記録）

## 残課題

- （0033 → 0036 で解消）SKILL.md（commit-push）のエラー表に CP007 / CP008 の行を追加した
- （0034）0035 へ: `frontmatter.sh` の `__fm_unquote` で二重引用符内の `\"` → `"`、`\\` → `\` を解除し、TICKET-T05 の期待値を元の値に戻す（FR-T05 の追記と一緒に）
- （0034）3/3 へ: shell-script 仕様 `fm_get` の「クォートは外す」にエスケープ解除を含めることを明記
- （0035）3/3 へ: `frontmatter.sh` の `__fm_unquote` で二重引用符内の `\"` → `"`、`\\` → `\` を解除し、TICKET-T05 の期待値を元の値に戻す（書き手と読み手を同じチケットの許可範囲に置く）
- （0039）3/3 の設計へ（追加）: (f) 実施タスク仕様に「完了検査は完了コミットの直前に、実際に完了させる版で回す」（I2-1・I2-2）/ (g) 仕様 complete 3 に「固定見出しがすべてある」を明記（I2-19）/ (h) TK007 の終了コードを明記して TK008 と揃える（I2-22）/ (i) `test-lib.sh` 自身のテスト ID（`--session` の値なし・`make_counting_path` など）を shell-script 仕様に置く（I2-21）/ (j) `strip_comments` の `RS` の可搬性（gawk 以外での確認）（I2-25）/ (k) md 正文と HTML の節構成の違いをどう扱うか（I2-27）/ (l) `commit.sh` のディレクトリ判定が `cd` より前にある（I2-28）
- （0039）別 issue（小改善）へ: 全件テストの所要（`test_ticket.sh` が 117 assert で 60 秒台、全件 5 分）。1 本 120 秒の上限に対する余裕（I2-26）
- （0036）3/3 の設計へ（仕様・DDR の書き戻し）: (a) `fm_get` の「クォートは外す」にエスケープ解除を含める / (b) `check-html.sh` が awk を使う前提（純 bash の記述を改める）と `strip_comments` の置き換え（D2-4）/ (c) 1 つのテスト ID を 2 ファイルに置いてよいか（CP-T08。分けるなら `CP-T08` を commit / push で別 ID に）/ (d) `10-task-ai-asset-implementation-plan` に「値の往復が要る修正は書き手と読み手を同じチケットの許可範囲に置く」/ (e) `run-tests.sh` の対象本数の数え方（`.claude/hooks/tests/` も拾うので「14 本」= lib 5 + hooks/tests 1 + skills 8）
- （0036）2/3 へ（機構の続き）: 片付けの提供コマンド（全体まとめの `complete` 代替）が無く、0037 は仕様の処理フロー 2〜9 を手作業で代替する。`work-boundary.sh` / `merge-prep.sh` 相当が無いため、レビュー依頼・完了・draft 解除の記録は PR コメントと本文で残す
- （0036）別 issue 候補: `check-html.sh` の残りの所要時間（1 検査 2.5〜3 秒 = fork 約 20 回）と `run-tests.sh` の全件 5 分（直列実行）。テストが増えるほど 1 本 120 秒・全件 10 分の上限に近づく
