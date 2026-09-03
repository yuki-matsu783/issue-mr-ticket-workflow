---
type: plan
title: 0016 AI アセット実装計画 — 共通ライブラリの作り直しから 17 行の段階登録までを 6 枚に割り付ける
description: 設計 0012〜0015 と境界レビュー反映 0019〜0026 が確定した仕様をもとに、既存の hooks/lib 3 本の改修・フック本体 11 本とテスト・settings.json への 17 行の段階登録（人間の操作）・フェーズ 4c の実測 10 項目を 6 枚のチケットに割り付け、T6 を最初に確かめる順序と、実測が拒否側フックに止められない段の切り分けと、ロックアウトの復旧経路を実装前に確定する計画
tags: [plan, ai-asset-implementation-plan, issue-9]
keywords: [実装計画, 段階登録, 17 行, HK-T01, T5, T6, T9, systemMessage, cmdpos_operands, hook_read_input, hc_lock, 読み込み行, SS-T05, ロックアウト, WORKFLOW_ENFORCE, フェーズ 4c, worktree, 4c プローブ]
---

# 0016 AI アセット実装計画 — 共通ライブラリの作り直しから 17 行の段階登録までを 6 枚に割り付ける

## この計画で何をするか

### 結論方針

**設計は「lib は #6 で既に正しい」という前提で書かれたが、境界レビュー 2 巡がその前提を崩した**。`hook-common.sh` には設計が要求する 5 関数（`hook_read_state` / `hc_append_jsonl` / `hc_json_write` / `hc_lock` / `hc_unlock`）が無く、`hook_read_input` はイベント固有フィールド（`prompt` / `source` / `tool_response` / `run_in_background`）も副入力も取らず、`cmdpos.sh` には `cmdpos_operands` が無く、`scope.sh` は `web` を知らず読み込み関数がパスを引数に取る。**フック本体 11 本を書く前に lib の改修が要る**。

そのうえで **T6（`permissionDecision` + 終了 0 の deny が実際に効くか）を 11 本を書き切る前に確かめる**。外れたときの手戻りが 11 本 + 登録ラッパー全部に及ぶためで、0006 の申し送り f7 が求めているのもこれである。そこで**拒否側の最も単純な 1 本（`block-chmod`）を lib と同じチケットで先に書き、それだけを単独で登録して T6 を確かめる ⓪ の段**を段階登録の前に置く。

6 枚に割る:

| 枚 | 中身 | 先行 |
|---|---|---|
| 0027 | `hooks/lib` 3 本の改修（`hook-common.sh` / `cmdpos.sh` / `scope.sh`）+ `config` 3 ファイルの新規 + 読み込み行の一斉置換 + `block-chmod` 1 本 | なし |
| 0028 | **⓪ T6 の先行確認**（`block-chmod` だけをラッパー無しで登録し deny が効くかを見る）。結果で終了方式を確定 | 0027 |
| 0029 | 案内側 6 本（`session-start` / `workflow-diff-check` / `post-push-compact-prompt` / `post-push-usage-report` / `subagent-start-check` / `subagent-stop-check`）とテスト | 0027 |
| 0030 | 拒否側の残り 4 本（`workflow-entry` / `workflow-state-guard` / `block-direct-git` / `workflow-guard`）とテスト | 0028, 0029 |
| 0031 | 段階登録 ①・②（17 行）と**フェーズ 4c の実測 10 項目**、HK-T01 と `run-tests.sh` の全件 | 0030 |
| 0032 | `feedback-plan`（次の計画） | 0027〜0031 |

### 実装前に確定した 11 件

1. **段階登録は 17 行**（§1 の表が正）。案内側 **12 行**・拒否側 **5 行**。全体計画が書いた「16 行 / ① 11 行」は `subagent-start-check` の PreToolUse `Agent` 登録（7 行目・WF803）が増える前の数で、**この計画で 17 行 / ① 12 行に組み直す**
2. **各段で AI が渡すのは「その段までの PreToolUse 配列の全文」**。HK-T01 は**配列上の位置**まで照合する（§1・§11）。人間が末尾に足していくと ⓪ の `block-chmod` が 1 番目に残り、最終配列が `[4,1,7,2,3,5,6]` になって HK-T01 が落ちる。**位置は AI が保証し、人間は貼り替えるだけ**にする
3. **T6 の確認は ⓪ で行い、そのときラッパーを付けない**。ラッパーは「本体が起動できない = deny」なので、T6 が未確認の段でラッパーごと登録すると、本体の不調と登録方式の不調が区別できず、しかも**ラッパーは環境変数を見ないので環境変数で戻れない**（§4）。⓪ は素の `command` で登録し最悪でも fail-open に留める
4. **4c の実測は 10 項目**（T2・T3・T4・**T5**・T7・T9 と `tool_response.status`・`agent_type`・worktree・ホットパスの実行時間）。**T1 と T8 は §12 が既に取り消し線で「解決（TBD ではない）」としているので含めない**（T8 は機械テスト `HK-T16` が `frontmatter.sh` を隠した環境で固定する）。**T6 は ⓪ で確認済み**。**T5（PowerShell ツールの stdin 共通フィールド）は §12 に生きた TBD として残っており、全体計画の申し送りにもある**ので必ず含める
5. **T9 と入力フィールドの実測は「4c プローブ」で行う**。`decisions.jsonl` は 10 キー固定（§5）で `permission_mode` / `model` / `tool_response` / `agent_type` を入れる場所が無く、`systemMessage` を出す WF801 / WF803 は `subagent_type` が `task-executor`（**実装が無い**）で `executor` が `main` 以外のときにしか発火しない。したがって**環境変数 `WORKFLOW_PROBE_4C=1` のときだけ有効になる一時的な観測経路**を仕込む: (a) 見たいフィールドの**値**（`tool_response.status` / `agentId` / `agent_type` / `model` / `permission_mode` / `source` / `run_in_background`。いずれも秘密でない）と、その他のキーの**有無と型だけ**を `logs/hooks/probe-4c.jsonl` に落とす、(b) `subagent-start-check` が `Agent` の呼び出しで無条件に `systemMessage` を 1 つ出す。**実測後に取り除き、取り除いたことを 0031 の DoD で確かめる**
6. **② の後には `git worktree add` / `claude -p` / `mv` が `workflow-guard` に止まる**（`worktree` と `claude` は `scope.sh` の読み取り一覧に無く WF204、`mv` は WF205）。そこで 4c を**「② より前に測るもの」と「② の後でしか測れないもの」に分ける**。worktree の実測だけは `workflow-guard` が登録されていないと意味が無いので、**worktree の作成を ② より前に済ませ、② の後にそこで Claude を起動する**
7. **HK-T01 の期待値は 17 行分の `command` 文字列の逐語一覧**をフィクスチャ（`.claude/hooks/tests/fixtures/settings-hooks.expected.tsv`。イベント・matcher・位置・`command` の 4 列）に持つ。イベント名からディレクトリを機械変換できない行が 4 行あるため（§1）。**うち拒否側 5 行は fail-closed ラッパー（`|| printf … WFx09 …`）まで含めた逐語**で、`x` はフックごとに違う（`workflow-entry` = WF109 / `workflow-guard` = WF209 / `workflow-state-guard` = WF309 / `block-direct-git` = WF409 / `block-chmod` = WF509）。逐語照合で最も長く最も間違えやすいのがこの 5 行
8. **読み込み行は雛形を先に直してから配る**。`^__ss_load() {` を持つのは **22 ファイル**（雛形 2 本 + 実体 20 本）。`SS-T05` の走査範囲は `.claude/hooks/**` と `.claude/skills/*/scripts/**` なので **`assets/test.template.sh` は検査対象外**（揃えること自体は正しいが、ずれても `SS-T05` は落ちない）
9. **実装フェーズは DDR を書けない**（`ai-asset-implementation.deny` に `.claude/docs/**`）。決定は**チケットの作業ログ「判断と根拠」**に、DDR にすべきものは**「AI アセットに反映すべき内容」**に書き、0032（`feedback-plan`）が棚卸ししてフェーズ 6 で DDR にする
10. **`settings.json` は許可範囲に入っているが AI は書かない**。機構としては確認つきで書けるが、この issue の制約として登録は人間の操作。AI は貼り付ける JSON と手順を提示し、登録後のコミットだけを行う
11. **フェーズ 7 は第 1 案（`WORKFLOW_STATE_GUARD_ENFORCE=0` の新セッション）で通す**。17 行の登録を保ったまま HK-T01 と全件テストが通る状態でマージできる唯一の案。フェーズ 7 の直前に人間と最終確認する

## 対象と範囲

### 入力（読んだもの）

- **設計の結果報告 12 枚**: `0012`〜`0015`（前半）・`0019`〜`0026`（境界レビュー 2 巡の反映）の「設計への反映（後続へ）」
- **指摘の原文**: `0015-ai-asset-design-appendix-A.md`（1 巡目 38 件）・`0022-ai-asset-design-appendix-A.md`（2 巡目 27 件）
- **仕様**: `フック共通仕様`（§1 登録表 17 行・§2 作業ツリー・§3 制御方式・§5 記録とロック・§7 `cmdpos.sh`・§8 `scope.sh`・§11 HK-T01〜T20・§12 TBD）、フック個別 11 本、`20-common-step-shell-script`
- **実体**: `.claude/hooks/lib/*.sh` 5 本・`.claude/hooks/config/` 2 ファイル・`^__ss_load() {` を持つ 22 ファイル・`scope-limits.json`・`.claude/rules/` 4 本・`.claude/agents/`（空）
- **申し送り**: `0006` の実装計画への 3 件（実装の型 / T6 を最初に / 重い 4 本と軽い 7 本）、全体計画の登録段取り・T5 の確認・#10 への申し送り

### 実体と仕様の差分（この計画が拾った未実装）

| 対象 | 現状 | 仕様が要求するもの | 割り当て |
|---|---|---|---|
| `.claude/hooks/**` のフック本体 | **0 本**（9 つのイベントディレクトリは `.gitkeep` のみ） | 11 本 | 0027（1 本）・0029（6 本）・0030（4 本） |
| `hook-common.sh` の**関数** | 30 関数 | `hook_read_state` / `hc_append_jsonl` / `hc_json_write` / `hc_lock` / `hc_unlock` の **5 関数が無い** | 0027 |
| `hook_read_input` の**抽出フィールド** | 14 個。**`prompt` / `source` / `tool_response.*` / `tool_input.run_in_background` / `agent_transcript_path` / `tool_input.old_string` / `new_string` / `content` / `edits` / `draft` が無い** | これらも同じ 1 回の `jq` で取る。取らないと `workflow-entry`（`prompt`）・`session-start`（`source`）・`workflow-guard`（WF208 が Edit の `old_string` / `new_string` と Write の `content` を見る）・`workflow-state-guard`（WF304 が MCP の `draft` を見る）が `hook_field` を追加で呼び、**ホットパスの「`jq` 最大 2 回」を破る** | 0027 |
| `hook-common.sh` の**副入力**と**作業ツリー** | 副入力を受け取らない。`HOOK_ROOT` が source 時に確定し、`logs/` と `wip/` を触る 4 関数（`hook_doing_ticket` / `hook_record` / `hook_session_dir` / `hook_rel_path`）が本流固定 | 副入力は `--rawfile` + `fromjson? // null`（不在は `--argjson null`）で受け `HC_<名前>_STATE` を立てる。**worktree では `cwd` から `.claude` を上向きに探した作業ツリーを基準にする**（§2） | 0027 |
| `tool_class`（`hook-common.sh:162`） | `Skill` を `00-workflow-*` の接頭辞で `declare` / `read` に振り分ける | **`Skill` は `tool_input.skill` の値を見ずに常に `declare`**（`20-common-step-shell-script` 仕様・§2・DDR `i0009-03`）。接頭辞判定が残ると `Skill(20-common-step-ticket)` が `read` に落ち、`workflow-entry` / `workflow-guard` の宣言判定と `decisions.jsonl` の分類が仕様とずれる | 0027 |
| `cmdpos.sh` | 公開関数 4 本（`cmdpos_args` / `cmdpos_parse` / `cmdpos_has_git_subcommand` / `cmdpos_has_provided`） | **`cmdpos_operands <i>` が無い**（`REPLY_OPERANDS` に位置引数を展開する。§7-9・DDR `i0009-39`）。`workflow-state-guard` の WF302 / WF303 の「元」の取り出しがこれに依存する | 0027 |
| `scope.sh` | 11 関数。読み込み関数がパス引数を取り自分で JSON を開く。`web` を知らない | パス引数を削り `HC_*` から詰め替える。`_SC_WEB_CMDS` と `web` の 3 段判定・出力先の走査、`scope_load_ticket` の戻り値 3 状態、`fm_*` の `\|\| true` の除去 | 0027 |
| `.claude/hooks/config/` | `scope-limits.json`・`task-types.tsv` の **2 ファイル** | 5 ファイル。`blocked-commands.txt`（初期値 `chmod`）・`entry-skills.txt`・`model-aliases.txt` が**無い** | 0027 |
| 読み込み行 | **22 ファイル**（雛形 2 + 実体 20）にコピーされているが、雛形自体が仕様と 3 点ずれている（`FM_AVAILABLE` を設定しない / `fm_*` スタブの戻り値が 1（仕様は 2）/ フォールバックの `git rev-parse`） | 雛形と実体 20 本がバイト一致（`SS-T05`） | 0027 |
| `.claude/settings.json` の `hooks` | 未登録 | 17 行 | 0028（⓪ 1 行）・0031（①② 16 行） |
| `transcript.sh` / `push-detect.sh` | 既に仕様どおり（`transcript.sh` は自前の暦計算で `strptime` を使わない） | — | **変更不要と確認した** |
| `scope-limits.json` | 15 種すべて揃い `common` の 5 キーも揃う。`investigation.ops` に `web` あり | §8 の初期値の表と一致 | **変更不要と確認した** |
| `SC_CLASS` の**値集合** | 実体は `write` と `opaque` を返す（`scope.sh:259`・`:262`・`:281`） | §8 の表にこの 2 値が無い。ただし WF205（コマンドによる書き込み）と WF204 / WF209 はこの 2 値を前提にしないと出せない | 0027（**実体に合わせて統一**）+ 0032（仕様の表への追記） |
| `SC_TARGETS` の**形** | US（0x1E）区切りの**スカラ文字列**（`scope.sh:25`・`:260`） | §8 の表は **`SC_TARGETS[]`（配列）**と書く。呼び手が `"${SC_TARGETS[@]}"` で回すと `set -u` 下で 1 要素目しか取れず**複数出力先の判定が静かに漏れる** | 0027（実体を US 区切りで統一）+ 0032（仕様の `[]` を外す書き戻し） |
| `.claude/rules/` | 4 本のみ。既存ルールから参照されていて解決しないのが **`markdown-docs` と `ai-asset-authoring` の 2 本** | 要件（`ルール体系.md`）は 15 本 | **0027 では扱わない**（下記） |

**`.claude/rules/` の 2 本を実装フェーズで閉じない理由**: AI アセットは要件書と 1:1:1（`ai-asset-design-docs.md:13`）で、`markdown-docs` の要件書・仕様書が `.claude/docs/**` に無い。実装フェーズは `.claude/docs/**` が `deny` なので**要件書を作れない**。逆に参照を消す案も、正史（`00_requirement/rules/ai-asset-design-docs.md:84` と `ルール体系.md`）がルールの存在を要求しているため `.claude/docs/**` を直す必要があり、同じ理由で**できない**。**0032 の棚卸しに送り、フェーズ 6 または #10 で 1:1:1 を揃えて作る**。

### やらないこと

- `.claude/docs/**` への書き込み（実装フェーズの `deny`。書き戻しはフェーズ 6）
- 提供コマンドの実体の変更。`push.sh` の 1 枚目依存は #10 への申し送り 2
- `boundary.sh` / `finalize.sh` の実装（3/3）と依存する 10 件のテスト観点（申し送り 1）
- `scope-limits.json` の実体変更（変更不要と確認した）
- `.claude/rules/markdown-docs.md` / `ai-asset-authoring.md` の新規作成（上記の理由で 0032 へ）
- `.claude/agents/task-executor.md` の実装（要件・仕様はあるが本 issue のフェーズ列に無い。T9 の実測はプローブで代替する）
- `PostToolUseFailure` / `PermissionRequest` / `PreCompact` の登録と空ディレクトリ 3 つ（申し送り 5）
- `WebFetch` / `WebSearch` の強制（§13 の意図的な緩和）
- マージ（人間）

## 方法とステップ

### ステップ 1: 共通ライブラリと足場（0027）

**1-1 読み込み行**（`i0009-36`）。順序を守る。

1. `assets/script.template.sh` の `__ss_load` を仕様（`20-common-step-shell-script`「読み込み行」）に合わせる: `FM_AVAILABLE` を設定する（読めたら 1・`nop` フォールバックで 0）／`fm_*` スタブの戻り値を **1 → 2** に直す（`i0009-16` の 3 状態）／ルート解決の 3 段目 `git rev-parse` は**残す**（外すと相対パス起動かつ `CLAUDE_PROJECT_DIR` 無しの経路が解決不能になる。ホットパスでは 1 段目・2 段目で必ず解決するので実行されない）
2. `assets/test.template.sh` の同じ行を揃える（**`SS-T05` の検査対象外**だが揃える）
3. 実体 **20 本**へ雛形の当該行を**バイト一致で**配る（**`grep -rl '^__ss_load() {' .claude` の 22 件**から雛形 2 本を除いた分。リポジトリ全体では 24 件あるが `wip/tmp/*.sh.new` の作業用コピー 2 本は `SS-T05` の走査範囲外なので触らない）
4. 配った後に**もう一度 `grep` して雛形との差分 0** を確かめる（0024・0026 の教訓「`applied=N/N` は内容を保証しない」）
5. `SS-T05` を実装して通す（違うファイルを列挙して落ちる失敗ケースも確かめる）

**1-2 `hook-common.sh`**。実装の型を 11 本で統一する（0006 f4）: **`HOOK_DENY_ID` の代入 → lib の `source`（読み込み行）→ `hook_init`**。この順でなければ、読み込み行が `deny` ポリシーで出す `WFx09` が既定の `WF009` になる。

- **`hook_read_input [設定パス...]` の 1 回の `jq` を拡張する**: 現在の 14 フィールドに加えて次を取る。**取らないと拒否側 4 本が `hook_field` を追加で呼び、ホットパスの上限を破る**
  - `prompt`（`split("\n")[0]` で 1 行目だけ。`workflow-entry` の宣言判定に要るのは 1 行目だけで、4 KB 制限と `redact` の負担も同時に落ちる）・`source`（`session-start`）
  - `tool_response.status` / `tool_response.agentId`（`subagent-stop-check`）・`tool_input.run_in_background`（§2 の background 判定）・`agent_transcript_path`
  - **`tool_input.old_string` / `new_string` / `content` / `edits`**（`workflow-guard` の WF208。**全文は要らない** — frontmatter の 6 キー（`ticket_type` / `allow` / `executor` / `human_review` / `adversarial_review` / `predecessors`）のどれかに触れたかだけが判ればよいので、`jq` の中で正規表現の**真偽 1 個**に畳む）
  - **`tool_input.draft`**（`workflow-state-guard` の WF304。MCP の `pull_request` / `merge_request` 系）
- **`tool_class` から `00-workflow-*` の接頭辞判定を除く**（DDR `i0009-03`）。`Skill` は常に `declare`
- 同じ 1 回の `jq` で、**パスが stdin に依存しない副入力**（`scope-limits.json` / `logs/review-state.json` / `logs/merge-state.json`）を読む。存在するものだけ `--rawfile <名前> <パス>`、無いものは `--argjson <名前> null`（存在確認は `[ -f ]`。fork しない）。`fromjson? // null` に通し、結果で `HC_<名前>_STATE`（`ok` / `missing` / `broken`）を立てる
- **副入力の受け渡しの形を先に決める**（この計画で唯一「やってみないと形が決まらない」箇所。0027 の最初にここだけを片付ける）:
  - **区切りバイトの割り当て**: 現在 `__HC_US` / `_SC_US` / `CP_ARGS` の区切りが**すべて 0x1E で衝突している**。stdin のフィールド区切りに 0x1E を残し、**副入力の行区切りに 0x1D（GS）・行内の列区切りに 0x1F（US）**を割り当てる
  - **`scope-limits.json` の射影は全 type を出す**。実体の `scope_load`（`scope.sh:34-41`）は `--arg t` で 1 type だけを射影しているが、`t`（`ticket_type`）はチケットの frontmatter を `frontmatter.sh` で読んで初めて分かる = `hook_read_input` の**後**。したがって 1 回の `jq` に移すなら 15 種すべての `allow` / `deny` / `confirm` / `ops` / `plan_mode` と `common` 5 キー・`commands.build-test` を出し、`scope_load [type]` が **`HC_LIMITS` から自分の type の行を選ぶ**
  - **検証エラーで `jq` を落とさない**。実体の `scope.sh:43-56` は `bad(...)` で `error` 終了させる作りだが、これを共有の `jq` に持ち込むと**stdin の解析ごと落ちる**（DDR `i0009-47` と `HK-T18` が明示的に禁じている形）。検証結果は `HC_LIMITS_STATE=broken` と WF210 用のメッセージ文字列として返し、`jq` は常に終了 0 にする
- `hook_read_state <パス>...`: `session_id` に依存する副入力（`approvals.json` / `entry.json`）を **1 回の `jq`** で読む。要るフックだけが呼ぶ
- **作業ツリーの解決**（§2・`i0009-55`）を `hook-common.sh` に入れる。`HOOK_ROOT`（`source` 時に確定。スクリプトの置き場）と `HOOK_WORKTREE`（`hook_read_input` の直後に確定）を分け、`hook_doing_ticket` / `hook_record` / `hook_session_dir` / `hook_rel_path` は `HOOK_WORKTREE` を基準にする。解決は「`cwd` が `HOOK_ROOT` と異なるとき `cwd` から上向きに `.claude` を持つディレクトリを探す（`[ -d ]` の繰り返し。fork ゼロ）。見つかればそれ、無ければ `HOOK_ROOT`」。
- **候補が `HOOK_ROOT` の worktree であることを必ず確かめる**。公式は `cwd` を「worktree に入った後の worktree ルート、**かつ Claude が `cd` した後の新しいディレクトリ**」と定めており、`cd` だけでも `cwd` は動く。このリポジトリには `参考ディレクトリ/agent-workflow/.claude` と `参考ディレクトリ/MR-driven-workflow/.claude` が実在し、どちらも `wip/10_tickets/10_doing/` を持つ（空）。**`cd 参考ディレクトリ/agent-workflow` しただけで `hook_doing_ticket` が 0 枚を返し、`workflow-guard` が「作業中 0 枚 → 判定しない」に落ちてガードが全面バイパスされる**。判定は fork ゼロで書ける 2 通りのどちらか: (a) 候補直下の `.git` が**ファイル**で、`197121<候補/.git)` の `gitdir:` が `HOOK_ROOT` 配下を指す、(b) `HOOK_ROOT/.git/worktrees/*` の名前列を glob で拾って候補と突き合わせる。仕様 §2 への書き戻しは 0032 へ
- `hc_append_jsonl` / `hc_json_write` / `hc_lock` / `hc_unlock`: §1 の契約の表どおり。**切り詰め（4 KB / `note` と `target` で 1 KB）は `hc_append_jsonl` が行い呼び手は切り詰めない**。**2 秒と 60 秒は `hc_lock` が持ち呼び手は指定しない**。`hc_lock` は取得を試みる前に既存ロックの作成時刻を見て 60 秒より古ければ `rmdir` して強制解放し、実行ログに 1 行残す（`i0009-60`）
- ロックの作成時刻は `find <dir> -maxdepth 0 -mmin +1` で判定する。**`hc_lock` はホットパスではない**（案内側だけが使う）ので `find` の fork は上限に触れない。Windows の Git Bash での挙動は 0027 で実測して作業ログに残す

**1-3 `cmdpos.sh`**。`cmdpos_operands <i>` を足す（§7-9・`i0009-39`）: `CP_ARGS[i]` から `-` で始まる語と `--` 以降の区切りを除いた位置引数を `REPLY_OPERANDS` 配列に展開する（`rm -rf a b` → `a b`、`mv -v src dst` → `src dst`）。**削除対象か宛先かの解釈は呼び手が行う**（`workflow-state-guard` が `rm` / `git rm` なら全部を「元」、`mv` なら最後を宛先とする）。これを lib に置かないと、`workflow-state-guard` 側にコマンド意味論を持たせることになり `i0009-39` が明示的に却下した案に戻る。

**1-4 `scope.sh`**。

- `scope_load [type]` / `scope_load_approvals` から**パス引数を削る**（`i0009-48`）。`HC_*` を読んで `SC_*` に詰め替えるだけにし、`HC_<名前>_STATE` を `SC_ERROR` と戻り値 2 に写す
- `scope_load_ticket <ticket.md>` の戻り値を **0 / 1 / 2** の 3 状態に分ける（`i0009-16`）
- `_SC_WEB_CMDS` を足し、`scope_classify` に **`web` の 3 段判定**を実装する（`i0009-56`）: (1) 送信側オプション → `WF206`、(2) 出力先オプション → 出力先を `SC_TARGETS` に入れて `WF205` の判定へ、(3) 残りが `web`。**出力先は `cmdpos_args` の引数列を先頭から走査**して取り、`://` を含む語は URL として除く（`i0009-57`）
- **`SC_TARGETS` は US（0x1E）区切りのスカラ文字列で統一する**（既存の実装に合わせる）。仕様 §8 の表が `SC_TARGETS[]`（配列）と書いているずれは実装フェーズでは直せないので、**0032 の棚卸しに送る**
- `fm_*` の呼び出しから **`|| true` を除き `|| rc=$?` に**、`local` と代入を 2 行に分ける（`i0009-35`）
- `hook-test` を `build-test` と `provided` より先に判定する点は **既に実装済み**（`scope.sh:253-256`）。**確認するだけで触らない**

**1-5 `config` 3 ファイル**。`blocked-commands.txt`（初期値 `chmod` の 1 行）・`entry-skills.txt`・`model-aliases.txt` を新規作成する。**`.claude/hooks/config/**` は `common.confirm` なので WF203 の確認が出るが、WF203 を出す `workflow-guard` は ② で登録される**ので、**② より前**に作れば確認は出ない（⓪ より前である必要は無い）。0027 で作るのでいずれにせよ ② より前になる。

**1-6 `block-chmod` 1 本**とそのテスト。⓪ で使う。

### ステップ 2: ⓪ T6 の先行確認（0028）

1. AI が `settings.json` に貼る PreToolUse 配列の**全文**（この段では 1 要素）を提示する。**ラッパー無しの素の `command`**:
   `{"matcher": "Bash|PowerShell", "hooks": [{"type": "command", "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/20-PreToolUse/block-chmod.sh\""}]}`
2. **登録前に人間がバックアップ**を取る（`.claude/settings.json` の登録前の版を手元にコピー）
3. 人間が登録する。AI は登録後の `settings.json` を `commit.sh` でコミットする（この段では `workflow-guard` が未登録なので **WF203 は出ない**）
4. **新しいセッション**で `chmod +x <適当なファイル>` を試し、`permissionDecision: "deny"` + 終了 0 で実際に拒否されるかを見る。あわせて `logs/hooks/decisions.jsonl` に記録が残るかを見る
5. **効いた場合**: §3 の終了方式が確定。0030 以降はラッパー付きで進む
6. **効かなかった場合**: `exit 2` + stderr へ切り替える。影響は `block-chmod` の出力・§1 の登録ラッパー・`hook_deny` / `hook_ask` の実装。**このとき影響を受ける本体は 1 本だけ**で、手戻りは `hook-common.sh` の出力ヘルパの書き換えに閉じる。仕様（§3）との食い違いは作業ログ「仕様からの逸脱」に書き、0032 が書き戻しの要否を決める
7. **ロックアウトが起きた場合**: `WORKFLOW_BLOCK_CHMOD_ENFORCE=0` の**新しいセッション**で再開する（§4）。ラッパーを付けていないので環境変数で必ず戻れる

**⓪ の後、`block-chmod` は本番で生きたまま 0029・0030 が進む**。`chmod` を使う作業が出たら上の環境変数で回避する。

### ステップ 3: 案内側 6 本（0029）

`session-start` / `workflow-diff-check` / `post-push-compact-prompt` / `post-push-usage-report` / `subagent-start-check` / `subagent-stop-check` と各テスト。0006 f5 の「重い 4 本と軽い 7 本」を、**案内側 / 拒否側の区切りの内側で**満たす（重い 4 本のうち `session-start` と `post-push-usage-report` がここに、`workflow-guard` と `workflow-state-guard` が 0030 に入る）。

- 案内側は**ラッパー無し**（失敗は通す。§3）
- `session-start` は `boundary.sh status --offline`（3/3・未実装）が無ければ**何も出さずに終了 0**。依存する 8 件のテスト観点（`SE-T01`〜`04`・`07`〜`09`・`WE-T10` と `SE-T05` / `SE-T06` の前半）は**書かずに #10 へ送る**（申し送り 1）
- `post-push-usage-report` は `--accumulate` と既定の両方で **`hc_lock usage-<branch>`** を取ってから加算する（`i0009-61`）
- `subagent-start-check` は PreToolUse `Agent`（WF801 の `systemMessage` + `additionalContext` の 2 経路・WF803 の background 警告）と SubagentStart（要点の注入）の**両方**に登録される 1 本
- `subagent-stop-check` は PostToolUse `Agent` で `tool_response.status`（`completed` / `async_launched`）で分岐し `agentId`（**camelCase**）を読む
- **6 本に「4c プローブ」を仕込む**（環境変数 `WORKFLOW_PROBE_4C=1` のときだけ有効）。詳細はステップ 5-3

### ステップ 4: 拒否側の残り 4 本（0030）

`workflow-entry` / `workflow-state-guard` / `block-direct-git` / `workflow-guard` と各テスト。⓪ で確定した終了方式で書く。

- **ホットパス 5 本の `jq` の回数を実装で固定する**: `block-chmod` / `block-direct-git` / `workflow-state-guard` = **1 回**、`workflow-guard` / `workflow-entry` = **2 回**。`test-lib.sh` の `make_counting_path` で数え、`HK-T19` で固定する。`hook_field` を追加で呼ばない（0027 で `hook_read_input` が必要なフィールドを取っているのが前提）
- **`git` / `date` / `sed` / `find` をホットパスで呼ばない**。パス照合・コマンド分割は純 bash
- **作業ツリーの基準は `HOOK_WORKTREE`**（0027 で `hook-common.sh` に入れたもの）を使う。各フックが自前で解決しない
- **置き場の削除**（`i0009-59`）: `cmdpos_operands` で位置引数を取り、正規化した元パスの前方一致で置き場のディレクトリ自身と祖先（`wip/10_tickets` / `wip`）を拾う。`rm -rf wip/tmp` と `rm -rf logs` は通す。**自前で引数を再パースしない**

### ステップ 5: 段階登録とフェーズ 4c の実測（0031）

**5-1 段階登録**（⓪ の 1 行は既に入っているので、残り 16 行を 2 段で）:

| 段 | 行数 | 中身 | 直後に確かめること |
|---|---|---|---|
| ⓪（0028 で完了） | 1 | `block-chmod`（ラッパー無し） | **T6** |
| ① 記録・案内側 | **12** | SessionStart 1 / UserPromptSubmit 1 / PreToolUse `Skill` 1 / **PreToolUse `Agent`（`subagent-start-check`）1** / PostToolUse 4 / SubagentStart 1 / SubagentStop 2 / Stop 1 | **T9**・**T4**・**T5**・**T2**・**T3**・**T7**・`tool_response.status`・`agent_type`（すべて 4c プローブで） |
| ② 拒否側 | 4 + 1 | PreToolUse の `workflow-entry` / `workflow-state-guard` / `block-direct-git` / `workflow-guard` をラッパー付きで足し、**⓪ の `block-chmod` にもラッパーを付ける** | **HK-T09**（**機械テスト**。下記）・**worktree**・**ホットパス 5 本の実行時間** |

- **`WORKFLOW_PROBE_4C=1` は人間が設定する**。環境変数はセッション開始時に読まれ **AI は設定できない**（§4）。Bash ツールで前置しても外側のフックプロセスには届かない。**① の登録後、人間が `WORKFLOW_PROBE_4C=1` を設定した新しいセッションを起動する**（`settings.json` の `env` に書く案は `common.confirm` の対象で登録操作が 1 段増えるので採らない）
- **各段で AI が渡すのは「その段までの PreToolUse 配列の全文」**（確定 2）。人間は配列ごと貼り替える。位置は §1 の表の順（1=`workflow-entry`(`Skill`) / 2=`workflow-entry` / 3=`workflow-state-guard` / 4=`block-chmod` / 5=`block-direct-git` / 6=`workflow-guard` / 7=`subagent-start-check`）に合わせる
- 段ごとに**新しいセッション**で軽い操作（Read → Skill 宣言 → Edit → `commit.sh`）を通し、想定外の deny が出ないことを確かめる
- 各段の登録後に AI が `commit.sh .claude/settings.json` でコミットする。**② の後は `common.confirm` により WF203 の確認が出る**（人間が承認する）

**5-2 実測の順序（拒否側に止められない段で測る）**

② の後は `workflow-guard` が `git worktree add`（`worktree` は読み取り一覧に無く WF204）・`claude -p`（同）・`mv`（WF205）を止める。そこで:

- **① の後・② の前に測る**: T2・T3・T4・T5・T7・T9・`tool_response.status`・`agent_type`。あわせて **worktree を `git worktree add` で作っておく**。**置き場はリポジトリの外**（親ディレクトリの兄弟）にする — リポジトリ配下に作ると未追跡ファイルとして `push.sh` の項目 1 で CP005 になり、逃げ道の `.gitignore` は `common.protected` かつ `types.ai-asset-implementation.allow` に無いので WF201 で足せない（測るのは ② の後）
- **② の後に測る**: HK-T09（ラッパー）・worktree での判定・ホットパス 5 本の実行時間
- ② の後にどうしても必要になったコマンドは `WORKFLOW_GUARD_ENFORCE=0` の**新しいセッション**で実行する（環境変数はセッション開始時に読まれる。§4）

**5-3 4c プローブ**（確定 5）

`decisions.jsonl` は 10 キー固定（§5）で `permission_mode` / `model` / `tool_response` / `agent_type` を入れる場所が無い。また `systemMessage` を出す WF801 / WF803 は `subagent_type` が `task-executor`（**`.claude/agents/` は空で実装が無い**）で `executor` が `main` 以外のときにしか発火せず、この issue のチケットはすべて `executor: main` なので**そのままでは T9 が測れない**。

そこで **`WORKFLOW_PROBE_4C=1` のときだけ有効になる一時的な観測経路**を 0029 で仕込む:

- (a) **フィールドの観測**: 見たいフィールドの**値**（`tool_response.status` / `tool_response.agentId` / `agent_type` / `model` / `permission_mode` / `source` / `run_in_background`。いずれも秘密でない）と、その他のキーの**有無と型だけ**を `logs/hooks/probe-4c.jsonl` に落とす。**値そのものを落とすのはこの 7 つに限る**（`.claude/rules/logger.md` の「値ではなく有無・長さ」からの逸脱なので、範囲を絞ったうえで作業ログ「仕様からの逸脱」に書く）
- (b) **`systemMessage` の観測**: `subagent-start-check` が `Agent` の呼び出しで無条件に `systemMessage` を 1 つ出す（WF801 の業務条件を通さずに「表示されるか」だけを見る。§12 T9 が問うているのはこれ）
- **出力は `hc_append_jsonl` 経由**にする（`redact` と 4 KB 切り詰めをただで得る）。並列に走るフックが 4 KB を超える行を書くと JSONL が割れるため、自前の `>>` は使わない
- **`session-start` ではプローブを早期 return の前に置く**。`boundary.sh` 不在で「何も出さずに終了 0」する経路の後に置くと、`source`（SessionStart 固有）の行が一切残らない
- **逸脱は 2 つ**: `rules/logger.md`（値ではなく有無・長さ）と、**§5 の `logs/` の表に無いパス（`logs/hooks/probe-4c.jsonl`）を一時的に増やすこと**。後者のほうが重い（§5 の表は正）
- **実測後に取り除く**。0031 の DoD で「取り除いたこと」「`grep -rn 'WORKFLOW_PROBE_4C\|probe-4c' .claude` が 0 件であること」「取り除いた後に全件テストが通ること」を確かめる

**5-4 フェーズ 4c の実測 10 項目**

| # | 項目 | 測る段 | 確かめ方 | 外れたときの影響 |
|---|---|---|---|---|
| T2 | サブエージェント内の `session_id` が親と同じか | ① の後 | プローブの `session_id` を親子で比較 | `hook_read_state` が読む置き場 |
| T3 | `claude -p` を入力から判別できるか / `defer` の実在 | ① の後 | `claude -p` を 1 回走らせ、プローブの `permission_mode` と共通フィールドを比較 | §10 のヘッドレス判定 |
| T4 | `SubagentStart` と `agent_id` / `agent_type` の実在（**`model` は来ない**前提） | ① の後 | サブエージェントを 1 つ起動しプローブを見る | SubagentStart 登録 |
| **T5** | **PowerShell ツールの stdin 共通フィールド**（`session_id` / `cwd` / `permission_mode`）が Bash と同じ形か | ① の後 | PowerShell ツールを 1 回呼び、プローブの共通フィールドを Bash のものと比較。あわせて #6 の作業ログと DDR を読み、既に解決済みなら書き戻し対象として記録する | `hook_read_input` の読み取り。全体計画の申し送り |
| T7 | `tool_response` の終了コードのフィールド名 | ① の後 | プローブに落ちた `tool_response` のキー一覧を見る。**公式では「存在しない」と分かっているが受け入れ条件 5 が実物の確認を求める**ので省かない | `push-detect.sh` の判定 |
| **T9** | **`systemMessage` が PreToolUse でユーザーに実際に表示されるか** | ① の後 | **観測者は人間**（`systemMessage` は §3 のとおり **AI には届かない**）。3 つの証跡を揃える: (1) プローブ (b) を有効にしてサブエージェントを 1 つ起動し、**人間が見た / 見なかったの一次報告**を作業ログに引く、(2) T3 のために走らせる `claude -p` を **`--output-format stream-json --verbose`** にして `Agent` 呼び出しを 1 回させ、`SDKInformationalMessage` の有無を機械的に採る（同じ 1 回で T3 と T9 の機械証跡が両方取れる）、(3) **負のコントロール**として同じ呼び出しでプローブ (a) が `logs/hooks/probe-4c.jsonl` に 1 行落ちていることを確かめる（落ちていなければ「表示されない」ではなく「フックが起動していない」）。**登録表を 17 行に保つ唯一の支え** | §1 の行数・WF801 の 2 経路 |
| — | `tool_response.status` が既定で `async_launched` か | ① の後 | 同じ起動でプローブを見る | `subagent-stop-check` の分岐 |
| — | `agent_type` の実物 | ① の後 | 同じ起動でプローブを見る | 受け入れ条件 5 |
| — | **worktree で worktree 側のチケットを見るか** | **② の前に作り ② の後に測る** | ② より前に `git worktree add` で**リポジトリの外**に作っておき、② の後に **`EnterWorktree` ツールでそこへ移る**（`workflow-entry` / `workflow-guard` のどちらの matcher にも含まれないので ② の後でも通る。**worktree ディレクトリで新しいセッションを起動してはならない** — その場合 `CLAUDE_PROJECT_DIR` が worktree になり `HOOK_ROOT == cwd` で §2 が想定する経路を一切踏まない）。worktree 側の `10_doing/` にチケットを置いて `workflow-guard` が判定するかを見る（本流を見ていれば「0 枚 → 許可」で何も起きない） | §2 の作業ツリーの解決 |
| — | **ホットパス 5 本の実行時間** | ② の後 | `logs/sh/` は**秒精度**（`logger.sh:54` の `printf '%()T'`）なので 1 秒以内の目安を測れない。**`time bash <script> < wip/tmp/input.json` を各本 10 回**回して測る。`logs/sh/` は「起動した / しなかった」の確認だけに使う。あわせて `post-push-usage-report` を測り **`hc_lock` の陳腐化 60 秒の妥当性**を評価する（こちらは秒スケールなので `logs/sh/` で足りる） | §1 の 1 秒目安・`i0009-60` の閾値 |

**HK-T09 は機械テストであって実登録の破壊試験ではない**: `HK-T09` は「拒否側フックのファイルを削除・構文エラーにしてもラッパーにより `WFx09` の deny になる」を確かめるもので、**一時コピーに対してラッパー文字列を再現して実行する**。実登録の `workflow-guard` を壊すと matcher が `Edit|Write|MultiEdit|NotebookEdit|Bash|PowerShell|EnterPlanMode|Agent|Workflow` なので書き込みも実行も全部 deny になり、**壊したファイルを AI が書き戻せない**（復旧はバックアップからの復元のみ）。実登録での生の確認をどうしても行うなら **`block-chmod` 1 本に限る**（matcher が `Bash|PowerShell` だけなので Edit / Write が生き残り AI が復元できる）。

**T1 と T8 を含めない理由**: §12 の表で両方とも取り消し線つきで「解決（TBD ではない）」と書かれている。T8（`frontmatter.sh` 不在時の案内側の挙動）は機械テスト **`HK-T16`** が「`frontmatter.sh` を隠した環境」で固定するので、実ファイルを `mv` する実測はしない — **`mv` すると `scope_load_ticket` が戻り値 2 を返して拒否側が WF209 に倒れ、戻すための `mv` も止まって自分自身をロックアウトする**（復旧は `WORKFLOW_ENFORCE=0` の新セッションのみ）。**T6** は ⓪ で確認済み。

**5-5 最終検査**: `HK-T01`（17 行のフィクスチャと `settings.json` の行単位の照合。**配列上の位置も**）と `run-tests.sh` の**全件**（`--ids` を付けて ID を確認する。`--ids` は出力の切り替えで実行本数は減らない — 絞るのは `--filter <glob>`）。結果を実装結果報告に記録する（受け入れ条件 2）。全件は約 5 分かかるのでバックグラウンドでファイルに出す。

### ステップ 6: フィードバック計画（0032）

実測の結果と「仕様からの逸脱」を棚卸しし、フェーズ 6（書き戻し）の要否を決める。**実装中に生まれた決定は DDR になっていない**ので、0032 が DDR 化の対象を列挙する。少なくとも次の 3 件は確定で入る:

- `SC_TARGETS` の形（仕様 §8 の `[]` を外す）と `SC_CLASS` の値集合（`write` / `opaque` を §8 の表に足す）
- `.claude/rules/markdown-docs.md` と `ai-asset-authoring.md` の 1:1:1 の整備（フェーズ 6 または #10）
- 4c プローブが必要だったこと（`decisions.jsonl` の 10 キー固定と、`systemMessage` の到達を業務条件から切り離して測れないこと）

### ヘッドレス実行の帰結

- **⓪・①・② の登録は対話セッションでのみ可能**。`settings.json` は `common.confirm` で、② の後はヘッドレスでは WF203 が deny になる（§10）
- `config/` 3 ファイルの新規作成は ② より前なので、その時点ではヘッドレスでも通る（`workflow-guard` が未登録）
- T3 の実測は逆に**ヘッドレス実行そのものが対象**なので `claude -p` を 1 回走らせる（① の後・② の前）

### 許可範囲（やってよいこと）

チケットごとに最小で絞る。`types.ai-asset-implementation.allow` / `.ops` の内側。

| チケット | `allow.write` | `allow.ops` | 備考 |
|---|---|---|---|
| 0027 | `.claude/hooks/**` `.claude/skills/**` | `read` `remote-read` `hook-test` `build-test` | `.claude/rules/**` は扱わないので外す。`settings.json` も触らないので外す |
| 0028 | `.claude/hooks/**` `.claude/settings.json` | 同上 | 登録後のコミットで `settings.json` が対象になる |
| 0029 | `.claude/hooks/**` | 同上 | |
| 0030 | `.claude/hooks/**` | 同上 | |
| 0031 | `.claude/hooks/**` `.claude/settings.json` `.claude/skills/20-common-step-shell-script/**` | 同上 | 登録後のコミットと、テスト補助の調整のため |
| 0032 | `wip/**`（実効は `common.allow`。`types.feedback-plan` に `allow` が無いので `d.write ∩ types.allow` は空で、§8 判定順 (5) により `common.allow` のまま） | `read` `remote-read` | 計画書・チケットは `common.allow` |

- **`.claude/settings.json` を書くのは人間**。宣言に入れているのは登録後のコミットの対象になるためで、AI が Edit / Write で触ることはしない
- `.claude/docs/**` は `types` の `deny` にあり、宣言に書いても通らない

## 検証

| # | 受け入れ条件（issue #9） | この計画が満たす形 | 検証 |
|---|---|---|---|
| 1 | フック本体 11 本が仕様どおり動きテストが通る | 0027（1 本）+ 0029（6 本）+ 0030（4 本）+ 各テスト | `run-tests.sh --ids` の全件（`boundary.sh` 依存の 10 件を除く） |
| 2 | `settings.json` への登録手順と登録後の全件・HK-T01 | 0028（⓪）+ 0031（①②）。手順はステップ 2・5-1 | HK-T01（位置まで照合）と全件の結果を実装結果報告に記録 |
| 3 | TBD T1〜T4 の検証結果が仕様に反映され DDR に残る | 0031 の実測 → 0032 が書き戻しの要否を決定 → フェーズ 6 | 共通仕様 §12 の該当行の消滅（フェーズ 6）。**T5 も含めて §12 を空にする** |
| 4 | `HOOK_DENY_ID` の既定と 2 枚以上をテストで固定 | 実装の型（`HOOK_DENY_ID` の代入 → source → `hook_init`）を 11 本で統一（0027 で確立） | `WG-T*`（WF207）と `HK-T09` |
| 5 | `tool_response` / `agent_type` / `web` の強制 / `defer` | `web` は 0027（`scope.sh`）。残りは 0031 の実測（プローブ） | 実測表（5-4）+ フェーズ 6 の書き戻し |
| 6 | 仕様との食い違いを書き戻し DDR に残す | 各チケットの作業ログ「仕様からの逸脱」→ 0032 の棚卸し | 0032 の棚卸し表 |

**この計画自身の検証**: 計画書 `.md` と HTML ビューが揃い `check-html.sh` が OK を返すこと。チケット 6 枚が `00_todo/` にあり `predecessors` と `allow` が上表と一致すること。

## チケット

| 番号 | 種類 | 内容 | 先行 | 人間レビュー | 敵対的レビュー |
|---|---|---|---|---|---|
| 0027 | `ai-asset-implementation` | lib 3 本の改修 / `config` 3 ファイル / 読み込み行 20 本 / `block-chmod` | なし | 要 | 要 |
| 0028 | `ai-asset-implementation` | ⓪ `block-chmod` 単独登録（人間）と **T6 の確認**。終了方式の確定 | 0027 | 要 | 不要 |
| 0029 | `ai-asset-implementation` | 案内側 6 本とテスト + **4c プローブ**の仕込み | 0027 | 要 | 要 |
| 0030 | `ai-asset-implementation` | 拒否側の残り 4 本とテスト | 0028, 0029 | 要 | 要 |
| 0031 | `ai-asset-implementation` | 段階登録 ①②（人間）+ **4c の実測 10 項目** + プローブの除去 + HK-T01 + 全件 | 0030 | 要 | 要 |
| 0032 | `feedback-plan` | 実測結果と逸脱の棚卸し、フェーズ 6 の要否 | 0027〜0031 | 要 | 不要 |

実行者は全体計画の方針（全種類メインエージェント。※1 — サブエージェントの起動テンプレートが 3/3 で未実装、かつこの issue が実行者を検査するフックを作るため）に従う。人間レビューは承認④により opus の敵対的自己レビューで代替する。

- **`work-defaults.md` の既定との差分**: `ai-asset-implementation` の既定は「サブエージェント（opus）/ 人間レビュー要 / 敵対的レビュー要」。**実行者だけ**がメインエージェントに変わる。0028 は「中核を含まず判定が 1 つで実測が根拠」なので敵対的レビューを**不要**に下げる

## リスクと復旧

**ロックアウトの復旧手段の使い分け**（全体計画「切り戻し」の 2 分類を維持する）:

1. **1 本のフックの判定が誤って deny を出す** → `WORKFLOW_<NAME>_ENFORCE=0` を設定した**新しいセッション**（`block-chmod` なら `WORKFLOW_BLOCK_CHMOD_ENFORCE=0`。§4 の命名規則）
2. **複数が同時に deny を出す / 原因が絞れない** → `WORKFLOW_ENFORCE=0` の新しいセッション
3. **フック本体が起動できない（ラッパーの `WFx09`）** → **環境変数は効かない**。登録前のバックアップからの復元（人間）だけが経路。**復元したら、直してから登録し直し、HK-T01 と全件を通してからコミットする**（復元したままだと `push.sh` の項目 1 で CP005、部分登録のままコミットすると HK-T01 が落ちる）

| リスク | 影響 | 対処 |
|---|---|---|
| **⓪ でロックアウトする**（`block-chmod` の判定が広すぎて全 Bash が deny） | 作業不能 | ラッパーを付けないので上記 1 で必ず戻れる。加えて登録前に `bash <script> < 入力 JSON` を手で通す |
| **② でロックアウトする**（拒否側 4 本 + ラッパー） | 作業不能 | 判定バグなら上記 1・2、起動不能なら上記 3。登録前に 4 本とも単体実行 + `bash -n` + `shellcheck`。**1 行ずつ足して各行の後に軽い操作を通す** |
| **T6 が外れる** | `exit 2` + stderr への切り替え | ⓪ で 1 本だけ書いた段で分かるので手戻りは `hook-common.sh` の出力ヘルパと `block-chmod` に閉じる |
| **T9 が外れる**（`systemMessage` が表示されない） | 登録表を 16 行へ戻す。PreToolUse `Agent` 登録が意味を失う | ① の後にプローブで確かめる。外れたら HK-T01 のフィクスチャを 16 行に直し §1 の書き戻しをフェーズ 6 へ |
| **4c プローブを取り除き忘れる** | 本番のフックが余計な出力と記録を続ける | 0031 の DoD に「取り除いたこと」と「取り除いた後に全件が通ること」を入れる。プローブは環境変数でしか有効にならないので既定では無害だが、コードは残さない |
| **② の後に実測用のコマンドが WF204 / WF205 で止まる** | 実測が進まない | 5-2 のとおり ① の後・② の前に済ませる。どうしても ② の後なら `WORKFLOW_GUARD_ENFORCE=0` の新セッション |
| **PreToolUse の配列上の位置がずれる** | HK-T01 が落ちる | 各段で配列の**全文**を AI が提示し、人間は貼り替えるだけにする |
| **worktree の実測で上向き探索が効かない** | worktree でフックが無効のまま | 効かなければ「worktree では機構を使わない」運用に倒し、フェーズ 6 で §2 を書き直す |
| **`hc_lock` の 60 秒が短すぎる** | 使用量の集計が壊れる | 0031 で実行時間を実測し妥当性を作業ログに残す。外れたら値と `HK-T20` の期待値を直す |
| **読み込み行の一斉置換で 1 本でも取りこぼす** | `SS-T05` が落ち続ける | `grep -rl` の一覧をチケットに固定し、置換後に**もう一度 `grep` して差分 0** を確かめる |
| **フェーズ 7 が通らない** | マージ前作業で詰む | 第 1 案（`WORKFLOW_STATE_GUARD_ENFORCE=0` の新セッション）。フェーズ 7 の直前に人間と最終確認 |
| **全件テストが約 5 分かかる** | 反復が遅い | 0031 ではバックグラウンド実行でファイルに出す。個別チケットでは **`--filter '<glob>'`** で対象を絞る（`--ids` は ID の確認に併用する） |

## スコープ外

- `.claude/docs/**` への書き戻し（フェーズ 6）と DDR の作成
- 提供コマンドの実体の変更（`push.sh` の 1 枚目依存は #10 への申し送り 2）
- `boundary.sh` / `finalize.sh` の実装と依存する 10 件のテスト観点（申し送り 1）
- `scope-limits.json` の実体変更（変更不要と確認した）
- `.claude/rules/markdown-docs.md` / `ai-asset-authoring.md` の新規作成（要件書が `.claude/docs/**` に無く実装フェーズでは 1:1:1 を作れないため。0032 へ）
- `.claude/agents/task-executor.md` の実装（T9 はプローブで代替する）
- `PostToolUseFailure` / `PermissionRequest` / `PreCompact` と空ディレクトリ 3 つ（申し送り 5）
- `WebFetch` / `WebSearch` の強制（§13 の意図的な緩和）
- マージ（人間）

## 保留した点 / 対象なし

| 項目 | 決める時期 |
|---|---|
| `hc_lock` の陳腐化 60 秒を変えるか | 0031 の実行時間の実測後 |
| 読み込み行の 3 段目（`git rev-parse`）を残すか外すか | **残す**と決めた（外すと相対パス起動かつ `CLAUDE_PROJECT_DIR` 無しの経路が解決不能）。実装で例外が出たら 0032 へ |
| `SC_TARGETS` の形と `SC_CLASS` の値集合を仕様と実体のどちらに寄せるか | 実体（US 区切り / `write`・`opaque` を含む）で統一し、**仕様 §8 の書き戻しは 0032** |
| 副入力 `HC_LIMITS` の形（区切りバイトの割り当てと全 type 射影） | **0027 の最初に決める**（ステップ 1-2）。ここが 0027 で唯一「やってみないと形が決まらない」箇所 |
| `.claude/rules/markdown-docs.md` と `ai-asset-authoring.md` の整備 | 0032（フェーズ 6 または #10。実装フェーズでは 1:1:1 を作れない） |
| T5 が #6 で既に解決済みか | 0031（#6 の作業ログと DDR を読み、済みなら §12 の行の削除を書き戻し対象にする） |
| フェーズ 6（書き戻し）の要否と範囲 | 0032（`feedback-plan`） |
| 実行者を既定のサブエージェントに戻す時期 | #10（3/3）の全体計画（申し送り 4） |
| フェーズ 7 を通す手の最終確認 | フェーズ 7 の直前（第 1 案を既定として確定済み） |

**対象なし**: `src/**` の変更（この issue はソフトウェアではなく AI アセットが対象）。
