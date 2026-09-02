---
type: plan
title: 0016 AI アセット実装計画 — 共通ライブラリの作り直しから 17 行の段階登録までを 6 枚に割り付ける
description: 設計 0012〜0015 と境界レビュー反映 0019〜0026 が確定した仕様をもとに、既存の hooks/lib 5 本の改修・フック本体 11 本とテスト・settings.json への 17 行の段階登録（人間の操作）・フェーズ 4c の実測 8 項目を 6 枚のチケットに割り付け、T6 を最初に確かめる順序とロックアウトの復旧経路を実装前に確定する計画
tags: [plan, ai-asset-implementation-plan, issue-9]
keywords: [実装計画, 段階登録, 17 行, HK-T01, T6, T9, systemMessage, hc_lock, hook_read_state, 読み込み行, SS-T05, ロックアウト, WORKFLOW_ENFORCE, フェーズ 4c, worktree]
---

# 0016 AI アセット実装計画 — 共通ライブラリの作り直しから 17 行の段階登録までを 6 枚に割り付ける

## この計画で何をするか

### 結論方針

**設計は「lib は #6 で既に正しい」という前提で書かれたが、境界レビュー 2 巡がその前提を崩した**。`hook-common.sh` には設計が要求する 5 関数（`hook_read_state` / `hc_append_jsonl` / `hc_json_write` / `hc_lock` / `hc_unlock`）が無く、`hook_read_input` は副入力を受け取れず、`scope.sh` は `web` を知らず読み込み関数がパスを引数に取る。**フック本体 11 本を書く前に lib の改修が要る**。

そのうえで **T6（`permissionDecision` + 終了 0 の deny が実際に効くか）を 11 本を書き切る前に確かめる**。外れたときの手戻りが 11 本 + 登録ラッパー全部に及ぶためで、0006 の申し送り f7 が求めているのもこれである。そこで**拒否側の最も単純な 1 本（`block-chmod`）を lib と同じチケットで先に書き、それだけを単独で登録して T6 を確かめる ⓪ の段**を段階登録の前に置く。

6 枚に割る:

| 枚 | 中身 | 先行 |
|---|---|---|
| 0027 | `hooks/lib` 5 本の改修 + `config` 3 ファイルの新規 + 読み込み行の一斉置換 + `block-chmod` 1 本 | なし |
| 0028 | **⓪ T6 の先行確認**（`block-chmod` だけをラッパー無しで登録し、deny が効くかを見る）。結果で終了方式を確定 | 0027 |
| 0029 | 案内側 6 本（`session-start` / `workflow-diff-check` / `post-push-compact-prompt` / `post-push-usage-report` / `subagent-start-check` / `subagent-stop-check`）とテスト | 0027 |
| 0030 | 拒否側の残り 4 本（`workflow-entry` / `workflow-state-guard` / `block-direct-git` / `workflow-guard`）とテスト | 0028, 0029 |
| 0031 | 段階登録 ①・②（17 行）と**フェーズ 4c の実測 8 項目**、HK-T01 と `run-tests.sh --ids` の全件 | 0030 |
| 0032 | `feedback-plan`（次の計画） | 0027〜0031 |

### 実装前に確定した 8 件

1. **段階登録は 17 行**（§1 の表が正）。案内側 **12 行**・拒否側 **5 行**。全体計画が書いた「16 行 / ① 11 行」は `subagent-start-check` の PreToolUse `Agent` 登録（7 行目・WF803）が増える前の数で、**この計画で 17 行 / ① 12 行に組み直す**
2. **T6 の確認は ⓪ で行い、そのときラッパーを付けない**。ラッパーは「本体が起動できない = deny」なので、T6 が未確認の段でラッパーごと登録すると、本体の不調と登録方式の不調が区別できず、しかも**ラッパーは環境変数を見ないので環境変数で戻れない**（§4）。⓪ は素の `command` で登録し、最悪でも fail-open に留める。ラッパーは ② で足し、HK-T09 はそこで通す
3. **T9（`systemMessage` がユーザーに実際に表示されるか）は ① の後に確かめる**。`subagent-start-check` の PreToolUse `Agent` 登録は**案内側**なので ① に入る。全体計画の 4c 表が「②-2（7 行目）の後」と書いているのは段の割り当てを 16 行時代のまま参照した誤りで、この計画で ① の後に直す
4. **HK-T01 の期待値は 17 行分の `command` 文字列の逐語一覧**を、テストのフィクスチャとして `.claude/hooks/tests/fixtures/settings-hooks.expected.tsv`（イベント・matcher・位置・`command` の 4 列）に持つ。イベント名からディレクトリを機械変換できない行が 4 行あるため（§1）
5. **読み込み行は雛形を先に直してから 22 本へ配る**。現在の雛形は仕様と 3 点ずれている（`FM_AVAILABLE` を設定しない / `fm_*` スタブの戻り値が 1（仕様は 2）/ フォールバックに `git rev-parse` が残る）。雛形 → 実体の順でなければ `SS-T05` はどの向きにも落ちる
6. **実装フェーズは DDR を書けない**（`ai-asset-implementation.deny` に `.claude/docs/**`）。実装中の決定は**チケットの作業ログ「判断と根拠」**に、DDR にすべきものは**「AI アセットに反映すべき内容」**に書き、0032（`feedback-plan`）が棚卸ししてフェーズ 6 で DDR にする
7. **`settings.json` は許可範囲に入っているが AI は書かない**。`ai-asset-implementation.allow` に `.claude/settings.json` があり `common.confirm` にもあるので機構としては「確認つきで書ける」が、**この issue の制約として登録は人間の操作**。AI は貼り付ける JSON と手順を提示し、登録後のコミットだけを `commit.sh` で行う（WF203 の確認は人間が承認する）
8. **フェーズ 7 は第 1 案（`WORKFLOW_STATE_GUARD_ENFORCE=0` の新セッション）で通す**。17 行の登録を保ったまま HK-T01 と全件テストが通る状態でマージできる唯一の案。フェーズ 7 の直前に人間と最終確認する

## 対象と範囲

### 入力（読んだもの）

- **設計の結果報告 12 枚**: `0012`〜`0015`（前半）・`0019`〜`0026`（境界レビュー 2 巡の反映）の「設計への反映（後続へ）」
- **指摘の原文**: `0015-ai-asset-design-appendix-A.md`（1 巡目 38 件）・`0022-ai-asset-design-appendix-A.md`（2 巡目 27 件）
- **仕様**: `フック共通仕様`（§1 登録表 17 行・§2 作業ツリー・§3 制御方式・§5 記録とロック・§8 `scope.sh` の出力の形・§11 HK-T01〜T20・§12 TBD）、フック個別 11 本、`20-common-step-shell-script`（読み込み行・`run-tests.sh`）
- **実体**: `.claude/hooks/lib/*.sh` 5 本・`.claude/hooks/config/` 2 ファイル・`__ss_load` を持つ 23 ファイル・`scope-limits.json`
- **申し送り**: `0006` の実装計画への 3 件（実装の型 / T6 を最初に / 重い 4 本と軽い 7 本の分割）、全体計画の「settings.json の登録とロックアウト対策」と「#10 への申し送り」

### 実体と仕様の差分（この計画が拾った未実装）

| 対象 | 現状 | 仕様が要求するもの | 割り当て |
|---|---|---|---|
| `.claude/hooks/**` のフック本体 | **0 本**（9 つのイベントディレクトリはすべて空） | 11 本 | 0027（1 本）・0029（6 本）・0030（4 本） |
| `hook-common.sh` | 30 関数。`hook_read_input` は stdin だけを読む | `hook_read_state` / `hc_append_jsonl` / `hc_json_write` / `hc_lock` / `hc_unlock` の **5 関数が無い**。`hook_read_input` は副入力を `--rawfile` + `fromjson? // null` で受け、`HC_<名前>_STATE` を立てる | 0027 |
| `scope.sh` | 11 関数。`scope_load` / `scope_load_approvals` がパス引数を取り自分で JSON を開く | パス引数を削り `HC_*` から詰め替える。`_SC_WEB_CMDS` と `web` の 3 段判定・出力先の走査、`scope_load_ticket` の戻り値 3 状態、`fm_*` の呼び出し規約（`\|\| true` の除去） | 0027 |
| `.claude/hooks/config/` | `scope-limits.json`・`task-types.tsv` の **2 ファイル** | 5 ファイル。`blocked-commands.txt`（初期値 `chmod`）・`entry-skills.txt`・`model-aliases.txt` が**無い** | 0027 |
| 読み込み行 | 23 ファイルにコピーされているが、雛形自体が仕様と 3 点ずれている | 雛形と 22 本がバイト一致（`SS-T05`） | 0027 |
| `.claude/settings.json` の `hooks` | 未登録 | 17 行 | 0028（⓪ 1 行）・0031（①② 16 行） |
| `.claude/rules/markdown-docs.md` | **存在しない**のに `ai-asset-design-docs.md:38` と `design-docs.md:36` が frontmatter の正として参照 | 参照が解決すること | 0027（`.claude/rules/**` は許可範囲） |

### やらないこと

- `.claude/docs/**` への書き込み（実装フェーズの `deny`。実測の書き戻しはフェーズ 6）
- 提供コマンド（`ticket.sh` / `commit.sh` / `push.sh` / `run-tests.sh` / `check-html.sh`）の実体の変更。`push.sh` の 1 枚目依存は #10 への申し送り 2
- `boundary.sh` / `finalize.sh` の実装（3/3）。依存する 10 件のテスト観点は申し送り 1 のまま
- `scope-limits.json` の実体変更。15 種すべてが揃い `investigation.ops` に `web` も入っており、**変更の必要が無い**ことを確認した（DDR `i0009-19` の「上限は広げない」と一致）
- `PostToolUseFailure` / `PermissionRequest` / `PreCompact` の登録と空ディレクトリ 3 つの扱い（申し送り 5）
- マージ（人間が行う）

## 方法とステップ

### ステップ 1: 共通ライブラリと足場（0027）

**1-1 読み込み行**（`i0009-36`）。順序を守る。

1. `assets/script.template.sh` の `__ss_load` を仕様（`20-common-step-shell-script`「読み込み行」）に合わせる: `FM_AVAILABLE` を設定する（読めたら 1・`nop` フォールバックで 0）／`fm_*` スタブの戻り値を **1 → 2** に直す（`i0009-16` の 3 状態）／ルート解決の 3 段目 `git rev-parse` の扱いを確定する（**ホットパスでは 1 段目・2 段目で必ず解決するので実行されない**が、`i0009-22` の「`git` を呼ばない」と読み手が矛盾を感じないよう、行にコメントは置けないため**仕様の解決順 3 の但し書きで説明済み**として残す）
2. `assets/test.template.sh` の同じ行を揃える
3. `grep -rl '^__ss_load() {'` で集めた残り 21 ファイルへ、雛形の当該行を**バイト一致で**配る
4. `SS-T05` を実装して通す（違うファイルを列挙して落ちること = 失敗ケースも確かめる）

**1-2 `hook-common.sh`**。実装の型を 11 本で統一する（0006 f4）: **`HOOK_DENY_ID` の代入 → lib の `source`（読み込み行）→ `hook_init`**。この順でなければ、読み込み行が `deny` ポリシーで出す `WFx09` が既定の `WF009` になる。

- `hook_read_input [設定パス...]`: stdin と**パスが stdin に依存しない副入力**（`scope-limits.json` / `logs/review-state.json` / `logs/merge-state.json`）を **1 回の `jq`** で読む。存在するものだけ `--rawfile <名前> <パス>`、無いものは `--argjson <名前> null`（存在確認は `[ -f ]`。fork しない）。`jq` の中で `fromjson? // null` に通し、結果で `HC_<名前>_STATE`（`ok` / `missing` / `broken`）を立てる
- `hook_read_state <パス>...`: `session_id` に依存する副入力（`approvals.json` / `entry.json`）を **1 回の `jq`** で読む。要るフックだけが呼ぶ
- `hc_append_jsonl` / `hc_json_write` / `hc_lock` / `hc_unlock`: §1 の契約の表どおり。**切り詰め（4 KB / `note` と `target` で 1 KB）は `hc_append_jsonl` が行い呼び手は切り詰めない**。**2 秒と 60 秒は `hc_lock` が持ち呼び手は指定しない**。`hc_lock` は取得を試みる前に既存ロックの作成時刻を見て 60 秒より古ければ `rmdir` して強制解放し、実行ログに 1 行残す（`i0009-60`）
- ロックの作成時刻は `find <dir> -maxdepth 0 -mmin +1` で判定する。**`hc_lock` はホットパスではない**（`post-push-usage-report` / `workflow-diff-check` などの案内側だけが使う）ので `find` の fork は上限に触れない。Windows の Git Bash での挙動は 0027 で実測して作業ログに残す

**1-3 `scope.sh`**。

- `scope_load [type]` / `scope_load_approvals` から**パス引数を削る**（`i0009-48`）。`HC_*` を読んで `SC_*` に詰め替えるだけにし、`HC_<名前>_STATE` を `SC_ERROR` と戻り値 2 に写す
- `scope_load_ticket <ticket.md>` の戻り値を **0 / 1 / 2** の 3 状態に分ける（`i0009-16`）
- `_SC_WEB_CMDS` を足し、`scope_classify` に **`web` の 3 段判定**を実装する（`i0009-56`）: (1) 送信側オプション → `WF206`、(2) 出力先オプション → 出力先パスを `SC_TARGETS[]` に入れて `WF205` の判定へ、(3) 残りが `web`。**出力先は `cmdpos_args` の引数列を先頭から走査**して取り、`://` を含む語は URL として除く（`i0009-57`）
- `fm_*` の呼び出しから **`|| true` を除き `|| rc=$?` に**、`local` と代入を 2 行に分ける（`i0009-35`）
- `hook-test` の判定を `build-test` と `provided` より**先**に置く（§8）

**1-4 `config` 3 ファイル**。`blocked-commands.txt`（初期値 `chmod` の 1 行）・`entry-skills.txt`・`model-aliases.txt` を新規作成する。**`.claude/hooks/config/**` は `common.confirm` なので 1 ファイルにつき WF203 の確認が出る**（フック未登録の段では出ないが、⓪ 以降に作ると出る）。**3 ファイルとも ⓪ より前に作る**。

**1-5 `block-chmod` 1 本**とそのテスト。⓪ で使う。

**1-6 `.claude/rules/markdown-docs.md`**。参照が解決しない状態を解消する。実体を作るか参照を消すかは 0027 で判断し、作業ログに根拠を残す。

### ステップ 2: ⓪ T6 の先行確認（0028）

1. AI が `settings.json` に貼る JSON 1 行分を提示する（**ラッパー無しの素の `command`**）:
   `{"matcher": "Bash|PowerShell", "hooks": [{"type": "command", "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/20-PreToolUse/block-chmod.sh\""}]}`
2. **登録前に人間がバックアップ**を取る（`.claude/settings.json` の登録前の版を手元にコピー）
3. 人間が登録する。AI は登録後の `settings.json` を `commit.sh` でコミットする（WF203 の確認は人間が承認）
4. **新しいセッション**で `chmod +x <適当なファイル>` を試し、`permissionDecision: "deny"` + 終了 0 で実際に拒否されるかを見る。あわせて `logs/hooks/decisions.jsonl` に記録が残るかを見る
5. **効いた場合**: §3 の終了方式が確定。0030 以降はラッパー付きで進む
6. **効かなかった場合**: `exit 2` + stderr へ切り替える。影響は `block-chmod` の出力・§1 の登録ラッパー・`hook_deny` / `hook_ask` の実装・拒否側 5 本すべて。**このとき影響を受ける本体は 1 本（`block-chmod`）だけ**で、手戻りは `hook-common.sh` の出力ヘルパの書き換えに閉じる。仕様（§3）との食い違いは作業ログ「仕様からの逸脱」に書き、0032 が書き戻しの要否を決める
7. **ロックアウトが起きた場合**: `WORKFLOW_BLOCK_CHMOD_ENFORCE=0` の**新しいセッション**で再開する（環境変数はセッション開始時に読まれる。§4）。ラッパーを付けていないので環境変数で必ず戻れる

### ステップ 3: 案内側 6 本（0029）

`session-start` / `workflow-diff-check` / `post-push-compact-prompt` / `post-push-usage-report` / `subagent-start-check` / `subagent-stop-check` と各テスト。0006 f5 の「重い 4 本と軽い 7 本」を、**案内側 / 拒否側の区切りの内側で**満たす（重い 4 本のうち `session-start` と `post-push-usage-report` がここに、`workflow-guard` と `workflow-state-guard` が 0030 に入る）。

- 案内側は**ラッパー無し**（失敗は通す。§3）
- `session-start` は `boundary.sh status --offline`（3/3・未実装）が無ければ**何も出さずに終了 0**。この経路を実装し、依存する 8 件のテスト観点（`SE-T01`〜`04`・`07`〜`09`・`WE-T10` と `SE-T05` / `SE-T06` の前半）は**書かずに #10 へ送る**（申し送り 1）
- `post-push-usage-report` は `--accumulate` と既定の両方で **`hc_lock usage-<branch>`** を取ってから加算する（`i0009-61`）。時刻の変換は自前の暦計算（Windows の jq 1.6 に `strptime` が無い）
- `subagent-start-check` は PreToolUse `Agent`（WF801 の `systemMessage` + `additionalContext` の 2 経路・WF803 の background 警告）と SubagentStart（要点の注入）の**両方**に登録される 1 本
- `subagent-stop-check` は PostToolUse `Agent` で `tool_response.status`（`completed` / `async_launched`）で分岐し、`agentId`（**camelCase**）を読む

### ステップ 4: 拒否側の残り 4 本（0030）

`workflow-entry` / `workflow-state-guard` / `block-direct-git` / `workflow-guard` と各テスト。⓪ で確定した終了方式で書く。

- **ホットパス 5 本の `jq` の回数を実装で固定する**: `block-chmod` / `block-direct-git` / `workflow-state-guard` = **1 回**、`workflow-guard` / `workflow-entry` = **2 回**。`test-lib.sh` の `make_counting_path` で数え、`HK-T19` で固定する
- **`git` / `date` / `sed` / `find` をホットパスで呼ばない**。パス照合・コマンド分割は純 bash
- **作業ツリーの解決**（`i0009-55`）: `cwd` が `HOOK_ROOT` と異なるとき、`cwd` から上向きに `.claude` を持つディレクトリを探す（`[ -d ]` の繰り返し。fork ゼロ）。見つかればそれ、無ければ `HOOK_ROOT`。スクリプトの置き場は常に `HOOK_ROOT`、`logs/` と `wip/` は作業ツリー側
- **置き場の削除**（`i0009-59`）: 正規化した元パスの前方一致で、置き場のディレクトリ自身と祖先（`wip/10_tickets` / `wip`）を拾う。`rm -rf wip/tmp` と `rm -rf logs` は通す

### ステップ 5: 段階登録とフェーズ 4c の実測（0031）

**5-1 段階登録**（⓪ の 1 行は既に入っているので、残り 16 行を 2 段で）:

| 段 | 行数 | 中身 | 直後に確かめること |
|---|---|---|---|
| ⓪（0028 で完了） | 1 | `block-chmod`（ラッパー無し） | **T6** |
| ① 記録・案内側 | **12** | SessionStart 1 / UserPromptSubmit 1 / PreToolUse `Skill` 1 / **PreToolUse `Agent`（`subagent-start-check`）1** / PostToolUse 4 / SubagentStart 1 / SubagentStop 2 / Stop 1 | **T9**（`systemMessage` の表示）・**T4**（`SubagentStart` と `model` / `agent_id`）・`tool_response.status`・`agent_type`・**T7**（`tool_response` の終了コードのフィールド名）・**T2**（親子の `session_id`） |
| ② 拒否側 | 4 + 1 | PreToolUse の `workflow-entry` / `workflow-state-guard` / `block-direct-git` / `workflow-guard` を fail-closed ラッパー付きで足し、**⓪ の `block-chmod` にもラッパーを付ける**（1 行の書き換え） | **HK-T09**（ラッパー）・**worktree**・**T8**（`frontmatter.sh` 不在）・**ホットパス 5 本の実行時間** |

- 段ごとに**新しいセッション**で軽い操作（Read → Skill 宣言 → Edit → `commit.sh`）を通し、想定外の deny が出ないことを確かめる
- 各段の登録後に AI が `commit.sh .claude/settings.json` でコミットする

**5-2 フェーズ 4c の実測 8 項目**（`T1` は `i0009-43` で公式解決済みのため**含めない**）:

| # | 項目 | 確かめ方 | 外れたときの影響 |
|---|---|---|---|
| T2 | サブエージェント内の `session_id` が親と同じか | `decisions.jsonl` の `session_id` を親子で比較 | `hook_read_state` が読むセッション状態の置き場 |
| T3 | `claude -p` を入力から判別できるか / `defer` の実在 | ヘッドレス実行時の入力（`permission_mode` 等）を `decisions.jsonl` に記録して比較 | §10 のヘッドレス判定 |
| T4 | `SubagentStart` と `model` / `agent_id` の実在 | ① の後にサブエージェントを 1 つ起動し `logs/` を見る | `subagent-start-check` の SubagentStart 登録 |
| T6 | deny が `permissionDecision` + 終了 0 で効くか | **⓪ で確認済み**（0028） | 拒否側 5 本 + ラッパー |
| T7 | `tool_response` の終了コードのフィールド名 | `post-push-*` が読む値を `logs/` に落として実物を見る。**公式では「存在しない」と分かっているが受け入れ条件 5 が実物の確認を求める**ので省かない | `push-detect.sh` の判定 |
| T8 | `frontmatter.sh` 不在時の案内側の挙動 | `frontmatter.sh` を一時的に `mv`（宣言済みの `.claude/skills/20-common-step-shell-script/**` の内側）して見る。`chmod` は `block-chmod` が WF501 で拒否し Windows では読み取り不可にできない | `scope.sh` の `nop` ポリシー |
| T9 | **`systemMessage` が PreToolUse でユーザーに実際に表示されるか** | ① の後、`executor` と違うモデルでサブエージェントを 1 つ起動し、警告がその場で表示されるかを見る。**登録表を 17 行に保つ唯一の支え**（外れたら 16 行に戻す） | §1 の行数・`subagent-start-check` の 2 経路 |
| — | `Agent` の `tool_response.status` が既定で `async_launched` か | 同じ起動で `logs/` の `tool_response` を見る | `subagent-stop-check` の分岐 |
| — | `agent_type` の実物 | 同じ起動で `logs/` の値を見る | 受け入れ条件 5 |
| — | **worktree で worktree 側のチケットを見るか** | ② の後に `git worktree add` して Claude をそこへ移し、worktree 側の `10_doing/` にチケットを置いて `workflow-guard` が判定するかを見る（本流を見ていれば「0 枚 → 許可」で何も起きない） | §2 の作業ツリーの解決 |
| — | **ホットパス 5 本の実行時間** | ② の後、`logs/sh/` の所要時間を見る。あわせて `post-push-usage-report` の実行時間を測り、**`hc_lock` の陳腐化 60 秒が妥当か**を確かめる | §1 の 1 秒目安・`i0009-60` の閾値 |

**5-3 最終検査**: `HK-T01`（17 行のフィクスチャと `settings.json` の行単位の照合）と `run-tests.sh --ids` の**全件**。結果を実装結果報告に記録する（受け入れ条件 2）。全件は約 5 分かかるのでバックグラウンドでファイルに出す。

### ステップ 6: フィードバック計画（0032）

実測の結果と「仕様からの逸脱」を棚卸しし、フェーズ 6（書き戻し）の要否を決める。**実装中に生まれた決定は DDR になっていない**（実装フェーズは `.claude/docs/**` に書けない）ので、0032 が DDR 化の対象を列挙する。

### ヘッドレス実行の帰結

- **⓪ と ① と ② の登録は対話セッションでのみ可能**。`settings.json` は `common.confirm` で、ヘッドレスでは WF203 が deny になる（§10）
- `config/` 3 ファイルの新規作成も同じ理由で対話セッションが要る
- T3 の実測は逆に**ヘッドレス実行そのものが対象**なので、`claude -p` を 1 回走らせて `decisions.jsonl` を見る

### 許可範囲（やってよいこと）

実装チケット 5 枚（0027〜0031）の宣言:

```yaml
allow:
  write: [".claude/hooks/**", ".claude/skills/**", ".claude/rules/**", ".claude/settings.json"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
```

- `types.ai-asset-implementation.allow` の内側で絞っている（`.claude/agents/**` `.claude/evals/**` `CLAUDE.md` `.gitattributes` は今回触らないので落とす）
- **`.claude/settings.json` を `write` に残すのは、登録後のコミットの対象になるため**。書き換えるのは人間で、AI が Edit / Write で触ることはしない
- `.claude/docs/**` は `types` の `deny` にあり、宣言に書いても通らない
- 0032（`feedback-plan`）は `ops: ["read", "remote-read"]` のみ

## 検証

| # | 受け入れ条件（issue #9） | この計画が満たす形 | 検証 |
|---|---|---|---|
| 1 | フック本体 11 本が仕様どおり動きテストが通る | 0027（1 本）+ 0029（6 本）+ 0030（4 本）+ 各テスト | `run-tests.sh --ids` の全件（0031。`boundary.sh` 依存の 10 件を除く） |
| 2 | `settings.json` への登録手順と登録後の全件・HK-T01 | 0028（⓪）+ 0031（①②）。手順は本計画のステップ 2・5-1 | HK-T01 と全件の結果を実装結果報告に記録 |
| 3 | TBD T1〜T4 の検証結果が仕様に反映され DDR に残る | 0031 の実測 → 0032 が書き戻しの要否を決定 → フェーズ 6 | 共通仕様 §12 の該当行の消滅（フェーズ 6） |
| 4 | `HOOK_DENY_ID` の既定と 2 枚以上をテストで固定 | 実装の型（`HOOK_DENY_ID` の代入 → source → `hook_init`）を 11 本で統一（0027 で確立） | `WG-T*`（WF207）と登録ラッパーの `WFx09`（HK-T09） |
| 5 | `tool_response` / `agent_type` / `web` の強制 / `defer` | `web` は 0027（`scope.sh`）で実装。残りは 0031 の実測 | 実測表（ステップ 5-2）+ フェーズ 6 の書き戻し |
| 6 | 仕様との食い違いを書き戻し DDR に残す | 各チケットの作業ログ「仕様からの逸脱」→ 0032 の棚卸し | 0032 の棚卸し表 |

**この計画自身の検証**: 計画書 `.md` と HTML ビューが揃い `check-html.sh` が OK を返すこと。チケット 6 枚が `00_todo/` にあり、`predecessors` が上表の依存と一致すること。

## チケット

| 番号 | 種類 | 内容 | 先行 | 人間レビュー | 敵対的レビュー |
|---|---|---|---|---|---|
| 0027 | `ai-asset-implementation` | lib 5 本の改修 / `config` 3 ファイル / 読み込み行 23 ファイル / `block-chmod` / `.claude/rules/markdown-docs.md` | なし | 要 | 要 |
| 0028 | `ai-asset-implementation` | ⓪ `block-chmod` 単独登録（人間）と **T6 の確認**。終了方式の確定 | 0027 | 要 | 不要（判定は 1 つ・実測が根拠） |
| 0029 | `ai-asset-implementation` | 案内側 6 本とテスト | 0027 | 要 | 要 |
| 0030 | `ai-asset-implementation` | 拒否側の残り 4 本とテスト | 0028, 0029 | 要 | 要 |
| 0031 | `ai-asset-implementation` | 段階登録 ①②（人間）+ **4c の実測 8 項目** + HK-T01 + 全件 | 0030 | 要 | 要 |
| 0032 | `feedback-plan` | 実測結果と逸脱の棚卸し、フェーズ 6 の要否 | 0027〜0031 | 要 | 不要 |

実行者は全体計画の方針（全種類メインエージェント。理由は※1 — サブエージェントの起動テンプレートが 3/3 で未実装、かつこの issue が実行者を検査するフックを作るため）に従う。人間レビューは承認④により opus の敵対的自己レビューで代替する。

- **`work-defaults.md` の既定との差分**: `ai-asset-implementation` の既定は「サブエージェント（opus）/ 人間レビュー要 / 敵対的レビュー要」。実行者だけがメインエージェントに変わる（全体計画の※1）。0028 は「中核を含まず判定が 1 つで実測が根拠」なので敵対的レビューを**不要**に下げる（`work-defaults.md` の調整条件「中核を含まず機械テストが全通過なら軽くしてよい」の趣旨に沿う）

## リスクと復旧

| リスク | 影響 | 対処 |
|---|---|---|
| **⓪ でロックアウトする**（`block-chmod` の判定が広すぎて全 Bash が deny） | 作業不能 | ラッパーを付けないので `WORKFLOW_BLOCK_CHMOD_ENFORCE=0` の新セッションで必ず戻れる。加えて登録前に `bash .claude/hooks/20-PreToolUse/block-chmod.sh < wip/tmp/input.json` を手で通す |
| **② でロックアウトする**（拒否側 4 本 + ラッパー） | 作業不能。**ラッパーは環境変数を見ないので `WFx09` が出たら環境変数では戻らない** | (1) 登録前のバックアップからの復元（人間）が唯一の経路。(2) 登録前に 4 本とも単体で `bash <script> < <入力 JSON>` を通し、`bash -n` と `shellcheck` を通す。(3) 1 行ずつ足して各行の後に軽い操作を通す |
| **T6 が外れる**（`permissionDecision` + 終了 0 が効かない） | `exit 2` + stderr への切り替え | ⓪ で 1 本だけ書いた段で分かるので、手戻りは `hook-common.sh` の出力ヘルパと `block-chmod` に閉じる。仕様との食い違いは 0032 → フェーズ 6 |
| **T9 が外れる**（`systemMessage` が表示されない） | 登録表を 16 行へ戻す。`subagent-start-check` の PreToolUse `Agent` 登録が意味を失う | ① の後に確かめる。外れたら HK-T01 のフィクスチャを 16 行に直し、§1 の書き戻しをフェーズ 6 に送る |
| **worktree の実測で `cwd` の上向き探索が効かない** | §2 の作業ツリーの解決が成立せず、worktree でフックが無効のまま | ② の後に確かめる。効かなければ `WORKFLOW_ENFORCE=0` の運用（worktree では機構を使わない）に倒し、フェーズ 6 で §2 を書き直す |
| **`hc_lock` の 60 秒が短すぎる**（正常な処理が奪われる） | 使用量の集計が壊れる | 0031 で `post-push-usage-report` の実行時間を実測し、閾値の妥当性を作業ログに残す。外れたら値を変えて `HK-T20` の期待値も直す |
| **読み込み行の一斉置換で 1 本でも取りこぼす** | `SS-T05` が落ち続ける | `grep -rl` で集めた一覧をチケットに固定し、置換後に**もう一度 `grep` して差分 0 を確かめる**（0024・0026 の教訓「`applied=N/N` は内容を保証しない」） |
| **`config/` 3 ファイルの作成で WF203 が連発する** | 対話が止まる | ⓪ より前（フック未登録の段）に 3 ファイルとも作る |
| **フェーズ 7 が通らない**（`workflow-state-guard` が draft 解除と完了移動を拒否） | マージ前作業で詰む | 第 1 案（`WORKFLOW_STATE_GUARD_ENFORCE=0` の新セッション）で通す。フェーズ 7 の直前に人間と最終確認 |
| **全件テストが約 5 分かかる** | 反復が遅い | 0031 ではバックグラウンド実行でファイルに出す。個別チケットでは `--ids` で対象を絞る |

## スコープ外

- `.claude/docs/**` への書き戻し（フェーズ 6）と DDR の作成
- 提供コマンドの実体の変更（`push.sh` の 1 枚目依存は #10 への申し送り 2）
- `boundary.sh` / `finalize.sh` の実装と、それに依存する 10 件のテスト観点（#10 への申し送り 1）
- `scope-limits.json` の実体変更（変更不要と確認した）
- `PostToolUseFailure` / `PermissionRequest` / `PreCompact` と空ディレクトリ 3 つ（#10 への申し送り 5）
- `WebFetch` / `WebSearch` の強制（§13 の意図的な緩和）
- マージ（人間）

## 保留した点 / 対象なし

| 項目 | 決める時期 |
|---|---|
| `.claude/rules/markdown-docs.md` を作るか参照を消すか | 0027（実装時に判断し作業ログに根拠を残す） |
| `hc_lock` の陳腐化 60 秒を変えるか | 0031 の実行時間の実測後 |
| 読み込み行の 3 段目（`git rev-parse`）を残すか外すか | 0027。**外すと相対パス起動かつ `CLAUDE_PROJECT_DIR` 無しの経路が解決不能になる**ので、既定は残す |
| フェーズ 6（書き戻し）の要否と範囲 | 0032（`feedback-plan`） |
| 実行者を既定のサブエージェントに戻す時期 | #10（3/3）の全体計画（申し送り 4） |
| フェーズ 7 を通す手の最終確認 | フェーズ 7 の直前（第 1 案を既定として確定済み） |

**対象なし**: `src/**` の変更（この issue はソフトウェアではなく AI アセットが対象）。
