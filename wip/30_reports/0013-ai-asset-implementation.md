---
type: report
title: AI アセット実装 結果報告（チケット 0013〜0021）
description: issue #6（実装 1/3）で作成した設定・ルール・共通ライブラリ・提供コマンド・共通ステップスキル・テストの一覧と仕様の節との対応、テスト結果（機械 / eval 未実行）、検査結果、仕様からの逸脱、想定と異なった点、残課題。実装チケットごとに節を追記し、0021 で集約する
tags: [report, ai-asset-implementation, issue-6]
---

# AI アセット実装 結果報告

- 対象 issue: #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6
- PR: #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 計画: `wip/20_plans/0011-ai-asset-implementation-plan.md`（0023 で修正）
- 対象チケット: 0013（S1）、0014（S2-1・S3-1）、0016（S2-3）、0017（S2-4）、0018（S2-5）、0015（S2-2。0024 の後）、0019（S4-1）、0020（S4-2）、0021（S4-3・S5-1）

## 要約

（0021 で集約）

## 確かめられなかったこと

- 0018: HTML テンプレート 2 本のブラウザでの実表示（ライト / ダーク・サイドバーの sticky）。この環境にブラウザ操作が無く未確認。機械検査（RV001〜007）のみ通過

## 作成・更新したアセット（仕様の節との対応）

### 0013 S1: 設定・定義

| アセット | 仕様の節 | 備考 |
|---|---|---|
| `.gitattributes` | フック共通仕様 §8（`ai-asset-implementation.allow`） | `*.sh` `*.tsv` `*.json` `*.html` を `text eol=lf`。`*.md` は含めず既存ファイルの再正規化なし |
| `.claude/hooks/config/task-types.tsv` | `00-workflow-issue-mr-driven` 仕様 OUT ひな形（6 列）・対応表（15 行） | 1 行目は `#` 始まりのヘッダ（読み手はコメント行として飛ばせる）。対の相手は plan ↔ exec、メインエージェント担当 3 種は `-` |
| `.claude/hooks/config/scope-limits.json` | フック共通仕様 §8（構造・キー規則・初期値表） | `common` 5 キー、`types` 15 種すべてに `ops`。`commands.build-test` は空配列（外部ビルド・テストコマンドが無い。機構のテストは提供コマンド経路） |
| `.claude/rules/work-defaults.md` | 要件 `rules/work-defaults.md`「ルールが定める内容」 | 15 行の表。行動ルールなので 7 章スキーマの対象外。効くタイミングは frontmatter `applies_when` で宣言（`paths` に馴染まない行動ルールの宣言キー。`markdown-docs` ルール未作成のため暫定 — 逸脱欄参照） |

### 0014 S2-1・S3-1: shell-script の scripts と HK-T02

| アセット | 仕様の節 | 備考 |
|---|---|---|
| `20-common-step-shell-script/assets/script.template.sh` | OUT ひな形、Script 処理「読み込み行」「終了コード」 | 読み込み行は `__ss_load <lib> <policy>` の 1 行（関数定義と呼び出しを同じ行に置く）。`{{NAME}}` `{{PREFIX}}` `{{ARG_ERROR_NO}}` 等 8 個のプレースホルダ |
| `assets/test.template.sh` | OUT ひな形 | `test-lib` を `fatal` で読み、`make_tmp_repo` → ケース関数 → `finish` |
| `scripts/test-lib.sh` | OUT ひな形 test-lib.sh | `run_cmd` / `assert_*` / `make_tmp_repo` / `make_tmp_dir` / `make_restricted_path`（ラッパースクリプト方式）/ `hook_payload` / `tl_jq`（CR 除去）/ `finish` |
| `scripts/logger.sh` | Script 処理「logger.sh」1〜6 | `printf '%(...)T'` + コロン挿入、`LOGGER_ROOT` 基準、失敗はすべて握りつぶす |
| `scripts/frontmatter.sh` | Script 処理「frontmatter.sh」 | 純 bash（`read` とパラメータ展開・文字走査のみ）。`fm_extract` / `fm_get` / `fm_list` / `fm_has` |
| `scripts/run-tests.sh` | Script 処理「run-tests.sh」1〜5、TR001〜006 | 提供コマンド。`--filter` / `--ids` / `--timeout`。TR004・TR005 は終了 2、TR001・TR002・TR003・TR006 は 1 |
| `scripts/tests/test_{frontmatter,logger,templates,run_tests}.sh`、`.claude/hooks/tests/test_config_integrity.sh` | テスト観点 FR-T / LG-T / SS-T / TR-T、共通仕様 §11 HK-T02 | 5 本・20 ID |

### 0016 S2-3: commit.sh / push.sh / exclude-patterns.txt（切り替え境目 A）

| アセット | 仕様の節 | 備考 |
|---|---|---|
| `20-common-step-commit-push/assets/exclude-patterns.txt` | OUT ひな形「除外パターン一覧」 | `/` を含まないパターンは basename、含むパターンはルート相対パス全体に一致。追跡済みファイルへの誤爆は `wip/tmp/.gitkeep` のみ（gitignore 対象で実害なし） |
| `scripts/commit.sh` | Script 処理「commit.sh」1〜6、CP001〜004 | オプション順不同。`git commit -- <paths>` で指定パスだけをコミット。フッター検出は `Co-Authored-By:` / `Generated with|by` / `noreply@anthropic.com` / 🤖 / `claude-<model>` / `gpt-N` 等（本文の語「Claude Code」は拒否しない） |
| `scripts/push.sh` | Script 処理「push.sh」1〜4、CP005〜006 | 4 項目を全件実施。スキップ記録は `- 項目 N: 理由` の行。項目 4 は `logs/merge-state.json` の `state == ready` のときだけ判定し、スキップ不可 |
| `scripts/tests/test_{commit,push}.sh` | テスト観点 CP-T01〜07 | 一時リポジトリ + bare リモート |
| `wip/push-check-skip.md` | OUT ひな形「スキップ記録」 | 項目 3（HTML 未作成）を 0021 まで飛ばす |

### 0017 S2-4: ticket.sh と ticket.template.md（切り替え境目 B）

| アセット | 仕様の節 | 備考 |
|---|---|---|
| `20-common-step-ticket/assets/ticket.template.md` | OUT ひな形 | frontmatter 全項目・目的・DoD・作業内容・作業ログ 10 見出し（要件書の一覧が正）。`{{ }}` 15 個 |
| `scripts/ticket.sh` | Script 処理 create / start / complete / cancel / next、TK001〜007 | 状態変更は `commit.sh` 経由（overall-plan の create / start は除く）。拒否時は作業ツリーと index を戻す。frontmatter は `frontmatter.sh` だけで読む |
| `scripts/tests/test_ticket.sh` | テスト観点 TICKET-T01〜11 | 一時リポジトリで `commit.sh` 実物を呼ぶ。79 assert |

### 0018 S2-5: check-html.sh と report / plan テンプレート（切り替え境目 C）

| アセット | 仕様の節 | 備考 |
|---|---|---|
| `20-common-step-report-view/assets/report.template.html` | OUT ひな形（規約・節構成） | `reports-clean.template.html` を土台にサイドバー型。`<body data-template="report">`。必須（`data-required`）: `h1#title`・`#counts`・`#toc`・`dl#meta`・`#overview`（+ 重点依頼 3 枠）・`#unverified`・`#findings`・`#next`・`#surprises`・`#todo`。任意: `#conditions`・`#verified`。プレースホルダは要素内容の `{{名前}}` 33 個 |
| `assets/plan.template.html` | OUT ひな形、計画タスク共通の節 | 同じ CSS 系統でサイドバー型に統一（D18）。`<body data-template="plan">`。必須: `h1#title`・`#toc`・`dl#meta`・`#goal`・`#target`・`#approach`・`#verify`・`#tickets`・`#pending`。任意: `#risks`・`#out-of-scope` |
| `scripts/check-html.sh` | Script 処理 RV001〜007 | HTML コメントを純 bash で除いてから検査。RV006 はテンプレート（`data-template` 属性、無ければ置き場）の `data-required` 要素（id、無ければ tag@出現順）から導出。RV002 は `<a href>`・`data:`・コメント内を数えない |
| `scripts/tests/test_check_html.sh` | テスト観点 RV-T01〜06 | 36 assert。テンプレートを埋めた HTML と壊した HTML |

## テスト結果

### 0018

- `run-tests.sh --ids` → `OK: 9 本 / 44 件`（RV-T01〜06 を含む全 ID PASS、重複なし）
- テスト先行の記録: 初回 12 件 FAIL → (1) テンプレート冒頭コメントの `{{名前}}` の語が RV001 に当たった（コメント文言を変更）。(2) `@import url(...)` を url() と @import で二重に数えた（@import 文を除いてから url() を数える）。(3) `set -o pipefail` 下で data-required が 0 件の HTML に対し `grep` の非 0 が関数を落とし、RV-T04 で出力が空になった（`|| true` を追加。負のコントロールの経路そのものが壊れていたので RV-T04 が捕まえた実装バグ）
- 境目 C の確認（試し埋め）: `wip/tmp/trial/0011-ai-asset-implementation-plan.html`（計画書、id 15 件 / リンク 8 件）と `wip/tmp/trial/0003-investigation.html`（レポート、id 16 件 / リンク 9 件）が `check-html.sh` で `OK:`。正式な HTML は 0021 で作る
- ブラウザでの目視: この環境ではできない（レポート「確かめられなかったこと」に記録）
- eval: なし

### 0017

- `run-tests.sh --ids` → `OK: 8 本 / 38 件`（TICKET-T01〜11 を含む全 ID PASS、重複なし）
- テスト先行の記録: 初回 39 件 FAIL → 原因 2 つ。(1) テスト側: 一時リポジトリで `logs/` が gitignore されておらず完了検査の「未コミットなし」に引っかかった（実リポジトリでは gitignore 済み）。(2) 実装側: `commit.sh` が拒否したとき、ステージ済みの追加・削除が index に残り、次の完了検査を落とした → `do_commit` の失敗経路で `git reset -q -- <paths>` を追加（TICKET-T10 が捕まえた実装バグ）
- 境目 B の確認: このチケット自身を `ticket.sh complete 0017` で完了し、`ticket.sh next` が 0018 を返すことを確認（結果は 0018 の作業ログに記録）
- eval: なし

### 0016

- `run-tests.sh --ids` → `OK: 7 本 / 27 件`（CP-T01〜07 を含む全 ID PASS、重複なし）
- テスト先行の記録: 初回 CP-T05 が 2 件 FAIL → いずれもテスト側（`appendix` の語が項目 1 の一覧に含まれる / リモートのコミット判定に `grep 't'` を使っていた）。実装側の修正なし
- 境目 A の確認: このチケットの成果物コミットを `commit.sh` で実行（OK: 7 ファイルをコミットした（7db4bfc）。除外: なし）。チケットの完了コミットと push（`push.sh`、項目 3 はスキップ記録で通過）も提供コマンドで実施
- eval: なし

### 0014

- `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids` → `OK: 5 本 / 20 件`。PASS ID: FR-T01〜05 / HK-T02 / LG-T01〜05 / SS-T01〜04 / TR-T01〜05（仕様の表と一致、重複なし）
- テスト先行の記録: 初回実行で FR-T04・SS-T02・SS-T03 が FAIL → いずれもテスト側の期待の誤り（フィクスチャの先頭空白 / 雛形の assert 数 / ログの出どころは `$0` の basename）を直して全 PASS。実装側の修正は frontmatter の「キーと `:` の間の空白」対応 1 件
- eval: なし
- `bash -n`: 11 ファイル全て通過。shellcheck は本環境に無く省略（調査の残課題どおり）

### 0013

- 機械テスト: なし（HK-T02 は 0014 で `test-lib.sh` 完成後に書く）。代わりに次を手で確認: `jq . scope-limits.json` が通る / `types` のキー 15 個 = tsv の type 15 個 = work-defaults の表の type 15 個（`diff` で一致）/ `.gitattributes` 追加後の `git status` に既存ファイルの変更が出ない
- eval: なし

## 検査結果

### 0013

- プレースホルダ（`{{ }}` / `TODO` / `TBD`）: 0 件（対象 4 ファイル）
- frontmatter: `work-defaults.md` に `type` / `title` / `description` / `tags` / `keywords`
- 参照更新の再検索: 新規ファイルに旧名なし

### 0018

- プレースホルダ: `check-html.sh`・`test_check_html.sh` で 0 件（テンプレート 2 本は対象外。テンプレート自身は RV001 で不合格になることを RV-T01 で確認）
- CR: 0 件
- 参照更新の再検索: 新規ファイルに旧名なし

### 0017

- プレースホルダ: `ticket.sh`・`test_ticket.sh` で 0 件（テンプレートは対象外。create が全数を埋めることを TICKET-T01 で確認）
- CR: 0 件
- 参照更新の再検索: 新規ファイルに旧名なし

### 0016

- プレースホルダ: scripts 2 本・テスト 2 本・パターン 1 本で 0 件
- CR: 0 件
- 参照更新の再検索: 新規ファイルに旧名なし

### 0014

- プレースホルダ: scripts 4 本・テスト 5 本で 0 件（テンプレート 2 本は対象外。テンプレートの `{{ }}` は SS-T01 が埋めて検証）
- CR: 全ファイル 0 件
- 参照更新の再検索: 新規ファイルに旧名なし

## 仕様からの逸脱

| # | チケット | 内容 | 理由 | 反映先の候補 |
|---|---|---|---|---|
| D-3 | 0014 | 読み込み行の `fatal` ポリシーの最終行を `FATAL: <理由>` にした（`<接頭辞><番号>:` の形ではない） | 共有の 1 行は呼び手の接頭辞を知らず、台帳（§6）に該当する識別子が無い | 0022 → shell-script 仕様「読み込み行」に最終行の形を明記、または台帳に共通の識別子を追加 |
| D-4 | 0014 | 読み込み行の `deny` ポリシーの識別子は呼び手が `HOOK_DENY_ID` を設定する（既定 `WF009`） | `WFx09` の `x` は呼び手のフックで決まる | 0022 → 仕様に `HOOK_DENY_ID` を明記（2/3 のフック実装が使う） |
| D-5 | 0014 | `fm_get` はインラインマップ・フロー配列のキーに対して生の文字列を返す（仕様は「スカラー値」のみ） | 呼び手が形を確かめる用途に使える。エラーにする理由が無い | 0022（仕様に 1 行追記の候補） |
| D-6 | 0014 | HK-T02 は 1 つの ID で 8 個の assert を出す（枝番を使わない） | 仕様の 1 行に対応する検査が複数ある。ID は仕様の表との突合単位 | なし（運用の確認） |
| D-7 | 0016 | `git commit` 自体が失敗した（コミット時のフック等）ときの最終行を `CP004:` にした（表の条件「差分なし」とは異なる） | 仕様 5 は「出力を返して停止する」とだけ定め、識別子が無い。`OK:` / `CP<番号>:` の型を守るため最も近い CP004 を使った | 0022 → 台帳と仕様に CP007（コミット失敗）を追加する候補 |
| D-8 | 0016 | `git add` できないパス（綴り誤り・未追跡のまま削除・.gitignore 対象）を CP001（対象の誤り）・終了 2 にした | 仕様の CP001 は「対象未指定・一括指定」。対象の誤りの一種として扱った | 0022（CP001 の条件に 1 語追加の候補） |
| D-9 | 0016 | スキップ記録の行の形を `- 項目 N: <理由>`（`- N:` も可）に決めた | 仕様は「列挙された項目」とだけ定め、形が無い | 0022 → 仕様 OUT ひな形に形を明記 |
| D-10 | 0017 | `create` の記載事項の渡し方を `--title` / `--purpose` / `--dod`（複数）/ `--work`（複数）/ `--predecessors` / `--executor` / `--human-review(-reason)` / `--adversarial-review(-reason)` / `--allow-write` / `--allow-ops` に決めた | 仕様は `--field 値 ...` とだけ書き、名前を定めない | 0022 → 仕様 Script 処理 create にオプション名を明記 |
| D-11 | 0017 | `next` は作業中があるときも `type` / `skill` を返す（仕様は `current` のみ言及） | 呼び出し元が再開時にスキルを引けるようにする | 0022（仕様 IN/OUT サンプルに 1 例追加の候補） |
| D-12 | 0017 | `cancel` は frontmatter に `cancelled_at` / `cancel_reason` を追加して記録する | 「記載事項に取り消し理由と時刻を書き」の置き場が未定義。テンプレートに無い項目をスクリプトが追加する形 | 0022 → §9 / テンプレートに 2 項目を追加するか判断 |
| D-13 | 0017 | 種類が `task-types.tsv` に無い `create` は TK004・終了 2 | 該当する識別子が無い。「対象が見つからない」に寄せた | 0022（TK004 の条件に追記、または TK008 新設） |
| D-14 | 0017 | TICKET-T10 の「件名の規約違反を強制した場合」は再現せず、コミット時の検査（pre-commit フック）の失敗で `commit.sh` の拒否を作った | `ticket.sh` は件名を自分で組み立てるため、規約違反を外から強制する経路が無い | 0022 → テスト観点の文言を「commit.sh が拒否する状況（フック失敗等）」に |
| D-15 | 0017 | 「現在地に未完了の項目が残っていない」の判定を、現在地の節に `次:` / `未着手` の語がないこと、とした | 仕様は判定基準を定めない | 0022 → 仕様 complete 3 に判定語を明記 |
| D-16 | 0018 | テンプレートの種別を `<body data-template="report|plan">` 属性で持たせ、`check-html.sh` はそれで必須節の導出元を選ぶ（無ければ置き場のディレクトリで推定） | 仕様は「テンプレートの必須節」とだけ定め、対象 HTML がどのテンプレート由来かの識別方法を定めない | 0022 → 仕様 OUT ひな形に属性を明記 |
| D-17 | 0018 | 計画書テンプレートの節を「この計画で何をするか / 対象と範囲 / 方法とステップ / 検証 / チケット / リスクと復旧（任意）/ スコープ外（任意）/ 保留した点・対象なし」に決めた（Q5 の案 + 計画タスク共通節） | 仕様は「計画タスクの要件に従う」とだけ定める。必須節の一覧はテンプレートだけが持つ規約どおり、判断の経緯は DDR が必要 | 0022 → DDR（必須節の判断）を起こす候補 |
| D-18 | 0018 | 必須要素にはすべて `id` を付けた（サイドバーの `dl#meta`・`h1#title` を含む） | 仕様の「id が無ければ要素名と出現順」の経路はテンプレート側で使わない方が検査の誤差が無い。経路自体は実装してある | なし |
| D-1 | 0013 | 行動ルールの「効くタイミング」を frontmatter の `applies_when` キーで宣言した | 要件は「frontmatter で宣言する」とだけ定め、キー名を定める仕様（`markdown-docs` ルール・ルール体系の仕様）が未作成 | 0022 → `markdown-docs` ルールの要件、または `ルール体系.md` の仕様 |
| D-2 | 0013 | `task-types.tsv` の 1 行目をヘッダ（`#` 始まり）にした | 仕様は 6 列を定めるがヘッダの有無を定めない。`#` 始まりなら読み手がコメントとして飛ばせる | 0022（仕様に 1 行追記の候補） |

## 想定と異なった点

- 0014: 読み込み行の関数内で `BASH_SOURCE[1]` が呼び手のスクリプトを指すことを利用したが、`bash -c` から直接呼ぶと空になる（テストは必ずファイルから実行する）
- 0014: ログの出どころは `{{NAME}}` ではなく `$0` の basename（仕様どおり）。テストの期待を先に誤った

## 残課題

（0021 で集約）
