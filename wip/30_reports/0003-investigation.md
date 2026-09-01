---
type: report
title: 調査結果レポート（0003〜0005）— 参考実装の流用範囲・テスト方式・TBD T5・logger と redact・HTML テンプレートの土台
description: issue #6 の調査チケット 0003〜0005 の結果。参考実装 2 系統のスクリプトを新仕様の機能単位で流用 / 改変 / 新規に判定し、テストの実行方式、PowerShell ツールのフック入力（TBD T5）、logger と redact の置き場、HTML テンプレートの土台を確定する
tags: [report, investigation, issue-6]
keywords: [調査結果, 参考実装, 流用, 改変, 新規, テスト方式, bats, TBD T5, PowerShell, tool_input, logger, redact, HTML テンプレート, data-required]
---

# 調査結果レポート（0003〜0005）

## 対象

- 対象 issue: #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6
- PR: #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 調査計画: `wip/20_plans/0002-investigation-plan.md`（問い Q1〜Q5）
- チケット: 0003（Q1・Q4）、0004（Q2・Q5）、0005（Q3）

## 要約

| 問い | 結論 |
|---|---|
| Q1 流用範囲 | フック lib: 43 単位で流用 12 / 改変 20 / 新規 11。`CommandPosition.sh` の正規化部（`:106-470`）と `UsageTracking.sh` のカーソル付き集計が最大の流用資産。segment 列 API・`redirects[]`・PowerShell 前処理・`redact`・`decisions.jsonl`・fail-closed・ヘッドレスは新規。提供コマンド: `ticket.sh` は 5 サブコマンドすべて新規（部品は流用）、`commit.sh` はパス指定 add 流用 + 検査新規、`push.sh` は骨格のみ、`check-html.sh` は 7 検査中 5 流用・RV006 新規 |
| Q2 テスト方式 | 素の bash 踏襲 + 共通ヘルパ `test-lib.sh` + ランナー `run-tests.sh`。ID 付き `PASS <ID>` 出力で仕様表と突合。bats は導入しない |
| Q3 T5 | 前提どおり（`tool_input` のキーは Bash と同一 — transcript の実記録で確認、matcher は既に `Bash\|PowerShell`）。フック stdin 固有フィールドの実物だけ 2/3 で確認 |
| Q4 logger / redact | 参考に共通 logger も redact も無い → 新規。置き場は仕様どおり、読み込みはフォールバック鎖（BASH_SOURCE 上向き探索 → CLAUDE_PROJECT_DIR → git）。`printf '%(%:z)T'` は使えない |
| Q5 HTML テンプレート | 土台は `reports-clean.template.html` と `plans.template.html`。`data-required` は必須節 5 + 格上げ 2（レポート）、5 + 新設 2（計画書）。参考固有の記述の削除箇所を行番号で特定済み |

仕様と食い違う点は **D1〜D19**（下表）。うち「仕様を直す / 補う」が 12 件（D2・D3・D4・D5・D8・D10・D11・D12・D13・D15・D16・D17・D19）で、AI アセット設計計画（0006）が採否を決める。

## 確かめられなかったこと

| 項目 | 理由 | どこで確かめるか |
|---|---|---|
| PowerShell ツールのフック stdin 固有フィールド（`session_id` / `cwd` / `permission_mode`）の実物 | 一時フックの登録（`.claude/settings.json` の変更）が auto モードの分類器に拒否された。`tool_input` 自体は transcript で確認済み | 2/3 のフック登録直後の `decisions.jsonl` |
| PreToolUse の deny が permissionDecision JSON 経路で確実に効くか（D5） | 本 issue ではフックを登録しない | 2/3（§12 に TBD として追加を提案） |
| bats を MSYS で動かしたときの速度 | 未インストールで、依存を増やさない方針のため導入して測らなかった | 採用しない限り不要 |
| 参考テスト 2 本の失敗原因（`test_block_direct_git_commit.sh` の改行を挟んだ `commit`、`test_install_to_project.sh` のタイムアウト） | 新機構に移植しないコードで、原因究明は調査の範囲を超える | 新機構の同種テストを書くとき |
| HTML テンプレート 2 本のブラウザでの実表示 | 参考実装側でも未確認（DDR i0203-01）。調査では開いていない | 実装で初版を作るときの目視 |
| shellcheck による規約検査 | 本環境に無い | CI（Linux）で回す案を 2/3 以降で検討 |

## Q1 参考実装の流用範囲（チケット 0003）
### 答え（1）フック共通ライブラリ側 — `hooks/lib/{hook-common,cmdpos,scope,push-detect,transcript}.sh`

- 結論の性質: **注意** / レビューの重み: **◆**（流用資産の判定が実装計画のステップ分割と工数を決める。PowerShell 検知漏れ・fail-open など危険側の差分を含む）

43 の機能単位で判定: **流用 12 / 改変 20 / 新規 11**（表は付録 A `0003-investigation-appendix-A.md` §1）。lib ごとの結論:

| lib | 判定 | 流用元（ファイル:行） | 主な差分 |
|---|---|---|---|
| `cmdpos.sh` | 正規化部は流用、走査部は改変（API 作り直し）、`redirects[]` / `write_targets[]` / PowerShell 前処理は新規 | MR-driven `hooks/lib/CommandPosition.sh:106-470`（クォート・ヒアドキュメント・コメント・行継続・`$( )`・算術式。純 bash・fork なし）。走査 `:471-566`、git 判定 `:498-534`、opaque 語彙 `:55-63`、縮退 `:568-582` | 参考の公開 API は真偽値の述語 2 本（`command_invokes_git_subcommand` / `command_invokes_script`）で、仕様 §7 の「segment ごとの `exe` / `args[]` / `redirects[]` / `write_targets[]` / `opaque`」を返さない。縮退の閾値（参考 8192 文字・行単位 → 仕様 4096 文字・コマンド単位）と「`degraded` を呼び出し側へ返す」形に変更。**PowerShell 専用処理は皆無で、`.\git.exe commit` はエスケープ解決で `.git.exe` に化けて検知漏れ**（`CommandPosition.sh:806-813` に既知の制約として明記。BG-T08 が落ちる） |
| `scope.sh` | 改変（骨格流用・判定順は別物）。`common.confirm` 優先・`logs/**` 対象外・`ops` 体系は新規 | agent-workflow `hooks/workflow-lib.sh:117-130`（`wf_resolve`: 表引きを 1 関数に閉じ結果を変数で返す）、`:69-80`（`wf_match`: fork なし `case` マッチ）、`:56-66`（`wf_to_rel`: Windows パス正規化）、`:145-161`（`wf_load_config`: jq 1 回で設定を読む）、`workflow-types.json` | **チケット宣言の意味が逆**（参考 `ticket.allowed_paths` は上限を広げる / 仕様 `d.write` は絞る）。`**`→`*` の読み替えは `case` glob が `/` を跨ぐため過剰一致。`bash_groups` 2 値 → `ops` 6 分類 + `gh`/`glab` の分類が新規 |
| `hook-common.sh` | 改変（入力読取・ask 出力・緊急停止・状態ファイルの原子的更新は流用）。`redact` / `decisions.jsonl` / fail-closed / ヘッドレス置換は新規 | `workflow-lib.sh:36-38`（`wf_jq` = `jq \| tr -d '\r'`）、`workflow-guard.sh:44-53`（ask JSON）、`workflow-entry.sh:52-53, 141-147`（緊急停止 2 段・tmp→`mv -f`）、`:160-162`（session_id サニタイズ） | 参考は**全体が fail-open**（読めなければ `exit 0`）。deny は `exit 2` + stderr が主で仕様（JSON + 終了 0）と違う。`redact` は参考に 1 か所も無く、`workflow-guard.sh:39,56` はコマンドを生のままログへ書く |
| `push-detect.sh` | 改変（fork ゼロ前置フィルタと縮退判定は流用）。`tool_response` による成功判定は新規 | MR-driven `hooks/post-push-usage-report.sh:360-378`（`raw_hints_at_git_push`）、`block-unchecked-push.sh:71-86` | 参考はコマンド文字列だけで push とみなし失敗した push でもレポートを作る。仕様の 3 条件 AND（終了コード 0 / `HEAD == @{upstream}` / `push-state.json`）は新規（`@{upstream}` の初回 push 問題 → 食い違い C） |
| `transcript.sh` | 改変（カーソル付き差分集計は流用価値 2 位） | MR-driven `hooks/lib/UsageTracking.sh:202-259`（`_usage_aggregate_new_lines`: `last_offset` 以降を 1 回の jq で 4 指標集計）、`:431-456`（カーソル）、`:177-189`（**ファイルパス渡し必須**の実例: `--argjson` で 120KB を渡すと Windows のコマンドライン長 32KB 上限で jq が exit 126） | 実作業時間の定義が違う（参考: gap 閾値の加算 / 仕様: ユーザー入力待ちと 10 分超を除く）。2 本立て（activeSeconds 全件 + 差分集計）を 1 関数に寄せる。`UserUtteranceSelect.jq` は仕様に対応要件が無い（使うなら仕様追加が先） |

新規に書くもの（付録 A §3 の 19 項目の要点）: `redact`、`decisions.jsonl`、fail-closed ラッパ + `trap ERR`、ヘッドレス判定、`disabled` 記録、segment 列 API、`redirects[]` / `write_targets[]`、PowerShell 前処理、push 成功判定、`ops` 体系と `gh`/`glab` 分類、**ネストした frontmatter の読み取り**（`allow.write` / `human_review.required`。参考の 1 行 sed では読めない）、`blocked-commands.txt` の外部化、`logs/sessions/` の期限削除、`common.confirm` 優先、`--accumulate`、HK-T01〜T10 のテスト基盤。

Windows Git Bash の実測（付録 A §4）: **jq が Windows ネイティブ版（1.6）で CRLF を出力**（`hook_jq` ラッパ必須。参考も `wf_jq` で対処）/ 外部プロセス起動 ≈95ms（拒否側 5 本は fork ゼロの前置フィルタ必須、`wf_log` の `date` fork は `printf '%(...)T'` へ）/ コマンドライン長 32KB / CRLF ファイルの正規化（`tr -d '\r'`）/ bash 5.2 の `shopt -u patsub_replacement` / `realpath` は使わず純 bash 正規化。

### 答え（2）提供コマンド側 — `ticket.sh` / `commit.sh` / `push.sh` / `check-html.sh`

- 結論の性質: **注意** / レビューの重み: **◆**（`ticket.sh` は全サブコマンド新規。frontmatter パーサの入れ子問題（D9）と仕様内矛盾（D10）を含む）

31 の機能単位で判定（表は付録 B `0003-investigation-appendix-B.md` §1）。コマンドごとの結論:

| 提供コマンド | 判定 | 流用元（ファイル:行） | 主な差分 |
|---|---|---|---|
| `ticket.sh` | **5 サブコマンドはすべて新規**（参考は AI が手で `git mv` する手順）。部品は流用・改変 | frontmatter ブロック切り出し `MR-driven scripts/src/extract-frontmatter.sh:101-124`（流用）、インライン配列の分解 `:163-174`（fork ゼロ。流用）、連番採番 `agent-workflow hooks/work-boundary.sh:43-47, 64-78`（`nullglob` 退避、`10#` 強制。4 ディレクトリ走査へ改変）、パス限定コミット `work-boundary.sh:143-146`（流用）、未コミット検査 `:176`（流用）、全件列挙の骨格 `push-checklist.sh:247-329`（`ok=0` フラグ集約。流用）、依存判定 `workflow-diff-check.sh:100-115`（「飛ばす」方式へ改変）、TSV 分割 `push-checklist.sh:83-103`（流用。`IFS=$'\t' read -a` 禁止） | **frontmatter パーサ（`extract-frontmatter.sh:147-187`）は §9 の入れ子 `allow.write/ops` を黙って捨て、`human_review: {…}` を文字列にする**（yq は本環境に無い）。取り消し・`overall-plan` 非コミット・完了検査の中身・`next` の JSON は新規。チケットテンプレート（`work-ticket-driven/assets/ticket.template.md`）は frontmatter 3 キー・作業ログ 2 見出しで骨格だけ流用 |
| `commit.sh` | パス指定 add は流用、規約検査は新規 | `MR-driven scripts/src/create-commit.sh:94, 59-63, 16-19, 117-121`（`--amend`/`-A` を構造的に持たない設計。流用）、`:65-89`（削除済みパスの分類。任意流用）、除外パターンの中身 `skills/commit/SKILL.md:84-108`（Markdown → `assets/exclude-patterns.txt` へ移し替え）、glob マッチ `workflow-lib.sh:69-80` | CP001〜CP004（一括指定拒否・メッセージ規約・除外突合と一覧出力・差分なし）はすべて新規。prefix 一覧は参考（`style`/`revert` あり）と仕様で差があり仕様に合わせる |
| `push.sh` | 機構が別物（参考は自己申告 TSV）。骨格と設計意図だけ流用 | `push-checklist.sh:37-58, 247-329, 399-411`、skip の理由必須 `:468-529` | 4 項目の自動判定・md/html の対の検査・`wip/push-check-skip.md`・`--set-upstream`・push 範囲の出力は新規。参考の `git push -q`（`work-boundary.sh:229`）は上流未設定を扱わない |
| `check-html.sh` | 検査 7 項目のうち 5 は流用、RV002 は改変、RV006 は新規。スクリプト化そのものが新規（参考は AI が打つ grep 列） | `MR-driven skills/issue-mr-flow/references/deliverables.md:86-141`（id 抽出をタグ内に限定・`uniq -d`・`comm -23`・コメント除去後の `<style>` 数え・負のコントロール）、`scripts/test/test_report_templates.sh:49-115` | RV002 は `<a href>`・`#`・`data:` の除外が要る。RV006（`data-required` をテンプレートから導出）は参考に無い。プレースホルダ記法は `<!-- -->` → `{{名前}}` |

新規に書くもの（付録 B §4 の 16 項目）: `logger.sh` 本体、`redact`、`script.template.sh` / `test.template.sh`、`ticket.sh` 全体とテンプレート、完了検査、取り消し、`next` の JSON と `task-types.tsv` 解決、`commit.sh` の全検査、`exclude-patterns.txt`、`push.sh` の 4 項目、md/html 対、`check-html.sh` 本体と RV006、出力の型（最終行 `OK:` / `<ID>:`）と終了コード 0/1/2 の統一。

## Q4 logger と redact の置き場と読み込み方（チケット 0003）

### 答え

- 結論の性質: **注意** / レビューの重み: **◇**（logger は新規だが仕様が明確。読み込み 1 行（D12）と時刻表記の制約だけ設計判断が要る）

- **参考実装に共通 logger も redact も存在しない**（`log_info` / `LOG_LEVEL` / `logger.sh` / `redact` で 2 リポジトリ全文検索してヒット 0 件）。個別実装は `workflow-lib.sh:40-43` の `wf_log`（単一ファイル固定・レベルなし・TZ なし・fail-open）と stderr 出力だけ。**流用できるのは fail-open の 1 行（`>>… 2>/dev/null || true`）と改行を畳む純関数 `push-checklist.sh:105-116`** で、`logger.sh` は事実上新規（付録 B §2-1 の差分表）
- 置き場は仕様どおり `.claude/skills/20-common-step-shell-script/scripts/logger.sh`、出力先は `logs/sh/<出どころ>.log`（参考の `.claude/hooks/workflow.log` は新仕様では `common.protected` 配下なので使えない）
- **読み込み方（hooks 配下 / skills 配下 / tests の 4 通りの深さから）**: 推奨はフォールバック鎖 (1) `${BASH_SOURCE[0]%/*}` を起点に `.claude` を持つ親を上向きに探す（fork ゼロ・段数非依存）→ (2) `CLAUDE_PROJECT_DIR` → (3) `git rev-parse --show-toplevel`（空文字ガード必須）→ (4) すべて失敗なら no-op 関数を定義して本体を止めない。参考の実例は付録 B §2-2 の 5 方式。**仕様の雛形が (3) 単独（`source "$(git rev-parse --show-toplevel)/…"`）で固定されている点は弱い**（フックは毎ツール呼び出しで git を fork する。git 不在時は `source "/.claude/…"` で `set -e` 即死）
- **時刻**: 仕様の `+09:00` 表記は bash 組み込み `printf '%(%:z)T'` では出せない（実測: 空文字。`%z` は `+0900`）。`printf -v` で `+0900` を得てコロンを文字列操作で挿す（fork ゼロ）
- **redact**: §3 の接頭辞決め打ちパターンは、参考ルール `shell-script-style.md:1252-1262`「接頭辞決め打ちに頼らない。当たらないマスクは誤った安心を与える」と思想が衝突する。仕様は直さず実装し（HK-T10 が「当たること」を担保）、仕様に「一次防御は値を出さないこと。redact は最後の砦」の 1 文を足す（→ D11）

### 根拠

- 付録 B（`wip/30_reports/0003-investigation-appendix-B.md`）§2・§5-1〜5-5。実測: bash 5.2.12 (msys)、jq は Windows ネイティブ 1.6、yq・shellcheck 不在、`git rev-parse --show-toplevel` は `C:/…` 形式、`.gitattributes` 不在

## Q2 テストの実行方式（チケット 0004）

### 答え

- 結論の性質: **良** / レビューの重み: **◇**（推奨案は仕様の雛形と許可 glob をそのまま使える。ヘルパとランナーの仕様追加（D19）だけが要る）

- **推奨: 素の bash を踏襲 + 共通ヘルパ 1 ファイル + ランナー 1 本**（決定は実装計画）。比較軸は付録 C §4 の表（両 OS 対応 / 依存追加 / 仕様との整合 / テスト ID の対応付け / 2 置き場 / 1 コマンド実行 / 出力形式）で、bats が勝るのは「1 コマンド実行と `--filter`」だけ。参考実装 2 系統とも素の bash（ファイルごとに `assert_eq` / `check` を自前定義、最終行に集計、失敗で非 0）。bats は本環境に無く、導入すると `.bats` 拡張子・`@test` 記法で仕様の雛形（`assets/test.template.sh`）とフックの許可 glob（`hook-test`: `.claude/hooks/**/tests/*.sh`・`.claude/skills/*/scripts/tests/*.sh`）を書き換えることになる。現規模（テスト ID 数十）では過剰
- **テスト ID の対応付け**は agent-workflow 方式: `check <ID> …` / `assert_eq <ID> …` の第 1 引数を仕様書の ID（`TICKET-T01`・`HK-T02`・`CP-T03`・`RV-T04`。枝番は `-T02a`）にし、`PASS <ID>` / `FAIL <ID>: …` を 1 行で出す。ランナーが `^(PASS|FAIL) ([A-Z]+-T[0-9]+)` を集めれば仕様の「テスト観点」表とのカバレッジ突合が grep でできる
- **共通ヘルパ** `.claude/skills/20-common-step-shell-script/scripts/test-lib.sh`（仮）: `assert_eq` / `assert_exit` / `assert_contains` / `assert_not_contains` / `run_cmd`（`R_EXIT` / `R_OUT` / `R_ERR`）/ `make_tmp_repo`（`mktemp -d` + `git init -q -b main` + user 設定 + `trap`）/ `hook_payload`（`jq -nc --arg` でイベント JSON を組む）/ `finish`（集計と exit）。`test.template.sh` はこれを `source` する 20 行程度。**`set -uo pipefail`（`-e` 無し）で統一**し終了コードは `run_cmd` が取る
- **ランナー** `run-tests.sh`（仮）: 上記 2 glob を列挙し各テストを `timeout` 付きで実行、ファイルごとの最終行と exit を表にして総合 exit。`--filter <glob>`・`--ids`（ID 一覧）。CI ではこの 1 コマンドだけ叩く
- **Windows 対策はヘルパ側で吸収**: PATH を絞るときは symlink ではなくラッパースクリプト（MSYS の bash.exe は同ディレクトリの dll を要求、`command -v printf` は組込みで絶対パスを返さない）、jq 出力の `tr -d '\r'`、`/` 始まり文字列を jq に渡すときの `MSYS_NO_PATHCONV=1`、性能閾値は環境変数で無効化、日本語を含む一時パスを避ける（native jq は開けない）

### 根拠（Git Bash での実行。付録 C §2）

| テスト | 結果 |
|---|---|
| `MR-driven scripts/test/test_command_position.sh` | passed=117 failures=1（13.2 s）。失敗は性能閾値（ヒアドキュメント判定 7〜8 s > 2000 ms）。**WSL Ubuntu では 118/118・2.3 s** → MSYS の fork 遅延起因 |
| `agent-workflow hooks/tests/test-workflow-entry.sh` | PASS=45 FAIL=0（28.6 s） |
| `test_report_templates.sh` | passed=8 failures=0 |
| agent-workflow 残り 4 本 | 4 本中 2 本全通過、fallback 2 本は symlink PATH 方式が MSYS で動かず全滅（Windows 起因） |
| MR-driven 残り 25 本 | 19 本全通過。失敗: 日本語パス × native jq、symlink PATH、`.git` 不在・Python 不在（環境起因）、1 本タイムアウト、1 件未調査 |

ツール: bats 無し、shellcheck 無し、bash 5.2.12 (msys)、jq 1.6 native、perl 5.36。

## Q5 HTML テンプレートの土台（チケット 0004）

### 答え

- 結論の性質: **良** / レビューの重み: **◇**（土台は DDR が名指し済み。`data-required` の対象と置き方（D16・D17・D18）が設計判断）

- HTML テンプレートを持つのは MR-driven のみ（実体 8 本）。土台は **`skills/issue-mr-flow/assets/reports-clean.template.html`**（565 行。DDR i0001-05 が名指し。sidebar + `#overview/#unverified/#conditions/#findings/#verified/#next/#surprises/#todo`、外部依存 0、`<style>` 1、ライト / ダーク対応、プレースホルダ `<!-- ここに書く: -->` 27 件）と **`plans.template.html`**（334 行。`#premise/#goal/#target/#approach/#phase-*/#out-of-scope/#verify/#criteria/#options`、ヘッダ帯型）。`html-slides` は `<script>` あり、`canvas-report` は mermaid CDN 依存で対象外
- 参考の機械検査は「成果物向け grep 手順 6 項目」（`references/deliverables.md:78-150`。未スクリプト化）と「テンプレート本体向け `test_report_templates.sh` T1〜T7」（負のコントロール付き）。新仕様 RV001〜RV007 のうち **RV006（`data-required` 導出）だけが新規**、RV002 は `<a href>` 除外の改変
- **`data-required` 案（レポート）**: サイドバーのメタ（issue / MR）、`#overview`、`#unverified`、`#findings`、`#next` に付ける。`#surprises`（想定と異なった点）・`#todo`（残課題）は参考では任意だが、実施タスク 6 種の仕様がすべてレポートに含めるため**必須に格上げ**が妥当（→ D16）。`#conditions` / `#verified` は任意のまま
- **`data-required` 案（計画書）**: `header`（対象）/ `#goal` / `#target` / `#approach` / `#verify` を必須。計画タスク 7 種の共通節「チケット」「保留した点 / 対象なし」に対応する節が無く**新設して必須**が妥当。`[全体作業計画のみ必須]` の 2 節は削除（全体計画書は HTML を持たない）。`#out-of-scope` は md 側に対応節が無い（判断点）
- **削るべき固有記述**: `wip/reports` / `wip/plans` パス、flow-id、`issue-mr-flow` / `deliverables.md` / `REVIEW-POINTS.md` / `canvas-report` 参照、issue #54/#186/#203 の経緯、冒頭コメントの検査手順（`check-html.sh` 参照に置換）、`[必須]/[任意]` コメント → `data-required` 属性、`<!-- ここに書く -->` → `{{名前}}`（付録 C §3 に行番号付きの表）

### 根拠

- 付録 C §1〜§3（ファイル一覧・節構成・検査項目の対応表・`data-required` の根拠は各 exec / plan 仕様の OUT ひな形）

## Q3 TBD T5 — PowerShell ツールのフック入力（チケット 0005）

### 答え

- 結論の性質: **良** / レビューの重み: **・**（前提どおり。設計差分なし）

- `tool_name` は `"PowerShell"`。`tool_input` のキーは `command` / `description`（実物の必須相当）/ `timeout` / `run_in_background`（任意）で **Bash ツールと同じ構造**。matcher は `"Bash|PowerShell"` と書け、ドキュメント自身が「`Bash` だけでは不十分（Windows では PowerShell がネイティブに動く）」と明記している（出典: https://code.claude.com/docs/en/tools-reference.md「PowerShell Tool Reference」）
- **T5 の結論: 前提どおり**（出典: 公式ドキュメント + 本リポジトリの transcript にある PowerShell ツールの `tool_use` 記録。下記「実機確認」）。`hook-common.sh` / `cmdpos.sh` は `tool_input.command` をそのまま読めばよい。フックの登録 matcher は Bash 系フック（workflow-guard / block-direct-git / block-chmod / post-push-*）で `Bash|PowerShell` にする（共通仕様 §1 の登録表は既に `Bash|PowerShell`（行 29〜36）で、設計差分なし）
- 付随して確定した事項（他の TBD・仕様に効く。出典: https://code.claude.com/docs/en/hooks-guide.md「Common Input Fields」「Structured JSON output」）
  - 共通入力フィールド: `session_id` / `prompt_id` / `transcript_path` / `cwd` / `permission_mode`（`default|plan|acceptEdits|auto|dontAsk|bypassPermissions`）/ `effort` / `hook_event_name`。**サブエージェント実行中のみ `agent_id` / `agent_type`** が付く（T2・`subagent-*` の実装材料）
  - ヘッドレス（`claude -p`）を判別するフィールドは記載なし → **T3 は前提どおり**（`WORKFLOW_HEADLESS` / `CI` で明示）。ただし `permissionDecision: "ask"` は非対話モードでは拒否として扱われ、`"defer"` という値（`-p` で SDK ラッパーが入力を集めて再開）が存在する
  - `permissionDecision` は `allow | deny | ask | defer`。exit 2 + stderr と exit 0 + JSON は併用しない
  - `SubagentStart` / `SubagentStop` イベントは存在し、matcher はエージェント種別。入力の固有フィールド（`model` の有無等）と、SubagentStop の出力がメインに届くかは**記載なし**（T1・T4 は 2/3 で実機確認）
  - settings.json のフック設定はセッション開始時に読まれ、**実行中の直接編集もファイル監視で通常は自動反映**される（`/hooks` は閲覧専用）。→ 一時フックによる実機確認は再起動なしで可能な見込み

### 実機確認の結果

- **transcript の一次情報で確認できた**（レビュー指摘 F7）: `~/.claude/projects/c--Users-taniyama-Desktop-git-issue-mr-ticket-workflow/78d6705f-….jsonl` に `"name":"PowerShell","input":{"command":"git branch --show-current; git status --short; …","description":"ブランチ・作業ツリー・チケット状態を確認"}` が 2 件実在する。同じ transcript の Bash ツール 541 件のキー集合も `command` / `description` で同一。フックの `tool_input` はこの `input` がそのまま渡る（hooks-guide「tool_input: ツール引数のオブジェクト」）ので、`tool_input.command` を読む実装で PowerShell も扱える
- transcript から取れないのはフック stdin 固有のフィールド（`session_id` / `cwd` / `permission_mode` / `hook_event_name`）だけで、これは 2/3 でフックを登録した直後の `decisions.jsonl` で確認する（一時フック方式は下記のとおり本 issue では使えなかった）

#### 一時フック方式が使えなかった経緯

- 一時フック `wip/tmp/dump-hook-input.sh`（stdin をそのまま `logs/tmp/` に保存するだけ）を用意し、`.claude/settings.json` に `PreToolUse` matcher `Bash|PowerShell` で一時登録しようとしたが、**Claude Code の auto モードの分類器が `.claude/settings.json` への書き込みを Bash・Edit の両方で拒否**した（「Blocked by classifier」）。迂回はしない
- したがって実機の JSON は取得していない。T5 の結論は公式ドキュメント（`tool_input` のキーが Bash と同一、matcher `Bash|PowerShell` を推奨）に基づく。実機確認は 2/3 でフックを正式に登録した直後の最初の PowerShell ツール呼び出し（`decisions.jsonl` に `tool: PowerShell` が残る）で自然に得られるので、2/3 のテスト観点（HK-T05 の PowerShell ケース）に含める
- 副産物の知見（2/3 の設計に効く）: **auto モードでは AI 自身が `settings.json` を書けない**。フック登録（2/3 の「設定・定義」ステップ）は人間が適用するか、権限ルールを明示的に許可した上で行う必要がある。共通仕様 §8 の `common.confirm`（`settings.json` は毎回 ask）と方向は同じで、機構の想定と矛盾しない

### 根拠

- `claude-code-guide` エージェントによる公式ドキュメント（hooks-guide / hooks / tools-reference）の確認結果（2026-09-01）

### 実装時の申し送り（仕様変更なし。実装計画が必ず拾う）

| # | 出所 | 内容 |
|---|---|---|
| H1 | 付録 A §2-D | `redact` を通す前にログへ書く経路を残さない。ログ出力ヘルパ（`log_decision` / `deny` / `ask` / `notify`）の内側で `redact` を呼ぶ。参考のログ行（`workflow-guard.sh:39,56`）をそのまま移植すると HK-T06 / HK-T10 が落ちる |
| H2 | 付録 A §2-G | 差分検査の無視リストは `.claude/hooks/.state/` → `logs/**` に読み替える（§5 と整合） |
| H3 | 付録 B §3-5 | 差分基準点は frontmatter の `base_sha`。参考の `git log --grep` 方式は `overall-plan` 非コミット仕様と両立しないので流用しない |
| H4 | 付録 B §3-7 | RV002 は `<a href>`・`#` アンカー・`data:` を除外する。参考の正規表現は `href=` を無差別に拾う |
| H5 | 付録 B §3-8 | `check-html.sh` の検査は RV001〜RV007 の 7 項目（調査計画の「1〜6」は表記ずれ） |
| H6 | 付録 A §4、付録 B §5 | Windows: `hook_jq`（CR 除去）、fork ゼロの前置フィルタ、`printf '%(…)T'` + コロン挿入、`tr -d '\r'` によるファイル正規化、`shopt -u patsub_replacement`、jq にプロセス置換を渡さない、`--` でハイフン始まり引数を守る、TSV は `split_tsv_line` 方式 |

### 実装計画の判断点（調査では決めない）

| 判断点 | 案 | 比較軸 |
|---|---|---|
| 入れ子 frontmatter パーサの置き場と共有（D9 A 案のとき。`scope.sh`（hooks/lib）と `ticket.sh`（skills/scripts）の両方が §9 の `allow` を読む） | (a) `hooks/lib/hook-common.sh`（または新 `frontmatter.sh`）に置き、`ticket.sh` が hooks/lib を `source` する / (b) `20-common-step-shell-script/scripts/` に置き、フックが skills 配下を `source` する（logger と同じ向き） | 変更量: 同程度（1 本を共有） / fork 回数: フックは毎ツール呼び出しで走るため純 bash 必須（jq 起動の参考 `run_fm_jq` 方式は不可） — どちらの置き場でも同じ制約 / 許可 glob: (a) は skills → hooks の依存が増え、(b) は logger と同じ依存方向で `hook-test` の glob に影響なし / 二重実装の回避: どちらでも 1 本。推奨は (b)（依存方向を logger と揃える） |
| テスト方式（Q2） | 素の bash + ヘルパ + ランナー / bats | 付録 C §4 の表 |
| 計画書テンプレートのレイアウト（D18） | サイドバー型に統一 / ヘッダ帯型のまま | CSS の系統数・見た目の一貫性・改変量 |

### 受け入れ条件との対応（この調査がカバーした範囲）

| # | issue #6 の受け入れ条件 | 調査の入力 | 不足と手当て |
|---|---|---|---|
| 1 | ルール 4 本 | Q6（追記） | ルール本文の土台は参考 rules（下記）。`work-defaults` / `logger` は参考に無く新規 |
| 2 | hooks/lib 5 本とテスト | Q1（1）・Q2 | — |
| 3 | `task-types.tsv` / `scope-limits.json` と整合テスト | Q1（1）#43・#13 | — |
| 4 | 共通ステップスキル 9 本の SKILL.md と assets | Q6（追記） | **テスト ID の無い仕様 5 本**（下記）は実装計画で「eval の定義」に落とすか、0006 で仕様にテスト観点を足す |
| 5 | 提供コマンド 4 本とテスト | Q1（2）・Q2 | — |
| 6 | シェルスクリプトの規約 | Q4 | shellcheck 不在（確かめられなかったこと） |
| 7 | 食い違いの書き戻しと T5 | Q3、D 表 | 書き戻しは後続の AI アセット設計 |

## Q6 ルール・スキル本文・eval の土台（チケット 0007 で追記）

- 結論の性質: **注意** / レビューの重み: **◇**

### 答え

- **ルール 4 本**: 参考 rules は agent-workflow 2 本（`markdown-frontmatter.md`・`claude-config-headless-awareness.md`）、MR-driven 8 本（`agent-common` / `ai-command-style` / `directory-structure` / `docs-workflow` / `git-workflow` / `markdown-frontmatter` / `powershell-encoding` / `shell-script-style`）。新機構の `design-docs` / `ai-asset-design-docs` は MR-driven `docs-workflow.md`・`markdown-frontmatter.md` の該当章が土台になり得る。`logger` / `work-defaults` は参考に無く新規（要件書だけが正）。`shell-script-style.md` は `20-common-step-shell-script` の規約側の土台
- **SKILL.md 9 本の土台**: agent-workflow `task-ai-asset-creator` / `task-gh-feature` / `task-gh-issue` / `task-requirements` / `task-spec` → `20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}`（5 本。ただし新仕様は 1:1:1・DDR・HTML 検査など要求が増えており、本文は仕様書から書き起こす方が早い見込み）。MR-driven `commit` → `commit-push`、`issue-mr-flow/references/deliverables.md` → `report-view`、agent-workflow `work-ticket-driven` → `ticket`、MR-driven `rules/shell-script-style.md` → `shell-script`
- **テスト ID の無い仕様 5 本**（`ai-asset-creator` / `feature-mr` / `issue` / `requirement` / `spec`。いずれも「Script 処理: なし」）: 実装計画の禁止事項「テスト ID の無いアセット変更をステップに入れない」に当たるため、**0006 の設計対象候補**として「eval ID（機械テストではなく eval）をテスト観点に足す」か、実装計画で「eval の定義」として扱うかを決める
- **eval の土台**: agent-workflow の各スキルに `evals/evals.json`（`skill_name` + `evals[{id, prompt, expected_output, files}]`）がある（`task-gh-issue` ほか 7 本以上）。`20-common-step-ai-asset-creator` 仕様の `assets/eval.template.md` の土台になる（形式は JSON → md への移し替えが要る。判断点）。本リポジトリの `00-workflow-*/evals/` も同形式

### 根拠

- `ls 参考ディレクトリ/*/.claude/rules`、`ls 参考ディレクトリ/agent-workflow/.claude/skills/*/evals/`、`head 参考ディレクトリ/agent-workflow/.claude/skills/task-gh-issue/evals/evals.json`、`grep -c 'T0[0-9]' .claude/docs/10_spec/skills/20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}.md` → すべて 0（2026-09-01 実測）

## 仕様と食い違う点（設計フェーズの対象候補）
| # | 出所 | 食い違い | 見立て |
|---|---|---|---|
| D1 | Q1 lib（付録 A §2-A） | チケット宣言の意味: 参考 `allowed_paths` は上限を広げる、仕様 `d.write` は絞る | 実装で吸収（仕様が正）。`scope.sh` のテストで最優先に固定 |
| D2 | Q1 lib（§2-B） | フック共通仕様 §8 が glob の `*` / `**` の意味（`*` が `/` を跨ぐか）を定めていない。初期値表にファイル単位指定と `**` が混在し、`common.confirm` と `types[t].allow` の優先関係が実装依存になる | **仕様を直す**（§8 に「`*` は `/` を跨がない。跨ぐ一致は `**`」を 1 文追加） |
| D3 | Q1 lib（§2-C） | post-push-compact-prompt「push 検知 2」の `HEAD == @{upstream}` は初回 push で解決できない可能性 | **仕様を補う**（`origin/<branch>` → 初回は終了コード 0 + `push-state.json` 未記録で真、の縮退経路） |
| D4 | Q1 lib（§2-E） | §7-8 提供コマンドの識別: 参考は basename 一致のみ（`/tmp/commit.sh` が提供コマンド扱い）かつクォート付きパスは検知不能 | **仕様を補う**（リポジトリルート相対のパス一致を要求。パスが確定しないセグメントは通常判定）+ 実装 |
| D5 | Q1 lib（§2-F） | deny の伝え方: 参考 4 本は `exit 2` + stderr の実績、仕様は permissionDecision JSON + 終了 0 | 仕様どおり実装し、§12 TBD に「JSON 経路の deny が確実に効くか（効かなければ `exit 2` 併用へ縮退）」を 1 行追加。2/3 で実機確認 |
| D6 | Q3 | なし（登録表は既に `Bash\|PowerShell`、`tool_input.command` は同一） | T5 を「確認済み」として §12 から消す（仕様の更新） |
| D7 | Q1 lib（§1-29） | `UserUtteranceSelect.jq`（直近の発話の再注入）は session-start 仕様に対応要件が無い | 推奨: 採らない（要件追加が先で、本 issue の受け入れ条件外）。transcript 形式の一次情報としてだけ参照 |
| D8 | 0001 作業ログ | ワークフロー仕様 手順 2a が参照する「敵対的レビュー要否」の欄が、共通仕様 §9 のチケット frontmatter 例に無い | **仕様を補う**（§9 に `adversarial_review: {required, reason}` を追加し、ticket テンプレートに載せる） |
| D9 | Q1 提供コマンド（付録 B §3-3） | チケット frontmatter の入れ子（`allow.write/ops`）とインラインマップ（`human_review`）を参考パーサは読めない。yq は無い | 2 案を 0006 で判定。**A 案（実装で吸収）**: パーサに「親キー + インデントで `parent.child` に畳む」「`{k: v}` の分解」を足す — 変更量: 20〜30 行の見込み / リスク: 自前 YAML 解釈の境界（クォート内の `:` 等）/ 整合: 仕様 §9・WF208 は無傷。**B 案（仕様変更でフラット化）**: `human_review_required` / `allow_write` 等の 4 キー — 変更量: §8・§9・WF208 の記述とテンプレート / リスク: 可読性低下 / 整合: sed 1 行で 1 キー取得でき hooks の fork ゼロ制約を満たしやすい。推奨は A（置き場の判断点は「実装計画の判断点」節） |
| D10 | Q1 提供コマンド（§3-4） | **仕様内の矛盾**: commit-push 仕様は「`ticket.sh` は内部から `commit.sh` を使う」、ticket 仕様は「各サブコマンドが内部で `git` を直接実行」 | **仕様を直す**（ticket 仕様を `commit.sh` 経由に寄せる。規約検査が 1 箇所に集まる） |
| D11 | Q4（§3-1） | redact の接頭辞決め打ちは参考ルール「当たらないマスクは無いのと同じ」と思想が衝突 | 仕様どおり実装。共通仕様 §3 に「一次防御は値を出さないこと。redact は最後の砦」を 1 文追加 |
| D12 | Q4（§3-2） | `rules/logger.md`「使い方」が `source "$(git rev-parse --show-toplevel)/…"` の 1 行を文字列で固定 | **仕様（要件）を直す**: 「1 行で読み込む・コピー禁止」は残し、行の中身をフォールバック鎖に差し替える |
| D13 | Q1 提供コマンド（§3-6） | ファイル名 `<連番>-<種類>.md` と frontmatter `ticket_type` が食い違ったときの扱いが仕様に無い | 実装は frontmatter を正とする。ticket 仕様に 1 文追加 |
| D14 | Q1 提供コマンド（§5-4） | `.gitattributes` がリポジトリに無いが、共通仕様 §8 の `common.protected` は存在する前提。`*.sh text eol=lf` が無いと CRLF で取り出されてシバンが壊れる | **仕様を補う + 実装**: §8 判定順 (2) は「`common.protected` に一致し、かつ `types[t].allow` に明示されていない → deny」で、宣言 `d.write` は上限を広げられないため、§8 初期値表の `ai-asset-implementation.allow` に `.gitattributes` を追加する必要がある（0006 の対象）。作成は実装フェーズの最初のステップ |
| D15 | Q1 提供コマンド（§4-16） | 終了コード 2 の意味が衝突する: 提供コマンドは「引数や環境の誤り」、フック契約では「ブロック」 | 仕様は既に別文脈（フックは JSON deny + 終了 0）なので矛盾はないが、shell-script 仕様に「フックでは exit 2 を使わない」を明記する |
| D16 | Q5（付録 C §3） | レポートの「想定と異なった点」「残課題」、計画書の「チケット」「保留した点」は参考テンプレートで任意 / 無いが、新仕様の各タスクは必ず含める | 推奨: **テンプレート側で `data-required` を付ける（格上げ）**。必須節の一覧は仕様に書かない（report-view 仕様「必須節一覧はテンプレート自身から導出する。二重管理をしない」と衝突するため）。格上げの根拠は DDR に残す。あわせて「必須節は空にせず『無し』の 1 行を書く」を運用規約として仕様に 1 文足す（存在検査だけでは空を防げない — 本レポート自身の「想定と異なった点」が空だった実例） |
| D17 | Q5 | `{{名前}}` プレースホルダを HTML コメント内に置くか要素内容に置くか、`data-required` を `<section>` 以外（sidebar / header）にも付けるかが仕様に無い（RV006 の抽出対象の定義） | **仕様を補う**（推奨: 要素内容に置く — 消し忘れがブラウザで見える。`data-required` は要素種別を問わず属性で抽出） |
| D18 | Q5 | 計画書テンプレートのレイアウト（reports-clean のサイドバー型に揃えるか、plans のヘッダ帯型か）は DDR に無い | 実装計画で決める（推奨: サイドバー型に統一し CSS を 1 系統にする） |
| D19 | Q2（付録 C §4） | 共通テストヘルパ `test-lib.sh` とランナー `run-tests.sh` は shell-script 仕様の OUT ひな形（`test.template.sh` に最小ヘルパを内包）に無い | **仕様を補う**: ヘルパを 1 ファイルに集約し雛形は `source` する（`source` 専用なので採番不要）。`run-tests.sh` は `.claude/skills/20-common-step-shell-script/scripts/` に置く提供コマンドになる（§7-8 の識別 glob に載るため `hook-test` の許可 glob は変更不要 — これが「変更不要」の理由）ので、§6 採番台帳に接頭辞（例 `TR`）を追加し、shell-script 仕様の Script 処理にサブコマンド・テスト観点を書く |
| D20 | レビュー F2 | **仕様間の矛盾**: 調査計画仕様は「動かして確かめる」（例: テスト 1 本の実行）を計画できるが、`10-task-investigation-exec` の禁止事項は「ビルドやテストの実行」を禁じ、§8 初期値の `investigation.ops` は `read, remote-read`（`build-test` なし）。本調査は計画に従い実行し、さらに 32 本まで広げた（逸脱。チケット 0007 の作業ログに記録） | 0006 で判定: (a) exec 仕様と §8 を「計画チケットの `allow.ops` に `build-test` が宣言されていれば実行可」に緩める（上限にも `build-test` を足す）か、(b) 計画仕様側を「実行は計画しない。既存の記録で代える」に合わせるか。推奨は (a)（参考テストを動かした証跡が Q2 の結論の根拠になった） |
| D21 | レビュー F7 | 調査計画 0002 の「一時フックを `settings.json` に登録」は、§8 初期値の `investigation`（deny `.claude/**`）と `common.confirm`（`settings.json`）のどちらでも通らない経路を計画していた。分類器の拒否より前に機構自身が止める設計 | 実装で吸収（計画の誤り。機構の上限が正）。調査計画仕様に「`.claude/**` への一時変更は計画しない」を 1 文足すか判断 |

## 想定と異なった点

- `.gitattributes` がリポジトリに無い（仕様 §8 は存在する前提。D14）
- `参考ディレクトリ/` という日本語パスは Windows native jq のテストを壊す（参考テストを動かすときだけの問題）
- auto モードでは AI 自身が `.claude/settings.json` を書けない（Bash・Edit とも分類器が拒否）。2/3 のフック登録は人間の適用か権限ルールの明示が要る
- `permissionDecision: "defer"` という値が存在する（`-p` で SDK ラッパーが入力を集めて再開）。§10 のヘッドレス設計の将来の選択肢
- 調査実施が参考テスト 32 本を実行しており、exec 仕様の禁止事項と §8 の `investigation.ops` を超えていた（計画は 1 本）。逸脱は 0007 の作業ログに記録し、仕様間の矛盾は D20 に載せた
- 参考実装に eval 資産（`evals/evals.json`）が存在する（敵対的レビューは「0 件」としたが誤り。Q6）

## 残課題

- 参考テストの未解明の失敗 2 件（`test_block_direct_git_commit.sh` の改行を挟んだ `commit` 1 件、`test_install_to_project.sh` のタイムアウト）は原因未調査。新機構のテストで同種のケースを書くときに再現を確認する
- HTML テンプレートのブラウザでの実表示は参考実装側でも未確認。初版作成時に目視する
- shellcheck が本環境に無く、shell-script 仕様の規約検査は「省略の事実を記録」の分岐に常に入る。CI（Linux）で shellcheck を回す案は 2/3 以降で検討
