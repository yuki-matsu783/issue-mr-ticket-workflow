---
type: report
title: "0030 AI アセット実装結果 — 拒否側フック 4 本（entry / state-guard / direct-git / guard）"
description: 振り分けの入口・進行状態の保護・git の直接実行の拒否・許可範囲の判定という拒否側フック 4 本を実装し、敵対的セルフレビュー 2 巡で見つけた 3 件（.. を挟んだ保護範囲の迂回・作業ツリー外が承認単位になる・シェルのループが既定拒否に落ちる）と共有ライブラリの重大バグ 1 件を直した結果
tags: [report, ai-asset-implementation, issue-9, hooks, 拒否側]
keywords: [workflow-entry, workflow-state-guard, block-direct-git, workflow-guard, WF101, WF30x, WF40x, WF20x, hook_read_state, 既定拒否]
---

# 0030 AI アセット実装結果 — 拒否側フック 4 本

- 対象 issue: #9 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9
- PR: #12 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/12

## サマリ

拒否側のフック 4 本を実装した。判定規則はフック側に持たせず、共有ライブラリ（`cmdpos.sh` / `scope.sh` / `hook-common.sh`）の戻り値だけで分岐している。

| フック | 役割 | 識別子 | テスト |
|---|---|---|---|
| `workflow-entry.sh` | プロンプトごとの振り分け（宣言）の強制 | WF101 / WF102 / WF109 | WE-T01〜T09・T11（65 件） |
| `workflow-state-guard.sh` | 進行状態ファイル・チケットの置き場・draft 解除の保護 | WF301〜WF304 / WF309 | SG-T01〜T11（87 件） |
| `block-direct-git.sh` | `git commit` / `git push` の直接実行の拒否 | WF401〜WF403 / WF409 | BG-T01〜T11（76 件） |
| `workflow-guard.sh` | チケットの宣言と上限設定による許可 / 確認 / 拒否 | WF201〜WF213 | WG-T01〜T17（147 件） |

**敵対的セルフレビューは 2 巡**行い、1 巡目を「拒否をすり抜けられるか」、2 巡目を「正当な操作を止めていないか（= ロックアウト）」に分けた。実物へ入力を流すプローブ（`wip/tmp/adv0030.sh` / `adv0030b.sh`）で、読みだけでは出なかった 3 件が実測で出た。

| # | 指摘 | 直し方 |
|---|---|---|
| 1 | `wip/../.claude/settings.json` が保護範囲の glob に一致せず **WF201 ではなく WF202（確認）**に落ちる | `workflow-guard` がルート相対に直したあと `.` / `..` を畳む |
| 2 | 作業ツリーの外のパスが **承認単位（`..`）として提示される** | 畳んだ結果が外に出るパスは WF209 で拒否し、承認単位にしない |
| 3 | `for f in a b; do …; done` が **WF204（分類外）で止まる** | シェルのキーワードだけの段を `scope.sh` で読み取り扱いにする |

あわせて、共有ライブラリの**重大バグ 1 件**を見つけて直した（下記「4」）。

全件テストは 2 ロケールで **25 本 / 161 件・FAIL 0（既定ロケールと LC_ALL=C。`--timeout 600`）**。

## レビューしてほしい観点

**◆特に見てほしい（判断に困っている）**

- **r1（△注意）`python` が既定拒否（WF204）になること**。実作業では一時スクリプトを `python wip/tmp/x.py` で走らせる場面が実際にある（このチケットでも使った）。`commands.build-test` に足すか、「`wip/tmp/**` のスクリプト実行」という分類を作るか、既定拒否のまま「都度 ops を宣言する」で通すかの判断が要る
- **r2（△注意）作業ツリーの外への書き込みを WF209（判定不能）で拒否したこと**。「範囲外だから WF201」でも「未記載だから WF202」でもなく、判定できない側に倒した。理由は、外のパスは上限設定のどの glob にも当たらず、承認単位にすると `..` のような無意味な単位が残るため。**リポジトリの外に出す正当な作業（別リポジトリの参照など）を止める**方に倒した判断なので見てほしい

**◇承認が欲しい（方針は決めた）**

- **r3**: WF208 の判定に入れ子の `write:` / `ops:` の行を足したこと（`allow:` の行に触れずに宣言を広げられた）。字下げのある行に限ったので箇条書きの作業ログは巻き込まない
- **r4**: シェルのキーワード（`for` / `done` / `fi` / `esac` / `case`）を `scope.sh` の読み取り扱いに足したこと。フック側に分類規則を複製しない方針を優先した
- **r5**: 提供コマンドの引数のパス判定を「パスらしい語」だけに当てたこと（値を取るオプションの次の語を飛ばし、空白を含む語と `/` も拡張子も無い語は見ない）

**・細かいレビューは不要（ほぼ確実）**

- `hook_read_state` のバグ修正（要求しない副入力も `null` で渡す）と HK-T18 への退行テスト
- `cmdpos.sh` の opaque に `invoke-expression` / `iex` を足したこと
- 各フックの識別子・文面（回復手順を必ず入れ、値そのものは出さない）

## 確かめられなかったこと（この結果が言っていないこと）

- **本番のフックとして動かしていない**。`settings.json` への登録は 0031（人間の操作）。ここまでは `bash <hook> < 入力 JSON` の単体実行とテストだけ
- **ロックアウトの実測をしていない**。2 巡目のプローブは「このチケットでやった操作」を並べただけで、他の作業で何が止まるかは分からない
- **PowerShell の読み取り系がすべて WF204 になる**ことは分かっているが、直していない（§8 の読み取り一覧は bash 前提）
- **`hook_read_state` のバグが本番でどこまで影響していたか**は追っていない（未登録なので実害は無いはずだが、0029 / 0038 のテストは修正後に回し直した）
- **`shellcheck` は 8 巡連続で未導入**
- **フックの実行時間を「1 本あたり」でしか測っていない**。5 本を登録したときの 1 ツール呼び出しあたりの待ちは 0031 の実測に委ねる

## 実施条件（読んだ対象）

| 対象 | 内容 |
|---|---|
| チケット | `wip/10_tickets/20_done/0030-ai-asset-implementation.md`（DoD 10 件） |
| 仕様 | `10_spec/hooks/10-UserPromptSubmit/workflow-entry.md` / `20-PreToolUse/workflow-state-guard.md` / `block-direct-git.md` / `workflow-guard.md` / `フック共通仕様.md` §1〜§10 |
| 実体 | 上記 4 本 + テスト 4 本。共有ライブラリ `hook-common.sh` / `cmdpos.sh` / `scope.sh` の修正 |
| 環境 | Windows 10 Pro / Git Bash・`jq` あり・`shellcheck` **無し** |

## 実施した内容と結果

### 1. `..` を挟むと保護範囲をすり抜けられた ✕問題

`hook_rel_path` はルート相対にするだけで `.` / `..` を畳まない。`wip/../.claude/settings.json` は `.claude/**` の glob に一致しないので、**保護範囲の拒否（WF201）ではなく未記載の確認（WF202）**になっていた。

```
（直す前）Write wip/../.claude/settings.json
{"permissionDecision":"ask","permissionDecisionReason":"WF202: wip/../.claude/settings.json は上限設定にもチケットの宣言にも無い…"}
（直した後）
{"permissionDecision":"deny","permissionDecisionReason":"WF201: .claude/settings.json は 作業中チケット 0003…"}
```

確認は人間が答えれば通る経路なので、**保護範囲が「確認すれば書ける範囲」に化けていた**ことになる。`workflow-guard` の中でルート相対に直したあとに段を畳み、畳んだ結果で判定する。

### 2. 作業ツリーの外が承認単位になっていた ✕問題

同じ経路で、リポジトリの外を指すパスは `..` を承認単位として提示していた。承認されると `../` で始まるあらゆるパスが同じ扱いになる。

畳んだ結果が絶対パスまたは `..` で始まるものは **WF209（判定不能）で拒否**する。`workflow-diff-check` が 0038 で「ルート相対でないパスを承認単位にしない」と決めたのと同じ立場に揃えた。

### 3. ふつうのループが既定拒否で止まった ✕問題

`workflow-guard` は分類できないコマンドを WF204 で拒否する（既定拒否）。`cmdpos.sh` は `;` で段に割るので、`for f in a b; do echo $f; done` は `for …` / `do echo …` / `done` の 3 段になり、**`for` と `done` が「分類外のコマンド」**になっていた。

```
（直す前）for f in a b; do echo $f; done
{"permissionDecision":"deny","permissionDecisionReason":"WF204: for はどの分類にも当たらない（既定拒否）…"}
（直した後）無出力（許可）
```

`scope.sh` に `_SC_SHELL_KEYWORDS`（`for` / `done` / `fi` / `esac` / `case` / `select` / `coproc` / `function`）を足し、読み取り扱いにした。**リダイレクトは段に残る**ので `done > src/api/a.ts` は従来どおり WF205 で止まる（テストで固定）。

### 4. `hook_read_state` が常に空を返していた ✕問題（共有ライブラリ）

`workflow-entry` のテストが全滅したことから見つけた。jq のプログラムは `$review` / `$merge` / `$approvals` / `$entry` の**4 つすべてを参照する**のに、要求された副入力だけを `--argjson` で渡していたため、jq がコンパイルに失敗して出力が空になっていた。呼び手からは「壊れている」ではなく**「無い（missing）」に見える**ので、縮退と区別がつかない。

```
（直す前）hook_read_state entry → HC_ENTRY_STATE=missing（ファイルはある）
（直した後）ent=[ok] prompt_seq=1 declared_skill=00-workflow-quick-request
```

要求しなかったものも `null` で必ず渡すようにし、HK-T18 に退行テストを足した。0027/0028 由来のバグで、**`workflow-diff-check` の承認の記憶と `subagent-stop-check` の approvals 参照は実際には効いていなかった**。修正後に両方のテストを回し直した（48 件 / 57 件 FAIL 0）。

### 5. WF208 が入れ子の宣言行をすり抜けた ✕問題

着手済みチケットの `ticket_type` / `allow` などの改変は WF208 で拒否する。判定は `hook_read_input` が jq で作る `HOOK_FM_KEYS_TOUCHED` に依るが、正規表現が行頭の `allow:` しか見ておらず、**`  write: [...]` の行だけを差し替える編集**が素通りしていた。字下げのある `write:` / `ops:` の行を判定に足した（`- ops: …` のような箇条書きは対象外なので、作業ログの追記は巻き込まない）。

### 6. その他（1 巡目で潰したもの）

- `cmdpos.sh` の opaque に `invoke-expression` / `iex`（PowerShell の eval 相当。無いと `Invoke-Expression "git commit"` が素通りした）
- PowerShell のヒアストリングのように**語が 1 つも無い段**は通す（`_`（読めない）と区別する）。区別しないとヒアストリングを含むだけで拒否になる
- `rm -rf wip` は WF303 ではなく **WF302**（作業中の置き場を先に見る。仕様 SG-T11）
- `hook_fail_closed`（ERR トラップ）の下では、素の関数呼び出しが 1 を返すだけで機構の不調（WFx09）に化ける。状態の読み出しは `|| true` で受ける

## 検証の結果

| 対象 | 件数 | 結果 |
|---|---|---|
| `test_workflow_entry.sh`（新規。WE-T01〜T09・T11） | 65 | FAIL 0 |
| `test_workflow_state_guard.sh`（新規。SG-T01〜T11） | 87 | FAIL 0 |
| `test_block_direct_git.sh`（新規。BG-T01〜T11） | 76 | FAIL 0 |
| `test_workflow_guard.sh`（新規。WG-T01〜T17） | 147 | FAIL 0 |
| `test_block_chmod.sh`（BC-T05 にホットパス検査を追加） | 93 | FAIL 0 |
| `test_hook_common.sh`（HK-T18 に退行テストを追加） | 187 | FAIL 0 |
| `test_scope.sh`（キーワードの分類を追加） | 312 | FAIL 0 |
| `test_workflow_diff_check.sh` / `test_subagent_stop_check.sh`（修正の影響確認） | 48 / 57 | FAIL 0 |
| `test_templates.sh`（SS-T05: `__ss_load` 行のバイト一致） | 43 | FAIL 0 |
| プローブ `wip/tmp/adv0030.sh`（すり抜け 15 本（MultiEdit の 1 本を含む））/ `adv0030b.sh`（偽陽性 11 本） | — | 直す前の再現と直した後の解消を実測 |
| 全件テスト（既定ロケール / `LC_ALL=C`。`--timeout 600`） | 25 本 / 161 件 | FAIL 0（両ロケール） |

ホットパス 5 本の外部プロセスは `make_counting_path` で固定した。

**テストの重さ**: `test_workflow_guard.sh` は単体で **5 分 07 秒**かかり、`run-tests.sh` の既定の上限（120 秒）を超える。判定 1 件がフック 1 プロセス（約 1.9 秒）で、147 件あるため。全件テストは `--timeout 600` で回した。既定の 120 秒では 5 本が TIMEOUT する（`test_workflow_guard` / `test_workflow_state_guard` は今回追加、`test_post_push_usage_report` / `test_check_html` / `test_ticket` は既存）。

**フック 1 回の内訳**（Windows / Git Bash）: bash 起動 0.3 秒 + 共有ライブラリ 3 本の読み込み 0.48 秒（hook-common 0.26 / cmdpos 0.12 / scope 0.10）+ 内部の jq 0.24 秒 + 記録の書き込み。**5 本を登録すると 1 ツール呼び出しあたりの待ちが無視できない**ので、0031 の実測（T1〜T4）で確かめる。

| フック | jq | git / date / sed / find |
|---|---|---|
| `block-chmod`（BC-T05） | 1 | 0 |
| `block-direct-git`（BG-T11） | 1 | 0 |
| `workflow-state-guard`（SG-T07） | 1 | 0 |
| `workflow-guard`（WG-T13） | 2（書き込み判定）/ 1（コマンド判定） | 0 |
| `workflow-entry`（WE-T03 / WE-T05） | 2 / 1（チケット継続の経路） | 0 |

## 設計への反映（後続へ）

0032（設計反映）へ送る:

1. フック共通仕様 §1: `hook_read_state` は要求しない副入力も `null` で渡す（jq のプログラムが 4 変数すべてを参照するため）
2. フック共通仕様 §7: `_CP_OPAQUE_WORDS` に `invoke-expression` / `iex`。語が 1 つも無い段は「読めない段」と区別して通す
3. フック共通仕様 §8: シェルのキーワードだけの段は読み取り扱い。`python` と PowerShell の読み取り系の扱いを決める
4. `workflow-guard.md`: パスの `.` / `..` を畳んでから判定し、作業ツリーの外は WF209
5. `workflow-guard.md`: WF208 の判定は入れ子の `write:` / `ops:` の行も見る
6. `workflow-guard.md`: WG-T05（`confirm` の例示）と WG-T17（`wget --method=GET`）を実装に合わせて直す
7. `workflow-guard.md`: 作業中が 2 枚以上のとき、プランモードも WF207 に含める（どちらのチケットの `plan_mode` を見るか決まらないため）
8. `20-common-step-shell-script.md`: `run-tests.sh` の既定の上限（120 秒）に収まらないテストの扱い（テストを軽くするか、テスト側で上限を宣言できるようにするか）

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 4 本を順に書けば終わる | 3 本目（`workflow-entry`）のテストが全滅し、原因は共有ライブラリのバグだった | ライブラリを直し、影響を受ける既存テストを回し直した |
| 敵対的レビューは「すり抜け」を見れば足りる | 拒否側は**偽陽性がロックアウトになる**ので、正当な操作を止めていないかの巡が要った | 2 巡目を偽陽性専用にした |
| 仕様のテスト観点をそのまま固定できる | WG-T05 / WG-T17 は仕様の例示が実装（`scope.sh` の判定順）と食い違う | 実装に合わせてテストを書き、仕様の修正を 0032 へ送った |

## 残課題

- **0031（人間の操作）**: `settings.json` への段階登録 ①② と TBD T1〜T4 / T9 の実測
- **0032（設計反映）**: 上記 6 件 + 0029 / 0038 からの累積
- **`python` と PowerShell の読み取り系が既定拒否**（r1・上記 3）。設定・仕様の判断が要る
- **ロックアウトの実測が無い**。0031 の段階登録で、実際に止まる操作を観察する
- **テストが重い / フックが遅い**: `run-tests.sh` の既定の上限（120 秒）を超えるテストが 5 本。テストを軽くするか既定値を上げるかは 0032 で決める
- `shellcheck` 未導入（8 巡連続）／`check-html.sh` が md と HTML の内容一致を検査しない（19 回連続）
