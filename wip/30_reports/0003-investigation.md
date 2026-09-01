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

（全チケット完了時に記入）

## Q1 参考実装の流用範囲（チケット 0003）

### 答え（1）フック共通ライブラリ側 — `hooks/lib/{hook-common,cmdpos,scope,push-detect,transcript}.sh`

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

- **参考実装に共通 logger も redact も存在しない**（`log_info` / `LOG_LEVEL` / `logger.sh` / `redact` で 2 リポジトリ全文検索してヒット 0 件）。個別実装は `workflow-lib.sh:40-43` の `wf_log`（単一ファイル固定・レベルなし・TZ なし・fail-open）と stderr 出力だけ。**流用できるのは fail-open の 1 行（`>>… 2>/dev/null || true`）と改行を畳む純関数 `push-checklist.sh:105-116`** で、`logger.sh` は事実上新規（付録 B §2-1 の差分表）
- 置き場は仕様どおり `.claude/skills/20-common-step-shell-script/scripts/logger.sh`、出力先は `logs/sh/<出どころ>.log`（参考の `.claude/hooks/workflow.log` は新仕様では `common.protected` 配下なので使えない）
- **読み込み方（hooks 配下 / skills 配下 / tests の 4 通りの深さから）**: 推奨はフォールバック鎖 (1) `${BASH_SOURCE[0]%/*}` を起点に `.claude` を持つ親を上向きに探す（fork ゼロ・段数非依存）→ (2) `CLAUDE_PROJECT_DIR` → (3) `git rev-parse --show-toplevel`（空文字ガード必須）→ (4) すべて失敗なら no-op 関数を定義して本体を止めない。参考の実例は付録 B §2-2 の 5 方式。**仕様の雛形が (3) 単独（`source "$(git rev-parse --show-toplevel)/…"`）で固定されている点は弱い**（フックは毎ツール呼び出しで git を fork する。git 不在時は `source "/.claude/…"` で `set -e` 即死）
- **時刻**: 仕様の `+09:00` 表記は bash 組み込み `printf '%(%:z)T'` では出せない（実測: 空文字。`%z` は `+0900`）。`printf -v` で `+0900` を得てコロンを文字列操作で挿す（fork ゼロ）
- **redact**: §3 の接頭辞決め打ちパターンは、参考ルール `shell-script-style.md:1252-1262`「接頭辞決め打ちに頼らない。当たらないマスクは誤った安心を与える」と思想が衝突する。仕様は直さず実装し（HK-T10 が「当たること」を担保）、仕様に「一次防御は値を出さないこと。redact は最後の砦」の 1 文を足す（→ D11）

### 根拠

- 付録 B（`wip/30_reports/0003-investigation-appendix-B.md`）§2・§5-1〜5-5。実測: bash 5.2.12 (msys)、jq は Windows ネイティブ 1.6、yq・shellcheck 不在、`git rev-parse --show-toplevel` は `C:/…` 形式、`.gitattributes` 不在

## Q2 テストの実行方式（チケット 0004）

（未着手）

## Q5 HTML テンプレートの土台（チケット 0004）

（未着手）

## Q3 TBD T5 — PowerShell ツールのフック入力（チケット 0005）

### 答え（公式ドキュメント確認分。実機確認はチケット 0005 で追記）

- `tool_name` は `"PowerShell"`。`tool_input` のキーは `command` / `timeout` / `run_in_background` で **Bash ツールと同じ構造**。matcher は `"Bash|PowerShell"` と書け、ドキュメント自身が「`Bash` だけでは不十分（Windows では PowerShell がネイティブに動く）」と明記している（出典: https://code.claude.com/docs/en/tools-reference.md「PowerShell Tool Reference」）
- **T5 の結論（暫定）: 前提どおり**。`hook-common.sh` / `cmdpos.sh` は `tool_input.command` をそのまま読めばよい。フックの登録 matcher は Bash 系フック（workflow-guard / block-direct-git / block-chmod / post-push-*）で `Bash|PowerShell` にする（共通仕様 §1 の登録表は既に `Bash|PowerShell`（行 29〜36）で、設計差分なし）
- 付随して確定した事項（他の TBD・仕様に効く。出典: https://code.claude.com/docs/en/hooks-guide.md「Common Input Fields」「Structured JSON output」）
  - 共通入力フィールド: `session_id` / `prompt_id` / `transcript_path` / `cwd` / `permission_mode`（`default|plan|acceptEdits|auto|dontAsk|bypassPermissions`）/ `effort` / `hook_event_name`。**サブエージェント実行中のみ `agent_id` / `agent_type`** が付く（T2・`subagent-*` の実装材料）
  - ヘッドレス（`claude -p`）を判別するフィールドは記載なし → **T3 は前提どおり**（`WORKFLOW_HEADLESS` / `CI` で明示）。ただし `permissionDecision: "ask"` は非対話モードでは拒否として扱われ、`"defer"` という値（`-p` で SDK ラッパーが入力を集めて再開）が存在する
  - `permissionDecision` は `allow | deny | ask | defer`。exit 2 + stderr と exit 0 + JSON は併用しない
  - `SubagentStart` / `SubagentStop` イベントは存在し、matcher はエージェント種別。入力の固有フィールド（`model` の有無等）と、SubagentStop の出力がメインに届くかは**記載なし**（T1・T4 は 2/3 で実機確認）
  - settings.json のフック設定はセッション開始時に読まれ、**実行中の直接編集もファイル監視で通常は自動反映**される（`/hooks` は閲覧専用）。→ 一時フックによる実機確認は再起動なしで可能な見込み

### 根拠

- `claude-code-guide` エージェントによる公式ドキュメント（hooks-guide / hooks / tools-reference）の確認結果（2026-09-01）

## 仕様と食い違う点（設計フェーズの対象候補）

| # | 出所 | 食い違い | 見立て |
|---|---|---|---|
| D1 | Q1 lib（付録 A §2-A） | チケット宣言の意味: 参考 `allowed_paths` は上限を広げる、仕様 `d.write` は絞る | 実装で吸収（仕様が正）。`scope.sh` のテストで最優先に固定 |
| D2 | Q1 lib（§2-B） | フック共通仕様 §8 が glob の `*` / `**` の意味（`*` が `/` を跨ぐか）を定めていない。初期値表にファイル単位指定と `**` が混在し、`common.confirm` と `types[t].allow` の優先関係が実装依存になる | **仕様を直す**（§8 に「`*` は `/` を跨がない。跨ぐ一致は `**`」を 1 文追加） |
| D3 | Q1 lib（§2-C） | post-push-compact-prompt「push 検知 2」の `HEAD == @{upstream}` は初回 push で解決できない可能性 | **仕様を補う**（`origin/<branch>` → 初回は終了コード 0 + `push-state.json` 未記録で真、の縮退経路） |
| D4 | Q1 lib（§2-E） | §7-8 提供コマンドの識別: 参考は basename 一致のみ（`/tmp/commit.sh` が提供コマンド扱い）かつクォート付きパスは検知不能 | **仕様を補う**（リポジトリルート相対のパス一致を要求。パスが確定しないセグメントは通常判定）+ 実装 |
| D5 | Q1 lib（§2-F） | deny の伝え方: 参考 4 本は `exit 2` + stderr の実績、仕様は permissionDecision JSON + 終了 0 | 仕様どおり実装し、§12 TBD に「JSON 経路の deny が確実に効くか（効かなければ `exit 2` 併用へ縮退）」を 1 行追加。2/3 で実機確認 |
| D6 | Q3 | なし（登録表は既に `Bash\|PowerShell`、`tool_input.command` は同一） | T5 を「確認済み」として §12 から消す（仕様の更新） |
| D7 | Q1 lib（§1-29） | `UserUtteranceSelect.jq`（直近の発話の再注入）は session-start 仕様に対応要件が無い | 使わない（仕様追加はしない）。transcript 形式の一次情報としてだけ参照 |
| D8 | 0001 作業ログ | ワークフロー仕様 手順 2a が参照する「敵対的レビュー要否」の欄が、共通仕様 §9 のチケット frontmatter 例に無い | **仕様を補う**（§9 に `adversarial_review: {required, reason}` を追加し、ticket テンプレートに載せる） |
| D9 | Q1 提供コマンド（付録 B §3-3） | チケット frontmatter の入れ子（`allow.write/ops`）とインラインマップ（`human_review`）を参考パーサは読めない。yq は無い | **実装で吸収（A 案）**: パーサに「親キー + インデントで `parent.child` に畳む」「`{k: v}` の分解」を足す（20〜30 行の見込み）。B 案（frontmatter をフラット化する仕様変更）は可読性を落とすので採らない |
| D10 | Q1 提供コマンド（§3-4） | **仕様内の矛盾**: commit-push 仕様は「`ticket.sh` は内部から `commit.sh` を使う」、ticket 仕様は「各サブコマンドが内部で `git` を直接実行」 | **仕様を直す**（ticket 仕様を `commit.sh` 経由に寄せる。規約検査が 1 箇所に集まる） |
| D11 | Q4（§3-1） | redact の接頭辞決め打ちは参考ルール「当たらないマスクは無いのと同じ」と思想が衝突 | 仕様どおり実装。共通仕様 §3 に「一次防御は値を出さないこと。redact は最後の砦」を 1 文追加 |
| D12 | Q4（§3-2） | `rules/logger.md`「使い方」が `source "$(git rev-parse --show-toplevel)/…"` の 1 行を文字列で固定 | **仕様（要件）を直す**: 「1 行で読み込む・コピー禁止」は残し、行の中身をフォールバック鎖に差し替える |
| D13 | Q1 提供コマンド（§3-6） | ファイル名 `<連番>-<種類>.md` と frontmatter `ticket_type` が食い違ったときの扱いが仕様に無い | 実装は frontmatter を正とする。ticket 仕様に 1 文追加 |
| D14 | Q1 提供コマンド（§5-4） | `.gitattributes` がリポジトリに無いが、共通仕様 §8 の `common.protected` は存在する前提。`*.sh text eol=lf` が無いと CRLF で取り出されてシバンが壊れる | 実装フェーズの最初のステップで `.gitattributes` を作る（仕様変更なし。`.gitattributes` は `common.protected` なので、この issue の許可範囲に明示が要る） |
| D15 | Q1 提供コマンド（§4-16） | 終了コード 2 の意味が衝突する: 提供コマンドは「引数や環境の誤り」、フック契約では「ブロック」 | 仕様は既に別文脈（フックは JSON deny + 終了 0）なので矛盾はないが、shell-script 仕様に「フックでは exit 2 を使わない」を明記する |

（調査 C の結果で追記）

## 想定と異なった点

## 残課題

- shellcheck が本環境に無く、shell-script 仕様の規約検査は「省略の事実を記録」の分岐に常に入る。CI（Linux）で shellcheck を回す案は 2/3 以降で検討
