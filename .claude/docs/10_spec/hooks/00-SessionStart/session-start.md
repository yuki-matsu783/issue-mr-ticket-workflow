---
type: spec
title: session-start フック 仕様
description: セッションの開始・再開・クリア・compact のたびに、ブランチ・issue・MR・チケットの状態・現在地・次に読み込むスキルを boundary.sh status --offline と作業領域から導出して注入するフックの内部仕様。注入の形式（1 項目 1 行）、伝えない項目、MR 未記録・単独実行・破損時の扱い、8 KB 警告、記録を定める
tags: [spec, hook, session-start]
keywords: [SessionStart, 現在地, 注入, boundary.sh status, offline, ブランチ, issue 番号, mr.json, チケット状態, 次のスキル, レビュー待ち, merge_prep, 8KB, サブエージェント, WF701]
---

# session-start フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/00-SessionStart/session-start.md](../../../00_requirement/hooks/00-SessionStart/session-start.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)。

案内側のフック。現在地の判定は `boundary.sh status --offline`（`00-workflow-issue-mr-driven` 仕様「切れ目の判定（正）」。`--offline` は CLI を呼ばず `logs/` と作業領域だけで導出する）に委ね、その結果を日本語 1 項目 1 行に整形して stdout に出す。

禁止事項:

- 独自の現在地判定、リモートへの問い合わせ（default との遅れも見ない）
- ファイルの中身（チケット・計画書・レポート）の注入
- MR 上のレビュー結果・指摘・未返信スレッドの件数や内容の注入
- 手書きの引き継ぎファイルの読み取り・要求
- サブエージェントのセッションへの注入

## 呼出条件（イベント・matcher・登録）

- SessionStart（`source`: `startup` / `resume` / `clear` / `compact` のすべて）
- サブエージェントの開始では何も出さない（入力の `agent_id` の有無、または `CLAUDE_AGENT_ID` 等の環境で判別。判別できなければ出す — メインで欠けるより副作用が小さい）

## 入出力

- 入力: `source`、`session_id`。参照: `git branch --show-current`、`boundary.sh status --offline` の JSON（`mr` / `current` / `next` / `at_boundary` / `last_task` / `review` / `position`）、`logs/merge-state.json`、`wip/00_overall_plan/` の有無
- 出力: stdout に注入テキスト（下記）。無ければ何も出さない

## 制御方式

1. 停止中 → 「機構は停止中（WORKFLOW_ENFORCE=0 / WORKFLOW_SESSION_START_ENFORCE=0）」の 1 行だけ出し、`disabled` を記録
2. `logs/sessions/` の 7 日より古いディレクトリを削除する（失敗は無視）。frontmatter 索引の機構があれば非侵襲的に最新化する（導入前は何もしない）
3. `boundary.sh status --offline` を実行する。**参照するパスは `$HOOK_WORKTREE/.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh`**（提供コマンドはそれを使うスキルの `scripts/` に置く — `00-workflow-issue-mr-driven` 仕様「Script 処理」）。失敗（`jq` / `git` 不在・スクリプト不在）→ 何も出さずに終了 0。不在で無出力に倒れる経路は「壊れても気づきにくい」ので、`hook_record skip` に不在の事実を残す（現行実装の 64 行はこのパスが `.claude/hooks/boundary.sh` になっており、実装フェーズで直す — `00-workflow-issue-mr-driven` 仕様「現行アセットとの差分」の 1 行目）
4. 注入テキストを組み立てる（各行 `- <項目>: <値>`。値が無い項目は「無し」）:

```
[WF701] 現在地（機構が導出）
- ブランチ: feature-12-login-validation（issue #12）
- MR: !13 https://...（記録: logs/mr.json）
- チケット: 未着手の先頭 0005-design-plan / 作業中 無し / 完了の最後 0004-investigation
- 現在地: レビュー待ち（investigation 0003-0004 を 2026-09-01T10:00 に依頼。レビュー結果は boundary.sh complete で取得する）
- 次に読み込むスキル: 00-workflow-issue-mr-driven（レビュー完了の連絡があるまで応答を終える）
- マージ前作業: 無し
```

   - 現在地の文言は `position` の対応: `in_task` → 「タスクの途中（<番号-種類>）」/ `before_request` → 「レビュー依頼前（<種類> <範囲>）」/ `requested` → 「レビュー待ち（依頼時刻・対象）」/ `completed` → 「レビュー済み（指摘の扱いから再開）」/ `merge_prep` → 「マージ前作業中（merge-state: <state>。`finalize.sh release` を再実行）」/ `none` → 下記 5
   - 次に読み込むスキル: 進行中なら常に `00-workflow-issue-mr-driven`（再開の入口）。作業中チケットがあればその type のスキル名も添える。`next.skill` が存在しないスキルなら **WF704**「対応するスキルが無い」と書き、存在するかのように案内しない
   - マージ前作業: `merge-state.json` があれば `state` と draft 解除済みか
5. チケットも MR も無い → 「進行中の作業は無い。依頼ごとに `CLAUDE.md`「作業の振り分け」に従う」の 2 行だけ（default ブランチでも同じ）
6. チケットが無く MR がある → MR の情報と、`requested` / `merge_prep` ならその現在地
7. チケットがあり MR が無い → 「全体計画の途中（issue 確定前）。次は `10-task-overall-plan`」
8. ブランチ名が `feature-<N>-*` / `fix-<N>-*` なのに `logs/mr.json` が無い → **WF703**「MR の記録が無い。`20-common-step-feature-mr` の手順で既存 MR を紐づけ直す（`boundary.sh status` が CLI で再導出する）」
9. 単独実行モード（`review-state.json` の `via: chat` または MR 無しでチケットあり）→ MR「無し（単独実行モード）」
10. 進行状態ファイルが壊れている → **WF702** をその項目に書き、残りは出す
11. 全体が 8 KB を超えたら切り詰めずに先頭に「[警告] 注入が 8 KB を超過」を足す

## エラー識別子とメッセージ

| ID | 種別 | 内容 |
|----|------|------|
| WF701 | 情報 | 現在地の注入（先頭行のタグ） |
| WF702 | 情報 | 進行状態ファイルの破損（該当項目に「破損: <ファイル>」） |
| WF703 | 情報 | MR 未記録（feature ブランチなのに `logs/mr.json` が無い） |
| WF704 | 情報 | `next.skill` に対応するスキルが無い |

## 回復手順

- WF703: `00-workflow-issue-mr-driven` 手順 0 の `boundary.sh status`（CLI あり）で再導出。無ければ `20-common-step-feature-mr` で紐づけ直す
- WF702: 提供コマンド（`boundary.sh status` / `finalize.sh release`）の再導出に任せる。手で直さない（state-guard が拒否する）
- 何も注入されない（依存の故障）: `logs/sh/hook-session-start.log` を確認する。セッションは通常どおり始まる

## 記録（logs/）

- `decisions.jsonl`: `inject`（`note` にブランチ・MR 番号・position・注入バイト数）または `skip`（理由）。注入内容そのものは記録しない
- 実行ログ: `logs/sh/hook-session-start.log`

## テスト観点

**接頭辞は `SE-T`**（旧 `SS-H`）。`run-tests.sh` が結果行から ID を抜き出す正規表現は `^(PASS|FAIL) ([A-Z]{2,6}-[TE][0-9]{2}[a-z]?)` で 3 文字目以降が `T` か `E` に限られるため、`SS-H*` は `--ids` の一覧にも重複検出にも現れない。`SS-T*` は `20-common-step-shell-script` の既存テストが使っているので、`SE-T` に変える（DDR i0009-08）。

| テスト ID | 種別 | 固定する振る舞い | この issue で実施するか |
|-----------|------|----------------|----------------|
| SE-T01 | 正常系（機械） | チケットあり・MR あり・`requested` で、6 行の形式と「レビュー待ち」「応答を終える」が出る | **3/3 へ**（`boundary.sh` 依存） |
| SE-T02 | 正常系（機械） | チケットも MR も無ければ 2 行だけ。default ブランチでも同じ | **3/3 へ**（同上） |
| SE-T03 | 正常系（機械） | チケットあり・MR 無しで「全体計画の途中」と `10-task-overall-plan` | **3/3 へ**（同上） |
| SE-T04 | 正常系（機械） | チケット無し・`merge-state.state=cleaned` で「マージ前作業中」と release の再実行 | **3/3 へ**（同上） |
| SE-T05 | 異常系（機械） | `review-state.json` 破損で WF702 が該当行に出て他の行は出る（前半）。`jq` 不在で無出力・終了 0（後半） | 前半は **3/3 へ**、**後半はこの issue で実施**（`boundary.sh` に依らない） |
| SE-T06 | 正常系（機械） | `source=compact` でも同じ内容。サブエージェントの開始では無出力 | **3/3 へ**（前半）。**後半（サブエージェントの開始で無出力）はこの issue で実施** |
| SE-T07 | 境界（機械） | 8 KB 超で警告行が先頭に付き切り詰めない | **3/3 へ**（8 KB の注入テキストを作れないため） |
| SE-T08 | 正常系（機械） | `boundary.sh status --offline` と同じ position を伝える（両者の結果を同じ入力で比較） | **3/3 へ**（本物との一致が観点なので偽実装では代えられない） |
| SE-T09 | 正常系（機械） | CLI の有無・`GH_TOKEN` の有無で出力が変わらない | **3/3 へ**（`boundary.sh` が無いと両方とも無出力になり、空同士の比較で無意味に通る） |

**この issue で実施するのは SE-T05 の後半と SE-T06 の後半だけ**。理由は 0012 の WE-T10 と同じで、`boundary.sh`（3/3 で実装）が無い環境では「本物と一致するか」という観点が成立せず、偽実装で代えると観点そのものが失われるため。issue #9 の受け入れ条件 1 の「テストが通る」は、この issue で実装するフックのテストを指すと解釈する（DDR i0009-09）。

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 導出して伝える項目 | 制御方式 4 |
| メイン: 導出の元（ブランチ・作業領域・進行状態・全体計画書） | 入出力、`--offline` |
| メイン: 提供コマンドと同じ判定 | 制御方式 3、SE-T08 |
| メイン: 中身を注入しない | 禁止事項 |
| メイン: レビュー結果を伝えず取得を案内 | 制御方式 4（requested の文言） |
| メイン: スキル不在はその旨 | WF704 |
| メイン: 進行中なしの伝え方 | 制御方式 5 |
| メイン: チケット無し・MR あり | 制御方式 6 |
| メイン: チケットあり・MR 無し（全体計画の途中） | 制御方式 7 |
| メイン: 再開は現在地から（レビュー待ちは応答を終える） | 制御方式 4 の文言 |
| メイン: entry と同じ判定の元 | `boundary.sh status --offline` を共有 |
| メイン: 実行環境によらず同じ内容 | 禁止事項（リモート不問合せ）、SE-T09 |
| メイン: サブエージェントには注入しない | 呼出条件 |
| メイン: default との遅れは見ない | 禁止事項 |
| メイン: 8 KB 超は全量 + 警告 | 制御方式 11 |
| メイン: 索引の最新化（導入後） | 制御方式 2 |
| メイン: 記録（要約のみ・機密なし） | 記録 |
| メイン: 日本語 1 項目 1 行 | 制御方式 4 |
| 代替: MR 未記録の案内 | WF703 |
| 代替: 単独実行モード | 制御方式 9 |
| 代替: 緊急停止 | 制御方式 1 |
| 例外: 依存故障は無出力で通す | 制御方式 3 |
| 例外: 進行状態破損は残りを伝える | WF702 |
