---
type: report
title: "0039 AI アセット実装結果 — フックの段階登録（16 行）とフェーズ 4c の実測"
description: 案内側 11 行・拒否側 5 行を 6 段に分けて人間が settings.json に登録し、各段で軽い操作を通して想定外の deny が無いことを確かめた結果。あわせてフェーズ 4c の TBD 6 件（T2 / T3 / T4 / T5 / T7 / T9）を本物のフックの記録で実測し、T9 が外れたため登録表を 17 行から 16 行へ縮退させた
tags: [report, ai-asset-implementation, issue-9, hooks, settings.json, 段階登録, フェーズ4c]
keywords: [HK-T01, HK-T09, WF109, WF209, WF309, WF409, WF509, WF204, WF205, WF208, WF601, WF814, systemMessage, additionalContext, probe-4c, worktree]
---

# 0039 AI アセット実装結果 — フックの段階登録（16 行）とフェーズ 4c の実測

- 対象 issue: #9 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9
- PR: #12 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/12

## サマリ

**フックを本番の `settings.json` に登録し、機構が自分自身の上で動く状態にした。** 登録は人間の操作で、AI は貼る JSON と手順を用意し、各段の後に軽い操作を通してコミットした。

| 段 | コミット | 足したもの |
|---|---|---|
| ①（11 行版） | `a41167e` | 案内側 11 行 + 4c プローブの撤去 |
| ②-1 | `e26cfbe` | `workflow-entry` 拒否側（`WF109`） |
| ②-2 | `9875270` | `workflow-state-guard`（`WF309`） |
| ②-3 | `d42e630` | `block-direct-git`（`WF409`） |
| ②-4 | `691b7a5` | `workflow-guard`（`WF209`） |
| ②-5 | `7827d2a` | `block-chmod` にラッパー（`WF509`）= 最終形 16 行 |

**ロックアウトは一度も起きなかった。** 拒否は 4 件出たがすべて仕様どおりの既定拒否で、書き方を宣言の範囲に合わせて続行した。

登録の前に、当初 17 行だった登録表を **16 行に縮退**させた。フェーズ 4c の実測で **T9（`systemMessage` がユーザーに表示されるか）が外れた**ためで、仕様 §12 があらかじめ定めていた分岐に従った。

| ID | 見たもの | 実測 | 仕様との対比 |
|---|---|---|---|
| T2 | 親子の `session_id` | **同じ**。子の呼び出しには `agent_id` / `agent_type` が付く | 一致（親子対応表は不要） |
| T3 | `claude -p` の判別 | **判別する入力フィールドは無い**。`source` は対話と同じ `startup` | 一致 |
| T4 | `SubagentStart` の `agent_id` / `agent_type` / `model` | 前 2 つは実在、**`model` は来ない**。`PreToolUse:Agent` の `tool_input.model` も**指定時のみ** | 一致（+ 補足 1 件） |
| T5 | `PowerShell` の共通フィールド | **Bash と同形** | 一致 |
| T7 | 終了コードのフィールド名 | **存在しない**。さらに **exit≠0 では PostToolUse が 1 本も起動しない** | 一致（「届いた = 成功」を裏付け） |
| T9 | `systemMessage` の表示 | **外れた。人間に通知が来ない**（SDK メッセージには載る） | **不一致 → 16 行へ縮退** |

登録した 16 行そのものに対する**敵対的レビューで 2 件の穴**が出た。重いのは **`workflow-guard` の matcher に `mcp__.*` が無い**こと（MCP 経由の書き込みが許可範囲の判定を受けない）。

機械検証は **HK-T01 / HK-T09 が 27 件全通過**（16 行の登録が期待値と逐語で一致）、**全件テストが 25 本 / 163 ID すべて PASS・失敗 0**（assertion 1999 件）。

## レビューしてほしい観点

**◆特に見てほしい（判断に困っている）**

- **r1（✕重要）T9 の縮退で `PreToolUse` / matcher `Agent` の登録を外したこと**。失うのは起動**前**の WF801（実行者の不一致）と WF803（background 起動）の通知で、受け皿は `subagent-stop-check`（`PostToolUse` `Agent`）の縮退判定と WF814。実測では **WF814 が実際に起動直後へ届いた**ので background の側は埋まっている。埋まりきっていないのは「起動する前に止める機会」で、これを機構として持たない判断でよいか。なお実行者の比較には **`tool_response.resolvedModel`（実際に使われたモデル）が使える**ことが実測で分かったので、起動後の判定の材料は増えている
- **r2（✕重要）`workflow-diff-check`（WF601）が worktree の中を見ない穴**。`EnterWorktree` で worktree に移ると、**事前の許可判定（`workflow-guard`）は効くが事後の差分検査は本体の作業ツリーしか見ない**。worktree の中で許可範囲外の書き込みが起きても WF601 は気づかない。今は「事前で止まるから実害は小さい」と判断して 0032 へ送ったが、拒否側が縮退（`WORKFLOW_GUARD_ENFORCE=0`）しているときに穴が開く

**◇承認が欲しい（方針は決めた）**

- **r3**: `cd` と `bash wip/tmp/<一時スクリプト>.sh` が既定拒否（`WF204`）になったこと。**設計としては正しい**（作業ツリー内の任意コードを無条件に実行させない）が、長いコマンドを一時スクリプトに逃がす書き方が使えなくなる。`allow.ops` に `tmp-script` のような分類を設ける案を 0032 へ送った
- **r4**: 4c プローブを**跡形なく撤去**したこと（`grep -rn 'WORKFLOW_PROBE_4C\|probe-4c' .claude` が 0 件）。撤去の際に **SE-T06 の前半（`source=compact`）の検査がプローブの assertion に寄生していた**のを見つけ、本来の検査として `case_compact` に書き直した
- **r5**: DoD の「boundary.sh 依存で実施できない 10 件」という数え方を実測に合わせて訂正すること（下の「検証の結果」）

**・細かいレビューは不要（ほぼ確実）**

- 段階ファイルの生成器（`wip/tmp/stages.py` / `fixture.py`）を 16 行に直して再生成したこと
- 各段のコミットを段ごとに分けたこと（戻す単位を段に揃えるため）

## 確かめられなかったこと（この結果が言っていないこと）

- **T9 の観測は VSCode 拡張の 1 面だけ**。CLI のターミナルで見たらどうかは確かめていない。ヘッドレスでは `system/informational`（`level: notice`）として**出ている**ので、「破棄されている」のではなく「対話 UI が人間に見せていない」
- **実登録に対する破壊試験はしていない**。HK-T09 は一時コピーに対してラッパー文字列を再現する機械テストで、実登録の `workflow-guard` を壊すと自分自身をロックアウトするため実施しない判断は維持した
- **worktree でどちらのチケットを見ているかは断定できていない**。本体と worktree の両方に同じ 0031 があったため。分かったのは「許可範囲の判定は書き込み先パスを cwd 基準で解決する」ことと「WF601 は本体の作業ツリーだけを見る」ことまで
- **T1 と T8 は実測していない**（§12 が取り消し線つきで解決済みとしている。T8 の実ファイル `mv` は自分自身をロックアウトする）
- **`shellcheck` は 8 巡連続で未導入**。`bash -n` だけで確かめた
- **性能は前のセッションの実測値**（ホットパス 5 本とも 1 回 1 秒以内）。登録後の実環境で測り直してはいない

## 実施条件（読んだ対象）

| 対象 | 内容 |
|---|---|
| チケット | `wip/10_tickets/10_doing/0031-ai-asset-implementation.md`（DoD 15 件） |
| 計画 | `wip/20_plans/0016-ai-asset-implementation-plan.md` のステップ 5 |
| 正 | `.claude/docs/10_spec/フック共通仕様.md` §1（登録表）・§2（入力）・§12（TBD） |
| 手引き | `wip/tmp/0031-handoff.md`（段階ごとの貼り替えとロックアウトの復旧） |
| 環境 | Windows 10 Pro / Git Bash・`jq` あり・`shellcheck` **無し**・VSCode 拡張 |

## 実施した内容と結果

### 1. フェーズ 4c の実測（プローブ経由） ✓

`WORKFLOW_PROBE_4C=1` を `settings.json` の `env` に置いた専用セッションで、**登録済みの本物のフック**が受け取る stdin を `logs/hooks/probe-4c.jsonl` に落として観測した。値を落とすのは 7 フィールドだけで、それ以外は**キーの名前と型のみ**。

- **T7 は負のコントロールが効いた**。`exit 3` と `exit 7` の Bash 呼び出しでは probe に行が増えず、WF601 の追記も出なかった。**失敗したツール呼び出しでは PostToolUse が 1 本も起動しない**
- **T9 の機械側**は `claude -p … --output-format stream-json --verbose` で採った。`{"type":"system","subtype":"informational","content":"PreToolUse:Agent says: …","level":"notice"}` が 1 件。**人間側は「通知が来ない」**（一次報告）
- **`tool_response.status` の両分岐を観測した**。対話で `run_in_background` 省略 → `async_launched`（WF814 が発火）／ヘッドレスの呼び出しが `false` を明示 → `completed`。§2 の「明示的に `false` でなければ background」が実物で裏づいた

### 2. T9 の縮退（17 行 → 16 行） ✓

`PreToolUse` / matcher `Agent` の `subagent-start-check` を登録から**外した**。フック本体は消していない（`SubagentStart` の WF802 = 要点注入はそのまま生きる）。

- `wip/tmp/fixture.py` の `ROWS` から 1 行削除 → `.claude/hooks/tests/fixtures/settings-hooks.expected.tsv` を 16 行で再生成
- `wip/tmp/stages.py` の `PRE` と `G` から `agent` を削除 → 段階ファイル 6 本を再生成
- `test_config_integrity.sh` のハードコード 2 か所（総行数 `17`→`16`、実体と登録先が一致しない行 `6`→`5`）を修正

外した行の受け皿は `subagent-stop-check` の縮退判定。**この行が無いとセッション内の印（`logs/sessions/<id>/subagent-start-check.json`）が常に書かれない**ので、縮退の側が必ず動く（DDR i0009-52 の設計どおり）。

### 3. 4c プローブの撤去 ✓

`lib/probe-4c.sh` の削除、6 フックの読み込み行と `probe_4c` 呼び出し、`subagent-start-check.sh` の `probe_4c_enabled` ブロック 2 か所、テスト 6 本の `cp` とプローブ用 assertion。

撤去で **SE-T06 の前半（`source=compact` でも同じ内容）の検査がプローブの assertion に寄生していた**ことが分かり、本来の検査（無出力・終了 0・記録が残る）を `case_compact` として書き直した。プローブが無ければ検査も消えていた箇所で、**一時の仕組みに本来の検査をぶら下げた作りの危うさ**が出た。

### 4. 段階登録（6 段） ✓

各段で人間が全文を貼り替え、AI が軽い操作（Bash → Read → Edit → `commit.sh`）を通してコミットした。**想定外の deny は 0 件**。仕様どおりの拒否は 4 件:

| 識別子 | 何が止まったか | どうしたか |
|---|---|---|
| `WF204` | `cd "<ルート>" && …` の前置 | cwd は元からルートなので `cd` を書かない形に修正 |
| `WF204` | `bash wip/tmp/p31-full.sh`（一時スクリプト経由の全件テスト） | 提供コマンド `run-tests.sh` を直接呼ぶ形に修正 |
| `WF204` | `git worktree list` | `EnterWorktree` ツールに切り替え（DoD が予告していた挙動） |
| `WF205` | worktree 内の後始末の `rm` | 後始末を人間に依頼（`git worktree remove --force`） |

### 5. worktree での挙動 ✓（穴を 1 件発見）

`EnterWorktree` で `../issue-mr-ticket-workflow-probe4c` に移って 4 つ試した。**拒否側フックは worktree の中でも生きている**:

| 試したこと | 結果 | 分かること |
|---|---|---|
| worktree 内の `.claude/hooks/**` に Write | 通る | 許可範囲の判定は**書き込み先パスを cwd 基準で解決**する |
| worktree 内の `.claude/docs/**` に Write | `WF201` | 許可範囲外の判定も効く |
| worktree 側チケットの `allow.write` を広げる | `WF208` | **worktree に逃げても許可範囲は広げられない** |
| `rm` で消す | `WF205` | コマンドでの書き換えの禁止も効く |

一方で **`workflow-diff-check`（WF601）は本体の作業ツリーだけを見る**。証拠は 2 つ:

1. worktree では無変更のはずの `.claude/settings.json` が「変更」として挙がり続けた（worktree の settings.json は分岐時点の 13 フック、本体は 16 フック）
2. worktree に作った未追跡ファイル `.claude/hooks/p31-worktree-probe.txt` が WF601 の一覧に**現れなかった**

### 6. 敵対的レビュー（登録した 16 行そのものを叩く） ✕問題

観点は「登録の網から漏れるツールはないか」「fail-closed ラッパーは本当に閉じるか」。

- **adv1（✕問題）`workflow-guard` の matcher に `mcp__.*` が無い**。隣の 2 行（`workflow-entry` の拒否側・`workflow-state-guard`）には入っているのに、**許可範囲の本体だけ入っていない**。MCP のツールは「宣言していないと deny」と「状態の守り」は通るが、**許可範囲・作業ツリー外・コマンド分類の判定を受けない**。書き込み系のツールを持つ MCP サーバを繋ぐと `allow.write` を無視して書ける。登録は仕様 §1 の 50 行目どおりなので**登録ミスではなく仕様の穴**
- **adv2（△注意）`EnterWorktree` / `ExitWorktree` がどの matcher にも無い**。worktree へ移ること自体が無検査で、f5 の「WF601 が worktree を見ない」と重なると「worktree に移って書けば事後の差分検査を素通りできる」
- **adv3（◎良・空振り）fail-closed ラッパーの二重出力・部分出力は起きない**。`cmd || printf '{deny}'` は、フックが出力を始めた後に異常終了すると壊れた JSON になり fail-open へ転びうる。実際に流すと確かに壊れた JSON が出るが、**実フックには当てはまらない**。出力は `__hc_emit_decision` の printf 1 回で完結し、`hook_deny` は `trap - ERR` → 記録 → printf → `exit 0` の順なので、記録で落ちれば deny は出ずラッパーの WFx09 に倒れる（正しく閉じる）
- **副産物**: `python -c '…'` は `WF209`（文字列をコードとして受け取る実行系）で拒否されるのに `jq -r '<式>'` は通る。jq の式もコードなので**判定の一貫性が無い**（jq からファイルは書けないので実害は小さい）

## 検証の結果

| 検査 | 結果 |
|---|---|
| HK-T01（16 行の逐語照合） | **通過**。イベント・matcher・配列上の位置・command の 4 列すべて一致 |
| HK-T09（fail-closed ラッパー） | **通過**（8 件） |
| `test_config_integrity.sh` 全体 | **27 件通過・失敗 0** |
| プローブ撤去で触った 6 本 | **251 件通過・失敗 0**（16 / 57 / 56 / 36 / 38 / 48） |
| 全件テスト `run-tests.sh --ids` | **25 本 / 163 ID すべて PASS・失敗 0**（assertion 合計 1999 件、TIMEOUT なし） |
| `bash -n` | 触った 12 本すべて通過 |
| `shellcheck` | **未実施**（環境に無い） |

**仕様に載っていて実行されていない ID は 27 件**。`AUTH-T01` / `AUTH-T03` / `WD-T06` はスキル仕様の中の**記入例**で実在しないので除いた。

| 群 | 件数 | 理由 |
|---|---|---|
| `BD-T01`〜`T13` | 13 | `boundary.sh` 自体が未実装 |
| `SE-T01`〜`T04`・`T07`〜`T09` | 7 | session-start のうち `boundary.sh` に依存するもの |
| `FN-T01`〜`T05` | 5 | `10-task-overall-summary` の release が未実装 |
| `WE-T10` | 1 | 継続条件が `boundary.sh status --offline` に依存 |
| `TR-T06` | 1 | `run-tests` の ID 抽出の境界（テスト未実装） |

**DoD の「boundary.sh 依存で実施できない 10 件」は実測と合わない**（依存は 8 件、`boundary.sh` 自体のテストが 13 件、未実装の提供コマンドが 5 件、未実装のテストが 1 件）。数え方の訂正を 0032 へ送る。

重複 ID が 1 件（`CP-T08` が `test_commit.sh` と `test_push.sh` の両方にある）。

## 設計への反映（後続へ）

実装フェーズは `.claude/docs/**` に書けないので、フェーズ 6（design-feedback）へ送る。

1. **§1 の登録表を 16 行にする**（`PreToolUse` `Agent` の `subagent-start-check` を削除）。§12 の T9 を「実測で外れた」に書き換え、縮退の発動を確定させる
2. **`subagent-start-check` 仕様から `PreToolUse` `Agent` の経路（WF801 / WF803 の起動前通知）を落とす**。あわせて **`tool_response.resolvedModel` で実際に使われたモデルを比較できる**ことを §2 と `subagent-stop-check` 仕様に書く
3. **§2 に「`PreToolUse:Agent` の `tool_input.model` は呼び出し側が明示したときだけ来る」を追記**する（未指定＝既定モデル。値が無いことを「一致」と読まない）
4. **§2 に「exit≠0 のツール呼び出しでは PostToolUse フックが起動しない」を追記**し、`workflow-diff-check` 仕様に「失敗した呼び出しの後の差分は次の成功した呼び出しまで検知が遅れる」を §13（意図的な緩和）として書く
5. **§12 の T2 / T3 / T4 / T5 / T7 を「実測で確認済み」に更新**する。T2 の縮退（親子対応表）は不要と確定。副産物として「サブエージェント内のツール呼び出しには `agent_id` / `agent_type` が付く」を §2 に明記できる

## 想定と異なった点

- **`systemMessage` は「破棄される」のではなく「対話 UI が見せない」**。ヘッドレスの SDK メッセージには `level: notice` で載っている。仕様が引いていた公式の記述（「Warning message shown to the user」）と実装の食い違い
- **`PreToolUse:Agent` の `tool_input` にモデルが来ない**（指定しない限り）。§2 は「実行者の比較は `tool_input.model` を読める PreToolUse で行う」と書いていたが、比較する値が無い場合がある。実装は既に「model が特定できない」へ倒していたので振る舞いの誤りは無い
- **失敗したツール呼び出しでは PostToolUse が動かない**。「`PostToolUseFailure` に流れる」という文書の記述を実物で確認した形だが、**WF601 の検知が失敗時に効かない**という運用上の含意は仕様に書かれていなかった
- **`cd` が既定拒否**。分類表に無いものは拒否という設計どおりだが、日常的に前置していた操作が止まるのは想定していなかった
- **`20-common-step-report-view` の手順（テンプレートを `cp` してコピーする）が `WF205` と衝突する**。この報告の HTML を作ろうとして実際に止まった。Read → Write で同じ内容を作って続行したが、**スキルの手順書がフックの規則に反している**状態なので直す必要がある

## 残課題

- **0032（feedback-plan）へ送るもの 9 件**: (1) WF601 が登録作業のチケットで `settings.json` を毎回挙げるノイズ（`common.confirm` が許可範囲より先に効く）、(2) 作業ツリー外の書き込みを WF209 で拒否する判断とメモリ機構の衝突、(3) `cd` を読み取り系に足すか、(4) `allow.ops` に `tmp-script` を設けるか、(5) WF601 が worktree を見ない穴、(6) `20-common-step-report-view` の手順が `cp` を指示していて WF205 と衝突すること、(7) **`workflow-guard` の matcher に `mcp__.*` を足すか（adv1。重い）**、(8) `EnterWorktree` / `ExitWorktree` を matcher に入れるか（adv2）、(9) eval 系の判定に `jq` の式が入っていない一貫性の穴
- **複数行のコミットメッセージが使えない**。`commit.sh` に改行入りの `-m` を渡すとコマンド位置の判定が崩れて `WF204` になる。あわせて `commit.sh` は規約（CP002）でフッターとモデル名を禁じているので、`Co-Authored-By` の類は付けられない
- **PR #12 の本文の更新**がこのチケットの `allow.ops` に無い（`remote-write:mr-edit` を宣言していない）ため、ワークの切れ目で行う
- **`shellcheck` の導入**が 8 巡続けて未了
