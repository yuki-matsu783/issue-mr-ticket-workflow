---
type: report
title: 0007 調査結果 — 公式 hooks リファレンスとの照合・T5 の扱い・クォート付き git の判定
description: フック共通仕様 §2・§8・§12 が前提にしている入力・出力フィールド 8 項目を公式ドキュメントで確かめ、model フィールドの不在・defer の実在・tool_response の記載なし・matcher による web の強制可否を判定し、あわせて §12 T5 が #6 でどこまで解決したかと、クォートで割った git のサブコマンド判定の穴を確認した調査結果
tags: [report, investigation, issue-9]
keywords: [公式リファレンス, SubagentStart, model, agent_id, agent_type, defer, permissionDecision, tool_response, matcher, WebFetch, T5, PowerShell, cmdpos, git commit]
---

# 0007 調査結果 — 公式 hooks リファレンスとの照合・T5 の扱い・クォート付き git の判定

## サマリ

仕様が前提にしている 8 項目のうち **6 項目は公式ドキュメントと一致**し、**2 項目は相違**（記載が見つからなかった 2 項目は、2 巡目で原本を `curl` で落として読み直したところ**どちらも記載があった**）。相違は `subagent-start-check` の要である **`model` フィールド**で、公式は「`model` を受け取れるのは `SessionStart` フックだけ」と明記している。したがって WF801（実行者の不一致）を SubagentStart の入力から判定する設計は成立せず、仕様が用意していた縮退（PostToolUse `Agent` の `tool_input.model` と比較）を既定にする判断が要る。一方 `SubagentStart` イベント・`agent_id` / `agent_type`・`permissionDecision: "defer"` は実在が確認でき、matcher は tool 名の完全一致または正規表現なので **`WebFetch` / `WebSearch` を強制対象にできる**（D3 の判断材料）。`tool_response` には**終了コードのフィールドが無く**、そもそも `PostToolUse` は成功時にしか発火しない（失敗は `PostToolUseFailure`）ため、§12 T7 は実測を待たずに閉じられる。あわせて §12 **T5 は #6 が半分しか答えていない**ことが分かった（#6 が確かめたのは `tool_input` の同一性で、これは §12 が「確定済み」と断った側。T5 の問いである共通フィールド `session_id` / `cwd` / `permission_mode` は未回答）。この issue の登録直後に確かめる申し送りは有効で、確認対象を共通フィールドに差し替える。**`git 'commit'`（クォートで割ったサブコマンド）は `block-direct-git` を素通りする**（作業中チケットがあれば `workflow-guard` の WF204 が受け止めるが、チケットが 0 枚の窓では抜ける）。さらにレビューで、**`command` 型フックはタイムアウトで打ち切られてもツール呼び出しをブロックしない**（出力も破棄される）ことが分かった — §1 の fail-closed ラッパーが効かないフェイルクローズドの穴で、仕様に `timeout` の記述が無い。

- ◎良 3 件 / △注意 4 件 / ✕問題 2 件（f7 は R1 により ◎良 → △注意、f4 は 2 巡目レビュー S14 により △注意 → ✕問題）

### ◆特に見てほしい（判断に困っている）

- **f7 の訂正（R1）**: `command` 型フックは**タイムアウトで打ち切られてもツール呼び出しをブロックしない**（出力も破棄）。§1 の fail-closed ラッパーも `trap ERR` も効かず、仕様に `timeout` の記述が無い。**フェイルクローズドの穴**をどう塞ぐか（`timeout` の明示・ホットパスの実行時間の上限）を設計で決める必要がある。ただし既定は 600 秒（`workflow-entry` の UserPromptSubmit 登録だけ 30 秒）と分かったので、実害の大きさは小さい
- **f2**: `model` は `SubagentStart` の入力に含まれない（公式は `SessionStart` のみと明記）。`subagent-start-check` の WF801 は仕様の縮退案（PostToolUse `Agent` の `tool_input.model` とチケットの `executor` を事後に比較）へ切り替える必要がある。§12 T4 の「実在する」という前提を書き換える設計判断

### ◇承認が欲しい（方針は決めた）

- **f3**: `defer` は実在するが**機構では使わない**（`claude -p` のサブプロセス統合用で、対話セッションでは Claude Code が警告を出して無視する）。§12 T3 の「`defer` の採用は別途判断」に対する答えとして「採用しない」を仕様に書く
- **f5**: `WebFetch` / `WebSearch` は matcher に書ける（技術的な障害なし）。D3「`web` の強制の可否」は**強制する / しない**の方針判断だけが残る
- **f8**: T5 の未回答部分（共通フィールド `session_id` / `cwd` / `permission_mode`）を、この issue の登録直後に `decisions.jsonl` の `tool: PowerShell` の行で確認する（実装フェーズ 4c の検証項目に追加）
- **f9**: `git 'commit'` は bash 経路でも「特定できない」として拒否側に倒す（現状でも `workflow-guard` の WF204 で止まるが、メッセージが不適切でチケット 0 枚の窓では抜ける）（共通仕様 §7-9 の記述に合わせて `block-direct-git` の制御方式を補う）
- **f4**: `post-push-*` の成功判定を「PostToolUse に来た = 成功」に寄せる（`tool_response` から終了コードを読む現行方針は、そのフィールドが存在しないため成立しない）

### ・細かいレビューは不要（ほぼ確実）

- **f1**: `SubagentStart` の実在と `agent_id` / `agent_type`（仕様どおり）
- **f6**: 仕様に無いイベントが 26 種類ある（拡張の余地。この issue では扱わない）


## 確かめられなかったこと（この結果が言っていないこと）

- `SubagentStart` の**完全な入力スキーマ**（`Stop` / `SubagentStop` / `PostToolUse` は 2 巡目で原本から取得できた。f4 / 検証表 7）
- **`hooks.md` 原本の全文を読み切ってはいない**（316,963 バイト）。今回 `grep` で当たったのは PreToolUse decision control・Timeouts・PostToolUse / PostToolUseFailure input・Stop / SubagentStop input・共通入力フィールドの各節。他の節に機構へ効く記述が残っている可能性はある
- `permissionDecision: "deny"` + 終了 0 が**実機で**効くか（§12 T6）。公式は「`"deny"` prevents the tool call」「the JSON alone decides the outcome」と明記しており文書上は解決済み。フェーズ 4b の ②-1 は確認のためのスモークテスト
- ドキュメントのバージョンと実行中の Claude Code のバージョンの一致（公式ページに版の記載が無い）
- `git 'commit'` の実挙動（`cmdpos.sh` を実行して確かめてはいない。コードと `HK-T05` の期待値からの読み取り）

## 実施条件（読んだ対象）

- 公式: `https://code.claude.com/docs/en/hooks`（`https://docs.claude.com/en/docs/claude-code/hooks` から 301 リダイレクト）、`https://code.claude.com/docs/en/hooks.md`、`https://code.claude.com/docs/en/agent-sdk/hooks`（2026-09-02 取得）
- リポジトリ: `.claude/docs/10_spec/フック共通仕様.md` §2・§7・§8・§12、`.claude/hooks/lib/cmdpos.sh`、`.claude/hooks/lib/tests/test_cmdpos.sh`
- #6 の履歴: コミット `bb2a527`（`wip/30_reports/0003-investigation.md` の Q3 = T5 の節）
- **2 巡目の追加取得**: `curl -sS -L -o wip/tmp/hooks.md https://code.claude.com/docs/en/hooks.md`（316,963 バイト）で原本を落とし、`grep` / `sed` で該当節を直接読んだ。WebFetch は長いページを**小型モデルの要約経由**で返すため原文の逐語引用に使えない（同じ URL で 2 回取得すると表の文言が変わる）ことが分かったため
- 実行はしていない（Web 閲覧・`curl` による取得と `git show` / `grep` のみ）

## 実施した内容と結果

### f1. `SubagentStart` の実在と `agent_id` / `agent_type` は仕様どおり ◎良

根拠: 公式 hooks リファレンス（イベント一覧・matcher 表）、Agent SDK hooks ドキュメント

- `SubagentStart` は「When a subagent is spawned」として実在し、**matcher は agent type**（`general-purpose`・`Explore`・`Plan`・カスタム名・`^my-plugin:reviewer$` のようなプラグイン名）に対して評価される。§1 の登録表は matcher 無し（= 全 source）なので問題ない
- `agent_id` / `agent_type` は「サブエージェントの中でフックが発火したときに入る」共通フィールドで、**Python SDK では `SubagentStart` と `SubagentStop` で必須フィールド**と明記されている（`PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `PermissionRequest` では任意）
- `agent_type` の値は「エージェント名（例: `"Explore"` や `"security-reviewer"`）」。`subagent-stop-check` が読む値の形が確定した（issue #9 の受け入れ条件 5 の `agent_type` の項目）
- 実測への依存: 無し（値の実物はフェーズ 4c で確認するが、フィールドの実在と意味は確定）

結論: `subagent-start-check` / `subagent-stop-check` の登録と入力の前提は成立する。§12 T4 のうち「`SubagentStart` イベントの実在」「`agent_id`」は**確認済み**として消せる。

### f2. `model` は `SubagentStart` の入力に含まれない（公式は `SessionStart` のみ）✕問題

根拠: 公式 hooks リファレンス「Only `SessionStart` hooks can receive a `model` field, and Claude Code doesn't always include it.」

- 仕様（共通仕様 §2）は「`agent_id` / `agent_type` / `model`（SubagentStart。`model` が無い版では実行者の比較を行わない）」とし、`subagent-start-check` の制御方式 4 は入力の `model` とチケットの `executor` を比較して WF801 を出す設計
- 公式は **`model` を受け取れるのは `SessionStart` だけ**と明記し、しかも「常に含まれるとは限らない」と断っている。SDK 側のドキュメントにも `SubagentStart` の `model` は現れない
- したがって `subagent-start-check` の WF801 は**入力からは判定できない**見込みが高い。仕様が用意している縮退（「実行者の不一致は `subagent-stop-check`（PostToolUse `Agent`）が `tool_input.model` と対象チケットの `executor` を比較して事後に WF801 を通知する」）が本線になる
- なお `hook-common.sh` の `hook_read_input` は `.tool_input.model // .model` を読むので、PostToolUse `Agent` の `tool_input.model` はそのまま `HOOK_MODEL` に入る（実装の準備はできている）
- 実測への依存: **あり**（フェーズ 4c で `SubagentStart` の実物に `model` が無いことを確かめる）。ただし設計判断は公式の記述だけで決められる

結論: §12 T4 の前提「`SubagentStart` イベントと `model` / `agent_id` フィールドの実在」は、**`model` について外れる**。案は 3 つ: (a) WF801 を PostToolUse `Agent` 経由の事後通知に一本化する（仕様の縮退案）/ (b) SubagentStart では `model` があれば使い、無ければ通知しない（現行の既定）/ **(c) PreToolUse `Agent` で `tool_input.model` と `executor` を比較する**（`workflow-guard` は既に `Agent` を matcher に持ち、`hook_read_input` は `tool_input.model` と `tool_input.subagent_type` を読む。起動**前**に気づけるので WF801 本来の性質が保てる）。
**どの案にも共通の限界**: `Agent` ツールの `model` は任意引数で、省略時は「エージェント定義のモデル」が使われる。省略された起動では `tool_input.model` が空になり、比較そのものができない（`hook_read_input` の `.tool_input.model // .model` は空文字を返し、`subagent-start-check` の制御方式 4 も「`model` が特定でき」を条件にしているため何もしない）。この限界を仕様に明記したうえで、(c) を本線に (b) を残すのが妥当。
**(c) を採るときの波及**（2 巡目レビュー S6）: (i) §1 の登録表が **16 行 → 17 行**になり、HK-T01（登録表との行単位の照合）・全体計画の段階登録の行数割り当て（① 11 行 / ② 5 行）・受け入れ条件 2 が連動する。(ii) WF801 は「通知」だが、§3 の制御方式表に **PreToolUse で通知（additionalContext）を出す行が無い**。PreToolUse が `additionalContext` を受け付けることは公式で確認済み（`hooks.md` L1747「String added to Claude's context alongside the tool result. Ignored when `permissionDecision` is `"defer"`」）なので、**§3 に 1 行足せば (c) は成立する**。

### f3. `permissionDecision: "defer"` は実在するが、機構では使わない ◎良

根拠: Agent SDK hooks ドキュメント「For `PreToolUse` hooks, this is where you set `permissionDecision` (`"allow"`, `"deny"`, `"ask"`, or `"defer"`)... If you return `"defer"`, the query ends so you can resume it later.」「`deny` takes priority over `defer`, which takes priority over `ask`, which takes priority over `allow`.」

- 値の集合は **`allow` / `deny` / `ask` / `defer`** の 4 つで確定。優先順位も明文化されている（`deny` > `defer` > `ask` > `allow`）
- `defer` は「クエリを終了して後で再開する」ためのもので、SDK が入力を集め直す用途。フックが「判断を保留する」意味ではなく、**機構が使う場面は無い**（拒否は `deny`、確認は `ask`、ヘッドレスでは `ask` を `deny` に置き換える現行方針で足りる）
- 補足: `updatedInput` を `defer` と併用すると入力が捨てられる（公式が明示）。機構は `updatedInput` を使わないので影響なし
- あわせて確認: `last_assistant_message` は **Stop / SubagentStop のイベント固有フィールド**として明記されている（`hooks.md` L2470「In addition to the common input fields, Stop hooks receive `stop_hook_active`, `last_assistant_message`, `background_tasks`, and `session_crons`.」・L2325 の SubagentStop 同文）。「共通入力フィールド」ではないので 2 巡目レビュー S12 で訂正した。transcript を読まずに最終応答を得られるため、`post-push-usage-report` の設計に効く
- **hooks リファレンス原本による裏付け**（2 巡目レビュー S1 の検証で確定。当初 SDK ページの 1 文だけを根拠にしていた）: `hooks.md` L1744 の `permissionDecision` の行は「`"defer"` exits gracefully so the tool can be resumed later」、専用節 L1783 は「`"defer"` is for integrations that run `claude -p` as a subprocess and read its JSON output… **Claude Code honors this value only in non-interactive mode with the `-p` flag. In interactive sessions it logs a warning and ignores the hook result.**」
- 実測への依存: 無し

結論: §12 T3 の「`defer` の採用は別途判断」に対する答えは **「採用しない」**。理由は「用途が違う（`claude -p` のサブプロセス統合用）」に加えて、**対話セッションでは Claude Code が警告を出して無視する**（`hooks.md` L1783）こと。この 2 点を仕様に 1 行書いて TBD を閉じられる。

### f4. `tool_response` に終了コードのフィールドは無く、PostToolUse は成功時にしか発火しない ✕問題

根拠: 公式 hooks リファレンス原本 `hooks.md` L1928（PostToolUse input）・L1990（Bash の出力の形）・L2034〜2068（PostToolUseFailure input）

- **1 巡目・2 巡目の当初の判定「記載なし」は誤り**だった（2 巡目レビュー S15）。WebFetch が長いページを要約で打ち切るために該当節に到達できていなかっただけで、`curl` で原本を落として `grep` すると記載がある
- **PostToolUse は成功時にしか発火しない**: 「`PostToolUse` hooks fire after a tool has already **executed successfully**.」（L1930）。失敗は別イベント `PostToolUseFailure` に流れる
- **`tool_response` に終了コードは無い**: 「`Bash` returns an object with `stdout`, `stderr`, `interrupted`, and `isImage` fields.」（L1990）。入力例の `tool_response` も `{filePath, success}`（Write の例）で、`exit_code` 系のフィールドは登場しない
- **失敗側には終了コードがある**: `PostToolUseFailure` の入力は `error`（文字列）・`is_interrupt`・`duration_ms` で、「For Bash and PowerShell, a command that ran and exited produces a first line `Exit code N`」（L2066）。ただし「treat the rest of the string as display text, not a stable format」と釘が刺されている
- したがって仕様の現行方針「`exit_code` / `exitCode` / `returnCode` / `code` を順に読み、**どれも無ければ 0（成功）とみなす**」は、**常に「無し → 0」に落ちる**。PostToolUse が成功時にしか来ない以上この既定自体は結果的に正しいが、「終了コードを読んで成功を確かめている」という設計の建て付けが実態と違う
- 実測への依存: **無し**（§12 T7 は原本の記載で閉じられる。フェーズ 4c で確かめるのは実物の 1 例だけでよい）

結論: §12 T7 は「実測待ち」から**「終了コードのフィールドは存在しない」**に書き換える。`post-push-*` の成功判定は (a) 「PostToolUse に来た = 成功」を根拠にする（追加の読み取り不要）か、(b) 失敗を捕まえたいなら `PostToolUseFailure` を登録して `error` の 1 行目 `Exit code N` を読む、のどちらか。(a) が最小で、§1 の登録表を増やさずに済む。

### f5. matcher は tool 名の完全一致または正規表現で、`WebFetch` / `WebSearch` を対象にできる ◎良

根拠: 公式 hooks リファレンスの matcher 評価表

| matcher の値 | 評価 |
|---|---|
| `"*"` / `""` / 省略 | すべてに一致 |
| 英数字・`_`・`-`・空白・`,`・`\|` だけ | 完全一致、または `\|` / `,` 区切りの完全一致リスト |
| それ以外の文字を含む | JavaScript の正規表現（アンカーなし） |

- `PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `PermissionRequest` / `PermissionDenied` は **tool 名**に対して評価される。したがって `WebFetch|WebSearch` と書けば強制対象にできる（技術的な障害は無い）
- §1 の登録表の matcher も、この規則で問題なく評価される: `Edit|Write|MultiEdit|NotebookEdit|Bash|PowerShell` は完全一致リスト、`Edit|Write|...|mcp__.*` は `.` を含むので正規表現（アンカーなし）として評価される
- 実測への依存: 無し

結論: D3「`WebFetch` / `WebSearch` を matcher に加えて `web` を強制するか」は**技術的には可能**で、残るのは方針判断（外部への問い合わせを機構で強制するか、宣言の記録に留めるか）だけ。設計で決める。

### f6. 仕様に無いフックイベントが 26 種類ある △注意

根拠: 公式 hooks リファレンスのイベント一覧

- 公式のイベント一覧は **33 種類**あり、仕様（§1）が扱う 7 イベント（SessionStart / UserPromptSubmit / PreToolUse / PostToolUse / SubagentStart / SubagentStop / Stop）を除くと **26 種類**が未使用。機構に関係しそうなものを挙げると `PostToolUseFailure` / `PostToolBatch` / `PreCompact` / `PostCompact` / `PreModelSwitch` / `PostModelSwitch` / `PermissionRequest` / `PermissionDenied` / `Notification` / `SessionEnd` など
- このうち機構に効きそうなのは 2 つ:
  - **`PostToolUseFailure`**（ツール呼び出しが失敗したとき）: `post-push-*` が「終了コード 0 か」を `tool_response` から読む代わりに、失敗はこのイベントで分けられる可能性がある
  - **`PermissionRequest` / `PermissionDenied`**: 機構のディレクトリには `21-PermissionRequest/` が用意されているが、§1 の登録表にフックは無い。空のまま残るディレクトリは **3 つ**（`01-PreCompact/`・`11-Stop/`・`21-PermissionRequest/`。いずれも `.gitkeep` のみ）。`11-Stop/` が空になるのは、Stop に登録される `post-push-usage-report` が §1 の置き場規約により `22-PostToolUse/` に置かれるためで、他の 2 つ（イベント自体を使わない）とは種類が違う
- 実測への依存: 無し

結論: この issue では**扱わない**（issue #9 のスコープは 11 本）。`PostToolUseFailure` の活用と `21-PermissionRequest/` の空ディレクトリの扱いは、3/3 または別 issue の検討事項として残す。

### f7. `exit 2` は JSON より優先するが、タイムアウトでは fail-open になる △注意

根拠: 公式 hooks リファレンス「exit 2 means a blocking error. On events that can block, exit 2 blocks whether or not you print JSON: even a JSON `permissionDecision` of `"allow"` can't override it.」「`PreToolUse` | Yes | Blocks the tool call」「On `PreToolUse`, a hook canceled at its timeout blocks the tool call.」

- `exit 2` は JSON 出力より強く、`PreToolUse` ではツール呼び出しをブロックする。公式の例（`block-rm.sh`）は `permissionDecision: "deny"` の JSON を返す形で、**JSON による deny も正規の経路**として示されている
- **公式は JSON deny の効果を明記している**（2 巡目レビュー S2。当初「例示にとどまる」と書いたのは誤り）: PreToolUse decision control の表（`hooks.md` L1744）に「`"deny"` prevents the tool call.」、同 L1751 に「A hook that blocks by exiting 2 routes the same way as `"deny"`: Claude sees the stderr message as the denial reason.」（= `exit 2` は deny と同じ経路に流れるだけで、deny の方が基本形）。さらに JSON 出力の節に「Claude Code ignores the exit code and the JSON alone decides the outcome: Each field the event supports is honored, including `permissionDecision`, `additionalContext`, `updatedInput`, and `systemMessage`」。したがって §12 T6 は**文書上は解決**しており、②-1 の実測は「設計の分岐点」ではなく**スモークテスト**
- **重要な訂正（レビュー指摘 R1）**: 当初「タイムアウトで打ち切られるとブロックされる」と書いたが、公式の原文は逆で、**`command` / `http` / `mcp_tool` のフックはタイムアウトで打ち切られてもツール呼び出しをブロックしない**（出力は破棄される）。ブロックするのは Agent SDK のコールバックフックだけ。原文: 「**Apart from a command hook you run with `async: true`,** Claude Code cancels a `command`, `http`, or `mcp_tool` hook that reaches its `timeout`, discarding the hook's output, so on most events a timed-out hook renders no decision.」（**限定句を落とさない**: 2 巡目レビュー S3 で、当初の転記が冒頭の除外条件を省いていたことが分かった）「A timed-out `command`, `http`, or `mcp_tool` hook doesn't block the tool call. The call continues through the normal permission flow, so don't count on a stalled hook to act as a gate.」
- 本機構は `settings.json` に `type: "command"` で登録するので**ブロックしない側**。§1 の fail-closed ラッパー（`bash ... || printf deny`）も §3 の `trap ERR` も、打ち切られた場合には効かない（出力ごと破棄される）。**フェイルクローズドの穴**であり、仕様には `timeout` の記述が 1 行も無い
- **`timeout` の既定値も公式にある**（S3）: 「Defaults: 600 for `command`, `http`, and `mcp_tool`; 30 for `prompt`; 60 for `agent`. Claude Code lowers the `command`, `http`, and `mcp_tool` default to 30 on `UserPromptSubmit`, `PreModelSwitch`, and `PostModelSwitch`, and to 10 on `MessageDisplay`.」つまり **`workflow-entry` の UserPromptSubmit 登録だけ既定 30 秒**、残りは 600 秒。フックが 600 秒かかる状況は現実には起こりにくく、**穴の実害は小さい**（ただし `async: true` のフックは打ち切られない点と合わせて、設計で明示する価値はある）
- 実測への依存: **あり**（T6 の最終確認はフェーズ 4b の ②-1）

結論: 段階登録 ②-1 で T6 を確かめる段取りはそのままでよいが、**位置づけはスモークテストに下がる**（公式が JSON deny の効果を明記しているため）。万一外れた場合の縮退（`exit 2` + stderr）も公式が保証しており、手戻りの内容は「11 本の終了方式と §1 のラッパーの書き換え」に限られる。**あわせてタイムアウト時の fail-open に対処が要る**（各フックの `timeout` を明示するか、ホットパスの実行時間の上限を仕様に置く）。

### f8. §12 T5 は #6 が半分しか答えていない（`tool_input` は解決・共通フィールドは未回答）△注意

根拠: `git show bb2a527 -- wip/30_reports/0003-investigation.md`（#6 の調査結果 Q3）

- #6 の結論: 「`tool_name` は `"PowerShell"`。`tool_input` のキーは `command` / `timeout` / `run_in_background` で **Bash ツールと同じ構造**」（出典は公式の tools-reference）。**T5 の結論は「前提どおり」**
- ただし**実機確認は行われていない**: 「一時フック `wip/tmp/dump-hook-input.sh` を `.claude/settings.json` に登録しようとしたが、auto モードの分類器が `settings.json` への書き込みを拒否した。迂回はしない」「実機確認は 2/3 でフックを正式に登録した直後の最初の PowerShell ツール呼び出し（`decisions.jsonl` に `tool: PowerShell` が残る）で自然に得られるので、**2/3 のテスト観点（HK-T05 の PowerShell ケース）に含める**」
- **ただし #6 が答えたのは T5 の問いの半分**（2 巡目レビュー S4）: §12 T5 の問いは「PowerShell ツールのフック stdin **固有フィールド**（`session_id` / `cwd` / `permission_mode`）が Bash と同じ形で来るか（`tool_input` の同一性は §2 に確定済み）」。#6 が確かめたのは `tool_input` の側で、§12 が「確定済み」と断った方。**共通フィールドの側は未回答**のまま
- なお `hook-common.sh` の `hook_read_input` は `.tool_input.command` を Bash / PowerShell で共通に読み、読み込んだ全フィールドから CR を落とす（`line="${line//$'\r'/}"`、`hook-common.sh:135`）。PowerShell の差異を吸収する実装は既にある
- したがって §12 に T5 の行が残っているのは正しく、**この issue で閉じる**のが申し送りどおり
- 実測への依存: **あり**（フェーズ 4c。登録直後の PowerShell 実行 1 回で足りる）

結論: T5 は「`tool_input` の側は #6 で解決済み・**共通フィールドの側は未回答**」。実装フェーズの検証項目は `tool_input.command` ではなく**共通フィールド**にする: `decisions.jsonl` に `tool: PowerShell` の行が残り、その入力の `session_id` / `cwd` / `permission_mode` が Bash のときと同じ形（`cwd` は Windows パスでも `hook_rel_path` が解けること）で読めること。

### f9. `git 'commit'` は bash 経路では素通りする（仕様の穴）△注意

根拠: 共通仕様 §7-9、`block-direct-git` 仕様 制御方式 3、`cmdpos.sh:324`（`gitlike` の条件）、`test_cmdpos.sh:226`（HK-T05 の期待値）

- 共通仕様 §7-9 は「`CP_SUBCMD[i]`（第 1 サブコマンド。…**クォートで割った語（`git 'commit'`）は `_` になり、呼び出し側は「特定できない」として扱う**）」と定める
- `cmdpos.sh` の実装もそのとおり: `git 'commit'` は `exe=git` / `subcmd=_`。`CP_GITLIKE` は**実行体が `_` のときだけ** 1 になる（`'git' commit` は gitlike=1、`git 'commit'` は gitlike=0）
- ところが `block-direct-git` の制御方式 3 で「サブコマンドが特定できないときに拒否側に倒す」と書いてあるのは **PowerShell の入力についてだけ**。bash 経路には `subcmd == "_"` の規定が無く、`opaque` でもないため、**現状の仕様どおりに実装すると `git 'commit'` は許可される**
- issue #9 の詳細 D2 は「`git 'commit'` のようにクォートで割った語のサブコマンドが `_` になる制約（`block-direct-git` は『特定できない』として扱う）」と申し送っており、**「特定できない = 拒否側に倒す」という意図**と読める
- **ただし機構全体では素通りしない**（レビュー指摘 R9）: 作業中チケットがある間は `workflow-guard` が止める。`scope_classify` は `exe == git` のとき `CP_SUBCMD` を読み取り系サブコマンドの一覧と照合し、`_` はどの分類にも当たらないため `unknown` → **WF204（分類外コマンド）**。真に素通りするのは「作業中チケットが 0 枚の窓」（§13 の意図的な緩和）と `workflow-guard` を止めているときだけ
- 実測への依存: 無し

結論: `block-direct-git` の制御方式 3 に「実行体が `git` で第 1 サブコマンドが `_`（特定できない）→ **deny WF403**」を bash 経路にも足すのが、§7-9 と D2 の意図に沿う。現状でも作業中チケットがあれば `workflow-guard` の WF204 で止まるため、**修正の効果は「メッセージが適切になること」と「チケットが 0 枚の窓でも止まること」**の 2 点で、優先度は中。テストは BG-T01 に 1 ケース足す。

## 検証の結果

| # | 仕様の前提 | 公式の記載 | 出典 | 判定 |
|---|---|---|---|---|
| 1 | `SubagentStart` イベントの実在 | 「When a subagent is spawned」。matcher は agent type | hooks.md（Events 一覧・matcher の節） | **一致** |
| 2 | `SubagentStart` の入力に `model` | 「Only `SessionStart` hooks can receive a `model` field」 | hooks.md（共通入力フィールドの節） | **相違**（f2） |
| 3 | `agent_id` | サブエージェント内で入る。SubagentStart / SubagentStop では必須 | agent-sdk/hooks（入力の型定義） | **一致** |
| 4 | `agent_type` | 同上。値はエージェント名（`"Explore"` 等） | agent-sdk/hooks（入力の型定義） | **一致** |
| 5 | `permissionDecision: "defer"` の実在 | `allow` / `deny` / `ask` / `defer` の 4 値。「`"defer"` exits gracefully so the tool can be resumed later」。対話セッションでは警告を出して無視される | hooks.md L1738-1751（PreToolUse decision control）・L1781-（Defer a tool call for later） | **一致**（採用しない。f3） |
| 6 | `tool_response` の終了コードのフィールド名 | 「`Bash` returns an object with `stdout`, `stderr`, `interrupted`, and `isImage` fields」。終了コードのフィールドは無い。PostToolUse は成功時のみ発火し、失敗は `PostToolUseFailure` の `error`（1 行目 `Exit code N`） | hooks.md L1930・L1990・L2034-2068 | **相違**（f4。仕様の「4 候補読み」は成立しない） |
| 7 | `Stop` / `SubagentStop` の入力 | Stop は `stop_hook_active` / `last_assistant_message` / `background_tasks` / `session_crons`、SubagentStop は加えて `agent_id` / `agent_type` / `agent_transcript_path` | hooks.md L2470（Stop input）・L2325（SubagentStop input） | **一致**（スキーマも取得済み） |
| 8 | matcher が `WebFetch` / `WebSearch` を対象にできるか | matcher は tool 名の完全一致 or 正規表現 | hooks.md（matcher の評価表） | **一致**（f5） |
| — | §12 T5（PowerShell の共通フィールド） | #6 が答えたのは `tool_input` の側（§12 が確定済みと断った方）。共通フィールドは未回答 | リポジトリ: コミット `bb2a527`・フック共通仕様 §12 | この issue の 4c で確認（f8） |
| — | フックのタイムアウト時の挙動 | `command` / `http` / `mcp_tool` はブロックしない（出力も破棄）。ブロックするのは Agent SDK のコールバックのみ | hooks.md（timeout・exit code の節） | **仕様に記述なし**（f7 / R1） |
| — | `git 'commit'` の扱い | §7-9 は「特定できない」、block-direct-git は PowerShell だけ規定。`workflow-guard` の WF204 が受け止める | リポジトリ: フック共通仕様 §7-9 | **仕様の穴**（f9） |

- 出典の URL: hooks リファレンス = `https://code.claude.com/docs/en/hooks`（本文の取得は `https://code.claude.com/docs/en/hooks.md`）／SDK = `https://code.claude.com/docs/en/agent-sdk/hooks`（いずれも 2026-09-02 取得）

## 設計への反映

1. **WF801 の判定経路**（f2）: `SubagentStart` の `model` に依存しない形へ（案 (c) PreToolUse `Agent` を本線に、(b) を残す）。§2・§12 T4・`subagent-start-check` 仕様の制御方式 4 を書き換える。**発行するフックが変わるなら §6 台帳の `WF801–809` の持ち主欄（現在は `subagent-start-check`）も直す**（現状の `subagent-stop-check` は「再掲」なので台帳と矛盾しないが、本線化すると持ち主の定義が変わる）
2. **`defer` を採用しない**（f3）: §12 T3 に「`defer` は `claude -p` のサブプロセス統合用で、対話セッションでは Claude Code が警告を出して無視する（`hooks.md` L1783）ため採用しない」と結論を書いて TBD を閉じる
3. **`web` の強制の可否**（f5 / D3）: 技術的には可能。強制する場合は §1 の登録表に `WebFetch|WebSearch` の行を足し、`scope.sh` の `web` 分類を PreToolUse で判定する。しない場合は §8 の「機構は強制せず宣言は意図の記録」を確定文にする
4. **`tool_response` の終了コード読みをやめる**（f4 / S14）: §12 T7 を「終了コードのフィールドは存在しない」で閉じ、`post-push-*` の成功判定を「PostToolUse に来た = 成功」に変える。失敗も捕まえるなら `PostToolUseFailure` の登録（§1 が 17 行になる）を別途決める
5. **T5 を実装フェーズの検証項目に追加**（f8）: 登録直後の PowerShell 実行 1 回で、**共通フィールド**（`session_id` / `cwd` / `permission_mode`）が Bash と同じ形で来るかを確認する（`tool_input` の側は #6 で解決済み）
6. **`git 'commit'` の穴を塞ぐ**（f9）: `block-direct-git` の制御方式に bash 経路の `subcmd == "_"` → WF403 を足し、BG-T01 にケースを追加
7. **タイムアウト時の fail-open**（f7 / R1）: `command` 型フックはタイムアウトで打ち切られるとブロックせず出力も破棄される。§1 のラッパーも `trap ERR` も効かない。各フックの `timeout` を明示するか、ホットパス（`workflow-entry` / `block-*`）の実行時間の上限を仕様に置くかを決める
8. **仕様に無いイベント**（f6）: この issue では扱わない。`PostToolUseFailure` と、空のまま残る 3 ディレクトリ（`01-PreCompact/`・`11-Stop/`・`21-PermissionRequest/`。`11-Stop/` はイベントを使うがスクリプトが `22-PostToolUse/` にある別種）は 3/3 の検討事項として残す

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 公式ドキュメントで 8 項目すべてに白黒が付く | 5 項目は確定したが、`tool_response` と完全な入力スキーマは記載が見つからなかった（ページが長く、取得できる範囲に該当節が含まれない） | f4 として「記載なし」を明示し、T7 を実測に残した |
| `model` は「無い版がある」程度の話 | 公式が「`SessionStart` だけが受け取れる」と明記しており、`SubagentStart` では**構造的に来ない** | f2 を ✕問題にし、WF801 の設計変更を設計への反映の 1 番目に置いた |
| `defer` は採否を実測で決める | 用途（クエリを終了して後で再開）が明文化されており、実測を待たずに「採用しない」と決められた | f3 として TBD を閉じる提案にした |
| `git 'commit'` は仕様どおりに実装すれば拒否される | 共通仕様 §7-9 は「特定できないとして扱う」と書くが、`block-direct-git` は PowerShell 経路にしか規定が無く、bash では素通りする | f9 として設計への反映に挙げた |
| WebFetch で公式ページを読めば逐語引用ができる | 長いページは小型モデルの要約経由で返るため、**存在しない表や文が返る**ことがある（2 巡目レビューで同じ URL の 2 回の取得が違う文言の表を返した）。`curl` で原本を落として `grep` する方法に切り替えて確定させた | 実施条件に取得方法を明記し、f3・f4・f7・検証表を原本の行番号付きで書き直した |
| `tool_response` の終了コードは実測でしか分からない | 原本には記載があり、**終了コードのフィールドは存在しない**（PostToolUse は成功時のみ発火し、失敗は PostToolUseFailure に `Exit code N` 付きで届く） | f4 を ✕問題に格上げし、`post-push-*` の成功判定の変更を設計への反映 4 に置いた |
| `exit 2` とタイムアウトは同じ「安全側」の話 | タイムアウトは逆で、`command` 型フックは**ブロックしない**（出力も破棄）。最初の取得では要約が原文を取り違えており、レビュー（R1）で原文を確認して訂正した | f7 を △注意 に格下げし、設計への反映 7 として fail-open の対処を追加 |

## 残課題

- `tool_response` の実フィールド名（T7）と `Stop` / `SubagentStop` / `PostToolUse` の完全な入力スキーマ。公式ページの該当節を取得できなかったため、**フェーズ 4c の実測で確かめる**
- ドキュメントの版と実行中の Claude Code の版の対応。matcher の評価規則やイベントの追加は版に依存し得るが、公式ページに版の記載が無い
- `WebFetch` / `WebSearch` を強制対象にした場合、`scope.sh` の `web` 分類が PreToolUse の入力（`tool_name` だけでコマンド文字列が無い）で判定できるか（`scope_classify` はコマンド列を前提にしている）。設計で確かめる
- `PostToolUseFailure` を使うと `post-push-*` の終了コード判定を簡略化できる可能性。3/3 の検討事項
- ホットパス（`workflow-entry` / `block-chmod` / `block-direct-git`）の実測所要。既定値は公式で確定した（600 秒。UserPromptSubmit だけ 30 秒）ので、残るのは「実際に何秒かかるか」だけ（フェーズ 4 で測る）
- `last_assistant_message`（Stop / SubagentStop の共通入力）を使うと `post-push-usage-report` が transcript を読まずに済むか
