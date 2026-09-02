---
type: report
title: 0022 付録 A — 設計ワークの境界レビュー 2 巡目の指摘記録（A1〜A10 / B1〜B17）
description: 承認④に基づき設計ワークの境界で 2 名のレビュアーが出した 2 巡目の指摘 27 件の記録と、追加チケット 0023〜0026 への割り付け
tags: [report, ai-asset-design, issue-9, adversarial-review]
keywords: [敵対的レビュー, 2 巡目, slurpfile, session_id, worktree, background, async_launched, agentId, systemMessage, web, curl, 割り付け]
---

# 0022 付録 A — 設計ワークの境界レビュー 2 巡目の指摘記録

## 実施条件

- 承認④（人間レビューを opus の敵対的自己レビューで代替）に基づき、**設計ワーク（`ai-asset-design`）の境界で 2 巡目**を実施した（1 巡目は `0015-ai-asset-design-appendix-A.md`。ユーザーの指示は「タスクごとに敵対的レビューを最大 2 回」なので**これが最後のレビュー巡**）
- 対象: `git diff 57b860f..HEAD`（チケット 0019〜0022 の差分）
- レビュアー: opus 2 名。観点 A =「決定そのものの妥当性と根拠の実在」、観点 B =「文書間の整合と、閉じたはずのものの取りこぼし」
- レビュアーには**書き込みを禁じ**、公式原本は `wip/tmp/hooks.md` を `grep` で読むよう指示した（WebFetch を使わせない）
- 指摘は **27 件**（A 10 件 / B 17 件）。すべて確信度 0.5 以上（最小は A8・A9・B12 の 0.6）

## メインエージェントによる独自検証

指摘を鵜呑みにせず、**影響度の高いものと根拠が実測に依るもの 12 件**を原本・実体・実行で確かめた。**12 件すべて実在を確認**した（1 巡目と同じく捏造は無い）。

| 指摘 | 確かめ方 | 結果 |
|---|---|---|
| A1 | `printf '{"bad"' > _bad.json; echo '{"a":1}' \| jq --slurpfile lim _bad.json '.a'` を実行 | **確認**。終了 2・stdout は空。不在ファイルも同じ |
| A2 | `workflow-guard.md:32` の参照に `logs/sessions/<session_id>/approvals.json`、`workflow-entry.md:34` に `entry.json`。`grep -c CLAUDE_SESSION wip/tmp/hooks.md` → **0** | **確認**。`session_id` は stdin からしか得られない |
| A3 | `sed -n '594,602p' wip/tmp/hooks.md`「**Worktrees are different.** … `${CLAUDE_PROJECT_DIR}` **stays put** … **`cwd` follows Claude**」 | **確認** |
| A6 | `workflow-state-guard.md:26`（呼出条件）に「置き場宛の書き込みを捕まえるために要る」が残存、`:50`（制御方式 4）は「それ以外の MCP は許可」 | **確認** |
| A8 | `workflow-state-guard.md:47` の元判定は `wip/10_tickets/10_doing/**` の glob。§8 の glob 規則ではディレクトリ自身に一致しない | **確認** |
| A10 | `sed -n '986,990p' wip/tmp/hooks.md \| cat -n` → 988 = UserPromptSubmit、**989 = PreToolUse …「next to the tool result」** | **確認**（1 行ずれ） |
| B1 | `sed -n '1695,1715p' wip/tmp/hooks.md`「`"completed"` for foreground subagents, `"async_launched"` for background subagents. **As of v2.1.198, subagents run in the background by default**」「a background launch **returns immediately**」 | **確認**。影響大 |
| B6 | `grep -n 'ロック\|hc_lock' post-push-usage-report.md` → ロックの規則は 0 件 | **確認** |
| B8 | `20-common-step-shell-script.md:126` の分類表に `web` が無い | **確認** |
| B14 | テスト観点表の並びが `SS-T01`(200) → `T02` → `T03` → **`T05`(203)** → `T04`(204) | **確認** |
| B15 | `wip/tmp/hooks.md:1702`「`agentId` \| string \| Identifier for the subagent run」（`tool_response` 側）。`agent_id` はイベント入力側 | **確認** |
| B17 | 全体計画の保留表 `:155`（D5）・`:156`（D6）が「決める時期」のまま | **確認** |

## 指摘の一覧（観点 A: 決定の妥当性と根拠の実在）

| ID | 確信 | 影響 | 要旨 | 根拠 | 割り付け |
|---|---|---|---|---|---|
| A1 | 0.85 | 高 | `jq --slurpfile` は副入力が壊れていると**呼び出しごと失敗して stdout が空**になる。設定 1 ファイルの破損で `tool_name` すら取れず、WF210 の復旧経路と `i0009-29` のフォールバックが実装できない。`i0009-29` が塞いだロックアウトを `i0009-37` が開け直している | 実測 + `workflow-guard.md:37` / `workflow-state-guard.md:36` | 0023 |
| A2 | 0.8 | 高 | `approvals.json` / `entry.json` のパスは `session_id` に依存し、`session_id` は stdin を解析して初めて分かるので `--slurpfile` に渡せない。`i0009-37` の「残るのは上限設定だけ」は偽で、**0019 f2 の ✕問題は解消していない** | `workflow-guard.md:32`・`workflow-entry.md:34`・`grep -c CLAUDE_SESSION` = 0 | 0023 |
| A3 | 0.75 | 高 | worktree に入ると `${CLAUDE_PROJECT_DIR}` は本流のままなので `HOOK_ROOT` も本流を指し、`workflow-guard` が本流の空の `10_doing/` を見て**0 枚 → 全面許可**になる。0019 が `git rev-parse` を禁じたことで旧仕様より悪化した。要件は worktree を推奨している | `hooks.md:598-601`・`フック共通仕様.md:71`・`hook-common.sh:15-18`・要件 `:163` | 0025 |
| A4 | 0.75 | 中 | `i0009-41` が `curl` の**送信側**（`-T` / `-d @` / `-F` / `-X POST`、`wget --post-file`）を勘定していない。`web` を宣言すれば GitHub API の直接書き込みが通る（改定前は WF204 で閉じていた） | `i0009-41:36`・`workflow-guard.md:55` | 0025 |
| A5 | 0.75 | 中 | 出力先の取得に `cmdpos_operands` は使えない（`-o` が落ちて URL と出力先が区別できない）。`WG-T15` の「`curl <url>` は通る」と食い違う | §7-9 の `cmdpos_operands` の定義・`i0009-41:38`・`WG-T15` | 0025 |
| A6 | 0.8 | 中 | `workflow-state-guard` の呼出条件が「MCP は置き場宛の書き込みを捕まえるために要る」のまま。制御方式 4（それ以外の MCP は許可）と目的が食い違う。理由の「MCP は `file_path` も `command` も持たない」も一般には成立しない断定 | `workflow-state-guard.md:26`・`:50` | 0026 |
| A7 | 0.65 | 中 | `hc_lock` の `mkdir` ロックに陳腐化の回収経路が無い。§3 が自ら「打ち切りでは `trap` が効かない」と書いているので、重い `post-push-usage-report` が打ち切られるとロックが残り、以後の集計が恒久的に止まる | §5・§3・`i0009-38` | 0026 |
| A8 | 0.6 | 中 | 削除の元判定が `wip/10_tickets/10_doing/**` の glob なので、`rm -rf wip/10_tickets/20_done`（ディレクトリ自身）や `rm -rf wip` を拾わない。作業中 0 枚の窓では `workflow-guard` も判定しないので穴が 1 段上に残る | `workflow-state-guard.md:47`・§8 の glob 規則 | 0026 |
| A9 | 0.6 | 低〜中 | 0022 は S9 で**打ち切り**の例外だけを要件に書いたが、`i0009-29` が作ったもう 1 つの例外（設定破損でも既定値で続ける）が要件に無い。「同じ事実が矛盾する場所すべてで揃った」という 0022 の結論と食い違う | 要件 `:151`・`:202`・`workflow-state-guard.md:36` | 0026 |
| A10 | 0.95 | 低 | 0020 報告の引用の行番号 `:988` は UserPromptSubmit の行で、PreToolUse の「next to the tool result」は `:989` | `sed -n '986,990p'` | 0026 |

## 指摘の一覧（観点 B: 整合と取りこぼし）

| ID | 確信 | 影響 | 要旨 | 根拠 | 割り付け |
|---|---|---|---|---|---|
| B1 | 0.75 | 高 | 公式は「**As of v2.1.198, subagents run in the background by default**」「a background launch **returns immediately**」。PostToolUse `Agent` は起動直後に `status: async_launched` で発火するので、`subagent-stop-check` の WF811〜813 は**作業前の作業領域を検査**することになる。`.claude/docs/` に background への言及が 0 件 | `hooks.md:1699`・`:1701`・`:1711` | 0024 |
| B2 | 0.8 | 中 | WF801 の再掲条件が論理的に成立しない（記録が**無い**ときに再掲する、と書いてあるが再掲する元が無い）。縮退時に自分で判定するなら制御方式と入出力にその手順が要る | `subagent-stop-check.md:17`・`:33`・`:38-46` | 0024 |
| B3 | 0.9 | 低 | §6 の採番台帳が「WF801 の再掲は**事後の保険**」のままで、`i0009-31` の決定（縮退時だけ）と食い違う。`i0009-31` の影響にも §6 が無い | `フック共通仕様.md:139`・`subagent-stop-check.md:17` | 0024 |
| B4 | 0.8 | 高 | §12 T4 の「残る検証」「縮退」が `i0009-26` と矛盾（`additionalContext` が届かなければ 16 行に戻す、のまま）。しかも **17 行維持の唯一の支えである `systemMessage` の実測が §12 にも 4c の表にも無い** | `フック共通仕様.md:298`・`subagent-start-check.md:51`・`grep -rn systemMessage wip/00_overall_plan/` = 0 | 0024 |
| B5 | 0.85 | 中 | `i0009-32`（WF801 を `task-executor` に絞る）が仕様だけに入り要件に無い。「仕様書は対応する要件書より先に変えない」に反する | 要件 `subagent-start-check.md:43`・`:46`・`i0009-32:31-33` | 0024 |
| B6 | 0.85 | 中 | `i0009-23` の影響に挙げた `post-push-usage-report` のロックによる直列化が、当該仕様に 1 文字も入っていない。**実際に競合する箇所**（`--accumulate` の加算）が無防備 | `grep -n 'ロック\|lock' post-push-usage-report.md` = 0 | 0026 |
| B7 | 0.8 | 中 | `10-task-investigation-exec` の要件 `:97` と仕様 `:19` に「リポジトリ外への問い合わせ禁止は**機構では強制されない**」が残る。`i0009-41` 以後は偽。横断要件 `:176` の自制リスト先頭も同じ | 要件 `:97`・仕様 `:19`・`i0009-41` の影響 | 0025 |
| B8 | 0.85 | 低 | `20-common-step-shell-script.md:126` の `scope_classify` の分類表に `web` が無い（`SC_CLASS` と `ops` の定義には有る）。「正は 1 箇所」に反する再掲 | `:126` | 0025 |
| B9 | 0.85 | 低 | `workflow-state-guard` の「要件との対応」表が制御方式の繰り下げに追随していない（判定不能は 4 → 5 になったのに表は 4 のまま） | `workflow-state-guard.md:108`・`:50-51` | 0026 |
| B10 | 0.7 | 低 | 制御方式 0 が `notify` を記録すると書くが記録節に `notify` が無い。また番号順では 0 が「停止中 → 許可」の 1 より先に走り、停止中でも記録が出て §3 に反する | `workflow-state-guard.md:36`・`:72`・`フック共通仕様.md:98` | 0026 |
| B11 | 0.7 | 中 | §8 の `scope_load <path>` / `scope_load_approvals <path>` がファイルパスを取る形で、§1 の「`hook_read_input` が 1 回の `jq` で読む」と噛み合わない。実装者がどちらが読むかを推測する | `フック共通仕様.md:52`・`:18`・`:221`・`:223` | 0023 |
| B12 | 0.65 | 中 | ロック失敗時に `parse_errors` を +1 する記述が循環（同じファイルの read-modify-write）。置き場が仕様内で 2 通り。ヘルパ 3 つの契約（戻り値・タイムアウト・切り詰めの責任）が未定義 | `フック共通仕様.md:119`・`:18`・`post-push-usage-report.md:26`・`:77` | 0023 |
| B13 | 0.75 | 中 | 0016 の作業内容が「0012〜0015 の結果報告を読む」のままで、0019〜0022 の申し送り（`command` 文字列 17 行・読み込み行の一斉置換・`systemMessage` の実測）が届く経路が無い。DoD の実測項目に閉じたはずの T1 が残る | `0016-ai-asset-implementation-plan.md:4`・`:25`・`:27`・`:34` | **メインエージェントが直す**（設計チケットは `.claude/docs/**` しか書けない） |
| B14 | 0.95 | 低 | `SS-T05` が `SS-T04` の前に挿入されて表の並びが乱れている（`i0009-45` で直したのと同型を新たに作った） | `20-common-step-shell-script.md:200-204` | 0026 |
| B15 | 0.7 | 低 | `tool_response` のフィールドは `agentId`（camelCase）。仕様は `agent_id` と書いており、照合が常に失敗して縮退扱いになる | `hooks.md:1702`・`subagent-stop-check.md:17`・`:29` | 0024 |
| B16 | 0.6 | 低 | §8 判定順 (1) に「`workflow-state-guard` が**先に**拒否するのでここに来ない」が残る。0019 が同じ文書で禁じた実行順の前提 | `フック共通仕様.md:53`・`:232` | 0026 |
| B17 | 0.6 | 低 | 全体計画の保留表の D5・D6 が `i0009-19` で決着済みなのに「決める時期」のまま（G8 だけ 0022 が更新した） | 全体計画 `:155`・`:156` | 0026 |

## 1 巡目 38 件の閉じ具合（観点 B の報告）

- 閉じたことを確認できた: **31 件**
- 部分的な閉じにとどまるもの: **7 件** — R20（B2・B3）/ R21（B5）/ R22（B6・B12）/ S1（B4）/ S3（B7・B8）/ R6（B11）/ R1（B16）

いずれも「横断仕様では閉じたが、実装される側の個別仕様・要件で閉じていない」という同じ型である。**横断で決めたら個別仕様と要件まで降ろす**という手順が抜けている。

## 追加チケットへの割り付け

| チケット | 主題 | 指摘 | DDR 帯 |
|---|---|---|---|
| 0023 | ホットパスの外部プロセス上限と読み取り経路の再設計 | A1・A2・B11・B12 | `i0009-46`〜`49` |
| 0024 | サブエージェントは既定で background という前提の反映 | B1・B15・B2・B3・B4・B5 | `i0009-50`〜`54` |
| 0025 | worktree の作業ツリーと `web` の送信側・出力先 | A3・A4・A5・B7・B8 | `i0009-55`〜`58` |
| 0026 | 記録・削除・要件・表の整合の掃き残し | A6〜A10・B6・B9・B10・B14・B16・B17 | `i0009-59`〜`62` |
| （なし） | 0016 のチケット本文の是正 | B13 | — |

先行関係は直列（0023 → 0024 → 0025 → 0026 → 0016）。**2 巡目が最後のレビュー巡**なので、これらを反映したら 3 巡目は行わず実装計画へ進む。

## この巡で分かったこと（次の設計への申し送り）

1. **横断仕様で決めた規則が個別仕様に降りていない**のが 7 件中 5 件の型（B5・B6・B7・B8・B3）。DDR の「影響」に挙げた文書を**実際に開いて直したか**を、チケット完了時に機械的に確かめる手段が要る
2. **公式原本の再読で前提が覆る**ことが 2 巡続けて起きた（1 巡目の `tool_response`、2 巡目の background 既定）。取得済みの原本があるのに読み切れていない箇所が残っている
3. **穴を塞ぐ決定が別の穴を開ける**（`i0009-37` が `i0009-29` を、`i0009-41` が送信側を、0019 の `git rev-parse` 禁止が worktree を）。決定のたびに「これで塞がらなくなるものは何か」を 1 行書く枠が要る
