---
type: report
title: 0007 調査結果 — 公式 hooks リファレンスとの照合・T5 の扱い・クォート付き git の判定
description: フック共通仕様 §2・§8・§12 が前提にしている入力・出力フィールド 8 項目を公式ドキュメントで確かめ、model フィールドの不在・defer の実在・tool_response の記載なし・matcher による web の強制可否を判定し、あわせて §12 T5 が #6 でどこまで解決したかと、クォートで割った git のサブコマンド判定の穴を確認した調査結果
tags: [report, investigation, issue-9]
keywords: [公式リファレンス, SubagentStart, model, agent_id, agent_type, defer, permissionDecision, tool_response, matcher, WebFetch, T5, PowerShell, cmdpos, git commit]
---

# 0007 調査結果 — 公式 hooks リファレンスとの照合・T5 の扱い・クォート付き git の判定

## サマリ

仕様が前提にしている 8 項目のうち **5 項目は公式ドキュメントと一致**し、**1 項目は明確に相違**、**2 項目は記載が見つからなかった**。相違は `subagent-start-check` の要である **`model` フィールド**で、公式は「`model` を受け取れるのは `SessionStart` フックだけ」と明記している。したがって WF801（実行者の不一致）を SubagentStart の入力から判定する設計は成立せず、仕様が用意していた縮退（PostToolUse `Agent` の `tool_input.model` と比較）を既定にする判断が要る。一方 `SubagentStart` イベント・`agent_id` / `agent_type`・`permissionDecision: "defer"` は実在が確認でき、matcher は tool 名の完全一致または正規表現なので **`WebFetch` / `WebSearch` を強制対象にできる**（D3 の判断材料）。`tool_response` の構造は公式に記載が無く、T7 は実測に回す。あわせて §12 **T5 は #6 で「文書上は前提どおり、実機確認は未了」**と結論づけられており、この issue の登録直後に確かめる申し送りがあることを確認した。**`git 'commit'`（クォートで割ったサブコマンド）は、現状の仕様どおりに実装すると bash 経路で素通りする**。

- ◎良 4 件 / △注意 4 件 / ✕問題 1 件

### ◆特に見てほしい（判断に困っている）

- **f2**: `model` は `SubagentStart` の入力に含まれない（公式は `SessionStart` のみと明記）。`subagent-start-check` の WF801 は仕様の縮退案（PostToolUse `Agent` の `tool_input.model` とチケットの `executor` を事後に比較）へ切り替える必要がある。§12 T4 の「実在する」という前提を書き換える設計判断

### ◇承認が欲しい（方針は決めた）

- **f3**: `defer` は実在するが**機構では使わない**（クエリを終了して後で再開する用途で、フックの拒否・確認とは目的が違う）。§12 T3 の「`defer` の採用は別途判断」に対する答えとして「採用しない」を仕様に書く
- **f5**: `WebFetch` / `WebSearch` は matcher に書ける（技術的な障害なし）。D3「`web` の強制の可否」は**強制する / しない**の方針判断だけが残る
- **f8**: T5 は #6 の申し送りどおり、この issue の登録直後に `decisions.jsonl` の `tool: PowerShell` で確認する（実装フェーズ 4c の検証項目に追加）
- **f9**: `git 'commit'` は bash 経路でも「特定できない」として拒否側に倒す（共通仕様 §7-9 の記述に合わせて `block-direct-git` の制御方式を補う）

### ・細かいレビューは不要（ほぼ確実）

- **f1**: `SubagentStart` の実在と `agent_id` / `agent_type`（仕様どおり）
- **f4**: `tool_response` の構造は公式に記載なし（T7 は実測へ。仕様の「4 候補を順に読む」を維持）
- **f6**: 仕様に無いイベントが 7 種類ある（拡張の余地。この issue では扱わない）
- **f7**: `exit 2` は JSON より優先する（T6 の裏付け）

## 確かめられなかったこと（この結果が言っていないこと）

- `tool_response` の実際のフィールド名（公式に記載が見つからず、**実測はフェーズ 4c**）
- `Stop` / `SubagentStop` / `PostToolUse` / `SubagentStart` の**完全な入力スキーマ**。公式ページの該当節が取得できた範囲に含まれず、SDK 側のドキュメントから断片（`stop_hook_active`・`last_assistant_message`・`agent_id`・`agent_type`）を確認したにとどまる
- `permissionDecision: "deny"` + 終了 0 が**実機で**確実に効くか（§12 T6。公式の例と exit 2 の説明から「効く」と読めるが、実測はフェーズ 4b）
- ドキュメントのバージョンと実行中の Claude Code のバージョンの一致（公式ページに版の記載が無い）
- `git 'commit'` の実挙動（`cmdpos.sh` を実行して確かめてはいない。コードと `HK-T05` の期待値からの読み取り）

## 実施条件（読んだ対象）

- 公式: `https://code.claude.com/docs/en/hooks`（`https://docs.claude.com/en/docs/claude-code/hooks` から 301 リダイレクト）、`https://code.claude.com/docs/en/hooks.md`、`https://code.claude.com/docs/en/agent-sdk/hooks`（2026-09-02 取得）
- リポジトリ: `.claude/docs/10_spec/フック共通仕様.md` §2・§7・§8・§12、`.claude/hooks/lib/cmdpos.sh`、`.claude/hooks/lib/tests/test_cmdpos.sh`
- #6 の履歴: コミット `bb2a527`（`wip/30_reports/0003-investigation.md` の Q3 = T5 の節）
- 実行はしていない（Web 閲覧と `git show` / `grep` のみ）

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

結論: §12 T4 の前提「`SubagentStart` イベントと `model` / `agent_id` フィールドの実在」は、**`model` について外れる**。設計で (a) WF801 を PostToolUse `Agent` 経由の事後通知に一本化する（仕様の縮退案）、(b) SubagentStart では `model` があれば使い、無ければ通知しない（現行の「`model` が無い版では比較しない」を既定にする）のどちらかを選ぶ。**(a) と (b) は排他ではなく、(b) を残したまま (a) を足すのが確実**。

### f3. `permissionDecision: "defer"` は実在するが、機構では使わない ◎良

根拠: Agent SDK hooks ドキュメント「For `PreToolUse` hooks, this is where you set `permissionDecision` (`"allow"`, `"deny"`, `"ask"`, or `"defer"`)... If you return `"defer"`, the query ends so you can resume it later.」「`deny` takes priority over `defer`, which takes priority over `ask`, which takes priority over `allow`.」

- 値の集合は **`allow` / `deny` / `ask` / `defer`** の 4 つで確定。優先順位も明文化されている（`deny` > `defer` > `ask` > `allow`）
- `defer` は「クエリを終了して後で再開する」ためのもので、SDK が入力を集め直す用途。フックが「判断を保留する」意味ではなく、**機構が使う場面は無い**（拒否は `deny`、確認は `ask`、ヘッドレスでは `ask` を `deny` に置き換える現行方針で足りる）
- 補足: `updatedInput` を `defer` と併用すると入力が捨てられる（公式が明示）。機構は `updatedInput` を使わないので影響なし
- 実測への依存: 無し

結論: §12 T3 の「`defer` の採用は別途判断」に対する答えは **「採用しない」**。理由（用途が違う・優先順位が `deny` の下）を仕様に 1 行書いて TBD を閉じられる。

### f4. `tool_response` の構造は公式に記載が無い △注意

根拠: 公式 hooks リファレンス（`PostToolUse` の節が取得できた範囲に含まれず、`PreToolUse` の入力例のみ提示）、Agent SDK hooks ドキュメント（`tool_response` のフィールド定義なし）

- 3 つの URL（`hooks`・`hooks.md`・`agent-sdk/hooks`）を読んだが、`PostToolUse` の入力例も `tool_response` のフィールド定義も見つからなかった（Web 検索の結果には「`tool_response` は `plan` と `filePath` を持つオブジェクト」という Plan ツール固有の記述があるのみ）
- したがって `exit_code` / `exitCode` / `returnCode` / `code` のどれが実際に来るかは**公式からは決められない**
- 実測への依存: **あり**（§12 T7。フェーズ 4c で `logs/` に落として実物を見る）

結論: 仕様の現行方針（4 つの候補を順に読み、どれも無ければ 0 とみなす。`interrupted: true` は失敗）を**そのまま維持**する。実測後に 1 つへ絞る。

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

### f6. 仕様に無いフックイベントが 7 種類ある △注意

根拠: 公式 hooks リファレンスのイベント一覧

- 仕様（§1）が扱う 7 イベント（SessionStart / UserPromptSubmit / PreToolUse / PostToolUse / SubagentStart / SubagentStop / Stop）のほかに、公式には **`PostToolUseFailure` / `PostToolBatch` / `PreCompact` / `PostCompact` / `PreModelSwitch` / `PostModelSwitch` / `PermissionRequest` / `PermissionDenied` / `Notification` / `SessionEnd`** がある
- このうち機構に効きそうなのは 2 つ:
  - **`PostToolUseFailure`**（ツール呼び出しが失敗したとき）: `post-push-*` が「終了コード 0 か」を `tool_response` から読む代わりに、失敗はこのイベントで分けられる可能性がある
  - **`PermissionRequest` / `PermissionDenied`**: 機構のディレクトリには `21-PermissionRequest/` が用意されているが、§1 の登録表にフックは無い（空のまま）
- 実測への依存: 無し

結論: この issue では**扱わない**（issue #9 のスコープは 11 本）。`PostToolUseFailure` の活用と `21-PermissionRequest/` の空ディレクトリの扱いは、3/3 または別 issue の検討事項として残す。

### f7. `exit 2` は JSON より優先し、PreToolUse をブロックする ◎良

根拠: 公式 hooks リファレンス「exit 2 means a blocking error. On events that can block, exit 2 blocks whether or not you print JSON: even a JSON `permissionDecision` of `"allow"` can't override it.」「`PreToolUse` | Yes | Blocks the tool call」「On `PreToolUse`, a hook canceled at its timeout blocks the tool call.」

- `exit 2` は JSON 出力より強く、`PreToolUse` ではツール呼び出しをブロックする。公式の例（`block-rm.sh`）は `permissionDecision: "deny"` の JSON を返す形で、**JSON による deny も正規の経路**として示されている
- したがって §12 T6（`permissionDecision` + 終了 0 の deny が効くか）は「効く」方に大きく傾く。ただし公式は「JSON deny が効く」と明示的に書いてはおらず、例示にとどまるので**実測は残す**
- 副次的に分かったこと: **フックがタイムアウトで打ち切られると PreToolUse ではツール呼び出しがブロックされる**。fail-closed ラッパー（§1）と同じ方向で、機構の安全側に働く
- 実測への依存: **あり**（T6 の最終確認はフェーズ 4b の ②-1）

結論: 段階登録 ②-1 で T6 を確かめる段取りはそのままでよい。外れた場合の縮退（`exit 2` + stderr）も公式が保証しているので、手戻りの内容は「11 本の終了方式の書き換え」に限られる。

### f8. §12 T5 は #6 で「文書上は前提どおり・実機確認は未了」と結論づけられていた △注意

根拠: `git show bb2a527 -- wip/30_reports/0003-investigation.md`（#6 の調査結果 Q3）

- #6 の結論: 「`tool_name` は `"PowerShell"`。`tool_input` のキーは `command` / `timeout` / `run_in_background` で **Bash ツールと同じ構造**」（出典は公式の tools-reference）。**T5 の結論は「前提どおり」**
- ただし**実機確認は行われていない**: 「一時フック `wip/tmp/dump-hook-input.sh` を `.claude/settings.json` に登録しようとしたが、auto モードの分類器が `settings.json` への書き込みを拒否した。迂回はしない」「実機確認は 2/3 でフックを正式に登録した直後の最初の PowerShell ツール呼び出し（`decisions.jsonl` に `tool: PowerShell` が残る）で自然に得られるので、**2/3 のテスト観点（HK-T05 の PowerShell ケース）に含める**」
- したがって §12 に T5 の行が残っているのは正しく、**この issue で閉じる**のが申し送りどおり
- 実測への依存: **あり**（フェーズ 4c。登録直後の PowerShell 実行 1 回で足りる）

結論: T5 は「文書上は解決済み・実機確認をこの issue で行う」。実装フェーズの検証項目に **T5**（`decisions.jsonl` に `tool: PowerShell` の行が残り、`tool_input.command` が Bash と同じ形で読めること）を 1 行足す。

### f9. `git 'commit'` は bash 経路では素通りする（仕様の穴）△注意

根拠: 共通仕様 §7-9、`block-direct-git` 仕様 制御方式 3、`cmdpos.sh:324`（`gitlike` の条件）、`test_cmdpos.sh:226`（HK-T05 の期待値）

- 共通仕様 §7-9 は「`CP_SUBCMD[i]`（第 1 サブコマンド。…**クォートで割った語（`git 'commit'`）は `_` になり、呼び出し側は「特定できない」として扱う**）」と定める
- `cmdpos.sh` の実装もそのとおり: `git 'commit'` は `exe=git` / `subcmd=_`。`CP_GITLIKE` は**実行体が `_` のときだけ** 1 になる（`'git' commit` は gitlike=1、`git 'commit'` は gitlike=0）
- ところが `block-direct-git` の制御方式 3 で「サブコマンドが特定できないときに拒否側に倒す」と書いてあるのは **PowerShell の入力についてだけ**。bash 経路には `subcmd == "_"` の規定が無く、`opaque` でもないため、**現状の仕様どおりに実装すると `git 'commit'` は許可される**
- issue #9 の詳細 D2 は「`git 'commit'` のようにクォートで割った語のサブコマンドが `_` になる制約（`block-direct-git` は『特定できない』として扱う）」と申し送っており、**「特定できない = 拒否側に倒す」という意図**と読める
- 実測への依存: 無し

結論: `block-direct-git` の制御方式 3 に「実行体が `git` で第 1 サブコマンドが `_`（特定できない）→ **deny WF403**」を bash 経路にも足すのが、§7-9 と D2 の意図に沿う。副作用として `git '状態確認用のエイリアス'` のような正当な用法も止まるが、`git status` などクォートしない書き方に言い換えれば通るため実害は小さい（WF403 のメッセージが言い換えを案内する）。テストは BG-T01 に 1 ケース足す。

## 検証の結果

| # | 仕様の前提 | 公式の記載 | 判定 |
|---|---|---|---|
| 1 | `SubagentStart` イベントの実在 | 「When a subagent is spawned」。matcher は agent type | **一致** |
| 2 | `SubagentStart` の入力に `model` | 「Only `SessionStart` hooks can receive a `model` field」 | **相違**（f2） |
| 3 | `agent_id` | サブエージェント内で入る。SubagentStart / SubagentStop では必須 | **一致** |
| 4 | `agent_type` | 同上。値はエージェント名（`"Explore"` 等） | **一致** |
| 5 | `permissionDecision: "defer"` の実在 | `allow` / `deny` / `ask` / `defer` の 4 値。`defer` はクエリを終了して後で再開 | **一致**（採用しない） |
| 6 | `tool_response` の終了コードのフィールド名 | 記載が見つからない | **記載なし**（f4） |
| 7 | `Stop` の入力（`stop_hook_active`） | SDK の例に `stop_hook_active` / `last_assistant_message` | **一致**（完全なスキーマは未取得） |
| 8 | matcher が `WebFetch` / `WebSearch` を対象にできるか | matcher は tool 名の完全一致 or 正規表現 | **一致**（f5） |
| — | §12 T5（PowerShell の入力） | #6 で文書上は解決・実機未確認 | この issue の 4c で確認（f8） |
| — | `git 'commit'` の扱い | §7-9 は「特定できない」、block-direct-git は PowerShell だけ規定 | **仕様の穴**（f9） |

## 設計への反映

1. **WF801 の判定経路**（f2）: `SubagentStart` の `model` に依存しない形へ。仕様の縮退（PostToolUse `Agent` の `tool_input.model` と `executor` の比較）を本線にし、§2・§12 T4・`subagent-start-check` 仕様の制御方式 4 を書き換える
2. **`defer` を採用しない**（f3）: §12 T3 に「`defer` は用途が違うため採用しない」と結論を書いて TBD を閉じる
3. **`web` の強制の可否**（f5 / D3）: 技術的には可能。強制する場合は §1 の登録表に `WebFetch|WebSearch` の行を足し、`scope.sh` の `web` 分類を PreToolUse で判定する。しない場合は §8 の「機構は強制せず宣言は意図の記録」を確定文にする
4. **`tool_response` は実測待ち**（f4）: 現行の 4 候補読みを維持し、§12 T7 は残す
5. **T5 を実装フェーズの検証項目に追加**（f8）: 登録直後の PowerShell 実行 1 回で確認する
6. **`git 'commit'` の穴を塞ぐ**（f9）: `block-direct-git` の制御方式に bash 経路の `subcmd == "_"` → WF403 を足し、BG-T01 にケースを追加
7. **仕様に無いイベント**（f6）: この issue では扱わない。`PostToolUseFailure` と `21-PermissionRequest/` の空ディレクトリは 3/3 の検討事項として残す

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 公式ドキュメントで 8 項目すべてに白黒が付く | 5 項目は確定したが、`tool_response` と完全な入力スキーマは記載が見つからなかった（ページが長く、取得できる範囲に該当節が含まれない） | f4 として「記載なし」を明示し、T7 を実測に残した |
| `model` は「無い版がある」程度の話 | 公式が「`SessionStart` だけが受け取れる」と明記しており、`SubagentStart` では**構造的に来ない** | f2 を ✕問題にし、WF801 の設計変更を設計への反映の 1 番目に置いた |
| `defer` は採否を実測で決める | 用途（クエリを終了して後で再開）が明文化されており、実測を待たずに「採用しない」と決められた | f3 として TBD を閉じる提案にした |
| `git 'commit'` は仕様どおりに実装すれば拒否される | 共通仕様 §7-9 は「特定できないとして扱う」と書くが、`block-direct-git` は PowerShell 経路にしか規定が無く、bash では素通りする | f9 として設計への反映に挙げた |

## 残課題

- `tool_response` の実フィールド名（T7）と `Stop` / `SubagentStop` / `PostToolUse` の完全な入力スキーマ。公式ページの該当節を取得できなかったため、**フェーズ 4c の実測で確かめる**
- ドキュメントの版と実行中の Claude Code の版の対応。matcher の評価規則やイベントの追加は版に依存し得るが、公式ページに版の記載が無い
- `WebFetch` / `WebSearch` を強制対象にした場合、`scope.sh` の `web` 分類が PreToolUse の入力（`tool_name` だけでコマンド文字列が無い）で判定できるか（`scope_classify` はコマンド列を前提にしている）。設計で確かめる
- `PostToolUseFailure` を使うと `post-push-*` の終了コード判定を簡略化できる可能性。3/3 の検討事項
