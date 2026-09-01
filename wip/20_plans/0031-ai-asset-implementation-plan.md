---
type: plan
title: 0031 AI アセット実装・テスト計画（2 回目）— 設計 0028〜0032 で仕様に書いた実装 9 件とテスト
description: 設計 0028〜0032 が仕様に書いた実装を伴う変更（識別子 CP007 / CP008 / RV008 / TK008 の付け替え、ticket.sh の完了検査と YAML エスケープ、hook_payload --session、HK-T15 の付番、SC-E への改名、テンプレートのガイド、SKILL.md のエラー表）を固定順のステップに割り、テスト ID の割付・許可範囲・自己変更するコマンドの復旧手順を決めて実装チケット 4 枚と全体まとめチケットを起こす
tags: [plan, ai-asset-implementation, issue-6]
keywords: [AI アセット実装計画, CP007, CP008, RV008, TK008, HK-T15, SC-E, hook_payload, YAML エスケープ, 見出し重複, skill.template.md, SKILL.md, エラー表, 全体まとめ]
---

# 0031 AI アセット実装・テスト計画（2 回目）

## 対象

- issue #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6 / PR #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 根拠とする仕様（設計 0028〜0030 と切れ目の反映 0032 の後が正。結果報告 `wip/30_reports/0028-ai-asset-design.md`）:
  - `10_spec/フック共通仕様.md` §6（台帳 CP001–008 / RV001–008 / TK001–008 / SC-E）・§11（HK-T15、HK-T05 / T10 / T11 の観点）
  - `10_spec/skills/20-common-step-commit-push.md`（commit.sh 2・4・5、push.sh 0、識別子表 CP001 / CP003 / CP007 / CP008、CP-T03 / T06 / T08）
  - `10_spec/skills/20-common-step-ticket.md`（create 1・3、complete 3、識別子表 TK004 / TK008、TICKET-T03 / T05 / T12）
  - `10_spec/skills/20-common-step-report-view.md`（check-html.sh の RV008、RV-T07）
  - `10_spec/skills/20-common-step-shell-script.md`（test-lib.sh の `hook_payload [--session]`・`make_counting_path`、テストの書き方（規約））
  - `10_spec/skills/20-common-step-ai-asset-creator.md`（`skill.template.md` の frontmatter と冒頭段落、AC-E04）、`20-common-step-requirement.md`（処理フロー 3 の小節の許容）、`20-common-step-spec.md`（SC-E01〜03）
- 実行者: 全チケットともメインエージェント（全体計画の方針）。人間レビューは実装の切れ目 1 回（承認④により opus 自己レビューで代替）、敵対的レビュー 1 回
- 前回の実装計画 0011 からの違い: 提供コマンド 4 本とテストランナーは稼働中で、切り替え境目は無い。代わりに「自分が使っているコマンドを自分で変える」復旧手順を持つ

## 判断点の決着（設計からの申し送り）

| 判断点 | 決定 | 根拠 |
|---|---|---|
| `ticket.sh` の現在地判定からコロン無しの `- 次` を外すか（レビュー G-6） | **外さない**（実装のまま。仕様も実装どおりに書かれた） | 現在地の「済 / 完了」の書き方で避けられ、誤検知の害は再実行で済む。判定を緩めると「- 次に 0031 へ」のような未完了行を見逃す |
| `scope.sh` の git 分岐で「サブコマンドが空なら read」にして `command -v git` を通すか（G-9） | **変えない** | `which git` / `type git` で代替できる。git 分岐を緩めると `git` 単独（ヘルプ表示）以外の未知形も read になる。フック本体は 2/3 で、そのとき実機の拒否ログを見て決める |
| CP001 の終了コード | 実装どおり **2**（対象の指定の誤り。仕様に明記済み） | 引数の誤りは呼び方を直すもので、検査未充足（1）ではない |
| `create` の YAML エスケープの対象と実装 | frontmatter に入る文字列値: `--human-review-reason` / `--adversarial-review-reason` の理由、`--allow-write` / `--allow-ops` の各要素、`--predecessors` の各要素。規則は `\` → `\\`、`"` → `\"`、改行 → 空白。**`yaml_escape` を新設**して使う（既存の `sed_escape` は sed の置換文字列用で `&` `\|` の変換と `\` の 4 連を含むため流用しない。`sed_escape` は `yaml_escape` + sed メタ文字の 2 段に組み替える）。`--executor` はテンプレートで引用符なし（`executor: {{EXECUTOR}}`）で、値は語彙（`main` / サブエージェント名）に限るのでエスケープ対象外。本文（title / purpose / dod / work）はエスケープしない | frontmatter は `frontmatter.sh` が二重引用符の規則で読む。本文は Markdown で規則が無い。`create` はテンプレートを bash の `${content//…}` で埋めるので sed を通らない |
| 見出し重複の判定 | `LOG_HEADINGS` の各見出しについて `^### <見出し>$` の行数が 2 以上なら未充足 1 件（見出し名を列挙） | 仕様 complete 3「同じ見出しが 2 回以上」。既存の完了済みチケットは遡って直さない（`20_done/` は検査対象外） |
| `hook_payload --session` の検証先 | `test_hook_common.sh` のセッション状態のケース（HK-T07 / T08 のうち `session_id` を読む方）で 2 つの `session_id` を作り、状態が分かれることを期待値にする | test-lib 自体はテスト ID を持たない（台帳 §6 の対象外）。使う側のテストで固定する |
| eval 定義の改名の範囲 | `20-common-step-spec.md` の SP-E01〜03 → SC-E01〜03（本文の参照 3 か所を含む）。`20-common-step-ai-asset-creator.md` に AC-E04 を追加 | 台帳と仕様のテスト観点に合わせる。他 3 本は変更なし |
| 全体まとめの実施方法 | `finalize.sh` は 3/3 で未作成。全体まとめチケット 0037 は `10-task-overall-summary` 仕様の処理フロー 2〜9 を手作業代替で順に行う: 2 別 issue 起票（候補 16 件の本文案を提示して承認を得る。承認④の範囲外なので提示して停止）→ 3 衝突確認（`git fetch origin`。あれば承認）→ 4 統括レポート（0037 の DoD × 根拠の表も写す）→ 5 PR 本文の `## 統括` 節 → 6 HTML 添付コメント 1 件 + 本文への URL 追記（失敗時はコミットのリンクで代替）→ 7 push → 8 承認③（最終確認）→ 9 片付け（`wip/` の `.gitkeep` 以外を削除しコミット・push）→ 最終ゲート（fetch して遅れ・衝突なし）→ `gh pr ready`。issue #6 への完了コメントは仕様に無いので行わない（`Closes #6` でマージ時に閉じる。「ルール 14 本」と要件 15 本の注記は統括レポートと `## 統括` 節に書く） | `10-task-overall-summary` 仕様 処理フロー・`finalize.sh` の手順。`ticket.sh complete` は overall-summary を TK005 で拒否するので、完了は片付けコミットに内包する。`overall-summary` の ops 上限には issue へのコメント（`issue-append`）が無い |

## 変更対象

| # | アセット | 新規/更新 | 仕様書の節 |
|---|---|---|---|
| A1 | `.claude/skills/20-common-step-ai-asset-creator/assets/skill.template.md` | 更新 | `ai-asset-creator` 仕様 OUT ひな形（frontmatter は name / description、冒頭段落は禁止事項の要約 — ガイドのコメントで説明） |
| A2 | `.claude/skills/20-common-step-requirement/assets/requirements.template.md` | 更新 | `requirement` 仕様 処理フロー 3（メインフローが長い要件書は `####` の小節を切ってよい — ガイド 1 行） |
| A3 | `.claude/skills/20-common-step-commit-push/scripts/commit.sh` | 更新 | 仕様 commit.sh 2（`-m` の値なし・`--amend` / `--no-verify`・不明オプション・ルートに移れない → CP007 終了 2。現在 CP001 の 4 か所: L71 / L76 / L77 / L90）、5（`git commit` 自体の失敗 → CP008 終了 1。現在 CP004 の 2 か所: L150 / L156）。CP008 化で `test_ticket.sh` の TICKET-T10（`CP004:` を期待する 3 assert）が落ちるので同じチケットで期待値を更新する |
| A4 | `.claude/skills/20-common-step-commit-push/scripts/push.sh` | 更新 | 仕様 push.sh 0（受け付けない引数・`git` / `jq` 不在・detached HEAD・ルートに移れない → CP007 終了 2。現在 CP005 が 1 か所、CP006 が 4 か所）。CP005 は検査未充足、CP006 はリモート拒否だけに |
| A5 | `.claude/skills/20-common-step-ticket/scripts/ticket.sh` | 更新 | 仕様 create 1・3（種類不正 → TK008、frontmatter 値の YAML エスケープ = `yaml_escape` 新設）、complete 3（固定見出しの重複）、識別子表 TK008（現在 TK004 を終了 2 で転用している 15 か所: L103 / 121 / 125 / 127 / 128 / 129 / 190 / 233 / 277 / 278 / 308 / 342 / 344 / 345 / 352 と、TK001 を誤用している 1 か所: L126「--title / --purpose / --dod は必須」）。TK004 は「番号で指定したチケットが期待する置き場に無い」（終了 1 の 6 か所）だけに |
| A6 | `.claude/skills/20-common-step-report-view/scripts/check-html.sh` | 更新 | 仕様 check-html.sh（引数・ファイル不正の最終行を `RV008:` に。現在 `RV:` が 4 か所） |
| A7 | `.claude/skills/20-common-step-shell-script/scripts/test-lib.sh` | 更新 | 仕様 OUT ひな形 `hook_payload <event> <tool_name> [--session <id>] <json-fields...>`（既定 `testsession`） |
| A8 | テスト: `commit-push/scripts/tests/test_{commit,push}.sh`、`ticket/scripts/tests/test_ticket.sh`、`report-view/scripts/tests/test_check_html.sh`、`shell-script/scripts/tests/test_{templates,run_tests,frontmatter}.sh`、`.claude/hooks/lib/tests/test_scope.sh`、`.claude/hooks/lib/tests/test_hook_common.sh` | 更新 | 各仕様のテスト観点（CP-T03 / T04 / T06 / T08、TICKET-T03 / T05 / T10 / T12、RV-T07、SS-T04、TR-T04、FR-T05、HK-T15、`--session`） |
| A9 | `.claude/skills/20-common-step-{commit-push,ticket,report-view,shell-script,spec,ai-asset-creator,feature-mr}/SKILL.md`（7 本） | 更新 | 各仕様のエラー識別子表と処理フロー（CP001 のディレクトリ・CP003 の 2 条件・CP004 は差分なしだけ・CP006 から環境の誤りを除く・CP007 / CP008 / TK008 / RV008 の行と範囲表記 `CP001〜008` / `TK001〜008` / `RV001〜008`、手順 2 の「ファイル単位」、スキップ記録は HEAD の版、complete の検査 3 条件、test-lib の関数一覧と `make_counting_path`、テストの書き方（規約）への参照）。spec の `SP-E01〜03` → `SC-E01〜03`、ai-asset-creator の `AC-E01〜03` → `AC-E01〜04`、feature-mr の「`push.sh` が `CP005:` `CP006:`」に CP007 を追記 |
| A10 | `.claude/evals/20-common-step-spec.md`、`.claude/evals/20-common-step-ai-asset-creator.md` | 更新 | `spec` 仕様 SC-E01〜03、`ai-asset-creator` 仕様 AC-E04 |
| A11 | `wip/30_reports/0033-ai-asset-implementation.md`（+ HTML） | 新規 | `10-task-ai-asset-implementation-exec` 仕様 OUT ひな形（最初の実装チケットが作り、以後のチケットが節を追記） |

## 許可範囲案

全チケット共通の上限は共通仕様 §8 の `ai-asset-implementation`（`.claude/docs/**` は deny）。宣言はステップごとに最小にする。

| チケット | write | ops |
|---|---|---|
| 0033（S1 + S2/S3 commit-push） | `.claude/skills/20-common-step-ai-asset-creator/assets/**`, `.claude/skills/20-common-step-requirement/assets/**`, `.claude/skills/20-common-step-commit-push/scripts/**`, `.claude/skills/20-common-step-ticket/scripts/tests/**`（TICKET-T10 の期待値の更新だけ）, `wip/**` | read, build-test, hook-test |
| 0034（S2/S3 ticket） | `.claude/skills/20-common-step-ticket/scripts/**`, `wip/**` | read, build-test, hook-test |
| 0035（S2/S3 report-view + test-lib + テスト追記） | `.claude/skills/20-common-step-report-view/scripts/**`, `.claude/skills/20-common-step-shell-script/scripts/**`, `.claude/hooks/lib/tests/**`, `wip/**` | read, build-test, hook-test |
| 0036（S4 + S5） | `.claude/skills/20-common-step-{commit-push,ticket,report-view,shell-script,spec,ai-asset-creator,feature-mr}/SKILL.md`, `.claude/evals/**`, `wip/**` | read, build-test, hook-test |
| 0037（全体まとめ） | `wip/**` | read, remote-read, remote-write:issue-create, remote-write:mr-edit, remote-write:mr-comment, remote-write:attach, remote-write:push, remote-write:draft-ready, merge-base |

- `wip/**` は `common.allow` により宣言によらず書ける。`read` / 提供コマンドは宣言によらず常に可（§8）。`run-tests.sh` は作業中チケットの `allow.ops` に `build-test`（`.claude/hooks/**` のテストを含めば `hook-test`）を要求するので、テストを回すチケットはすべて両方を宣言する
- 0037 の ops は `overall-summary` の上限（`scope-limits.json`）の語彙から選ぶ: 別 issue 起票 = `issue-create`、PR 本文 = `mr-edit`、添付コメント = `mr-comment` / `attach`、push = `push`、draft 解除 = `draft-ready`、衝突確認 = `merge-base`（フック本体は未登録だが、宣言は記録として正しく書く）
- **作業中（`10_doing/` にチケットがある間）の `push.sh` は項目 2 で止まる**（作業中チケットの `allow.ops` に `remote-write:push` を要求するが、`ai-asset-implementation` の上限に無く宣言できない）。push は各チケットの完了コミット直後（doing が空の時点）に行う（0011 と同じ運用）

## テスト方針

機械テストは `test-lib.sh` の assert に仕様の ID を渡し、`bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids` で回す。実装の前にテストを足して失敗を確認してから実装する（テスト先行）。テストの書き方は shell-script 仕様「テストの書き方（規約）」に従う（契約は `assert_eq` で exact、負のケースに正の期待値、秘密の実例を置かない）。

| テスト ID | ステップ | 種別 | 内容・実行方法 |
|---|---|---|---|
| CP-T08（新） | S3（0033） | 機械 | `test_commit.sh`: `-m` の値なし・`--amend`・不明オプション → 最終行 `CP007:`・終了 2 / pre-commit フックで失敗 → `CP008:` + git の出力・終了 1 / `logger.sh` を退避しても最終行の契約が守られる。`test_push.sh`: `--foo` → `CP007:` 終了 2、`git` または `jq` を PATH から外す（`make_restricted_path`）→ `CP007:` 終了 2、detached HEAD → `CP007:` |
| CP-T04（付け替え） | S3（0033） | 機械 | 既存の「`-m` の値なし → `CP001:`」assert（`test_commit.sh:116-120`）を `CP007:` に直し ID を CP-T08 へ移す。CP-T04 は差分なし・全除外だけに |
| TICKET-T10（期待値の更新） | S3（0033） | 機械 | `test_ticket.sh` の TICKET-T10 が期待する `CP004:`（3 assert）を `CP008:` に更新する（`commit.sh` の変更と同じチケット。0033 の `allow.write` に `ticket/scripts/tests/**`） |
| CP-T03（追記） | S3（0033） | 機械 | ディレクトリ引数・symlink → `CP001:` 終了 2（既存）に加え、`.gitignore` 対象を含む実パスでステージ後の除外が当たり `CP003:`（既存の 0025 のケースの ID を CP-T03 に揃える） |
| CP-T06（追記） | S3（0033） | 機械 | 未コミットの `push-check-skip.md` は効かず HEAD の版だけが効く（既存の 0025 のケースの ID を確認） |
| TICKET-T12（新） | S3（0034） | 機械 | 不明サブコマンド・不明引数・`task-types.tsv` に無い種類の `create`・4 桁でない番号 → 最終行 `TK008:`・終了 2。`find_ticket` 失敗は `TK004:` のまま（負のケースの正の期待値） |
| TICKET-T03（追記） | S3（0034） | 機械 | 固定見出しを 2 回持つ作業ログの `complete` が TK003 で「見出し「〜」が重複」を列挙。根拠欄ごと削った `- [x]`（既存） |
| TICKET-T05（追記） | S3（0034） | 機械 | `create --human-review-reason 'a"b\c & d'` と `--allow-write 'x/**,y"z'` で frontmatter が壊れず `fm_get human_review.reason` / `fm_list allow.write` が元の値を返す（`&` `\|` が変換されないことも見る）。仕様の TICKET-T05 は `cancel` の理由だけを書いており、`create` の往復は次の設計で仕様側に足す（保留した点） |
| TICKET-T10（追記） | S3（0034） | 機械 | `commit.sh` 拒否後に `git diff --cached --name-only` が空（index にも残らない） |
| RV-T07（新） | S3（0035） | 機械 | `test_check_html.sh`: 引数なし・存在しないファイル・`.html` 以外 → 最終行 `RV008:`・終了 2。`data-template` 無し + 置き場外の HTML → `RV006:` 終了 1（負のケースの正の期待値） |
| HK-T15（付け替え） | S3（0035） | 機械 | `test_scope.sh` の `case_order`（24）/ `case_declaration`（9）/ `case_ops`（8）/ `case_classify`（41）/ `case_load_errors`（11）= 93 assert の ID を HK-T11 → HK-T15 に。`case_glob`（20 assert）は HK-T11 のまま。冒頭コメント（2 行目）は「HK-T11（glob）と HK-T15（判定順・宣言・ops・分類・設定検査）」に書き換える。`run-tests.sh --ids` で HK-T15 が現れ、`grep -c HK-T11` は 21（20 assert + コメント 1 行） |
| SS-T04（追記） | S3（0035） | 機械 | `test_templates.sh`: `nop` でも `LOGGER_ROOT` が設定される（雛形の sh が `cd "$LOGGER_ROOT"` して落ちない）/ `fatal` の最終行が `FATAL: <理由>` で終了 2 / `deny` が `HOOK_DENY_ID`（未設定なら `WF009`）の deny JSON で終了 0 |
| TR-T04（追記） | S3（0035） | 機械 | `test_run_tests.sh`: `make_restricted_path` で `timeout` を外す → 最終行 `TR005:`・終了 2。不明な引数 → `TR004:`・終了 2（既存なら ID を確認） |
| FR-T05（追記） | S3（0035） | 機械 | `test_frontmatter.sh`: `make_counting_path` で `counted_calls` が 0（外部プロセスなし）/ `fm_get … predecessors` と `human_review` が生の文字列、`fm_get … allow` が空で戻り値 1 |
| HK-T07 / T08（`--session` の利用） | S3（0035） | 機械 | `test_hook_common.sh` のセッション状態のケースで `hook_payload --session s2 ...` を使い、`session_id` ごとに状態ファイルが分かれることを期待値に足す。既存の呼び出し（`--session` なし）は `testsession` のまま通る |
| SC-E01〜03（改名）・AC-E04（新） | S4（0036） | eval | `.claude/evals/20-common-step-spec.md` の ID と本文の参照を SC-E に、`20-common-step-ai-asset-creator.md` に AC-E04 の行（入力 / 期待 / 判定 / 添付）を追加。実行しない |
| 規約検査（受け入れ条件 6） | 各 S2 | 機械 | 変更した sh に `bash -n`、`shellcheck` が入っていれば実行。`run-tests.sh` の全件（現在 14 本 / 55 件）が通る |

受け入れ条件 4（SKILL.md と assets が仕様と 1:1）は機械テストを持たないため、0036 は DoD に「仕様の識別子表・処理フロー × SKILL.md の行」の対応表を作業ログに残す。

完了前の検査（exec 仕様）: プレースホルダ（`{{名前}}`・`TODO`・`TBD`）はテンプレート（`**/assets/*.template.*`）を対象外にする。frontmatter は SKILL.md が `name` / `description` の 2 項目、eval 定義が `type: eval` を持つことを見る。

## ステップ（固定順）

| 順 | ステップ | 内容 | 依存 | チケット |
|---|---|---|---|---|
| S1 | 設定・定義（テンプレート） | A1 `skill.template.md`（冒頭段落のガイドを目的の前に置き、frontmatter は 2 項目のまま）、A2 `requirements.template.md`（メインフローのガイドに小節の許容を 1 行） | — | 0033 |
| S2-1 | 中核 | A3 `commit.sh`（CP007 4 か所・CP008 2 か所）、A4 `push.sh`（CP007 5 か所。CP005 / CP006 の条件を限定）。テスト先行（CP-T08 を先に書いて失敗を確認） | S1 | 0033 |
| S3-1 | 中核の機械テスト | CP-T08・CP-T04（付け替え）・CP-T03・CP-T06、`test_ticket.sh` の TICKET-T10 の期待値 CP004 → CP008。`run-tests.sh --ids` → 全件 | S2-1 | 0033 |
| S2-2 | 中核 | A5 `ticket.sh`（TK008 15 + 1 か所、`yaml_escape` の新設と `create` への適用、`complete` の見出し重複）。テスト先行 | S3-1 | 0034 |
| S3-2 | 中核の機械テスト | TICKET-T12・T03・T05・T10（index）。`run-tests.sh --ids` → 全件。**0034 自身の `complete` が新しい検査を通ることが最初の実機確認** | S2-2 | 0034 |
| S2-3 | 中核 | A6 `check-html.sh`（`RV008:` 4 か所）、A7 `test-lib.sh`（`--session`）。テスト先行 | S3-1 | 0035 |
| S3-3 | 中核の機械テスト | RV-T07、HK-T15 の付け替え、HK-T07 / T08 の `--session`、SS-T04 / TR-T04 / FR-T05 の追記。`run-tests.sh --ids` → 全件（HK-T15 が一覧に現れる） | S2-3 | 0035 |
| S4 | スキル・eval | A9 SKILL.md 7 本、A10 eval 2 本 | S3-1〜S3-3 | 0036 |
| S5 | 参照更新 | 下記「参照更新一覧」の検索を再実行し期待値どおりを記録。`run-tests.sh --ids` の全件と、`check-html.sh` を実装結果レポートの HTML に通す | S4 | 0036 |
| — | 全体まとめ | `10-task-overall-summary` 仕様の 2〜9 を手作業代替（別 issue 起票 → 衝突確認 → 統括レポート → PR 本文 `## 統括` → HTML 添付 → push → 承認③ → 片付け → 最終ゲート → draft 解除） | 0033〜0036 | 0037 |

依存欄はチケットの `predecessors` と同じ値。0034 と 0035 は互いに独立だが、同時に作業中は 1 枚の規則により連番順（0034 → 0035）で進む。

## 参照更新一覧

改名するのは eval ID（SP-E → SC-E）と識別子の転用の解消。旧名の残存検索は S5 で再実行する（`grep -rn "<語>" .claude --include='*.md' --include='*.sh' --exclude-dir=docs`。件数は 2026-09-01 の実測）。検索語は行末に依存しない形にし、期待値は「残るもの」で書く。

| 名称・パス | 検索語 | 現在のヒット | 除外 | S5 の期待 |
|---|---|---|---|---|
| eval 接頭辞 | `SP-E` | 7 行 / 2 ファイル（`.claude/evals/20-common-step-spec.md` 6 行、`.claude/skills/20-common-step-spec/SKILL.md:17` 1 行） | なし | 0 件 |
| ai-asset-creator の eval 範囲 | `AC-E01〜03` | 1 件（`20-common-step-ai-asset-creator/SKILL.md:17`） | なし | 0 件（`AC-E01〜04` に） |
| check-html の番号無し識別子 | `"RV: ` | 4 件（`check-html.sh` L61 / 64 / 65 / 66） | なし | 0 件 |
| commit.sh の CP001 のうち引数の誤り | `result_ng 001 "(-m に|.* は存在しないオプション|不明なオプション|リポジトリルート)` | 4 件（L71 / 76 / 77 / 90） | 対象の指定の誤り（未指定・一括・glob・ディレクトリ・`git add` 失敗）の CP001 5 件は残る | 0 件 |
| commit.sh のコミット失敗を CP004 で返す箇所 | `result_ng 004 "git commit が失敗` | 2 件（L150 / 156） | なし | 0 件 |
| push.sh の CP005 / CP006 の転用 | `result_ng 005 "引数` / `result_ng 006 "(git が無い|リポジトリルート|現在ブランチ|jq が無い)` | 1 + 4 件（L61 / 64 / 65 / 68 / 136） | `result_ng 006 "リモートに拒否された` 2 件は残る | 0 件 |
| ticket.sh の TK004 転用 | `result_ng 004` の全件を数え、終了コード引数が `2` の行 | 21 件のうち終了 2 が 15 件（L103 / 121 / 125 / 127 / 128 / 129 / 190 / 233 / 277 / 278 / 308 / 342 / 344 / 345 / 352） | 終了 1 の 6 件（`find_ticket` 失敗・状態違い）は残る | `result_ng 004 … 2` が 0 件、`result_ng 004` は 6 件 |
| ticket.sh の TK001 誤用 | `result_ng 001 "--title` | 1 件（L126） | `result_ng 001 "プレースホルダ`（L174）は残る | 0 件 |
| SKILL.md のエラー表の旧記述 | `CP004:\` 差分なし・コミット失敗` / `CP001〜006` / `TK001〜007` / `RV001〜007` / `push.sh\` が \`CP005:\` \`CP006:\`` | commit-push 2 件（L16 / L59）、ticket 1 件（L16）、report-view 2 件（L8 / L16）、feature-mr 1 件（L47） | なし | 0 件 |
| test_scope.sh の HK-T11 | `HK-T11` | 114 件（`case_glob` 20 + 他 5 関数 93 + 冒頭コメント 1） | `case_glob` の 20 と冒頭コメント（両 ID を書く）は残る | 21 件 |

S5 で同じ検索を再実行し、期待値と一致することを件数で記録する。増えていれば新規の変更が旧名を持ち込んだと見て直す。

## ロックアウト対策

- `.claude/settings.json` にフックは登録されていない（2026-09-01 時点で `hooks` キーなし）。フックによるロックアウトの経路は無い
- 残る経路は**自分が使っている提供コマンドを自分で変える**こと。各チケットで次の順を守る:

| チケット | 変更するコマンド | 最初の操作（自分で確認） | 止まったときの復旧 |
|---|---|---|---|
| 0033 | `commit.sh` / `push.sh` | テスト全通過を確認してから、0033 の成果物を**変更後の** `commit.sh` でコミットする（`ticket.sh complete` も内部で呼ぶ）。`push.sh` は完了コミット直後（doing が空）に実行する — 作業中は項目 2 で止まる | `commit.sh` が契約外の出力で止まったら `git checkout <base_sha> -- .claude/skills/20-common-step-commit-push/scripts/commit.sh` で戻し、原因をテストに足してから再実装。`push.sh` が CP007 / CP005 の誤判定で止まったら同様に戻す |
| 0034 | `ticket.sh` | テスト全通過を確認してから、0034 自身の `ticket.sh complete 0034` を実行する（見出し重複検査・TK008 の付け替えを含む新版で自分を完了させる） | `complete` が誤判定で止まったら、判定の正誤を作業ログの実物で確かめる。誤判定なら `git checkout <base_sha> -- .claude/skills/20-common-step-ticket/scripts/ticket.sh` で戻して直す。正しい判定なら作業ログを直す |
| 0035 | `check-html.sh` / `test-lib.sh` | 実装結果レポートの HTML を新版の `check-html.sh` に通す。`run-tests.sh --ids` を全件回す（`test-lib.sh` の変更で既存 14 本が壊れていないことの確認） | `check-html.sh` が誤って RV008 を返すなら `git checkout <base_sha> -- <path>`。`test-lib.sh` の変更で既存テストが落ちたら `hook_payload` の既定値（`testsession`）が変わっていないかを先に疑う |

- 基準点への戻し: `git checkout <base_sha> -- <path>`（各チケットの `base_sha`）。`WORKFLOW_ENTRY_ENFORCE=0` 等の強制無効化は使わない（該当フックが無い）
- 0037 の片付け（`wip/` のリセット）は PR 本文の最終整形と統括レポートの push の後に行う（`reset` 後は `wip/` の記録が消える）

## リスク

| リスク | 影響 | 対処・巻き戻し |
|---|---|---|
| `ticket.sh complete` の見出し重複検査が既存の作業中チケット（0034 自身）の形に合わない | 0034 が完了できない | 0034 の作業ログはテンプレートの見出しを 1 回ずつだけ持つ形で書く。誤判定なら上の復旧手順 |
| `create` のエスケープで既存の呼び出し（`create-*.sh`）の値が変わって見える | `--allow-write` の glob に `\` は無いので実害なし。理由文の `"` は今まで壊れていた | TICKET-T05 で往復（書いて `fm_get` で読む）を固定 |
| `sed_escape` を `create` に流用して値を壊す（`&` → `\&`、`\` の 4 連） | TICKET-T05 の往復が落ちる。frontmatter が読めないチケットができる | `yaml_escape` を分けて新設し、`sed_escape` は `yaml_escape` + sed メタ文字の 2 段にする（判断点） |
| `test_ticket.sh` の TICKET-T10 が `CP004:` を期待したまま 0033 で `commit.sh` を変える | 0033 の全件 PASS が満たせない | 0033 の `allow.write` に `ticket/scripts/tests/**` を入れ、同じチケットで期待値を CP008 に更新する |
| CP005 → CP007 の付け替えで `push.sh` を呼ぶ側（`ticket.sh` は呼ばない。SKILL.md の案内のみ）が旧番号を期待 | 案内文の不一致 | S4 で SKILL.md を直す。スクリプト側に CP005 の分岐を持つ呼び手は無い（grep で確認） |
| `test-lib.sh` の `hook_payload` に `--session` を足す解析で、`key=value` の先頭が `--` のフィールド名と衝突 | 既存テストが壊れる | `--session` は第 3 引数位置に限定し、以降は従来の `key=value` 解析 |
| `test_scope.sh` の ID 付け替えで `run-tests.sh` の重複 ID 報告が出る | 出ない（同じ ID を複数ファイルに置かない） | `--ids` の出力で HK-T15 が 1 ファイルだけであることを確認 |
| 全体まとめの手作業代替で手順を飛ばす | 片付け漏れ・draft 解除の前提未確認 | 0037 の DoD に `10-task-overall-summary` 仕様の手順を 1 項目ずつ書く。承認⑥（issue コメント本文）は承認④の範囲外なので本文を提示して停止する |

巻き戻しは各チケットの `base_sha` 単位。

## 実装チケットと次の計画チケット

| チケット | 種類 | ステップ | 先行 |
|---|---|---|---|
| 0033 | ai-asset-implementation | S1・S2-1・S3-1（テンプレート 2 本、commit.sh / push.sh、CP-T08 / T04 / T03 / T06、TICKET-T10 の期待値。実装結果レポート 0033 を作る） | 0031 |
| 0034 | ai-asset-implementation | S2-2・S3-2（ticket.sh、TICKET-T12 / T03 / T05 / T10） | 0033 |
| 0035 | ai-asset-implementation | S2-3・S3-3（check-html.sh、test-lib.sh、RV-T07、HK-T15、`--session`、SS-T04 / TR-T04 / FR-T05） | 0034 |
| 0036 | ai-asset-implementation | S4・S5（SKILL.md 7 本、eval 2 本、参照更新、全件テスト） | 0035 |
| 0037 | overall-summary | 仕様の処理フロー 2〜9 の手作業代替（別 issue 起票・衝突確認・統括レポート・PR 本文・HTML 添付・push・承認③・片付け・draft 解除） | 0033, 0034, 0035, 0036 |

## 保留した点 / 対象なし

| 項目 | 決める時期 |
|---|---|
| `bash-script` ルールと shell-script 仕様「テストの書き方（規約）」の正の置き場 | 3/3（ルール作成時） |
| frontmatter キー名（`category` / `applies_when`）の正を `ルール体系.md` から読み手の仕様へ移すか | 3/3（`markdown-docs` ルール作成時） |
| §12 T7 / T8 の実機確認 | 2/3（フック登録時） |
| 別 issue 候補 16 件（フィードバック計画 0022）の起票と、issue #6 の受け入れ条件 1「ルール 14 本」と要件 15 本の食い違いの注記 | 0037（起票は本文案を提示して承認を得る。注記は統括レポートと PR 本文 `## 統括`） |
| 仕様の TICKET-T05 に `create` のエスケープ往復（記号入りの理由・glob）が無い（0034 はテストに足す） | 次の設計（3/3）で仕様側に揃える |
| `overall-summary` の ops 上限に issue へのコメント（`issue-append`）が無い。仕様の処理フローにも issue コメントは無いので矛盾ではないが、`00-workflow-issue-mr-driven` の旧 SKILL.md（6-5 notify-issue）とは食い違う | 3/3（ワークフロースキルの改訂） |
