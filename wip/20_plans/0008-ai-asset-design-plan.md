---
type: plan
title: 0008 AI アセット設計計画 — 実測を待たずに決められる 16 件を 4 枚の設計チケットに割り付ける
description: 調査結果 0005〜0007 が挙げた設計への反映 19 項目と issue #9 の申し送り（G7・G8・D3・D5・D6）を突き合わせ、実測に依存しない 16 件の決定を「拒否側フック 4 本 / 案内側フック 5 本 / フック共通仕様の横断 / 共通ライブラリと提供コマンド」の 4 枚の設計チケットに割り付ける計画
tags: [plan, ai-asset-design-plan, issue-9]
keywords: [AI アセット設計計画, フック共通仕様, HOOK_DENY_ID, WF801, tool_response, defer, timeout, web の強制, G8, SS-H, boundary.sh, DDR]
---

# 0008 AI アセット設計計画 — 実測を待たずに決められる 16 件を 4 枚の設計チケットに割り付ける

- 対象 issue: [#9](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9)
- PR: [#12（draft）](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/12)
- ブランチ: `feature-9-hook-bodies-settings`
- チケット: 0008-ai-asset-design-plan
- 起点: 調査結果 `wip/30_reports/0005-investigation.md` / `0006-investigation.md` / `0007-investigation.md`（2 巡のレビュー反映後）と全体計画のフェーズ 3

## 対象

フェーズ 3（AI アセット設計）で `.claude/docs/` に書く決定の割り付け。対象は**実測に依存しない決定だけ**で、実測（§12 の T1・T2・T5・T6 の最終確認と実物の形）はフェーズ 4c、その結果の書き戻しはフェーズ 5 が要否を決めてフェーズ 6 で行う。

**全体計画からの差分**: 全体計画のフェーズ 4c は T1〜T4 を実測項目に挙げているが、調査（0007）が公式ドキュメントの原本で **T3 の `defer` の側と T4 の `model` の側を解決した**ため、この 2 つはフェーズ 3 で閉じる。T3 のもう一方の問い（「`claude -p` を入力から判別できるか」）は実測が要るのでフェーズ 4c に残す。

起点の内訳:

- 調査結果の「設計への反映」: 0005 が 5 項目、0006 が 2 項目（＋実装計画への申し送り 3 件）、0007 が 8 項目 = **15 項目**
- issue #9 の申し送りのうち全体計画がフェーズ 3 に置いたもの: G7（`HOOK_DENY_ID`）・G8（作業中チケット 2 枚以上）・D2（`tool_response` の実物・案内側の `scope.sh` ポリシー・`git 'commit'` の制約）・D3（`web` の強制）・D5（`ops` 上限）・D6（`shellcheck` の CI）= **6 項目**
- 16 件の導出: 15 + 6 − **3**（調査結果と重複する G7・D2・D3）− **2**（0007 の反映 5「T5 を 4c の検証項目に」と反映 8「仕様に無いイベント」をスコープ外へ）− **1**（D5 と D6 を 1 行 #16 に統合）+ **1**（0007 の反映 4 を「`post-push-*` の成功判定」#6 と「§12 T7 を閉じる」#12 の 2 決定に分割）= **16 件**
- D2 は #1（`git 'commit'`）・#6・#12（`tool_response`）・#13（`scope.sh` のポリシー）の 4 件に展開される
- 0006 の「実装計画への申し送り」3 件は設計チケットに割り付けず、次の計画チケット（`ai-asset-implementation-plan`）に渡す

## この計画で何をするか

### 結論方針

**中核（フック・`settings.json`）の変更は「要」**。根拠:

1. 16 件のうち 6 件がフック共通仕様の中核の定義（**§1 登録表 / §3 制御方式 / §6 識別子台帳 / §8 許可範囲 / §12 TBD**）に触る（`assets/` の置き場 §1・タイムアウト §1・§3・`web` の強制 §8・WF801 の持ち主 §6・`WF009` §6・`defer` §12 T3）
2. とくに **WF801 の判定経路で案 (c)（PreToolUse `Agent`）を採ると、§1 の登録表が 16 行 → 17 行になる**。登録表は `settings.json` に写す元であり、HK-T01（行単位の照合）・全体計画の段階登録の行数割り当て（① 11 行 / ② 5 行）・受け入れ条件 2 が連動する
3. **`tool_response` の終了コード読みをやめる**決定は `post-push-*` 2 本の成功判定を変える。`PostToolUseFailure` を登録する案を採れば、ここでも §1 が 1 行増える

**ロックアウトの可能性**: このフェーズ自体は `.claude/docs/**` しか書かないため無い（`ai-asset-design` の上限は `allow: [".claude/docs/**"]` で、`wip/**` は common の許可）。影響が出るのは**フェーズ 4b の段階登録**で、登録表の行数が変わると全体計画の「① 11 行 → ②-1 1 行 → ②-2 4 行」の割り当てを組み直す必要がある。これは実装計画（次の計画チケット）の入力として明示する。

### 決定の一覧（16 件）

| # | 決定項目 | 由来 | 採る案の見込み | チケット |
|---|---|---|---|---|
| 1 | `git 'commit'` の bash 経路を拒否側に倒す | 0007 f9 / D2 | 制御方式に `subcmd == "_"` → deny WF403 を追加 | 0012 |
| 2 | `workflow-state-guard` の呼出条件に `mcp__.*` を明記 | 0005 f6 | 1 行の追記 | 0012 |
| 3 | G8: 作業中チケットが 2 枚以上のときの扱い | issue G8 | WF207（機構の異常）で拒否。提供コマンド 3 本（`run-tests.sh` / `push.sh` / `ticket.sh next`）側の方針は 0015 | 0012 / 0015 |
| 4 | `entry-skills.txt` を振り分けスキル名の正にする | 0006 f2 | `workflow-entry` がファイルを読み、lib は分類のみ | 0012 / 0015 |
| 5 | WF801 の判定経路（`model` が来ない） | 0007 f2 | (c) PreToolUse `Agent` を本線、(b) を残す | 0013 / 0014 |
| 6 | `post-push-*` の成功判定 | 0007 f4 | 「PostToolUse に来た = 成功」に変える | 0013 / 0014 |
| 7 | `SS-H*` がランナーの ID 正規表現に一致しない | 0005 f3 | (a) `session-start` の接頭辞を変える | 0013 / 0015 |
| 8 | `boundary.sh` 依存テスト 8 本（`session-start` の 7 本 + `workflow-entry` の WE-T10）+ SS-H05 前半の扱い | 0005 f5 | 受け入れ条件 1 の解釈とセットで決める。**WE-T10 は 0012**（`workflow-entry` 仕様を持つ側）、残りは 0013 | 0012 / 0013 |
| 9 | `assets/` の基準ディレクトリ | 0005 f4 | §1 に置き場を定義し、**0014 が確定後に個別フック仕様（`workflow-entry` / `subagent-start-check` / `block-chmod`）へ反映する**。0012・0013 はパスを暫定として書く | 0014 |
| 10 | タイムアウト時の fail-open | 0007 f7 | §1 に `timeout` の既定、§3 に「打ち切りは fail-open」を明記 | 0014 |
| 11 | `defer` を採用しない | 0007 f3 | §12 T3 を閉じる | 0014 |
| 12 | §12 T7（`tool_response` の終了コード）を閉じる | 0007 f4 | 「フィールドは存在しない」で閉じる | 0014 |
| 13 | §12 T8（案内側の frontmatter 読み込み）の縮退 | 0006 f3 | `scope.sh` を `nop` にし、呼び手が失敗ポリシーを決める | 0014 / 0015 |
| 14 | D3: `web` の強制の可否 | 0007 f5 | 強制しない（§8 の「宣言は意図の記録」を確定文にする）を既定案とする | 0014 |
| 15 | G7: `HOOK_DENY_ID` の既定 `WF009` | 0005 f2 | 台帳に `WF009` を登録（最小の変更） | 0014 / 0015 |
| 16 | D5: `investigation` 以外の `ops` 上限 / D6: `shellcheck` の CI | issue D5・D6 | 方針まで（`scope-limits.json` と CI 設定は変えない） | 0015 |

「採る案の見込み」は計画時点の見立てで、決定は各設計チケットが行う。見込みと違う案を採る場合はチケットの作業ログに理由を残す。

## 対象と範囲

| 決定 | 触る文書 | 根拠 |
|---|---|---|
| 1・2 | `10_spec/hooks/20-PreToolUse/block-direct-git.md`（制御方式・テスト観点 BG-T01）、`.../workflow-state-guard.md`（呼出条件） | 0007 f9 / 0005 f6 |
| 3 | `10_spec/hooks/20-PreToolUse/workflow-guard.md`（WF207）、`10_spec/skills/20-common-step-ticket.md`・`20-common-step-shell-script.md`・`20-common-step-commit-push.md`（1 枚目しか見ない 3 本） | issue G8。現物確認: **1 枚目しか見ない** = `run-tests.sh:86` の `ticket="${doing[0]}"`・`push.sh:98` の同型・`ticket.sh:334`（`next`）の `DOING_FILES[0]`。**件数で見る** = `ticket.sh:208`（`start` は 1 枚でもあれば TK002）。**完了検査は番号引数で `find_ticket` するので非対称ではない** |
| 4 | `10_spec/hooks/10-UserPromptSubmit/workflow-entry.md`、`10_spec/skills/20-common-step-shell-script.md`（`tool_class`） | 0006 f2 |
| 5 | `10_spec/hooks/12-SubagentStart/subagent-start-check.md`・`13-SubagentStop/subagent-stop-check.md`、`10_spec/フック共通仕様.md` §1・§2・§3・§6・§12 T4 | 0007 f2 |
| 6 | `10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md`・`post-push-usage-report.md`、`フック共通仕様.md` §12 T7 | 0007 f4 |
| 7・8 | `10_spec/hooks/00-SessionStart/session-start.md`（テスト観点）、`10_spec/skills/20-common-step-shell-script.md`（ID 正規表現） | 0005 f3・f5 |
| 9〜15 | `10_spec/フック共通仕様.md` §1・§3・§6・§8・§12、`10_spec/skills/20-common-step-shell-script.md` | 0005 f2・f4、0006 f3、0007 f3・f5・f7 |
| 16 | `00_requirement/自己改善ワークフロー機構.md`（方針）、DDR | issue D5・D6 |

**範囲外**（このフェーズで触らない）:

- `.claude/hooks/**` のスクリプト本体とテスト（フェーズ 4）
- `.claude/settings.json`（人間の操作。フェーズ 4b）
- `.claude/hooks/config/scope-limits.json` の実体（D5 は方針まで。実体変更はフェーズ 4）
- CI 設定（D6 は方針まで。リポジトリ設定の変更に近い）

## 方法とステップ

### ステップ 1: 拒否側フックの判定を決める（0012）

`block-direct-git` / `workflow-state-guard` / `workflow-guard` / `workflow-entry` の 4 本。いずれも「判定順に 1 項目足す / 呼出条件を明記する」レベルで、他の決定に依存しない。要件定義書に外から見える振る舞い（何を拒否するか）、仕様書に判定順・識別子・テスト観点を書く。

### ステップ 2: 案内側フックの判定を決める（0013）

`subagent-start-check` / `subagent-stop-check` / `post-push-compact-prompt` / `post-push-usage-report` / `session-start` の 5 本。WF801 の経路と `post-push-*` の成功判定は**公式の記載で結論が出ている**ので、仕様に落とすのが仕事。`session-start` はテスト ID の接頭辞と `boundary.sh` 依存の扱いを決める。

### ステップ 3: フック共通仕様の横断決定（0014、先行 0012・0013）

§1（登録表と `assets/` の置き場・`timeout`）・§2（`model` の記述）・§3（打ち切り時の fail-open・PreToolUse の通知経路）・§6（`WF009` と WF801 の持ち主）・§8（`web` の強制）・§12（T3・T4・T7・T8 の開閉）。**ステップ 1・2 の決定を受けて書く**ので先行に置く。登録表の行数が変わるかどうかがここで確定する。

### ステップ 4: 共通ライブラリと提供コマンドの仕様（0015、先行 0014）

`20-common-step-shell-script` の要件・仕様: `HOOK_DENY_ID` の既定、`scope.sh` の読み込みポリシー（T8 の縮退）、`tool_class` の役割、`run-tests.sh` の ID 正規表現、G8 の提供コマンド側の方針。D5・D6 の方針と DDR もここ。**§6 台帳と §12 T8 の決定を受ける**ので 0014 を先行に置く。

### 文書一覧と骨子（1:1:1）

| アセット | 要件定義書 | 仕様書 | 骨子 |
|---|---|---|---|
| `hooks/20-PreToolUse/block-direct-git` | `00_requirement/hooks/20-PreToolUse/block-direct-git.md`（更新） | `10_spec/hooks/20-PreToolUse/block-direct-git.md`（更新） | 要件: 「サブコマンドが特定できない `git` の呼び出しも拒否する」を受け入れ基準に追加 / 仕様: 制御方式 3 に bash 経路の `subcmd == "_"` → deny **WF403**、テスト観点 BG-T01 に `git 'commit'` のケースを追加 |
| `hooks/20-PreToolUse/workflow-state-guard` | 同（更新） | 同（更新） | 仕様: 呼出条件に `mcp__.*`（matcher の 3 番目）を明記。判定順は変えない |
| `hooks/20-PreToolUse/workflow-guard` | 同（更新） | 同（更新） | 要件: 「作業中チケットが 2 枚以上は機構の異常として拒否する」/ 仕様: WF207 の判定順の位置（0 枚 → 2 枚以上 → 設定不正）と、提供コマンドが 1 枚目しか見ないことへの注記 |
| `hooks/10-UserPromptSubmit/workflow-entry` | 同（更新） | 同（更新） | 仕様: 振り分けスキル名の正は `entry-skills.txt`。`tool_class` の戻り値は「`Skill` = 分類の候補」に留め、名前の照合は本フックが行う。WE-T07 の期待値を `CLAUDE.md` の表 × ファイルの一致に |
| `hooks/12-SubagentStart/subagent-start-check` | 同（更新） | 同（更新） | 要件: 「起動前に実行者の不一致に気づける」/ 仕様: 制御方式 4 を「`SubagentStart` の入力に `model` は来ない」前提で書き直し、本線を PreToolUse `Agent`（案 c）に。`model` 省略時は比較しない限界を明記。SA-T\* の期待値を更新 |
| `hooks/13-SubagentStop/subagent-stop-check` | 同（更新） | 同（更新） | 仕様: WF801 の「再掲」の位置づけを、案 (c) 採用後の役割（事後の保険）に合わせて書き換える |
| `hooks/22-PostToolUse/post-push-compact-prompt` | 同（更新） | 同（更新） | 仕様: 成功判定を「PostToolUse に来た = 成功」に。`tool_response` の 4 候補読みを削除 |
| `hooks/22-PostToolUse/post-push-usage-report` | 同（更新） | 同（更新） | 同上。`last_assistant_message`（Stop / SubagentStop の固有入力）を使えるかの検討を「代替」に記す |
| `hooks/00-SessionStart/session-start` | 同（更新） | 同（更新） | 仕様: テスト ID の接頭辞を `SS-H*` から変える（案 a）。`boundary.sh` 不在時に通せないテストの扱い（スタブ / 3-3 送り / 偽実装）を決めてテスト観点に反映 |
| フック共通仕様（横断） | — | `10_spec/フック共通仕様.md`（更新） | §1: 登録表の行数（WF801 の案次第で 16 or 17）・`assets/` の置き場・`timeout` の既定 / §2: `model` は SessionStart のみ / §3: 打ち切りは fail-open・PreToolUse の `additionalContext` / §6: `WF009` と WF801 の持ち主 / §8: `web` の扱い / §12: T3・T4・T7・T8 を閉じる |
| `skills/20-common-step-shell-script` | `00_requirement/skills/20-common-step-shell-script.md`（更新） | `10_spec/skills/20-common-step-shell-script.md`（更新） | `HOOK_DENY_ID` の既定 / `scope.sh` の読み込みポリシー（`nop` にした場合の失敗の伝え方）/ `tool_class` の責務 / `run-tests.sh` の ID 正規表現 / G8 の提供コマンド側 |
| `skills/20-common-step-ticket` | 同（更新。G8 の `next` の扱いだけ） | 同（更新） | `next` が `DOING_FILES[0]` を見る前提を「2 枚以上は機構の異常でフックが止める」と明記するか、件数で異常を返すか |
| `skills/20-common-step-commit-push` | 同（更新。G8 の `push.sh` の扱いだけ） | 同（更新） | `push.sh:98` が `doing[0]` の `allow.ops` だけを見る前提を、`ticket.sh` と同じ方針でそろえる |

**新規に作る文書は無い**（11 本のフックとライブラリの要件・仕様は #6 と 2/3 の設計で作成済み）。1:1:1 は既に成立しており、このフェーズは更新のみ。

`assets/entry-skills.txt`・`assets/model-aliases.txt`・`config/blocked-commands.txt` のパスは、0012・0013 では**暫定**として書き、基準ディレクトリを確定した 0014 が個別フック仕様へ反映する。

### 横断整合

| 文書 | 担当 | 更新内容 |
|---|---|---|
| `00_requirement/自己改善ワークフロー機構.md` | 0014（D3）/ 0015（D5・D6） | `web` の強制の可否（D3）の結論、`ops` 上限の考え方（D5）の方針、`shellcheck` の CI 方針（D6）。直列（0015 ← 0014）なので同じ節に同時に触ることはない |
| `00_requirement/rules/ルール体系.md` | 0014 | 変更なしの見込み（ルールの追加・削除が無いため）。0014 が確認して、無ければ「対象なし」と書く |
| `90_glossary/ワークフロー用語.md` | 0014 | 「fail-open」「defer」「実行者の不一致（WF801）」の 3 語を追加するか確認する。`assets/` の基準ディレクトリを定義したら「アセット置き場」の項も |
| `20_ddr/` | 4 枚が分担 | 決定ごとに `i0009-NN`。番号帯を先に割る: **0012 = i0009-01〜04 / 0013 = i0009-05〜09 / 0014 = i0009-10〜15 / 0015 = i0009-16〜19**（衝突を避けるため） |

### ヘッドレス実行の帰結

| アセット | 帰結 |
|---|---|
| `block-direct-git`・`workflow-state-guard` | 拒否側。ヘッドレスでも判定は同じ（deny は確認を伴わない）。変更なし |
| `workflow-guard` | WF207（2 枚以上）は **deny**。`ask` にしない（ヘッドレスでは応答が得られず、確認が拒否に化けるため。既存の §10 の方針どおり） |
| `workflow-entry` | 未宣言は deny。`entry-skills.txt` が読めない場合は「機構の破損」として deny に倒す（fail-closed） |
| `subagent-start-check`・`subagent-stop-check` | 案内側。`model` が特定できないときは**何も出さない**（通知しないだけで、起動は止めない）。ヘッドレスでも同じ |
| `post-push-*` | 案内側。判定できなければ無出力・終了 0。ヘッドレスでも同じ |
| `session-start` | 案内側。`boundary.sh` が無ければ無出力・終了 0。ヘッドレスでも同じ |
| 共通仕様 §3 | **打ち切り（timeout）は fail-open** で、ヘッドレスかどうかに関係なくツール呼び出しが通る。この事実を §3 に書き、`timeout` の設定で緩和する |

### 許可範囲（やってよいこと）

| チケット | write | ops |
|---|---|---|
| 0012・0013・0014・0015 | `.claude/docs/**`（`wip/**` は common で常時許可のため宣言しない） | `read`, `remote-read` |

`ai-asset-design` の上限（`scope-limits.json`）どおり。`types.ai-asset-design.ops` は `["read", "remote-read"]` だけで **`web` を含まない**（`web` を持つのは `investigation` のみ）ので、外部への問い合わせは宣言の裁量ではなく**そもそも許されない**。必要になったら `investigation` チケットを別に起こす。

## 検証

issue #9 の受け入れ条件（原文の 6 条件）に対して、このフェーズが満たす部分を割り当てる。

| # | 受け入れ条件（issue #9 の原文の要旨） | 満たす文書 | テスト ID の予定 |
|---|---|---|---|
| 1 | フック本体 11 本が各仕様の判定順・識別子・終了方式どおりに動き、テスト（HK-T01 / HK-T09 / HK-T03 の登録部分を含む）が失敗ケースを含めて通る | 各フック仕様のテスト観点（0012・0013 が更新） | BG-T01（`git 'commit'` を追加）、SG-T\*、WG-T\*（WF207）、WE-T07・WE-T10、SA-T\*、SP-T\*、PP-T\*、UR-T\*、`session-start` の 9 本（接頭辞を変更） |
| 2 | `settings.json` への登録手順が書かれ、登録後に `run-tests.sh --ids` の**全件**と HK-T01 が通る | フック共通仕様 §1（0014。行数の確定）、`20-common-step-shell-script` 仕様（0015。ID 正規表現） | HK-T01（登録表との行単位の照合。**行数が 16 か 17 かは 0014 で確定**）。`--ids` は**既存の約 60 本と新規 93 本を含む全件**が並ぶことを実装フェーズで確認 |
| 3 | §12 の TBD T1〜T4 の検証結果がフック共通仕様に反映され、経緯が DDR に残っている | T3 の `defer` と T4 の `model` は 0014 が設計で閉じる。T1・T2 と T3 の残り（`claude -p` の判別）はフェーズ 4c → 5 → 6 | — |
| 4 | `HOOK_DENY_ID` の既定と「作業中チケット 2 枚以上」の扱いが仕様（§6・該当フック）に決まり、**テストで固定されている** | フック共通仕様 §6（0014）、`workflow-guard` 仕様（0012）、`20-common-step-shell-script` 仕様（0015） | WG-T\*（WF207 の拒否）、SS-T04（`HOOK_DENY_ID` の既定） |
| 5 | `tool_response` / `agent_type` / `web` の強制 / `defer` の扱いが実物の確認に基づいて仕様に書かれている（扱わないものは理由つきで「扱わない」） | `post-push-*` 仕様と `subagent-stop-check` 仕様（0013）、§8 と §12 T3（0014） | PP-T\*・UR-T\*（成功判定）、SP-T\*（`agent_type`）。`web` と `defer` は「扱わない」の理由を仕様に書く |
| 6 | 実装で判明した仕様との食い違いは仕様書へ書き戻し、経緯を DDR に残している | このフェーズの対象外（フェーズ 5 が要否を決め、フェーズ 6 が実施） | — |
| — | 決定の経緯を DDR に残す（1〜5 に共通） | `20_ddr/i0009-01`〜`i0009-19`（4 枚が分担） | — |

各設計チケットの DoD は次の型で書く（`10-task-ai-asset-design-plan` 仕様）:

- 要件定義書・仕様書がテンプレートに沿って更新されている
- 受け入れ条件 {{X}} が仕様のテスト観点（テスト ID）に落ちている
- 横断文書（`自己改善ワークフロー機構.md`・`ルール体系.md`・`90_glossary/`）と整合している
- 決定の経緯が DDR（割り当てられた番号帯）に残っている
- ヘッドレス実行の帰結が書かれている


## チケット

| 番号 | 種類 | 担当 / 内容 | 先行 |
|---|---|---|---|
| 0012 | `ai-asset-design` | 拒否側フック 4 本（`block-direct-git` / `workflow-state-guard` / `workflow-guard` / `workflow-entry`）。決定 1・2・3・4。DDR i0009-01〜04 | なし |
| 0013 | `ai-asset-design` | 案内側フック 5 本（`subagent-start-check` / `subagent-stop-check` / `post-push-compact-prompt` / `post-push-usage-report` / `session-start`）。決定 5・6・7・8。DDR i0009-05〜09 | なし |
| 0014 | `ai-asset-design` | フック共通仕様の横断決定（§1・§2・§3・§6・§8・§12）。決定 9〜15 と登録表の行数の確定。DDR i0009-10〜15 | 0012, 0013 |
| 0015 | `ai-asset-design` | 共通ライブラリと提供コマンドの仕様（`20-common-step-shell-script` / `20-common-step-ticket`）と D5・D6 の方針。決定 3（提供コマンド側）・4（lib 側）・7（正規表現案の場合）・13・15・16。DDR i0009-16〜19 | 0014 |
| 0016 | `ai-asset-implementation-plan` | 次の計画。0006 の「実装計画への申し送り」3 件（実装の型・T6 を最初に確かめる・実装チケットの分割）と、0014 が確定した登録表の行数を入力にする | 0012, 0013, 0014, 0015 |

実行者・レビュー要否は全体計画の方針（全種類メインエージェント、人間レビューは opus の敵対的自己レビューで代替）に従う。

- **0012〜0015（`ai-asset-design`）**: `work-defaults.md` の既定（サブエージェント opus / 人間レビュー要 / 敵対的レビュー要）からの差分は**実行者だけ**。理由は全体計画の ※1（サブエージェントの起動テンプレートが 3/3 で未実装、かつこの issue が実行者を検査するフックを作るため）
- **0016（`ai-asset-implementation-plan`）**: 既定は敵対的レビュー**不要**だが、全体計画が「中核とロックアウト対策を含むため **要**」に上げている。0016 のチケットはこの方針に従う

## リスクと復旧

| リスク | 影響 | 対処 |
|---|---|---|
| WF801 の案 (c) を採ると §1 が 17 行になり、全体計画の段階登録（① 11 / ②-1 1 / ②-2 4）が崩れる | フェーズ 4b の段取りの組み直し | 0014 で行数を確定し、**実装計画（0016）の入力として明示する**。案 (b) に留めれば 16 行のまま |
| `session-start` のテスト ID の接頭辞を変えると、仕様・テスト・`--ids` の 3 か所がずれる | 受け入れ条件 2 が満たせない | 0013 で仕様を変え、0015 で `run-tests.sh` 側の規約（正規表現の制約）を明記して、実装フェーズで `--ids` に現れることを確認する |
| `scope.sh` の読み込みポリシーを `nop` にすると、`frontmatter.sh` 不在（機構の破損）とチケットの記載不正が区別できなくなる | WF209 と WF211 が混ざる | 0015 で「`scope_load_ticket` の戻り値を 2 値以上にする」か「呼び手が別途ファイルの存在を確かめる」かを決める。決められなければ現状維持（`deny`）に倒し、§12 T8 は閉じずに残す |
| 4 枚が同じ節（§1・§6・§12）に触って衝突する | 手戻り | 横断（§1・§6・§8・§12）は **0014 に一本化**し、0012・0013 は各フック仕様だけを触る。0014 は 0012・0013 を先行に置く |
| DDR の番号が衝突する | 文書の重複 | 番号帯を先に割った（0012 = 01〜04 / 0013 = 05〜09 / 0014 = 10〜15 / 0015 = 16〜19）。余らせてよい |

## スコープ外

- 実測が要る決定（§12 T1・T2・T5・T6 の最終確認、`tool_response` の実物、`agent_type` の実物）。フェーズ 4c
- 実測の結果の仕様への書き戻し。要否はフェーズ 5、実施はフェーズ 6
- `.claude/hooks/**` のスクリプトとテストの作成（フェーズ 4a）
- `.claude/settings.json` への登録（フェーズ 4b。人間の操作）
- `scope-limits.json` の実体変更（D5 は方針まで）と CI 設定（D6 は方針まで）
- 公式の仕様に無いイベント（`PostToolUseFailure` の常用・`PermissionRequest`）と空ディレクトリ 3 つの扱い。3/3 または別 issue

## 保留した点 / 対象なし

| 保留 | いつ決めるか |
|---|---|
| WF801 の案 (c) が §3 の制御方式表に「PreToolUse の通知」を足すだけで成立するか（公式は PreToolUse の `additionalContext` を認めているが、機構の判定順で `workflow-guard` より前に置くかは未定） | 0013 → 0014 |
| `boundary.sh` の最小スタブを作る場合の忠実度（SS-H08 は「本物と同じ判定か」を確かめるテストなので偽実装では代替できない） | 0013 |
| `ルール体系.md` の更新が要るか（現時点では不要の見込み） | 0014 が確認して「対象なし」を明記する |
| `90_glossary/` に足す用語の粒度 | 0014 |
| `PostToolUseFailure` を登録して失敗も捕まえるか（登録表が 1 行増える） | 0014。既定は「登録しない」（`post-push-*` は成功時の案内が仕事のため） |
