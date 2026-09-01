---
type: report
title: 0006 調査結果 — hooks/lib との結線の確認と参考実装との差分
description: issue #9 で実装する 11 本のフックが呼ぶ hooks/lib 5 本の公開関数を洗い出し、各フック仕様の前提との対応・欠けている機能・二重定義・読み込み順の制約を確認し、参考実装（agent-workflow）の構造・終了方式・テストの書き方との差分を列挙した調査結果
tags: [report, investigation, issue-9]
keywords: [hooks/lib, hook-common, cmdpos, scope, push-detect, transcript, 結線, tool_class, HOOK_DENY_ID, frontmatter, 参考実装, exit 2, permissionDecision]
---

# 0006 調査結果 — hooks/lib との結線の確認と参考実装との差分

## サマリ

`hooks/lib` 5 本（`hook-common` / `cmdpos` / `scope` / `push-detect` / `transcript`）の公開 API は、11 本のフック仕様が前提にしている呼び出しを**ほぼそのまま満たす**。仕様にあって lib に無い関数は 0 件で、lib にあって誰も呼ばない関数も 0 件だった。ただし結線の際に注意が要る点が 4 件ある: `tool_class` の振り分けスキル判定が `00-workflow-*` のハードコードで `entry-skills.txt` と二重定義になること、案内側フックが frontmatter を読む経路が未定（§12 T8）であること、`HOOK_DENY_ID` を `scope.sh` の `source` より前に設定する必要があること、そして各フックが自前で書く処理が 9 種類あること。参考実装（`agent-workflow`）は**流用できるのはテストの骨格まで**で、本体は終了方式（`exit 2` + stderr）・状態ファイルの置き場・登録タイミングがいずれも本仕様と違うため書き直しになる。

- ◎良 2 件 / △注意 5 件 / ✕問題 0 件

### ◆特に見てほしい（判断に困っている）

- **f3**: 案内側フック（`subagent-start-check` / `subagent-stop-check` / `workflow-diff-check`）が frontmatter を読む経路。`scope.sh` は `frontmatter.sh` を **`deny` ポリシー**で `source` するため、読めないときに deny JSON を出して終了 0 になる。案内側の「失敗しても何も出さずに通す」と矛盾する（§12 T8 そのもの）。`subagent-start-check` は `scope.sh` を必要としないので `__ss_load frontmatter nop` で自前に読むのが整合的だが、`workflow-diff-check` / `subagent-stop-check` は `scope.sh` が要るため選べない

### ◇承認が欲しい（方針は決めた）

- **f2**: `hook-common.sh` の `tool_class` が持つ `00-workflow-*` の判定を、`workflow-entry` 側で `entry-skills.txt` と突き合わせる形にする（lib は分類のみ、宣言スキル名の正はファイル）
- **f4**: 拒否側フックは `HOOK_DENY_ID=WFx09` を**ライブラリの `source` より前**に置く。実装の型として全フックで統一する
- **f6・f7**: 参考実装からは**テストの骨格**（一時ディレクトリをルートに見立てて stdin に JSON を与え、終了コード・stdout・stderr を検証）だけを流用し、本体は仕様どおりに書き直す

### ・細かいレビューは不要（ほぼ確実）

- **f1**: lib の公開 API × 11 フックの対応表（欠けている関数 0 / 未使用の関数 0）
- **f5**: 各フックが自前で書く処理 9 種類の一覧

## 確かめられなかったこと（この結果が言っていないこと）

- lib の各関数が**仕様どおりに動くか**（#6 で HK-T02〜T08・T10〜T15 が通っている前提を採った（HK-T01 と HK-T09 はこの issue で作る）。この調査では実行していない）
- 公式 hooks リファレンスとの整合（**0007 の担当**）
- `permissionDecision` + 終了 0 の deny が実際に効くか（**§12 T6。実測はフェーズ 4**。この報告は「参考実装に実績が無い」ことまで）
- 参考実装の `MR-driven-workflow` 側（提供コマンド相当）の流用可否。今回は `agent-workflow/.claude/hooks/` に限定した
- `HOOK_DENY_ID` を設定必須にした場合の提供コマンド側への影響（0005 の残課題）: `hook-common.sh` を `source` しているのはフックだけで、提供コマンド（`commit.sh` / `ticket.sh` 等）は `logger.sh` と `frontmatter.sh` しか読まないことは確認した（`grep -l hook-common`）が、将来の追加までは保証しない

## 実施条件（読んだ対象）

- `.claude/hooks/lib/*.sh` 5 本（1148 行）と `.claude/skills/20-common-step-shell-script/scripts/frontmatter.sh`（246 行）のヘッダコメントと公開関数
- `.claude/docs/10_spec/hooks/**/*.md` 11 本（0005 で読んだもの。呼び出しの前提の抽出）
- `参考ディレクトリ/agent-workflow/.claude/hooks/` 8 本（2013 行）とそのテスト 6 本（879 行）
- 実行はしていない（`grep` / `sed` による読み取りのみ）

## 実施した内容と結果

### f1. lib の公開 API は 11 本の仕様の前提を満たす（欠け 0 / 未使用 0）◎良

根拠: 各 lib のヘッダコメント（提供する関数の一覧）と 11 本の仕様の「入出力」「制御方式」

| lib | 公開関数 | 使うフック |
|---|---|---|
| `hook-common.sh` | 関数: `hook_init` / `hook_read_input` / `hook_field` / `tool_class` / `hook_enforce_enabled` / `hook_headless` / `redact` / `hook_jq` / `hook_require_jq` / `hook_record` / `hook_deny` / `hook_ask` / `hook_notify` / `hook_inject` / `hook_allow` / `hook_disabled` / `hook_fail` / `hook_fail_closed` / `hook_session_read` / `hook_session_write` / `hook_rel_path` / `hook_doing_ticket`<br>変数（`hook_read_input` が設定）: `HOOK_SESSION_ID` / `HOOK_TRANSCRIPT_PATH` / `HOOK_CWD` / `HOOK_EVENT` / `HOOK_PERMISSION_MODE` / `HOOK_TOOL` / `HOOK_AGENT_ID` / `HOOK_AGENT_TYPE` / `HOOK_PROMPT_ID` / `HOOK_COMMAND` / `HOOK_FILE_PATH` / `HOOK_SKILL` / `HOOK_SUBAGENT_TYPE` / **`HOOK_MODEL`** / **`HOOK_DOING_COUNT`**（`hook_doing_ticket`） | 11 本すべて |
| `cmdpos.sh` | `cmdpos_parse` / `cmdpos_args` / `cmdpos_has_git_subcommand` / `cmdpos_has_provided`（+ 配列 `CP_EXE` / `CP_ARGS` / `CP_SUBCMD` / `CP_REDIRECTS` / `CP_WRITE_TARGETS` / `CP_OPAQUE` / `CP_PROVIDED` / `CP_GITLIKE` / `CP_DEGRADED` / `CP_LOWER`） | `block-direct-git`（正）/ `block-chmod` / `workflow-guard` / `workflow-state-guard` / `post-push-*`（`push-detect` 経由） |
| `scope.sh` | `scope_load` / `scope_load_ticket` / `scope_load_approvals` / `scope_match` / `scope_resolve` / `scope_op_declared` / `scope_classify`（+ `SC_DECISION` / `SC_ID` / `SC_STAGE` / `SC_ASK_SCOPE` / `SC_CLASS` / `SC_TARGETS` / `SC_COMMON_*`） | `workflow-guard`（正）/ `workflow-diff-check` / `subagent-stop-check` / `workflow-state-guard`（`SC_COMMON_STATE_FILES` のみ） |
| `push-detect.sh` | `push_detect`（+ `PD_BRANCH` / `PD_HEAD` / `PD_PREV_SHA` / `PD_COUNT` / `PD_REASON`） | `post-push-compact-prompt`（正）/ `post-push-usage-report` |
| `transcript.sh` | `transcript_aggregate` | `post-push-usage-report`（正） |

- **仕様にあって lib に無い関数: 0 件**。各仕様が名前を挙げている呼び出し（`cmdpos.sh` でコマンド列を得る / `scope.sh` の判定順 / `push-detect.sh` の検知 / `transcript.sh` の集計）はすべて公開 API で足りる
- **lib にあって誰も呼ばない関数: 0 件**。`hook_ask` は `workflow-guard` の WF202 / WF203 のみ、`hook_inject` は `session-start`（SessionStart は stdout・他は additionalContext の分岐を関数が内包）と `subagent-start-check` / `post-push-*`、`hook_jq` / `hook_require_jq` は jq を使う全フックが使う
- 仕様が前提にする値は関数ではなく**変数**で渡る: `HOOK_MODEL`（`subagent-start-check` の WF801 の材料。ただし 0007 f2 のとおり `SubagentStart` の入力には `model` が来ない）/ `HOOK_DOING_COUNT`（`workflow-guard` の WF207）/ `HOOK_AGENT_TYPE`（`subagent-stop-check`。受け入れ条件 5）/ `HOOK_COMMAND`・`HOOK_FILE_PATH`・`HOOK_SKILL`・`HOOK_SUBAGENT_TYPE`（各判定の入力）
- 出力の形（deny / ask JSON、additionalContext、SessionStart の stdout）と `redact` の適用は `hook_deny` / `hook_ask` / `hook_notify` / `hook_inject` の内側で完結しており、フック本体が JSON を組み立てる必要は無い

結論: 結線は「`hook_init` → `hook_read_input` → 判定 → `hook_deny`/`hook_ask`/`hook_notify`/`hook_inject`/`hook_allow`」の型に収まる。11 本ともこの型で書ける。

### f2. `tool_class` の振り分けスキル判定が `entry-skills.txt` と二重定義になる △注意

根拠: `hook-common.sh:156-166`（`tool_class`）と `workflow-entry` 仕様「呼出条件」・WE-T07

- `tool_class` は `Skill` ツールのとき `case "${2:-}" in 00-workflow-*) declare ;; *) read ;; esac` と、**`00-workflow-` の接頭辞をコードに持っている**
- 一方 `workflow-entry` 仕様は、振り分けスキル名の正を `assets/entry-skills.txt`（`00-workflow-issue-mr-driven` / `00-workflow-quick-request`）に置き、WE-T07 で `CLAUDE.md` の表との一致を検査すると定める
- したがって「振り分けスキルかどうか」の判定が lib（接頭辞）とファイル（列挙）の 2 か所にある。将来 `00-workflow-` で始まる別のスキル（例: `00-workflow-hotfix`）が増えると、`tool_class` は `declare` を返すが `entry-skills.txt` には無い、という食い違いが起こる
- 実測への依存: 無し

結論: `tool_class` は「ツールの種類の分類」に徹し（`Skill` は常に `declare` 候補として返す）、**振り分けスキル名の照合は `workflow-entry` が `entry-skills.txt` を読んで行う**のが素直。lib を変えるか、`workflow-entry` 側で二重に確かめるかは設計で決める（`tool_class` を変えると HK-T03 系のテストに影響する可能性がある）。

### f3. 案内側フックが frontmatter を読む経路が未定（§12 T8 そのもの）△注意

根拠: `scope.sh:20`（`__ss_load frontmatter deny`）、`20-common-step-shell-script` 仕様「読み込み行」、`subagent-start-check` / `subagent-stop-check` / `workflow-diff-check` 仕様

- `scope.sh` はファイル先頭で `__ss_load frontmatter deny` を実行する。`frontmatter.sh` が見つからないと **deny JSON（`${HOOK_DENY_ID:-WF009}`）を出して `exit 0`** する
- `scope.sh` を `source` するのは `workflow-guard`（拒否側 = deny で正しい）に加えて、**案内側の `workflow-diff-check` と `subagent-stop-check`**。案内側の禁止事項は「判定できないときに何かを伝えない（黙って通す）」なので、deny JSON を吐くのは矛盾する（PostToolUse では `permissionDecision` は無視されるため実害は小さいが、出力としては誤り）
- `subagent-start-check` は frontmatter を読むが `scope.sh` は要らない。`__ss_load frontmatter nop`（読めなければ `fm_*` が空を返すスタブ）を自前で使えば、案内側の方針と一致する
- 実測への依存: **あり**（T8 は「実機で害があるか」を確かめる項目）。ただし**経路の設計**は実測を待たずに決められる

結論: 3 案 —（a）`scope.sh` の読み込みポリシーを `nop` にして、呼び手（拒否側）が自分で失敗を deny に倒す（§12 T8 の縮退案そのもの）／（b）案内側専用の薄いラッパを用意する／（c）現状のまま T8 の実測を待つ。**（a）が仕様の縮退案と一致**する。ただし倒す材料は `scope_load` ではなく **`scope_load_ticket` の戻り値**（`scope_load` は `scope-limits.json` と `jq` しか見ず `fm_*` を呼ばない。frontmatter を使うのは `scope_load_ticket` の `fm_get` / `fm_list`）。さらに `nop` にすると、`scope_load_ticket` の失敗が「`frontmatter.sh` が無い（機構の破損 → WF209）」なのか「チケットに `ticket_type` が無い（記載不正 → WF211）」なのか**戻り値から区別できなくなる**（現行の `deny` ポリシーは前者を `source` 時点で捕まえている）。区別の付け方は設計の論点。

### f4. `HOOK_DENY_ID` はライブラリの `source` より前に設定する必要がある △注意

根拠: `scope.sh:20` の読み込み行（`${HOOK_DENY_ID:-WF009}` を `source` 時に評価）、`hook-common.sh:23`・`hook_init` の第 3 引数

- `hook_init <名前> <side> <識別子>` で `HOOK_DENY_ID` を設定できるが、`scope.sh` の読み込み行は **`source` した瞬間**に `${HOOK_DENY_ID:-WF009}` を参照する。`. scope.sh` を `hook_init` より前に書くと、`frontmatter.sh` が読めない場合の deny が `WF009`（台帳に無い番号。0005 の f2）になる
- したがって拒否側フックの冒頭は「`HOOK_DENY_ID=WF209` を代入 → `. hook-common.sh` → `. scope.sh` → `hook_init ... deny WF209`」の順になる。この順序は `20-common-step-shell-script` 仕様の「識別子は呼び手が読み込み行より前に `HOOK_DENY_ID` で設定する」と一致する
- 実測への依存: 無し

結論: 実装の型として「変数の代入 → lib の source → `hook_init`」を 11 本で統一する。実装計画のチェックリストに入れる。

### f5. 各フックが自前で書く処理は 9 種類 ◎良

根拠: 11 本の仕様の制御方式と lib の公開 API の差分

| # | 自前で書く処理 | 必要なフック |
|---|---|---|
| 1 | チケットの存在判定（`00_todo` / `20_done` を含む。lib は `10_doing` のみ） | `workflow-entry`（継続条件）、`subagent-start-check`（todo 最小連番） |
| 2 | `approvals.json` への**追記** | `workflow-diff-check`（lib は読み取り `scope_load_approvals` のみ） |
| 3 | `push-state.json` の更新 | `post-push-compact-prompt`（`push_detect` は読むだけ） |
| 4 | `logs/usage/<branch>.json` の加算・レポート本文の整形・ファイル出力 | `post-push-usage-report` |
| 5 | 注入テキストの組み立てと 8 KB 判定 | `session-start` |
| 6 | `model-aliases.txt` による起動モデルの正規化 | `subagent-start-check` |
| 7 | `blocked-commands.txt` の読み取りと前置フィルタ | `block-chmod` |
| 8 | draft 解除コマンドの検知（`gh pr ready` / `glab mr update --ready` / MCP の `draft:false`） | `workflow-state-guard` |
| 9 | ホスト判定とリンクの組み立て（GitHub / GitLab の URL 表） | `post-push-compact-prompt` |

- `logs/sessions/` の 7 日より古いディレクトリの削除（`session-start` 制御方式 2）も lib に無いが、`find -mtime +7 -exec rm -rf` 相当の 1 行なので上表には含めない

結論: 実装量の重心は `workflow-guard`（判定順が長い）・`post-push-usage-report`（集計と整形）・`session-start`（注入の組み立て）・`workflow-state-guard`（3 系統の検知）。実装チケットの分割はこの重さに合わせる。

### f6. 参考実装は構造・状態ファイル・登録タイミングが本仕様と違う △注意

根拠: `参考ディレクトリ/agent-workflow/.claude/hooks/` 8 本のヘッダと本文

| 観点 | 参考実装（agent-workflow） | 本仕様 | 扱い |
|---|---|---|---|
| ライブラリ | `workflow-lib.sh` 1 本（240 行。`wf_resolve` / `wf_match` / `wf_session_remember` / `wf_load_config` ほか 14 関数） | `hooks/lib/` 5 本に分割済み（#6 で実装） | **書き直し済み**。参考にする必要なし |
| 状態ファイル | `.claude/hooks/.state/<session_id>.entry`（key=value） | `logs/sessions/<session_id>/entry.json`（JSON） | 本仕様に従う |
| 宣言の記録 | **PostToolUse**（matcher `Skill`）で記録 | **PreToolUse**（matcher `Skill`）で記録 | 本仕様に従う（読み込み前に記録するので、Skill の実行が失敗しても宣言は立つ） |
| 設定 | `workflow-types.json`（種別ごとの許可範囲） | `.claude/hooks/config/scope-limits.json` + `task-types.tsv` | 本仕様に従う（#6 で実装済み） |
| フックの本数 | 6 本（entry / guard / boundary / diff-check / block-chmod / merge-prep・work-boundary は提供コマンド） | 11 本 | 参考にできるのは 4 本（entry / guard / diff-check / block-chmod）。`session-start` / `subagent-*` / `post-push-*` / `state-guard` に相当するものは**無い**（7 本は新規） |
| テスト | 一時ディレクトリをプロジェクトルートに見立て、stdin に JSON を与えて終了コード・stdout・stderr を検証（6 本 879 行） | `test-lib.sh` の `hook_payload` + `run-tests.sh`（#6 で実装） | **骨格は同じ**。`cygpath -m` による Windows パスの扱いは参考になる |

- ファイル単位の判定: `workflow-lib.sh`（使わない。lib に置き換え済み）/ `workflow-entry.sh`・`workflow-guard.sh`・`workflow-diff-check.sh`・`block-chmod.sh`（**参考**。判定の骨格は流用できるが、終了方式・設定・状態ファイルが違うので写経はしない）/ `workflow-boundary.sh`・`work-boundary.sh`・`merge-prep.sh`（**使わない**。本仕様では `workflow-state-guard` と提供コマンド `boundary.sh` / `finalize.sh` に再編され、後者は 3/3）
- 実測への依存: 無し

結論: 流用するのは**テストの骨格**（一時ディレクトリ + stdin JSON + 終了コード / stdout / stderr の検証、`cygpath` によるパス正規化）だけ。本体 11 本は仕様から書き起こす。

### f7. 参考実装の deny は `exit 2` + stderr で、`permissionDecision` + 終了 0 の実績が無い △注意

根拠: `workflow-guard.sh:15`・`workflow-entry.sh:16`・`block-chmod.sh:17-18`・`workflow-boundary.sh:17`

- 参考実装は**拒否を `exit 2` + stderr** で行い、`permissionDecision` を使うのは `ask`（`workflow-guard.sh:51`）だけ。`workflow-boundary.sh` と `merge-prep.sh` は「ask は使わず exit 2 のみ（ヘッドレス実行で『確認できないため拒否』にならない）」と明記している
- `block-chmod.sh` だけが **deny JSON と `exit 2` を併用**している（`permissionDecision: "deny"` を出したうえで `exit 2`）。`permissionDecisionReason` は無く `systemMessage` に理由を書いている
- 本仕様（フック共通仕様 §3）は「deny も `permissionDecision` + 終了 0」で統一し、§1 の fail-closed ラッパーもその形を前提にしている。**この形の実績が参考実装には無い**
- 実測への依存: **あり**（§12 T6 の実測でしか確かめられない）

結論: T6（`permissionDecision` + 終了 0 の deny が効くか）は、参考実装が回避していた点でもあるため、**実装の最初に確かめる**価値がある。全体計画の段階登録 ②-1 で拒否側 1 本を登録して確かめる段取りは妥当。外れた場合は 11 本すべての終了方式と §1 のラッパーが変わるので、後回しにするほど手戻りが大きい。

## 検証の結果

| 検証 | 結果 |
|---|---|
| 仕様が呼ぶ lib の関数が実在するか | 実在する（欠け 0 件。f1 の表） |
| lib にあって誰も呼ばない関数 | 0 件（f1） |
| 引数・戻り値・出力先の食い違い | 0 件。ただし結線の制約が 2 件（`tool_class` の二重定義 f2、`HOOK_DENY_ID` の設定順序 f4） |
| 案内側フックの `scope.sh` 読み込みポリシー | 矛盾あり（deny ポリシー。f3 = §12 T8） |
| 各フックが自前で書く処理 | 9 種類（f5） |
| 参考実装から流用できるもの | テストの骨格のみ。本体 11 本は書き起こし（うち 7 本は参考実装に相当物が無い。f6） |
| 参考実装の終了方式 | `exit 2` + stderr。`permissionDecision` + 終了 0 の実績なし（f7） |

## 設計への反映

1. **`tool_class` と `entry-skills.txt` の二重定義**（f2）: 振り分けスキル名の正をファイルに一本化するか、lib の接頭辞判定を残すかを決める（決めたら `workflow-entry` 仕様と `hook-common` の役割分担を仕様に書く）
2. **案内側の frontmatter 読み込み**（f3 / §12 T8）: `scope.sh` の読み込みポリシーを `nop` にして呼び手が失敗ポリシーを決める案を採るか。採るなら `scope.sh` のヘッダと共通仕様 §12 T8 を書き換える
（以下は設計ではなく **実装計画（フェーズ 4）への申し送り**。0008 は設計チケットに割り付けず、実装計画に渡す）

- **実装の型**（f4）: 「`HOOK_DENY_ID` の代入 → lib の source → `hook_init`」を 11 本で統一する。実装計画のチェックリストに入れる
- **T6 を最初に確かめる**（f7）: 段階登録 ②-1（拒否側 1 本）で `permissionDecision` + 終了 0 の deny を確認してから残りを書く。外れた場合の手戻り（11 本 + §1 ラッパー）を保留した点に記録する
- **実装チケットの分割**（f5）: 重い 4 本（`workflow-guard` / `post-push-usage-report` / `session-start` / `workflow-state-guard`）と軽い 7 本で分ける

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| lib に足りない関数が見つかる | 欠け 0 件・未使用 0 件。#6 の実装が 11 本の仕様を正確に先取りしていた | f1 に記録。設計の対象は「結線の制約」に絞られた |
| 参考実装のフックを部分的に流用できる | 相当するフックは 4 本だけで、終了方式・状態ファイル・設定がすべて違う。流用できるのはテストの骨格のみ | f6 に記録し、流用可否の決定は実装計画へ送る |
| `scope.sh` の読み込みポリシーは実測（T8）待ち | 案内側 2 本が deny ポリシーの `scope.sh` を読む構造は、実測を待たずに矛盾と分かる | f3 として設計への反映に挙げた |

## 残課題

- `tool_class` を変更する場合、既存テスト（HK-T03 系）の期待値に影響するかは未確認（テストを実行していない）
- `scope.sh` の読み込みポリシーを `nop` に変えた場合、`workflow-guard` が `scope_load` の戻り値だけで deny に倒せるか（`fm_*` のスタブが空を返す経路の網羅）は実装時に確かめる
- 参考実装の `cygpath -m` によるパス正規化は #6 の `test-lib.sh` に取り込まれていない（`grep -c cygpath` → 0）。Windows のパスで問題が出たら実装時に足す
- `MR-driven-workflow` 側の参考実装（提供コマンド相当）は今回読んでいない。3/3 の `boundary.sh` / `finalize.sh` の実装時に見る
