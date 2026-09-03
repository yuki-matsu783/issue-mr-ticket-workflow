---
type: spec
title: workflow-entry フック 仕様
description: 振り分けスキルの読み込み（宣言）をプロンプトごとに強制するフックの内部仕様。UserPromptSubmit でのリセットとスラッシュ起動の扱い、PreToolUse(Skill) での宣言の記録、未宣言時の拒否、継続条件（チケットの存在・レビュー待ち・マージ前作業中）の判定順、WF10x、記録を定める
tags: [spec, hook, workflow-entry]
keywords: [振り分け, 宣言, UserPromptSubmit, Skill, 拒否, 継続条件, チケット存在, レビュー待ち, merge-state, entry.json, WF101, WF102, WF109]
---

# workflow-entry フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/10-UserPromptSubmit/workflow-entry.md](../../../00_requirement/hooks/10-UserPromptSubmit/workflow-entry.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)。

プロンプトごとに「振り分けスキルが Skill ツールで読み込まれたか」を `logs/sessions/<session_id>/entry.json` に記録し、未宣言のまま書き込み・実行・プランモード・起動が試みられたら拒否する。`00-workflow-issue-mr-driven` の作業が進行中（継続条件）なら宣言を問わず通す。

禁止事項:

- 宣言の有無以外の判定（範囲は `workflow-guard`、進行状態は `workflow-state-guard`）
- コマンドの中身の分類（実行ツールは読み取り目的でも宣言が要る）
- リモートへの問い合わせ、会話内容を材料にした判定
- 継続条件の独自の規則（判定規則は `00-workflow-issue-mr-driven` 仕様「切れ目の判定（正）」と同じものを使う。毎ツール呼び出しのホットパスなので `boundary.sh` は起動せず同じファイルを直接読み、結果が一致することをテスト WE-T10 で固定する）

## 呼出条件（イベント・matcher・登録）

| 登録 | matcher | 役割 |
|---|---|---|
| UserPromptSubmit | — | `prompt_seq` を +1 し `declared_skill` を空にする。プロンプト 1 行目が `/00-workflow-issue-mr-driven` または `/00-workflow-quick-request`（引数付き可）なら宣言として記録する |
| PreToolUse | `Skill` | `tool_input.skill` が振り分けスキル名（`.claude/hooks/config/entry-skills.txt`: `00-workflow-issue-mr-driven` / `00-workflow-quick-request`。`CLAUDE.md`「作業の振り分け」の表と同一 — テスト WE-T07 で照合）なら `declared_skill` に記録する。Skill ツール自体は常に許可。**振り分けスキル名の正はこのファイルで、照合を行うのはこのフック**。`hook-common.sh` の `tool_class` は「ツールの種類の分類」までを返す関数であり、スキル名の照合には使わない（`00-workflow-` の接頭辞判定を分類の根拠にすると、将来 `00-workflow-` で始まる別のスキルが増えたときにファイルとコードで判定が食い違う。DDR i0009-03） |
| PreToolUse | 書き込み / 実行 / プランモード / 起動（共通仕様 §2 の分類）+ **`mcp__.*`** | 宣言と継続条件を判定し、未宣言なら拒否。**MCP ツールを含めるのは、宣言の有無の判定にツールの種類が要らないから**（何をする MCP ツールかを分類できなくても「振り分けを宣言したか」は判定できる）。MCP 経由のリモート書き込みの**種別**の強制は行わない（`workflow-guard` の責務外。共通仕様 §13・DDR i0009-27） |

## 入出力

- 入力: 共通（`session_id`、`tool_name`、`tool_input`、`prompt`）。参照: `wip/10_tickets/{00_todo,10_doing,20_done}/`（ファイルの存在だけ。git の追跡状態は見ない）、`logs/review-state.json`、`logs/merge-state.json`、`logs/sessions/<session_id>/entry.json`
- 出力: PreToolUse で deny（WF101 / WF102 / WF109）または許可。UserPromptSubmit では出力なし（記録のみ）

## 制御方式

PreToolUse（書き込み / 実行 / プランモード / 起動）での判定順:

1. 停止中（`WORKFLOW_ENFORCE=0` / `WORKFLOW_ENTRY_ENFORCE=0`）→ `disabled` を記録して許可
2. **継続条件**（宣言より先に評価。理由を記録の `note` に残す）:
   - `wip/10_tickets/00_todo` / `10_doing` / `20_done` のいずれかに `.md` がある → 許可（`continuation: tickets`）
   - チケットが無く `logs/review-state.json` の `state` が `requested` → 許可（`review`）
   - チケットが無く `logs/merge-state.json` の `state` が `started` / `cleaned` / `pushed` → **宣言が無くても**許可するのは、提供コマンド `finalize.sh`（release の再実行）と `boundary.sh`（`status` による現在地の確認）の実行だけ（共通仕様 §7-8 の識別）。それ以外の操作はこの分岐では決めず 3〜4 の宣言の判定に進む（宣言があれば通常どおり許可、無ければ WF101 で「再宣言するか、`finalize.sh release` を再実行する」を案内）。継続条件は緩和であって、宣言済みより厳しくはしない
   - 上記のどれにも当たらないが `20_done/` にだけチケットがある状態も `tickets` として通す（要件どおり。無宣言の窓になることは共通仕様 §13 の意図的な緩和）
3. `entry.json` を読む（`hook_read_state`。`session_id` に依存するパスなので **`jq` の 2 回目**になる — §1・DDR i0009-46）。無い・壊れている（`HC_ENTRY_STATE` が `missing` / `broken`）→ 未宣言として扱う（WF102。継続条件は 2 で評価済み）
4. `declared_skill` が空 → **deny WF101**。理由: 「このプロンプトでは振り分けが宣言されていない。Skill ツールで `00-workflow-issue-mr-driven` または `00-workflow-quick-request` を読み込んでから、元の操作をやり直すこと」
5. 宣言あり → 許可（他の判定は行わない）
6. 入力が解釈できない・`jq` が無い → **deny WF109**（機構の不調を明記）

- サブエージェント内の呼び出しは同じ `session_id` の記録を使うため、改めて宣言を求めない
- ヘッドレスでも同じ（確認は使わない。拒否と案内で AI が Skill ツールで復旧できる）

## エラー識別子とメッセージ

| ID | 条件 | メッセージに含める内容 |
|----|------|----------------------|
| WF101 | 未宣言で対象ツールを使おうとした（マージ前作業中の再実行以外を含む） | 未宣言であること / 読み込むべき 2 つのスキル名 / 読み込んでから元の操作をやり直すこと / 継続中なら許される操作（`finalize.sh release` の再実行） |
| WF102 | `entry.json` が無い・壊れている | 記録が無いため未宣言として扱ったこと（対処は WF101 と同じ） |
| WF109 | 入力不正・依存不足 | 機構の不調であること / 対処（`jq` の確認、ユーザーへの報告） |

## 回復手順

- WF101 / WF102: Skill ツールで振り分けスキルを読み込む（フックが記録する）→ 元の操作を再実行。緊急停止・別手段での迂回はしない
- 停止したい場合: ユーザーが新しいセッションで `WORKFLOW_ENTRY_ENFORCE=0`（またはWORKFLOW_ENFORCE=0）を設定する。AI は設定しない

## 記録（logs/）

- `logs/sessions/<session_id>/entry.json`（共通仕様 §5）: プロンプトごとに `prompt_seq` / `declared_skill` / `declared_at` / `continuation`
- `decisions.jsonl`: 宣言の記録（`decision: inject` 相当は使わず `note: declared <skill>`）、許可（継続の根拠を `note`）、拒否（WF101 / 102 / 109）、停止中（`disabled`）
- 実行ログ: `logs/sh/hook-workflow-entry.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| WE-T01 | 正常系 | UserPromptSubmit で `prompt_seq` が進み宣言が消える。フォローアップ（「はい」）でも消える |
| WE-T02 | 正常系 | PreToolUse(Skill) で振り分けスキルを読むと宣言が記録され、以後の Write / Bash が通る |
| WE-T03 | 異常系 | 未宣言の Write / Bash / EnterPlanMode / Agent が WF101。Read / Grep は通る |
| WE-T04 | 正常系 | プロンプト 1 行目のスラッシュ起動が宣言として扱われる |
| WE-T05 | 正常系 | チケットが 1 枚でも（未追跡でも）あれば未宣言でも通り、`note` に `tickets` が残る |
| WE-T06 | 境界 | チケット無し + `review-state.state=requested` で通る。`merge-state.state=cleaned` で `finalize.sh release` だけ通り、Write は WF101 |
| WE-T07 | 正常系 | `.claude/hooks/config/entry-skills.txt` と `CLAUDE.md` の表のスキル名が一致する |
| WE-T11 | 異常系 | 未宣言のセッションで MCP ツール（`mcp__github__add_issue_comment`）が WF101 で拒否される。宣言後は通る（種別の判定は行わない） |
| WE-T08 | 異常系 | `entry.json` 破損で WF102、`jq` 不在で WF109 |
| WE-T09 | 正常系 | 別の `session_id` の宣言が効かない |
| WE-T10 | 正常系 | 継続条件の判定が、同じ作業領域・`logs/` に対する `boundary.sh status --offline` の `position` と食い違わない。**`boundary.sh` は 3/3 で実装するため、この観点は 3/3 に送る**（両方が無出力になる空同士の比較では意味が無く、偽実装で代えると「本物と一致するか」という観点そのものが失われる。issue #9 の受け入れ条件 1 の「テストが通る」は、この issue で実装するフックのテストを指す。DDR i0009-04） |
| WE-T11 | 正常系 | `merge-state.state=cleaned` で宣言済みなら Write も通り、未宣言でも `boundary.sh status` は通る |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: プロンプトごとに宣言を無効化・再要求 | 呼出条件（UserPromptSubmit） |
| メイン: Skill ツールの読み込みを宣言として記録 | 呼出条件（PreToolUse Skill） |
| メイン: スラッシュ起動を宣言として扱う | 呼出条件（UserPromptSubmit） |
| メイン: 未宣言の書き込み・実行・プランモード・起動を拒否し案内 | 制御方式 4、WF101 |
| メイン: 読み取り専用は拒否しない・コマンドは中身を分類しない | 呼出条件（対象ツール）、禁止事項 |
| メイン: 宣言済みなら他の判定をしない | 制御方式 5 |
| メイン: チケットがあれば継続（ファイルの存在で判定） | 制御方式 2 |
| メイン: レビュー待ちの継続 | 制御方式 2 |
| メイン: マージ前作業中は再実行だけ許可・再宣言不要 | 制御方式 2 |
| メイン: 継続の根拠を記録 | 記録（`note`） |
| メイン: 継続中で作業中チケット無しのとき書き込みを一律拒否しない | 制御方式 2（許可）、他フックの責務 |
| メイン: 振り分けスキル名は CLAUDE.md と一致 | 呼出条件、WE-T07 |
| メイン: サブエージェントに再宣言を求めない | 制御方式（session_id） |
| メイン: 識別子と対処 | エラー識別子 |
| メイン: 判定の記録 | 記録 |
| 代替: 緊急停止 | 制御方式 1、回復手順 |
| 代替: 記録破損は未宣言扱い | 制御方式 3、WF102 |
| 例外: ヘッドレスは拒否と案内で復旧 | 制御方式（確認を使わない） |
| 例外: 拒否されたら読み込んでやり直す・迂回しない | 回復手順 |
