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

### 0019 S4-1: SKILL.md 4 本と ai-asset-creator のテンプレート 2 本

| アセット | 仕様の節 | 備考 |
|---|---|---|
| `20-common-step-ai-asset-creator/assets/skill.template.md` | ai-asset-creator 仕様 OUT ひな形 | frontmatter（name / description に Use when）+ 目的 / 手順 / 参照 / エラー時の対処。`{{ }}` 10 個 |
| `assets/eval.template.md` | 同 OUT ひな形 | 目的 / 評価シナリオ表（eval ID・入力・期待・判定・添付）/ 比較条件（with / without・回数）/ 判定基準 / 実行状況（未実行の明記）。`{{ }}` 11 個 |
| `20-common-step-shell-script/SKILL.md` | 同仕様 処理フロー 1〜6・OUT ひな形・参照ナレッジ・Script 処理（読み込み行・run-tests） | 手順 1〜7 が処理フロー 1〜6 + 読み込み行の使い方。エラー表は TR001〜006 + FATAL |
| `20-common-step-ticket/SKILL.md` | 同仕様 呼出条件・IN/OUT・OUT ひな形・参照ナレッジ・Script 処理 | 手順 1〜6 が next / create / start / complete / cancel / 再開。エラー表は TK001〜007 + CP の伝播 |
| `20-common-step-commit-push/SKILL.md` | 同仕様 IN/OUT・OUT ひな形・参照ナレッジ・Script 処理 | 手順がコミット 1〜5・push 1〜4。エラー表は CP001〜006 |
| `20-common-step-report-view/SKILL.md` | 同仕様 処理フロー 1〜6・OUT ひな形・参照ナレッジ・Script 処理 | 手順 1〜6 が処理フロー 1〜6。エラー表は RV001〜007 |

### 0020 S4-2: SKILL.md 5 本と assets 4 本・eval 定義 5 本

| アセット | 仕様の節 | 備考 |
|---|---|---|
| `20-common-step-ai-asset-creator/SKILL.md` | 同仕様 禁止事項・処理フロー 1〜7・OUT ひな形・参照ナレッジ | 手順 1〜7 が処理フロー 1〜7（置き場表を転記）。エラー表は停止条件 + TR006 / CPxxx の伝播 |
| `20-common-step-feature-mr/SKILL.md` + `assets/mr-body.template.md` | 同仕様 禁止事項・処理フロー 1〜6・OUT ひな形（4 節 + 命名規約）・参照ナレッジ | 手順 4 に commit.sh / push.sh、5 に gh / glab の MR 作成コマンド。テンプレートは 概要 / 変更点（空）/ 動作確認（レビュー完了のみ）/ `- Closes #N` |
| `20-common-step-issue/SKILL.md` + `assets/issue.template.md` + `assets/issue-addendum.template.md` | 同仕様 禁止事項・呼出条件・処理フロー 1〜6・GitLab の長文送信・OUT ひな形・参照ナレッジ | 手順 2 に検索コマンド 4 本、4・5 に作成・追記コマンド。issue = 種別 / 概要 / 詳細 / 受け入れ条件 / スコープ外 / 優先度、addendum = 区切り / 日付 / 経緯 / 内容（+ 受け入れ条件（任意）→ D-21） |
| `20-common-step-requirement/SKILL.md` + `assets/requirements.template.md` | 同仕様 禁止事項・処理フロー 1〜7・OUT ひな形・参照ナレッジ | 手順 1〜7 が処理フロー 1〜7。テンプレートは frontmatter 5 項目 + 7 章（受け入れ基準は メイン / 代替 / 例外 / 整合）、各章に 1 行ガイドのコメント、`{{ }}` 29 個 |
| `20-common-step-spec/SKILL.md` | 同仕様 禁止事項・処理フロー 1〜6・種別ごとの節構成・OUT ひな形（持たない）・参照ナレッジ | 手順 3 に節構成の表とエラー識別子の規則を転記。テンプレートは仕様どおり持たない |
| `.claude/evals/20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}.md` | 各仕様 Script 処理「テスト観点（eval）」、ai-asset-creator 仕様 OUT ひな形（eval.template） | `eval.template.md` のコピー + プレースホルダ置換で生成。AC-E / FM-E / IS-E / RQ-E / SP-E 各 3 行、with / without × 3 回、実行状況 **未実行** |

### 0015 S2-2: hooks/lib 5 本（hook-common / cmdpos / scope / push-detect / transcript）

| アセット | 仕様の節 | 備考 |
|---|---|---|
| `.claude/hooks/lib/hook-common.sh` | フック共通仕様 §2（入力・`tool_class`）・§3（deny / ask / additionalContext の出力、`redact`、`trap ERR` の fail-closed）・§4（`hook_enforce_enabled`・`disabled` 記録）・§5（`decisions.jsonl` のスキーマ、`logs/sessions/<session_id>/` の原子的更新）・§10（ヘッドレスで ask → deny） | 提供: `hook_init` / `hook_read_input`（1 回の jq で共通フィールドを US 区切りで取得）/ `hook_field` / `tool_class` / `hook_enforce_enabled` / `hook_headless` / `redact` / `hook_jq` / `hook_record` / `hook_deny` / `hook_ask` / `hook_notify` / `hook_inject` / `hook_allow` / `hook_disabled` / `hook_fail` / `hook_fail_closed` / `hook_require_jq` / `hook_session_read` / `hook_session_write` / `hook_rel_path` / `hook_doing_ticket`。JSON の組み立て・redact・時刻は純 bash（fork なし） |
| `.claude/hooks/lib/cmdpos.sh` | §7-1〜7-8（前処理・分割・ラッパー・正規化・opaque・PowerShell・縮退・提供コマンド） | 正規化部は参考実装 `CommandPosition.sh` から流用、走査部はセグメント列 API（`CP_EXE` / `CP_ARGS` / `CP_SUBCMD` / `CP_REDIRECTS` / `CP_WRITE_TARGETS` / `CP_OPAQUE` / `CP_PROVIDED` / `CP_GITLIKE`、`CP_DEGRADED`）に書き直し。`2>&1` の fd 複製と `&>` を保護してから分割。PowerShell はヒアストリング除去・バッククォート継続の結合・`\` → `/`・呼び出し演算子 `&` の除去を前処理 |
| `.claude/hooks/lib/scope.sh` | §8（`scope-limits.json` の検査と読み込み、判定順 (1)〜(7)、glob 規則、宣言の絞り込み、ops の分類）・§9（`frontmatter.sh` で `ticket_type` / `allow.write` / `allow.ops`） | 提供: `scope_load` / `scope_load_ticket` / `scope_load_approvals` / `scope_match` / `scope_resolve` / `scope_op_declared` / `scope_classify`。glob は正規表現に変換（`*` → `[^/]*`、`**/` → `(.*/)?`）してキャッシュ。設定の検査（common 5 キー必須・`ops` 必須・未知キー拒否）は 1 回の jq |
| `.claude/hooks/lib/push-detect.sh` | `post-push-compact-prompt` 仕様「push 検知」1〜3、§11 HK-T13 | `push_detect <cmd> <tool_response> [shell] [root]`。前置フィルタ（fork ゼロ）→ cmdpos（提供コマンド `push.sh` か実行位置の `git push`。縮退時は部分一致）→ 終了コード → HEAD == `@{upstream}` → `origin/<b>` → 終了コード 0 の縮退 → `push-state.json[b].sha` != HEAD |
| `.claude/hooks/lib/transcript.sh` | `post-push-usage-report` 仕様 `--accumulate` 2・5、§11 HK-T14 | `transcript_aggregate <path> [cursor]`。カーソル（行数）以降を 1 回の jq で集計（4 指標・`tool_calls`・`responses`・タイムスタンプ列・`parse_errors`・`new_offset`）。ファイルパスを jq に渡し中身を引数に載せない。エポック変換は strptime に依存しない自前実装 |
| `.claude/hooks/lib/tests/test_{hook_common,cmdpos,scope,push_detect,transcript}.sh` | §11 HK-T03（lib 部分）/ T04 / T05 / T06 / T07 / T08 / T10 / T11 / T12 / T13 / T14 | 雛形 `test.template.sh` 由来。ドライバ sh を一時リポジトリに置いて別プロセスで実行（fail-closed・fork ゼロ・PATH 制限を観察できる形）。フック本体が要る HK-T01・T09・T03 の登録部分は 2/3 |
## テスト結果

### 0015

- `run-tests.sh --ids` → `OK: 14 本 / 55 件`（新規 PASS ID: HK-T03 / T04 / T05 / T06 / T07 / T08 / T10 / T11 / T12 / T13 / T14。既存の 44 件も PASS、重複なし）。個別実行の assert 数: hook_common 79 / cmdpos 135 / scope 105 / push_detect 26 / transcript 21
- テスト先行の記録: 初回は 5 本すべてで FAIL（hook_common は無限ループでタイムアウト）→ 実装側の修正 4 件: (1) `redact` の `Bearer <語>` パターンが置換後の `***` に再一致して無限ループ（HK-T10 が捕まえた。除外文字に `*` を追加）。(2) `scope_classify` の `local i="$1" exe="${CP_EXE[$i]}"` が `set -u` で未定義参照（`local` の全語が代入前に展開される。2 文に分割）。(3) `ln -s a b` の `-s` を truncate 用の値付きオプションとして読み飛ばし宛先を落とした（値付きオプションをコマンドごとに分けた）。(4) Windows の jq 1.6 では `fromdateiso8601`（strptime）が使えずタイムスタンプが全部 null になった（参考実装と同じ自前の暦計算に置換。HK-T14 が捕まえた）。テスト側の誤り 6 件（エポック定数・`parse_errors` の期待値・`env PATH="" bash` は bash 自体が見つからない・上流のテストの順序・サブシェルで解析した状態を親で参照・`git 'commit'` は既知の制約）
- 性能の観点: 前置フィルタと cmdpos は外部プロセスを起動しない（PATH を空にしても `command not found` が出ないことを HK-T13 で確認）
- `bash -n`: 10 ファイル全て通過。shellcheck は本環境に無く省略
- eval: なし
- 2/3 送り: HK-T01（`settings.json` の登録照合）・HK-T09（登録ラッパーの deny）・HK-T03 の登録部分（フック本体の停止経路）はフック本体と登録が要るため書いていない### 0020

- 機械テスト: なし（SKILL.md・テンプレート・eval 定義は指示文。`run-tests.sh` の対象に変更なし）
- eval: 5 本を定義（AC-E01〜03 / FM-E01〜03 / IS-E01〜03 / RQ-E01〜03 / SP-E01〜03）。実行はしていない（定義のみ。人間の明示的な依頼時に実行）
- 対応の確認: 各 SKILL.md の手順番号が仕様の処理フロー番号と一致（対応表は 0020 チケットの作業ログ）。Claude Code が 5 本のスキルを認識した（セッションの利用可能スキル一覧に現れた）

### 0019

- 機械テスト: なし（SKILL.md とテンプレートは指示文。eval は 0020 で ai-asset-creator 分を定義）
- 対応の確認: 各 SKILL.md の節（手順 / 参照 / エラー時の対処）と仕様の節（処理フロー / OUT ひな形 / 参照ナレッジ / Script 処理）の対応は上表。規約（bash・logger・frontmatter の中身）は再掲せず参照にした
- Claude Code が 4 本のスキルを認識した（セッションの利用可能スキル一覧に `20-common-step-{commit-push,shell-script,ticket}` が現れた。report-view は次のプロンプトで反映）

### 0018

- `run-tests.sh --ids` → `OK: 9 本 / 44 件`（RV-T01〜06 を含む全 ID PASS、重複なし）
- テスト先行の記録: 初回 12 件 FAIL → (1) テンプレート冒頭コメントの `{{名前}}` の語が RV001 に当たった（コメント文言を変更）。(2) `@import url(...)` を url() と @import で二重に数えた（@import 文を除いてから url() を数える）。(3) `set -o pipefail` 下で data-required が 0 件の HTML に対し `grep` の非 0 が関数を落とし、RV-T04 で出力が空になった（`|| true` を追加。負のコントロールの経路そのものが壊れていたので RV-T04 が捕まえた実装バグ）
- 境目 C の確認（試し埋め）: `wip/tmp/trial/0011-ai-asset-implementation-plan.html`（計画書、id 11 件 / リンク 8 件。0018 のチケットには 15 件と誤記）と `wip/tmp/trial/0003-investigation.html`（レポート、id 16 件 / リンク 9 件）が `check-html.sh` で `OK:`。正式な HTML は 0021 で作る
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

### 0015

- プレースホルダ（`{{ }}` / `TODO` / `TBD`）: 0 件（対象 10 ファイル）
- frontmatter: 対象なし（sh のみ）
- 参照更新の再検索: 新規 10 ファイルに旧名（`workflow-lib.sh` / `work-boundary.sh` / `merge-prep.sh` / `10-work-` / `20-task-gh-`）と参考固有の記述（`.claude/hooks/.state`・`shell-script-style`）なし。CR なし
- H1（redact を通す前にログへ書く経路が無い）: `hook-common.sh` の `log_*` 呼び出しは `hook_record` 内の 1 か所だけで、`target` は `__hc_redact_to_reply` 済み。deny / ask / additionalContext の本文と `decisions.jsonl` の `target` / `note` はすべてヘルパの内側で redact を通る（HK-T06 が記録と出力の両方を検査）
- H2（無視リストは `logs/**`）: `scope_resolve` の (1) で `logs/**` を対象外にし、`state_files` だけ除外しない（HK-T11 で `logs/sh/x.log` = skip、`logs/mr.json` = 判定続行を確認）
- 許可範囲: `git diff --name-only d36cfea` は `.claude/hooks/lib/**` と `wip/` のみ### 0020

- プレースホルダ（`{{ }}` / `TODO` / `TBD`。`assets/*.template.*` 4 本は対象外）: 0 件（対象 10 ファイル。規約の説明文中の語を除く）
- frontmatter: SKILL.md 5 本の `name` がディレクトリ名と一致、description に `Use when`。eval 5 本は `type: eval` + title / description / tags / keywords。`requirements.template.md` は `type: requirement`（D-20）
- 参照更新の再検索: 新規 14 ファイルに旧名（`workflow-lib.sh` / `work-boundary.sh` / `merge-prep.sh` / `10-work-` / `20-task-gh-`）なし。CR なし
- 許可範囲: `git diff --name-only 71956c3` は 5 スキルディレクトリ・`.claude/evals/`・`wip/` のみ

### 0013

- プレースホルダ（`{{ }}` / `TODO` / `TBD`）: 0 件（対象 4 ファイル）
- frontmatter: `work-defaults.md` に `type` / `title` / `description` / `tags` / `keywords`
- 参照更新の再検索: 新規ファイルに旧名なし

### 0019

- プレースホルダ: SKILL.md 4 本で `{{大文字}}` / TODO / TBD 0 件（テンプレート 2 本は対象外。`{{名前}}` の語は説明として使用）
- frontmatter: 4 本とも `name` / `description`（Use when を含む）
- 提供コマンドの起動はすべてルート相対表記（`grep -nE 'bash (\./|/)'` 0 件）
- CR: 0 件。参照更新の再検索: 新規 6 ファイルに旧名なし

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
| D-19 | 0019 | SKILL.md の frontmatter は `name` / `description` のみ（`type` / `title` 等の OKF 項目を付けない） | `ルール体系.md` の `markdown-docs`（未作成）が「SKILL.md の既存 description は上書きしない」「対象外」に言及し、既存の 2 スキルも name / description のみ。Claude Code のスキル発見は name / description を読む | なし（`markdown-docs` ルール作成時に再確認） |
| D-1 | 0013 | 行動ルールの「効くタイミング」を frontmatter の `applies_when` キーで宣言した | 要件は「frontmatter で宣言する」とだけ定め、キー名を定める仕様（`markdown-docs` ルール・ルール体系の仕様）が未作成 | 0022 → `markdown-docs` ルールの要件、または `ルール体系.md` の仕様 |
| D-2 | 0013 | `task-types.tsv` の 1 行目をヘッダ（`#` 始まり）にした | 仕様は 6 列を定めるがヘッダの有無を定めない。`#` 始まりなら読み手がコメントとして飛ばせる | 0022（仕様に 1 行追記の候補） |
| D-20 | 0020 | `requirements.template.md` の frontmatter を `type: requirement` にした（仕様 requirement 処理フロー 2 は `type: requirements`） | 既存の要件書 42 本がすべて `type: requirement`。テンプレート由来の新規文書が既存と揃わない害の方が大きい | 0022 → 仕様の表記を `requirement` に修正 |
| D-21 | 0020 | `issue-addendum.template.md` に「受け入れ条件（追加分）」の小節（任意。不要なら削る）を置いた | 仕様 OUT ひな形は 4 項目（区切り・日付・経緯・内容）だが、追記した依頼を DoD に落とす鍵が要る | 0022 → 仕様 OUT ひな形に「受け入れ条件（任意）」を追加 |
| D-22 | 0015 | `cmdpos.sh` の出力を bash の配列（`CP_EXE[i]` / `CP_ARGS[i]`（US 区切り）/ `CP_SUBCMD[i]` / `CP_REDIRECTS[i]` / `CP_WRITE_TARGETS[i]` / `CP_OPAQUE[i]` / `CP_PROVIDED[i]` / `CP_GITLIKE[i]`、`CP_DEGRADED`）にし、git の第 1 サブコマンドと「実行体は不明だが git を含む」（PowerShell の判定不能）を足した | §7 は項目（exe / args / redirects / write_targets / opaque）を定めるが受け渡しの形を定めない。純 bash・fork なしで呼び手が判定できる形にした | 0022 → §7 に出力の形（変数名）を明記 |
| D-23 | 0015 | `push-detect.sh` の終了コードは `tool_response` の `exit_code` / `exitCode` / `returnCode` / `code` の順に読み、どれも無ければ 0（`interrupted: true` は失敗）とみなす | 仕様は「`tool_response` の終了コード」とだけ定め、Claude Code の PostToolUse の実際の形（フィールド名・終了コードの有無）が未確認 | 0022 → 実機で `tool_response` の形を確認して仕様に明記（T5 と同種の TBD） |
| D-24 | 0015 | `transcript.sh` のカーソル（`last_offset`）は「処理済みの行数」（空行を含む総行数）にした | 仕様は `last_offset` の単位を定めない。行数なら jq 1 回で `[inputs]` の添字で切れる | 0022 → 仕様に単位を明記 |
| D-25 | 0015 | `redact` の「40 文字以上の 16 進 / base64 様の語」は `/` を含む語を対象外にした（`[A-Za-z0-9+=_-]{40,}`） | `/` を含めると `.claude/skills/20-common-step-shell-script/scripts/logger.sh` のようなパスの一部（`/` で区切られた 40 文字超の並び）がマスクされ HK-T10 の「通常のパスを壊さない」と両立しない | 0022 → §3 のパターンに注記 |
| D-26 | 0015 | `scope.sh` の判定順・宣言の絞り込み・ops の分類・設定の検査のテストを HK-T11 の ID で書いた（§11 には glob と confirm の優先だけ） | §11 に該当する ID が無く、実装計画が「テスト ID の無いアセット」を起こせないため、最も近い ID に付けた（D-6 と同じ運用） | 0022 → §11 に HK-T15（判定順と ops 分類）の追加を検討 |
| D-27 | 0015 | `scope.sh` は `frontmatter.sh` を読み込み行の `deny` ポリシーで source する（チケットの DoD どおり）。案内側フック（diff-check / subagent-stop-check）が source したときも読めなければ deny JSON を出して終了 0 になる | 読み込み行のポリシーはファイル単位で固定。案内側の「何も出さずに通す」と食い違うが、frontmatter.sh が無い状態は機構全体の破損であり、PostToolUse の permissionDecision は無視される | 0022 → 2/3 で案内側の挙動を確認し、必要なら scope.sh を `nop` にして呼び手が判定 |

## 想定と異なった点

- 0014: 読み込み行の関数内で `BASH_SOURCE[1]` が呼び手のスクリプトを指すことを利用したが、`bash -c` から直接呼ぶと空になる（テストは必ずファイルから実行する）
- 0014: ログの出どころは `{{NAME}}` ではなく `$0` の basename（仕様どおり）。テストの期待を先に誤った
- 0020: Bash ツールで複数ファイルを 1 回のヒアドキュメントの列で書くと unexpected EOF で落ちた（3 回とも。小さな単体は通る）。Write ツールで 1 ファイルずつ書いて回避。生成物への影響なし
- 0015: Windows の jq 1.6 では `fromdateiso8601`（strptime）が動かず、タイムスタンプが全部 null になった。参考実装が自前の暦計算を持っていた理由がこれ（H6 に追加すべき事項）
- 0015: `redact` の `Bearer` パターンが置換後の `***` に再一致して無限ループになり、テストがタイムアウトした。置換結果が再び当たらないことをパターンごとに確かめる必要がある
- 0015: 参考実装の走査部（真偽値を返す述語）はそのままでは使えず、セグメント列を積む形に全面的に書き直した（正規化部は無改造で流用）。付録 A の見立てどおり

## 残課題

（0021 で集約）
