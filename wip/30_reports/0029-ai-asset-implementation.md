---
type: report
title: "0029 AI アセット実装結果 — 案内側フック 6 本: 判定できないときは黙って通す"
description: 登録段階 ① に載る案内側フック 6 本（session-start / workflow-diff-check / post-push-compact-prompt / post-push-usage-report / subagent-start-check / subagent-stop-check）とテスト 237 件。4c プローブの仕込みと、実装中に見つけた仕様との 7 件の差
tags: [report, ai-asset-implementation, issue-9, hooks]
keywords: [案内側, additionalContext, systemMessage, approvals.json, usage.json, push-detect, transcript, scope.sh, 4c プローブ, WF601, WF801, WF811, WF901, WF911]
---

# 0029 AI アセット実装結果 — 案内側フック 6 本

- 対象 issue: #9 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9
- PR: #12 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/12

## サマリ

登録段階 ① に載る**案内側フック 6 本**を書いた。案内側は「判定できないときは黙って通す」ので、fail-closed ラッパーを付けていない。

| フック | 何をするか | 識別子 | テスト |
|---|---|---|---|
| `00-SessionStart/session-start.sh` | 現在地の注入（判定は `boundary.sh` に委ねる） | WF701〜704 | SE-T05 後半 / SE-T06 後半 = 14 件 |
| `22-PostToolUse/workflow-diff-check.sh` | 許可範囲外の差分の検知と承認の記憶 | WF601〜604 | DC-T01〜T07 = 43 件 |
| `22-PostToolUse/post-push-compact-prompt.sh` | push 後の参照リンクと `/compact` の促し | WF901〜903 | PP-T01〜T08 = 37 件 |
| `22-PostToolUse/post-push-usage-report.sh` | 対応工数の集計とレポート本文 | WF911〜913 | UR-T01〜T07 = 36 件 |
| `12-SubagentStart/subagent-start-check.sh` | 実行者の不一致・background 起動の通知と要点の注入 | WF801〜803 | SA-T01〜T09 = 56 件 |
| `13-SubagentStop/subagent-stop-check.sh` | 作業中のまま残ったチケット・未コミット・範囲外差分 | WF811〜814 + 縮退時の WF801 | SP-T01〜T08 = 51 件 |

本体に判定規則は 1 つも書いていない。許可範囲は `scope.sh`、push の検知は `push-detect.sh`、transcript の解析は `transcript.sh`、コマンド位置は `cmdpos.sh` に閉じている。**`workflow-diff-check` と `subagent-stop-check` が同じ `scope_resolve` を通す**ので、範囲の判定が 2 か所で食い違わない。

6 本すべてに **4c プローブ**（`WORKFLOW_PROBE_4C=1` のときだけ働く一時の仕組み）を仕込んだ。既定では副作用がゼロであることを 4 本のテストで固定している。

実装中に**仕様との差を 7 件**見つけた（作業ログ「仕様からの逸脱」）。うち 2 件（`git status -uall`・縮退判定の引き方）は仕様の側を直す必要があり、0032 へ送る。

## レビューしてほしい観点

**◆特に見てほしい（判断に困っている）**

- **r1（△注意）`subagent-stop-check` の縮退判定を agentId で引けない**。仕様は「同じ `tool_response.agentId` について `subagent-start-check` の記録があるか」と書くが、`subagent-start-check` が走る PreToolUse `Agent` の時点では **agentId がまだ発行されていない**ので、記録に載せようがない。実装は「このセッションの `subagent-start-check` の記録が 1 件でもあるか」で引いた。**縮退は「登録行が外れている」というセッション横断の条件**なので単位としては合っているつもりだが、「同じセッションで 1 回でも Agent を起動していれば以後は縮退でないと判定する」という副作用がある
- **r2（△注意）`git status` に `-uall` を足したこと**。既定では未追跡がディレクトリ単位に畳まれ、`wip/` の 1 行になる。中身の許可範囲を判定できず、実測で `wip/` が未記載（WF202）として WF601 に化けた。代償は「未追跡が大量にあるリポジトリで走査が重くなる」こと。**この交換で良いか**
- **r3（△注意）`workflow-diff-check` が `approvals.json` にロックを取らないこと**。ホットパスから `hc_lock` を呼ぶと `find` が毎回 fork する。`hc_json_write` の一時ファイル + `mv` だけで守り、競合時に失われるのは「同時に別のフックが書いた承認 1 件」に留まる、という判断

**◇承認が欲しい（方針は決めた）**

- **r4**: `workflow-diff-check` が「今回承認された範囲」をその場の差分判定にも反映すること（足さないと、承認されて実行された直後の Write が WF601 に列挙される）
- **r5**: `subagent-start-check` の 2 経路出力を、`hook-common` の private ヘルパ（`__hc_redact_to_reply` / `__hc_json_str`）を直に使って組み立てたこと。公開 API 化は 0032 へ
- **r6**: WF911 / WF913 の識別子を本文の先頭に自分で置いたこと（`hook_inject` は `hook_notify` と違って識別子を付けない）
- **r7**: `--accumulate`（Stop / SubagentStop）は停止中に `decisions.jsonl` へ何も書かないこと

**・細かいレビューは不要（ほぼ確実）**

- `post-push-compact-prompt` の 2 件のバグ修正（`logs/mr.json` のキーを `.mr` に、`push-state.json` の更新を `--slurpfile` + プロセス置換から直読みに）
- SP-T08 のテストで `executor` を `sub-opus` ではなく `opus` にしたこと
- `session-start` のテストを SE-T05 後半・SE-T06 後半の 2 件に絞ったこと（DDR i0009-09 と同じ理由）

## 確かめられなかったこと（この結果が言っていないこと）

- **本番のフックとして動かしていない**。6 本とも `settings.json` に登録していない（登録は ① で、人間の操作。0031）。したがって「Claude Code が実際にこの JSON を受け取ってどう振る舞うか」（T1〜T4 / T9）はまだ 1 つも測れていない。4c プローブはそのために仕込んだ
- **`boundary.sh` が無いので `session-start` の本体（注入の整形）は空**。SE-T01〜T04・T07〜T09 は 3/3（issue #10）へ送った
- **`--accumulate` を本物の transcript で動かしていない**。テストは固定の JSONL で、実際の Claude Code の transcript の形（フィールド名・ネスト）とは突き合わせていない
- **並行実行を測っていない**。`workflow-diff-check` と `post-push-usage-report` は同じ PostToolUse で並列に走るが、`approvals.json` / `usage/<branch>.json` の同時書き込みは検査していない
- **`shellcheck` は 6 巡連続で未導入**。静的検査は実施できていない
- **PowerShell 側の経路は薄い**。`cmdpos_parse ... powershell` を渡す分岐はあるが、テストは bash の入力しか通していない

## 実施条件（読んだ対象）

| 対象 | 内容 |
|---|---|
| チケット | `wip/10_tickets/20_done/0029-ai-asset-implementation.md`（DoD 11 件） |
| 計画 | `wip/20_plans/0016-ai-asset-implementation-plan.md` ステップ 3 |
| 仕様 | 各フック仕様 6 本、フック共通仕様 §1〜§12 |
| 実体 | `.claude/hooks/00-SessionStart/`、`12-SubagentStart/`、`13-SubagentStop/`、`22-PostToolUse/`、`lib/probe-4c.sh` |
| 環境 | Windows 10 Pro / Git Bash・`jq` あり・`shellcheck` **無し**・`block-chmod` のみ登録済み |

## 実施した内容と結果

### 1. `workflow-diff-check` — 承認の記憶と差分の検知

2 つの仕事を 1 本に持つ。

**承認の記憶**: 書き込み操作が PostToolUse に届いた = 人間が承認して実行された、と読む。対象パスを `scope_resolve` にかけ、WF202（未記載）だったものの承認単位（親ディレクトリ。`file_granular` とルート直下はファイル単位）を `approvals.json` に追記する。WF203（毎回確認）は記憶しない。対象パスは Edit / Write なら `tool_input.file_path`、Bash なら `cmdpos` + `scope_classify` の `SC_TARGETS`（リダイレクト先・`cp` / `mv` / `tee` などの書き込み先）から取る。

**差分の検知**: `git status --porcelain=v2 -z -uall` と `git diff --name-status -z <base_sha>` を合わせ、パスごとに `scope_resolve`。deny / ask のものを WF601 に並べる。

**今回承認された範囲は、その場の差分判定にも反映する**。足さないと「未記載パスへの Write が承認されて実行された直後に、そのファイルが範囲外として列挙される」ことになる。

### 2. `post-push-usage-report` — 1 本を 2 つの契機で使う ◯確認

`--accumulate`（Stop / SubagentStop）で `logs/usage/<branch>.json` に加算し、既定（PostToolUse）で合算してレポート本文を作る。

- **二重計上の防止**は `last_offset`（transcript の処理済み行数）。`--accumulate` を 2 回呼んでも、push 時の取り込みでも増えない（UR-T02）
- **SubagentStop は `agent_transcript_path` を読む**。`transcript_path` はメインのものなので、読むとメイン分が `subagents[]` に二重計上される。負のケース（`agent_transcript_path` が無い SubagentStop で `subagents` が増えない）も固定した（UR-T03）
- **起点は自分の状態から渡す**。`push-state.json` は読まないので、並列に走る `post-push-compact-prompt` が先に状態を進めても検知が壊れない（UR-T07。DDR i0009-24）
- **実作業時間**は `transcript.sh` が返す `timestamps` を呼び手側で足す。ユーザー入力（`u`）の直前の間隔と 10 分超の間隔を除く

### 3. `subagent-start-check` — 2 つのイベント、2 つの経路 △注意

同じスクリプトを SubagentStart と PreToolUse `Agent` に登録し、`hook_event_name` で分ける。SubagentStart には `model` が来ないので、比較できるのは PreToolUse だけ（DDR i0009-06）。

WF801 / WF803 は **`systemMessage` と `additionalContext` の両方**に出す。前者はユーザーにその場で表示され、**サブエージェントが動き出す前に人間が気づける唯一の経路**。後者は `Agent` の結果の隣に入る。

**通知しなかったときも `skip` を理由つきで記録する**（DDR i0009-52）。`subagent-stop-check` が「PreToolUse の経路が使えたか」を記録の有無で判定するため。理由は 6 通り（一致 / 対象チケット無し / `executor` の記載無し / 実行者がメイン / `model` が特定できない / `subagent_type` が対象外）。

### 4. `subagent-stop-check` — `status` で分ける ◯確認

`tool_response.status` が `async_launched`（background へ移った = **まだ作業していない**）なら、作業後の検査（WF811〜813）をしない。行うと作業前の作業領域を見ることになる。代わりに WF814 で「background 起動なので完了後の検査は届かない」と伝える。

`completed` なら SubagentStop が残した `logs/sessions/<session_id>/subagent-<agent_id>.json` を `tool_response.agentId`（camelCase）で引き、無ければその場で検査する。

### 5. 4c プローブ ✕逸脱

`decisions.jsonl` は §5 で 10 キー固定なので `permission_mode` / `model` / `tool_response` / `agent_type` を入れる場所が無い。`systemMessage` を出す WF801 / WF803 は `subagent_type` が `task-executor` で `executor` が main 以外のときにしか発火しないので、そのままでは T9（`systemMessage` が届くか）が測れない。

`lib/probe-4c.sh` を足し、6 本すべてが入力の読み込み直後・**早期 return より前**で `probe_4c` を呼ぶ。落とすのは (a) 7 フィールドの値と (b) それ以外のキーの名前と型だけ。`hc_append_jsonl` 経由にして redact と 4 KB 切り詰めを得る。

**逸脱 2 件**（`rules/logger.md` の「値ではなく有無・長さ」／§5 の `logs/` の表に無いパス）は作業ログに記録した。0031 の実測が終わったらこのファイルと呼び出し 1 行を削る。

### 6. 実装中に見つけた自分のバグ 2 件（`post-push-compact-prompt`）✕問題

どちらも 0029 で書いたコードで、テストが拾った。

- **`push-state.json` が 1 度も書けていなかった**。`jq -nc --slurpfile cur <(cat "$state" ...)` のプロセス置換（`/dev/fd/63`）を Windows の jq が開けず、`__cp_new` が空になって黙って終わっていた。ファイルを直に読む形に直した
- **`logs/mr.json` の MR 番号を `.number // .iid` で読んでいた**。正のキーは `.mr`（`00-workflow-issue-mr-driven` 仕様）。`.mr // .number // .iid` に直した

## 検証の結果

| 対象 | 件数 | 結果 |
|---|---|---|
| `test_session_start.sh`（SE-T05 後半 / SE-T06 後半） | 14 | FAIL 0 |
| `test_workflow_diff_check.sh`（DC-T01〜T07） | 43 | FAIL 0 |
| `test_post_push_compact_prompt.sh`（PP-T01〜T08） | 37 | FAIL 0 |
| `test_post_push_usage_report.sh`（UR-T01〜T07） | 36 | FAIL 0 |
| `test_subagent_start_check.sh`（SA-T01〜T09） | 56 | FAIL 0 |
| `test_subagent_stop_check.sh`（SP-T01〜T08） | 51 | FAIL 0 |
| `test_templates.sh`（SS-T05 = `__ss_load` のバイト一致を含む） | 43 | FAIL 0 |
| 全件テスト（既定ロケール / `LC_ALL=C.UTF-8`） | 21 本 / 112 件 | FAIL 0 |

`bash -n` は 6 本とも通る。各テストは `bash <script> < 入力 JSON` の形で本体を起動し、終了コード 0 を `assert_exit` で固定している。

## 設計への反映（後続へ）

0032（設計反映）へ送る項目は作業ログ「AI アセットに反映すべき内容」に列挙した。今回の分の要点:

- `workflow-diff-check.md` 制御方式 4 に `-uall` を書く
- `subagent-stop-check.md` 制御方式 2 の縮退判定を「セッション単位」に直す（agentId では引けない理由つき）
- `hook-common` に 2 経路出力（`systemMessage` + `additionalContext`）の公開 API を置く
- フック共通仕様 §3 に `hook_notify` と `hook_inject` の識別子の扱いの差を書く
- `logs/mr.json` の MR 番号のキーが `.mr` であることを明記する

## 想定と異なった点

- **テストが本物のリモートへ接続した**。`post-push-compact-prompt` のリンク形式を見るために origin の URL を `https://github.com/example/repo.git` に差し替え、そのまま `git push` したため、github.com への認証プロンプトがユーザーに見えた。push 先をローカルの bare に固定し、`GIT_TERMINAL_PROMPT=0` と空の `credential.helper` を下ごしらえに入れた
- **`subagent-start-check` の記録に agentId を載せられない**（上記 r1）。仕様を書いた時点では PreToolUse で agentId が取れる前提だった
- **`hook_inject` が識別子を付けない**。`hook_notify` と対称だと思っていた

## 残課題

- **0030（拒否側 4 本）**: `workflow-guard` / `workflow-state-guard` / `workflow-entry-guard` / `block-gh-ready`
- **0031（人間の操作）**: 段階登録 ①② と T1〜T4 / T9 の実測。`WORKFLOW_PROBE_4C=1` の新しいセッションが要る
- **0032（設計反映）**: 上記に加えて累積分（フック共通仕様 §7 の `CP_DATA`・区切りバイトの割り当て表・`push_detect` の終了コード検査の除去ほか）
- **`shellcheck` 未導入**（6 巡連続）
- **`check-html.sh` が md と HTML の内容一致を検査しない**（17 回連続の申し送り）
- **`hc_append_jsonl` / `hc_json_write` の並行書き込みが未検査**
