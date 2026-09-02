---
type: report
title: 0023 AI アセット設計結果 — ホットパスの外部プロセス上限と読み取り経路の再設計
description: jq --slurpfile が副入力の破損で呼び出しごと失敗する実測と session_id 依存パスの構造から、fork 上限を内訳の決まった最大 2 回に改め副入力を --rawfile + fromjson? に変えた設計結果
tags: [report, ai-asset-design, issue-9, review-fix]
keywords: [jq, slurpfile, rawfile, fromjson, fork 上限, session_id, approvals.json, entry.json, scope_load, parse_errors, hc_lock, ロックアウト]
---

# 0023 AI アセット設計結果 — ホットパスの外部プロセス上限と読み取り経路の再設計

## サマリ

境界レビュー 2 巡目の **A1・A2・B11・B12** を反映した。中心は **0021 が「解消した」と報告した宿題が実は解消しておらず、しかもロックアウト経路を 1 つ開けていた**という発見で、実測とパスの構造の両方から確かめた。更新は仕様 4 本・DDR 3 本の訂正（うち 1 本はファイル名も）、新規の DDR は 4 件（`i0009-46`〜`49`）。

確定したのは 4 つ。

1. **ホットパスの `jq` は最大 2 回**（`i0009-46`）。内訳は「stdin と固定パスの副入力で 1 回」＋「`session_id` に依存する副入力で 1 回」。**2 回目は構造が強いている**ので、これ以上は増えない
2. **副入力は `--rawfile` + `fromjson? // null` で読む**（`i0009-47`）。`--slurpfile` は副入力の破損・不在で**呼び出しごと失敗して stdout を空にする**（実測）
3. **`scope.sh` の読み込み関数は JSON のファイルを開かない**（`i0009-48`）。パス引数を外し、`hook-common.sh` が取り出した値を受け取る
4. **`parse_errors` は実行ログ 1 か所**（`i0009-49`）。あわせて書き込みヘルパ 6 つの契約（引数・戻り値・タイムアウト・切り詰めの責任）を表にした

## レビューしてほしい観点

**◆特に見てほしい（判断に困っている）**

- **f1（✕問題）0021 の「解消」は誤りだった**。`--slurpfile` は副入力が壊れていると `tool_name` の取得すら奪う。**`i0009-29` が塞いだロックアウトを `i0009-37` が別の形で開け直していた**という構図で、これは**穴を塞ぐ決定が別の穴を開けた 3 例目**（0019 の相対パス禁止 → worktree、`i0009-41` → `curl` の送信側、今回）。個々の直しは実測で確かめたが、**この型を機構として防ぐ手立てが無い**のが本当の問題だと考えている。DDR に「この決定で塞がらなくなるものは何か」を書く枠を設けるべきか
- **f2（△注意）上限を 1 回から 2 回に上げたこと**。0021 は「上限が要求に押されて動くなら制約として機能しない」として緩めなかった。今回は緩めているので、**「構造が強いているから 2 回」という理由が、次に別の要求が来たときに歯止めとして機能するか**を見てほしい

**◇承認が欲しい（方針は決めた）**

- **f3**: `scope.sh` の読み込み関数からパス引数を外すこと（`jq` を呼ぶのを `hook-common.sh` 1 か所に閉じる）
- **f4**: `parse_errors` を実行ログに置くこと（JSON に書くと循環する）

**・細かいレビューは不要（ほぼ確実）**

- ヘルパの契約の表、`i0009-22` の改名、`HK-T18` / `HK-T19` / `WG-T16` の追加

## 確かめられなかったこと（この結果が言っていないこと）

- **`hook_read_state` が実際に 1 回で足りるか**。`workflow-entry` は `entry.json` だけ、`workflow-guard` は `approvals.json` だけなので今は 1 回だが、セッション依存の状態が増えれば同じ問題が繰り返す
- **`--rawfile` に渡すファイルが巨大になったとき**の挙動（`approvals.json` が承認を貯め続ける経路がある）。文字列としてメモリに載る
- **`[ -f ]` と実際の読み取りの間にファイルが消える**競合（TOCTOU）。起きれば `jq` が終了 2 になり、ラッパーの deny に落ちる（拒否側は安全側だが、案内側は無出力で通る）
- `HK-T19` の期待値（1 回 / 2 回）が、実装で `hook_read_state` を呼ばない経路まで含めて正しいか
- `hc_lock` の 2 秒が実運用で妥当か（0021 から持ち越し）

## 実施条件（読んだ対象・実行したこと）

- **実行**: `jq --slurpfile` に壊れた JSON・不在ファイルを渡す実験と、`--rawfile` + `fromjson?` の対照実験（下の f1 に出力を載せた）
- 更新対象: `10_spec/フック共通仕様.md`（§1・§5・§8・§11）、`hooks/20-PreToolUse/workflow-guard.md`、`hooks/20-PreToolUse/workflow-state-guard.md`、`hooks/10-UserPromptSubmit/workflow-entry.md`
- 訂正した DDR: `i0009-22`（ファイル名も変更）・`i0009-33`・`i0009-37`
- 入力: `wip/30_reports/0022-ai-asset-design-appendix-A.md`（A1・A2・B11・B12）
- 公式原本: `wip/tmp/hooks.md`（`grep -c CLAUDE_SESSION` → 0）

## 実施した内容と結果

### 1. `--slurpfile` は副入力の破損で判定ごと落ちる（A1） ✕問題

`i0009-37` は `hook_read_input` が `jq --slurpfile lim <scope-limits.json>` で設定を副入力に渡す形を決めた。実際に走らせると、副入力が壊れているか無いときに**呼び出し全体が失敗して stdout が空**になる。

```
$ printf '{"bad"' > bad.json
$ echo '{"a":1}' | jq --slurpfile lim bad.json '.a'
jq: Bad JSON in --slurpfile lim bad.json: Unfinished JSON term at EOF at line 1, column 6
exit=2      # stdout は空

$ echo '{"a":1}' | jq --slurpfile lim missing.json '.a'
jq: Bad JSON in --slurpfile lim missing.json: Could not open missing.json: …
exit=2      # stdout は空
```

つまり設定 1 ファイルが壊れた瞬間、フックは `tool_name` も `tool_input.file_path` も `session_id` も取れない。ところが機構は 2 つの縮退を要求している。

- `workflow-guard` 制御方式 3: 設定が壊れたら **WF210**。復旧経路（提供コマンド・`wip/10_tickets/**`・`scope-limits.json` 自身への ask 付き書き込み）は通す
- `workflow-state-guard` 制御方式 0（`i0009-29`）: 設定が読めなくても**既定値で判定を続ける**

どちらも「`tool_name` と対象パスが分かっていること」が前提で、相乗りさせると前提ごと失われる。**`i0009-29` が塞いだロックアウト経路を `i0009-37` が別の形で開け直していた**。

**決定**: `--slurpfile` を使わない。存在するファイルだけを **`--rawfile`** で文字列として渡し、`jq` の中で **`fromjson? // null`** に通す。存在しないファイルは `--argjson <名前> null` に差し替える（存在確認は `[ -f ]` = bash 組み込みで fork しない）。読めなかったことは `HC_<名前>_STATE`（`ok` / `missing` / `broken`）で呼び手に伝え、**どう扱うかは各フックの制御方式が決める**。

```
$ echo '{"a":1}' | jq -r --rawfile lim bad.json '{a:.a, lim:(($lim|fromjson?) // null)} | @json'
{"a":1,"lim":null}
exit=0
```

`HK-T18` で固定する（壊した状態・消した状態で `hook_read_input` が終了 0 で戻る。`--slurpfile` 版が stdout 空・終了 2 になることを負のコントロールとして添える）。DDR `i0009-47`。

**結論**: 実測で塞げるロックアウト経路（0019 の相対パス登録、0020 の設定破損時の拒否に続く **3 つ目**）を塞いだ。ただし**同じ型の失敗が 3 回続いている**ことが問題として残る。

### 2. `session_id` 依存のパスは 1 回目に混ぜられない（A2） ✕問題

`i0009-37` は「チケットの frontmatter は純 bash で読むので、**残るのは上限設定だけ**」と書いていた。これが偽だった。

| フックが読む JSON | パス | 1 回目に混ぜられるか |
|---|---|---|
| フック入力 | stdin | — |
| `scope-limits.json` / `review-state.json` / `merge-state.json` | 固定 | できる |
| **`logs/sessions/<session_id>/approvals.json`**（`workflow-guard` 判定順 (6)） | **`session_id` 依存** | **できない** |
| **`logs/sessions/<session_id>/entry.json`**（`workflow-entry` 手順 3） | **`session_id` 依存** | **できない** |

`session_id` は stdin を解析して初めて分かる。公式に `session_id` を渡す環境変数は無い（`grep -c CLAUDE_SESSION wip/tmp/hooks.md` → **0**）。

**決定**: 上限を「**`jq` だけを起動してよく、呼び出しは最大 2 回**」に改め、内訳を固定する。1 回目 = `hook_read_input`（stdin + 固定パス）、2 回目 = `hook_read_state`（`session_id` 依存。要るフックだけ）。実際の回数は `block-chmod` / `block-direct-git` / `workflow-state-guard` が 1 回、`workflow-guard` / `workflow-entry` が 2 回。`HK-T19` で数える。DDR `i0009-46`。

**却下した案**: 純 bash の JSON パーサ（入れ子とエスケープで壊れやすい）／書式を `key=value` に変える（書き手が独自形式を持ち、原子的置換の対象から外れる）／`session_id` で分離するのをやめる（並行セッションの承認が互いに見える）／承認の記憶を捨てる（要件違反）。

**結論**: 0019 の f2（✕問題）はここで決着した。0021 の「解消」は**固定パスの副入力についてだけ**正しかった。

### 3. `scope.sh` の読み込み関数はファイルを開かない（B11） ◎良

`i0009-33` の「出力の形」では `scope_load <scope-limits.json>` / `scope_load_approvals <approvals.json>` がパスを取る形だった。`jq` の回数を `hook-common.sh` に閉じる決定と並べると、実装者が「どちらが読むのか」を推測することになる。

**決定**: 2 関数からパス引数を外し、`hook-common.sh` が取り出した `HC_*` を `SC_*` に詰め替えるだけにする。副入力が読めなかったことは `HC_<名前>_STATE` から `SC_ERROR` と戻り値 2 に写す。**例外は `scope_load_ticket <ticket.md>`** で、`frontmatter.sh`（純 bash・fork なし）が読むので上限に関わらない。境界は「ファイルを開くかどうか」ではなく「**`jq` を使うかどうか**」。DDR `i0009-48`。

**結論**: 回数の検査（`HK-T19`）が意味を持つ形になった。`i0009-17`（ライブラリは分類まで）の線引きがここでも使えた。

### 4. `parse_errors` の循環とヘルパの契約（B12） ◎良

§5 は「ロックを取得できなければ 2 秒待って諦め、加算せずに **`parse_errors` を +1**」と書いていたが、`parse_errors` が `usage/<branch>.json` の中にあるなら**その +1 自体が同じ read-modify-write でロックを要る**。しかも `post-push-usage-report` 仕様のスキーマ列挙に `parse_errors` は無く、回復手順は実行ログ側を指しており、**置き場が仕様内で 2 通り**あった。

**決定**: `parse_errors` の置き場は**実行ログ（`logs/sh/hook-<name>.log`）1 か所**。JSON には書かない（理由も §5 に添えた）。あわせて §1 にヘルパの契約の表を置いた。

| 関数 | 決めたこと |
|---|---|
| `hook_read_input [固定パス...]` / `hook_read_state <パス>...` | 引数・戻り値・読む範囲（1 回目 / 2 回目） |
| `hc_append_jsonl` | **切り詰めはこの関数が行う**（`redact` → 4 KB 未満 → `>>`）。呼び手は切り詰めない |
| `hc_json_write` | 一時ファイル名は関数が作る |
| `hc_lock` | **2 秒のタイムアウトは関数が持つ**。呼び手は指定しない |
| `hc_unlock` | **冪等**（取っていなくても失敗しない） |

DDR `i0009-49`。**結論**: 「方針だけ書いても実装で消える」（0021 の `fm_*` と同じ型）を、関数の契約に落として防いだ。

## 検証の結果

| 検証 | 結果 |
|---|---|
| 更新した仕様書 | 4 本（`フック共通仕様`・`workflow-guard`・`workflow-state-guard`・`workflow-entry`） |
| 更新した要件定義書 | 0 本（**対象なし**。`jq` の回数・副入力の渡し方・関数の引数はすべて内部構造で、外部から見える性質に変化が無い） |
| 訂正した DDR | 3 件（`i0009-22`（ファイル名も変更）・`i0009-33`・`i0009-37`）。いずれも未マージ |
| 新規の DDR | 4 件（`i0009-46`〜`49`。**割り当て帯 46〜49 に完全一致**） |
| 追加したテスト観点 | 3 件（`HK-T18` 副入力の縮退 / `HK-T19` `jq` の回数 / `WG-T16` 設定破損時の復旧経路） |
| 対応した指摘 | 4 件（A1・A2・B11・B12）。すべて反映済み |
| 実測したこと | `--slurpfile` の破損・不在での失敗（終了 2・stdout 空）、`--rawfile` + `fromjson?` の成功（終了 0・`null`）、`--argjson null` へのフォールバック、`grep -c CLAUDE_SESSION` = 0 |
| 塞いだロックアウト経路 | 1 つ（設定破損時に stdin の解析まで失う経路）。**通算 3 つ目** |
| ヘッドレス実行の帰結 | 変更なし |

### 受け入れ条件との対応

| # | 受け入れ条件（issue #9） | このチケットが満たす分 | テスト ID（種別） |
|---|---|---|---|
| 1 | フック本体 11 本が仕様どおり動きテストが通る | ホットパス 5 本の読み取り経路と外部プロセスの上限が実装できる形に確定した。`scope.sh` と `hook-common.sh` の責務の境界も決まった | HK-T18・HK-T19・WG-T16（すべて機械） |
| 4 | `HOOK_DENY_ID` と 2 枚以上をテストで固定 | 設定破損時に WF210 が**返せる**（stdout が空にならない）ことを `WG-T16` で固定した | WG-T16（機械） |
| 6 | 決定の経緯が DDR に残っている | `i0009-46`〜`49`（4 件）+ 既存 3 件の訂正 | — |

## 設計への反映（後続へ）

1. **0016 へ**: ホットパス 5 本のテストに `make_counting_path` による **`jq` の回数検査**（1 回 / 2 回）を入れる。`scope.sh` に `jq` の呼び出しが 1 つも無いことも同時に確かめる
2. **0016 へ**: `hook_read_input` / `hook_read_state` の実装が先。`scope.sh` の読み込み関数はそれに依存する
3. **実装フェーズへ**: `[ -f ]` で存在を確かめてから `--rawfile`、無ければ `--argjson <名前> null`。この分岐を `hook-common.sh` の 1 か所に閉じる
4. **実装フェーズへ**: `hc_append_jsonl` は `redact` → 切り詰め → `>>` の順。`hc_lock` は取得時に `trap` へ解放を登録する
5. **0024 以降へ**: 「この決定で塞がらなくなるものは何か」を DDR に書く枠を設けるかを検討する（f1 の申し送り）

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| A1 は「`--slurpfile` を `--rawfile` に変える」1 行の直し | `--rawfile` も**不在**では失敗する（破損だけが救われる）。`[ -f ]` の分岐が要った | 実験で切り分け、`--argjson null` へのフォールバックまで決めた |
| A2 は上限を 2 回に上げれば済む | 「なぜ 2 回で止まるのか」を書かないと、0021 が退けた「要求に押されて緩む」そのものになる | **内訳（固定パス / セッション依存）を固定**することで歯止めにした |
| B11 は表の 2 行の書き換え | 「`jq` を使うかどうか」が境界だと気づくまで、`scope_load_ticket` だけ引数を残す理由が説明できなかった | `i0009-48` の理由に書いた |
| B12 は `parse_errors` の置き場を選ぶだけ | ヘルパ 4 つの契約が丸ごと未定義だった（切り詰めの責任・タイムアウトの持ち主・冪等性） | 表にして §1 に置いた |

## 残課題

- **穴を塞ぐ決定が別の穴を開ける型が 3 回続いている**（f1）。DDR に「この決定で塞がらなくなるものは何か」を書く枠が要るかもしれない。0026 までの間に決める
- **`hook_read_state` が 1 回で足りるのは今の状態の数による**。セッション依存の状態が増えれば同じ問題が繰り返す
- `--rawfile` に渡すファイルが巨大になったときの挙動（`approvals.json` が貯まり続ける経路）
- `[ -f ]` と読み取りの間の競合（TOCTOU）。拒否側は安全側に落ちるが案内側は無出力で通る
- `hc_lock` の 2 秒が実運用で妥当か（0021 から持ち越し）
- **`.claude/rules/markdown-docs.md` が存在しない**のに `ai-asset-design-docs.md` が frontmatter の正としてそれを参照している（スコープ外で見つけた。0026 か別 issue で扱う）
