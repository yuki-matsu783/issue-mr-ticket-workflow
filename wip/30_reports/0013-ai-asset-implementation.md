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

（0021 で集約）

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

## テスト結果

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
| D-1 | 0013 | 行動ルールの「効くタイミング」を frontmatter の `applies_when` キーで宣言した | 要件は「frontmatter で宣言する」とだけ定め、キー名を定める仕様（`markdown-docs` ルール・ルール体系の仕様）が未作成 | 0022 → `markdown-docs` ルールの要件、または `ルール体系.md` の仕様 |
| D-2 | 0013 | `task-types.tsv` の 1 行目をヘッダ（`#` 始まり）にした | 仕様は 6 列を定めるがヘッダの有無を定めない。`#` 始まりなら読み手がコメントとして飛ばせる | 0022（仕様に 1 行追記の候補） |

## 想定と異なった点

- 0014: 読み込み行の関数内で `BASH_SOURCE[1]` が呼び手のスクリプトを指すことを利用したが、`bash -c` から直接呼ぶと空になる（テストは必ずファイルから実行する）
- 0014: ログの出どころは `{{NAME}}` ではなく `$0` の basename（仕様どおり）。テストの期待を先に誤った

## 残課題

（0021 で集約）
