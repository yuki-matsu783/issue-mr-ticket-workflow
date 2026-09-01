---
type: report
title: 0005 調査結果 — フック 11 本の仕様の洗い出しと矛盾の検出
description: issue #9 で実装する 11 本のフック仕様を読み、判定順・エラー識別子・終了方式・テスト ID・依存を 1 枚の表にまとめ、識別子の台帳との不一致・テスト ID の命名の揺れ・未作成の設定ファイル・3/3 の未実装（boundary.sh）への依存を列挙した調査結果
tags: [report, investigation, issue-9]
keywords: [フック仕様, 判定順, エラー識別子, 終了方式, テスト ID, 依存, HOOK_DENY_ID, WF009, boundary.sh, blocked-commands.txt, entry-skills.txt, model-aliases.txt]
---

# 0005 調査結果 — フック 11 本の仕様の洗い出しと矛盾の検出

## サマリ

11 本のフック仕様は、判定順・エラー識別子・終了方式・テスト ID・依存のすべてが仕様に書かれており、**そのまま実装に落とせる状態にある**。エラー識別子は 11 本とも共通仕様 §6 の台帳の範囲に収まっていて重複も無い。一方で、**実装を始める前に決めておくべき食い違いが 7 件**見つかった。最も重いのは `session-start` と `workflow-entry` の一部テストが 3/3 の `boundary.sh` に依存していて、この issue の中では通せないこと。次に、`hooks/lib` の `HOOK_DENY_ID` の既定 `WF009` が台帳に無い番号であること（issue #9 の G7）と、フックが読む設定・アセットのファイル 3 本が未作成で、置き場の規約が仕様間で揺れていること。

- ◎良 3 件 / △注意 3 件 / ✕問題 1 件

### ◆特に見てほしい（判断に困っている）

- **f5**: `session-start` の 9 テスト中 6 本、`workflow-entry` の WE-T10 が `boundary.sh`（3/3・未実装）に依存する。受け入れ条件 1「テストが失敗ケースを含めて通る」をこの issue でどう満たすか（スタブを置く / テストを 3/3 に送る / 依存部分だけ別 ID に切る）を設計で決める必要がある

### ◇承認が欲しい（方針は決めた）

- **f2**: `HOOK_DENY_ID` の既定を `WF009` から**呼び手ごとの `WFx09` の設定必須**（未設定なら拒否側の共通番号を台帳に追加）に変える方針。台帳（§6）は `x09` を「拒否側のフックだけが持つ」と定めており、`WF009` の持ち主が居ない
- **f4**: 未作成のファイル 3 本（`config/blocked-commands.txt` / `10-UserPromptSubmit/assets/entry-skills.txt` / `12-SubagentStart/assets/model-aliases.txt`）を実装フェーズで作る。置き場は**仕様の記述どおり**にする（config と assets の使い分けは 3/3 の整理に送る）
- **f3**: テスト ID の命名の揺れ（`session-start` だけ `SS-H`、`block-direct-git` に `BG-T09b`）はこのまま維持し、規約の統一は 3/3 に送る。実 ID の重複は無い

### ・細かいレビューは不要（ほぼ確実）

- **f1**: 11 本 × 5 項目の一覧表（仕様からの転記）
- **f6**: §1 の登録表 16 行と各仕様の「呼出条件」が一致していること
- **f7**: 実装に要る外部コマンド（`jq` / `sha256sum` / `sha1sum` / `openssl`）が実行環境にあること

## 確かめられなかったこと（この結果が言っていないこと）

- 各フックの**実装が仕様どおり動くか**（この調査は仕様書の読み取りのみ。実測はフェーズ 4）
- `hooks/lib` の関数が各仕様の呼び出しを満たすか（**0006 の担当**。この報告は「依存する lib」の名前を挙げるだけ）
- 公式 hooks リファレンスとの整合（**0007 の担当**）
- テスト ID の重複について、`run-tests.sh --ids` を実行しての確認（実行はせず既存テストファイルの grep で照合した。ランナー自身の重複検出は実装フェーズで通る）
- 仕様の矛盾を「設計で直すか実装で扱うか」の振り分け（0008 の担当。この報告は列挙と「実測に依存するか」の注記まで）

## 実施条件（読んだ対象）

- `.claude/docs/10_spec/hooks/**/*.md` 11 本（合計 1179 行）と `.claude/docs/10_spec/フック共通仕様.md`（269 行）
- 既存のテスト ID: `.claude/hooks/tests/`・`.claude/hooks/lib/tests/`・`.claude/skills/*/scripts/tests/` の grep
- `.claude/hooks/lib/hook-common.sh`（`HOOK_DENY_ID` の既定値の確認のみ）
- 実行環境: Windows 10 / Git Bash（`type` での存在確認のみ。テストは実行していない）

## 実施した内容と結果

### f1. 11 本の仕様は判定順・識別子・終了方式・テスト ID がそろっている ◎良

根拠: 11 本の仕様書の「制御方式」「エラー識別子とメッセージ」「テスト観点」節

| # | フック | 側 | 登録（イベント / matcher） | 判定順の要点 | 識別子 | 終了方式 | テスト ID | 依存 |
|---|---|---|---|---|---|---|---|---|
| 1 | `session-start` | 案内 | SessionStart（全 source） | 停止中 → 古い `logs/sessions/` の掃除 → `boundary.sh status --offline` → 注入テキスト組み立て（6 行）→ 8 KB 超で警告 | WF701 情報 / 702 破損 / 703 MR 未記録 / 704 スキル不在 | stdout に注入。失敗時は無出力・終了 0 | SS-H01〜H09（9 本） | **`boundary.sh`（3/3）**、`logs/merge-state.json`、`git` |
| 2 | `workflow-entry` | 拒否（PreToolUse 書き込み系のみ）+ 記録 | UserPromptSubmit / PreToolUse `Skill` / PreToolUse 書き込み・実行・プランモード・起動 | 停止中 → 継続条件（チケット / review-state / merge-state）→ `entry.json` → 宣言の有無 | WF101 未宣言 / 102 記録破損 / 109 判定不能 | deny JSON + 終了 0 | WE-T01〜T11（11 本） | `logs/sessions/<id>/entry.json`、`assets/entry-skills.txt`（**未作成**）、`logs/review-state.json`・`merge-state.json`、（WE-T10 のみ **`boundary.sh`**） |
| 3 | `workflow-state-guard` | 拒否 | PreToolUse `Edit\|Write\|MultiEdit\|NotebookEdit\|Bash\|PowerShell\|mcp__.*` | 停止中 → 書き込みツール（state_files / 10_doing 新規 / 20_done）→ 実行ツール（提供コマンド → state_files の書き込み位置 → 置き場宛の mv・cp → draft 解除 → opaque）→ 入力不正 | WF301〜304 / 309 | deny JSON + 終了 0 | SG-T01〜T08（8 本） | `cmdpos.sh`、`scope-limits.json` の `common.state_files` |
| 4 | `block-chmod` | 拒否 | PreToolUse `Bash\|PowerShell` | 停止中 → 前置判定（語を含まなければ即許可）→ `cmdpos.sh` で実行体の basename 照合 → opaque/degraded → 入力不正 | WF501 / 509 | deny JSON + 終了 0 | BC-T01〜T06（6 本） | `cmdpos.sh`、`config/blocked-commands.txt`（**未作成**） |
| 5 | `block-direct-git` | 拒否 | PreToolUse `Bash\|PowerShell` | 停止中 → `cmdpos.sh` → セグメントごとに提供コマンド除外・`git commit`/`push`/コミット生成系の判定 → opaque → degraded → 入力不正 | WF401 commit / 402 push / 403 縮退 / 409 入力不正 | deny JSON + 終了 0 | BG-T01〜T08・T09b・T09・T10（11 本） | `cmdpos.sh`（**このフックが正**） |
| 6 | `workflow-guard` | 拒否 | PreToolUse 書き込み・実行・プランモード・起動 | 停止中/0 枚 → 2 枚以上 → 設定不正 → チケット不正 → 書き込み（チケット自身の改変 → `scope.sh` 判定順 (1)〜(7)）→ 実行（提供コマンド → opaque → コマンド書き込み → read → remote-read → ops 分類）→ プランモード → 起動 → ヘッドレス → 入力不正 | WF201〜213（13 個） | deny / ask JSON + 終了 0 | WG-T01〜T14（14 本） | `scope.sh`、`cmdpos.sh`、`scope-limits.json`、`approvals.json`、チケット frontmatter |
| 7 | `workflow-diff-check` | 案内 | PostToolUse `Edit\|Write\|MultiEdit\|NotebookEdit\|Bash\|PowerShell` | 停止中/0 枚/2 枚以上 → `base_sha` 無し → 承認の記憶 → 差分の範囲判定 → 先行チケット → 種類の改変 → 取得失敗 | WF601〜604 | additionalContext（無ければ無出力）・終了 0 | DC-T01〜T07（7 本） | `scope.sh`、`git status/diff/show`、`approvals.json`、チケット frontmatter |
| 8 | `post-push-compact-prompt` | 案内 | PostToolUse `Bash\|PowerShell` | 停止中 → push 検知（`push-detect.sh`。**このフックが正**）→ ホスト判定 → リンク組み立て（表）→ `push-state.json` 更新 → 注入 | WF901 情報 / 902 初回 / 903 MR 未記録 | additionalContext・終了 0 | PP-T01〜T08（8 本） | `push-detect.sh`、`cmdpos.sh`、`git`、`logs/mr.json`、`logs/push-state.json`、`sha256sum`/`sha1sum`（差分ページ内リンク） |
| 9 | `post-push-usage-report` | 案内 | PostToolUse `Bash\|PowerShell` / SubagentStop `--accumulate` / Stop `--accumulate` | `--accumulate`: transcript を `last_offset` 以降だけ集計 → 加算。既定: push 検知 → 未蓄積分の取り込み → 合算 → 本文生成 → ファイル出力 → 注入 | WF911 情報 / 912 記録読めず / 913 状態破損 | additionalContext + `logs/usage/` への書き出し・終了 0 | UR-T01〜T07（7 本） | `transcript.sh`、`push-detect.sh`、`logs/usage/<branch>.json` |
| 10 | `subagent-start-check` | 案内 | SubagentStart（全サブエージェント） | 停止中 → 対象チケット決定（doing 1 枚 → todo 最小連番）→ frontmatter 読めない → 実行者の不一致 → 要点の注入（4 KB 上限）→ 入力不正 | WF801 不一致（通知）/ 802 注入（情報） | additionalContext・終了 0 | SA-T01〜T06（6 本） | チケット frontmatter、`assets/model-aliases.txt`（**未作成**） |
| 11 | `subagent-stop-check` | 案内 | SubagentStop / PostToolUse `Agent` | 停止中 → 検査（doing 残り → 未コミット差分 → 範囲外差分）→ PostToolUse で伝達（対処 3 点を必ず含む）→ 取得失敗 → 入力不正 | WF811 / 812 / 813（通知） | additionalContext + `logs/sessions/<id>/subagent-<agent_id>.json`・終了 0 | SP-T01〜T06（6 本） | `scope.sh`、`git status`、チケット frontmatter |

結論: 11 本とも「判定順の番号付きリスト」「識別子の表」「テスト観点の表」を持ち、実装に必要な粒度がある。空欄（仕様に記載がない項目）は無かった。

### f2. エラー識別子は台帳と一致するが、lib の既定値 `WF009` だけが台帳に無い △注意

根拠: 各仕様の識別子表と `フック共通仕様.md` §6 の台帳、`.claude/hooks/lib/hook-common.sh:23`

- 11 本が使う識別子はすべて台帳の範囲内（`WF101–109` / `201–219` / `301–309` / `401–409` / `501–509` / `601–609` / `701–709` / `801–809` / `811–819` / `901–909` / `911–919`）。**重複は 0 件**
- 一方 `hook-common.sh:23` は `HOOK_DENY_ID="${HOOK_DENY_ID:-WF009}"` と、**台帳に持ち主のいない番号を既定にしている**。台帳は「`x09` は拒否側のフック（1xx〜5xx）だけが持つ」と定めており、`WF009` はどのフックの範囲にも属さない
- `20-common-step-shell-script` 仕様 L92・SS-T04 も「未設定なら `WF009`」を明記しているため、変更するなら仕様 2 か所（共通仕様 §6 の台帳と shell-script 仕様）とテスト SS-T04 が連動する
- 実測への依存: **無し**（設計で決められる）

結論: issue #9 の G7 のとおり。取り得る案は (a) 台帳に `WF009` を「呼び手が設定しなかった場合の共通の判定不能」として登録する、(b) 既定を廃して拒否側フックに `HOOK_DENY_ID` の設定を必須にする（未設定なら `fatal`）、(c) 既定を `WF209`（最も範囲の広い guard）に寄せる。**(a) が最小の変更**で、`hook-common.sh` を変えずに済む。

### f3. テスト ID の重複は無いが、命名に 2 か所の揺れがある △注意

根拠: 各仕様のテスト観点表と、既存テストの grep（`.claude/hooks/tests`・`.claude/hooks/lib/tests`・`.claude/skills/*/scripts/tests`）

- 新規に増える ID は **93 本**（SS-H 9 / WE-T 11 / SG-T 8 / BC-T 6 / BG-T 11 / WG-T 14 / DC-T 7 / PP-T 8 / UR-T 7 / SA-T 6 / SP-T 6）。既存 ID（`AA/BB/CC-T`（ランナーのテスト用ダミー）・`CP-T01〜08`・`FR-T01〜05`・`HK-T02〜T15`・`LG-T01〜05`・`RV-T01〜07`・`SS-T00〜04`・`TR-T01〜05`・`TICKET-T01〜12`）と**文字列としての重複は 0 件**
- 揺れ 1: `session-start` だけテスト ID が `SS-H`（他の 10 本は `-T`）。既存の `SS-T00〜04` が `20-common-step-shell-script` に取られているための回避と読めるが、共通仕様 §6 は「テスト ID は `<接頭辞>-T<2 桁>`」と定めており、`-H` はその規約から外れる
- 揺れ 2: `block-direct-git` のテスト観点表が `BG-T01〜T08 → BG-T09b → BG-T09 → BG-T10` の順に並び、`T09b` という枝番がある。`T09b`（PowerShell のヒアストリング）と `T09`（入力 JSON 不正）は別の観点
- HK-T01（登録照合）と HK-T09（登録ラッパーの deny）は既存テストに**まだ無い**（issue #9 の受け入れ条件 1 が求めるもの）
- 実測への依存: **無し**

結論: 実 ID が重ならないので実装は進められる。規約（`-T` に統一するか、`SS` の持ち主を分けるか）の整理は 3/3 に送る。

### f4. フックが読む設定・アセットのファイルが 3 本未作成で、置き場の規約が揺れている △注意

根拠: 各仕様の参照先と `ls .claude/hooks/config/`（`scope-limits.json` と `task-types.tsv` のみ）

| ファイル | 読むフック | 仕様上の置き場 | 現状 | 初期値 |
|---|---|---|---|---|
| `blocked-commands.txt` | `block-chmod` | `.claude/hooks/config/` | **無し** | `chmod`（`#` はコメント） |
| `entry-skills.txt` | `workflow-entry` | `assets/`（フック配下） | **無し** | `00-workflow-issue-mr-driven` / `00-workflow-quick-request` |
| `model-aliases.txt` | `subagent-start-check` | `assets/`（フック配下） | **無し** | `claude-sonnet-4-5-…` → `sonnet` などの族名対応 |

- 同じ「フックが読む外部データ」なのに、1 本は `config/`、2 本は各フックの `assets/` に置くことになっている。共通仕様 §1 は `.claude/hooks/<NN-Event>/<name>.sh` と `lib/`・`config/` しか定義していないため、`assets/` の位置づけ（フックのディレクトリ直下か、`<NN-Event>/assets/` か）が未定
- `.claude/hooks/config/**` は `scope-limits.json` の `common.confirm` に入るため、作成時に毎回 WF203 の確認が入る（`assets/` 側は `.claude/hooks/**` の許可範囲で確認なし）
- 実測への依存: **無し**

結論: 3 本とも実装フェーズで作る。`assets/` の置き場（`<NN-Event>/assets/<name>/…` か `<NN-Event>/assets/…` か）は実装計画で決め、共通仕様 §1 への追記は書き戻しフェーズに送る。

### f5. `session-start` と `workflow-entry` の一部テストが 3/3 の `boundary.sh` に依存する ✕問題

根拠: `session-start` 仕様「入出力」「制御方式 3」、`workflow-entry` 仕様 WE-T10、issue #9 スコープ外（`finalize.sh` / `boundary.sh` は 3/3）

- `session-start` は現在地の判定を丸ごと `boundary.sh status --offline` に委ねる設計で、**スクリプトが無ければ「何も出さずに終了 0」**（制御方式 3）。したがって本 issue で登録しても実質何も注入しない
- 影響するテスト: SS-H01（6 行の形式）・SS-H02（2 行）・SS-H03（全体計画の途中）・SS-H04（マージ前作業中）・SS-H06（compact でも同じ）・SS-H08（`boundary.sh` と同じ position）の **6 本**。SS-H05（`jq` 不在で無出力）・SS-H07（8 KB 警告）・SS-H09（CLI 非依存）は依存しない
- `workflow-entry` は `boundary.sh` を起動しない設計（ホットパスのため `logs/` を直接読む）なので本体は動くが、**WE-T10**（継続条件の判定が `boundary.sh status --offline` の `position` と食い違わない）だけは比較対象が無く実行できない
- 実測への依存: **無し**（仕様の読み取りだけで確定する）

結論: 受け入れ条件 1「11 本が仕様どおり動き、テストが失敗ケースを含めて通る」を満たすには、この 7 本の扱いを決める必要がある。案: (a) `boundary.sh status --offline` の**最小スタブ**を本 issue で作る（3/3 で本実装に差し替え。スコープが 3/3 に食い込む）、(b) 7 本を「3/3 で通す」と明示して本 issue のテストから外し、issue #9 の完了条件に注記する、(c) テストの中で `boundary.sh` をテスト用の偽実装に差し替える（`PATH` ではなくパス指定で呼ぶ設計なので、テスト時だけ差し替え可能かは実装方式に依存）。**(c) が最も影響が小さい**（`test-lib.sh` に偽 `boundary.sh` を置く仕組みを足す）が、SS-H08 は「本物と同じ判定か」を確かめるテストなので (c) では意味が無く、3/3 に送るしかない。

### f6. §1 の登録表 16 行と各仕様の「呼出条件」は一致している ◎良

根拠: `フック共通仕様.md` §1 の登録表と 11 本の「呼出条件（イベント・matcher・登録）」節

- 16 行の内訳: SessionStart 1 / UserPromptSubmit 1 / PreToolUse 6 / PostToolUse 4 / SubagentStart 1 / SubagentStop 2 / Stop 1
- 11 本のうち複数登録を持つのは 3 本: `workflow-entry`（3 行）・`post-push-usage-report`（3 行）・`subagent-stop-check`（2 行）。11 + 5 = 16 で一致
- PreToolUse の実行順（entry → state-guard → block-chmod → block-direct-git → guard）は、各仕様の「呼出条件」の但し書き（「state-guard の後、block-direct-git の前」など）と矛盾しない
- 唯一の表記の差: `workflow-state-guard` の呼出条件は「書き込み / 実行」とだけ書き、§1 の matcher にある `mcp__.*` に触れていない（制御方式の「外部委任モード」では MCP の draft 解除を拒否すると書いている）。実装には影響しないが、呼出条件の記述としては不足

結論: 登録表は実装時にそのまま `settings.json` へ写せる。HK-T01 はこの 16 行との行単位の照合として書ける。

### f7. 実装に要る外部コマンドは実行環境にそろっている ◎良

根拠: `type jq sha256sum sha1sum openssl`（Windows 10 / Git Bash）

- `jq`（全フック）・`sha256sum`（GitHub の差分アンカー）・`sha1sum`（GitLab の差分アンカー）・`openssl`（代替）はいずれも利用可能
- `shellcheck` は**この環境に無い**（#6 で確認済み。issue #9 の D6 で CI 実行の方針を決める）

結論: `post-push-compact-prompt` の差分ページ内リンク（`sha256(path)` / `sha1(path)`）は追加の依存なしに実装できる。

## 検証の結果

| 検証 | 結果 |
|---|---|
| 11 本の仕様に判定順・識別子・終了方式・テスト ID・依存がそろっているか | そろっている（f1 の表。空欄 0） |
| エラー識別子の重複 | 0 件。台帳の範囲外は `HOOK_DENY_ID` の既定 `WF009` の 1 件のみ（f2） |
| テスト ID の重複（既存 ID との照合） | 0 件（新規 93 本 vs 既存 60 本。f3） |
| §1 の登録表と各仕様の呼出条件の一致 | 一致（16 行 = 11 本 + 複数登録 5 行。f6） |
| 未作成の設定・アセットファイル | 3 本（f4） |
| 3/3（`boundary.sh`）に依存して本 issue で通せないテスト | 7 本（SS-H01〜04・06・08、WE-T10。f5） |

## 設計への反映

1. **`HOOK_DENY_ID` の既定**（f2 / G7）: 台帳（§6）に `WF009` を登録するか、既定を廃するかを決める。決めたら `フック共通仕様.md` §6 と `20-common-step-shell-script` 仕様 L92・SS-T04 を同時に直す（→ `0008` が設計チケットに割り付ける）
2. **`boundary.sh` 依存のテスト 7 本の扱い**（f5）: (a) 最小スタブ / (b) 3/3 へ送る / (c) テスト用の偽実装、のどれを採るか。受け入れ条件 1 の解釈（「11 本が仕様どおり動く」に依存先未実装のテストを含めるか）とセットで決める
3. **設定・アセット 3 本の置き場**（f4）: `assets/` の位置づけを共通仕様 §1 に足すかどうか。実装は仕様の記述どおりに作る
4. **テスト ID の規約**（f3）: `SS-H` と `BG-T09b` を現状維持で進め、規約の統一は 3/3 の課題として残す
5. **`workflow-state-guard` の呼出条件に `mcp__.*` を明記**（f6）: 1 行の追記。書き戻しフェーズで拾う

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 仕様どうしの矛盾が複数見つかる | 識別子・登録表・判定順の矛盾は **0 件**。見つかったのは「未確定の項目」（既定値・置き場・テストの依存）で、仕様どうしの食い違いではなかった | 「矛盾」ではなく「実装前に決めるべき項目」として設計への反映に挙げた |
| テスト ID の重複が起こり得る | 重複 0 件。ただし `SS` 接頭辞が 2 つのアセットで共有され、片方が `-H` で回避していた | f3 に記録し、規約の統一は 3/3 へ |
| `session-start` は `boundary.sh` 不在でも部分的に動く | 制御方式 3 で**丸ごと無出力**になる設計だった（現在地の判定を完全に委譲している） | f5 を ✕問題として挙げ、受け入れ条件 1 との関係を設計の論点にした |

## 残課題

- `boundary.sh status --offline` の出力スキーマ（`mr` / `current` / `next` / `at_boundary` / `last_task` / `review` / `position`）は `00-workflow-issue-mr-driven` 仕様にあるが、**この issue では実装されない**。スタブを作る場合の忠実度をどこまで求めるかは未決（f5 の案 (a) を採る場合の論点）
- `assets/` をフックのどの階層に置くか（`<NN-Event>/assets/` か `<NN-Event>/<name>-assets/` か）は仕様に記述が無く、実装計画で決める必要がある（f4）
- `HOOK_DENY_ID` を設定必須にした場合、`hooks/lib` を読む**提供コマンド側**（フック以外）の挙動が変わらないかは未確認（`hook-common.sh` を source するのはフックだけかを 0006 が確かめる）
- テスト ID の総数 93 本は仕様の表から数えたもので、実装時に観点が分割・統合されれば増減する
