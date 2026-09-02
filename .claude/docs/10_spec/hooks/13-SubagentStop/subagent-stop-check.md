---
type: spec
title: subagent-stop-check フック 仕様
description: サブエージェント終了時に、作業中のまま残ったチケット・未コミットの差分・許可範囲外の差分を検知してメインエージェントに実態として伝えるフックの内部仕様。SubagentStop での記録と PostToolUse(Agent) での通知経路、scope.sh の共有、WF81x を定める
tags: [spec, hook, subagent-stop-check]
keywords: [SubagentStop, PostToolUse Agent, 作業中のまま, 未コミット, 未追跡, 許可範囲外, scope.sh, 結果報告との突き合わせ, 勝手に完了しない, WF811, WF812, WF813]
---

# subagent-stop-check フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/13-SubagentStop/subagent-stop-check.md](../../../00_requirement/hooks/13-SubagentStop/subagent-stop-check.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)（§3 通知経路、§8 scope.sh）。

案内側のフック。同じスクリプトを 2 つのイベントに登録する: SubagentStop（検査して `logs/` に記録）と PostToolUse `Agent`（メインエージェント側へ additionalContext で伝える）。検査はいずれも同じ関数。**PostToolUse `Agent` は既定では起動直後に発火する**（サブエージェントは既定で background。§2・DDR i0009-50）ので、この経路の振る舞いは `tool_response.status` で分かれる。

実行者の不一致の検知は `subagent-start-check` が PreToolUse `Agent` で行う（DDR i0009-06）。**PreToolUse の経路が使えない縮退のときだけ、このフックが WF801 を出す**（同じ不一致を 2 回通知しない。DDR i0009-31）。これは**再掲ではなく、このフックが自分で判定する**（縮退時は再掲する元の記録が存在しないため。DDR i0009-52）。

**縮退かどうかの判定**: `subagent-start-check` は PreToolUse `Agent` で**通知しなかった場合も `decisions.jsonl` に `skip`（理由つき）を記録する**（DDR i0009-52）。したがって同じ `agentId` について `subagent-start-check` の記録が **1 件も無い**ときだけが縮退である（`notify` があれば通知済み、`skip` があれば通知不要と判定済み）。

禁止事項:

- チケットの移動・完了、差分の巻き戻し
- 異常の断定（実態の報告として書き、判断は AI に委ねる）
- 結果報告の真偽の判定
- 独自の許可範囲（`scope.sh` を使う）

## 呼出条件（イベント・matcher・登録）

- SubagentStop（全サブエージェント）: 検査 → `logs/sessions/<session_id>/subagent-<agent_id>.json` に結果を記録（この経路の出力はメインエージェントに届かない。§12 T1）
- PostToolUse、matcher `Agent`: **`tool_response.status` で分岐する**（§2・DDR i0009-51）
  - `completed`（foreground で走り終わった）: 直近の記録（`tool_response.agentId` に対応するもの。無ければ最新）を読み、該当があれば additionalContext で伝える。記録が無ければその場で検査する
  - `async_launched`（background へ移った＝**まだ作業していない**）: **作業後の検査（WF811〜813）を行わない**。行うと作業前の作業領域を見ることになる。代わりに **WF814** で「background 起動なので完了後の検査は届かない」ことを伝える。WF801 の縮退判定（下記）はこの経路でも行う

## 入出力

- 入力: SubagentStop では `agent_id`・`agent_transcript_path`（使わない）/ PostToolUse では `tool_input`（`subagent_type`・`model`）と `tool_response`（**`status`**・**`agentId`**。camelCase。§2・DDR i0009-53）。参照: `wip/10_tickets/10_doing/`、`git status --porcelain -z`、作業中（または直近で完了）チケットの frontmatter、`scope-limits.json`、`decisions.jsonl`（`subagent-start-check` の記録の有無）、`.claude/hooks/config/model-aliases.txt`（縮退時の実行者の比較に使う）
- 出力: PostToolUse `Agent` の additionalContext（WF811 / 812 / 813、WF801 の再掲）

## 制御方式

1. 停止中 → `disabled` を記録して何もしない
2. **WF801 の縮退判定**（PostToolUse `Agent` のときだけ。`status` を問わない）: `decisions.jsonl` に同じ `tool_response.agentId` についての `subagent-start-check` の記録（`notify` / `skip` のいずれか）が **1 件も無い**とき、このフックが自分で判定する — `tool_input.subagent_type` が `task-executor` で、対象チケットの `executor` が `main` 以外で、`tool_input.model` が特定でき、`model-aliases.txt` で正規化して不一致なら **WF801**。記録があるときは何もしない（DDR i0009-52）
3. 検査（SubagentStop 時、または PostToolUse で `status` が `completed` かつ記録が無いとき）:
   - `10_doing/` に `.md` がある → **WF811**（番号・種類・作業ログ「現在地」の有無）
   - `git status` に未コミットの変更・未追跡がある（`logs/**`、`wip/tmp/**` を除く）→ **WF812**（パス一覧。件数が 20 を超えれば先頭 20 件 + 件数）
   - 作業中チケットがあり、その差分に `scope.sh` で deny / 未承認 ask となるパスがある → **WF813**
   - いずれも無ければ「該当なし」を記録し、何も伝えない
4. PostToolUse `Agent` で伝えるとき、文面に必ず含める: 「サブエージェントの結果報告と突き合わせること」「完了していれば `ticket.sh complete` で完了の手続きを行うこと（サブエージェントが完了まで行う運用なら作業中のまま残るのは異常）」「失敗・中断なら作業中のまま残ったチケットをユーザーに報告し、勝手に完了にしないこと」
5. 作業領域・差分の取得に失敗 → 何も伝えない
6. 入力不正 → 何もしない（終了処理を止めない）

## エラー識別子とメッセージ

| ID | 種別 | 内容 |
|----|------|------|
| WF811 | 通知 | 作業中のまま残ったチケット（番号・種類・現在地の有無）+ 対処 3 点 |
| WF814 | 通知 | サブエージェントが **background で起動された**（`tool_response.status` が `async_launched`）ため、完了後の検査（WF811〜813）はメインエージェントに届かない。タスクの実施者は `run_in_background: false` で起動し直すか、完了を確かめてから自分で作業領域を確認すること |
| WF812 | 通知 | 未コミットの差分・未追跡（パス一覧）+ 対処 |
| WF813 | 通知 | 許可範囲外のパスに残る差分（パス一覧）+ 復旧は `workflow-diff-check` の指示と同じ |

## 回復手順

- 結果報告と突き合わせ、完了なら `ticket.sh complete`、失敗・中断なら `00-workflow-issue-mr-driven` 手順 2-6（報告して指示を待つ）。範囲外の差分は基準点へ戻す

## 記録（logs/）

- `logs/sessions/<session_id>/subagent-<agent_id>.json`: 検査結果（`checked_at`、`findings[]`）
- `decisions.jsonl`: `notify`（WF811〜813）/ `skip`（該当なし・取得失敗）
- 実行ログ: `logs/sh/hook-subagent-stop-check.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| SP-T01 | 正常系 | 作業中なし・差分なしで何も伝えない |
| SP-T02 | 異常系 | `10_doing/` に 1 枚残ると WF811 と対処 3 点 |
| SP-T03 | 異常系 | 未コミット 3 件（うち `logs/` 1 件）で WF812 に 2 件だけ列挙 |
| SP-T04 | 異常系 | 禁止範囲のパスに差分があると WF813 |
| SP-T07 | 正常系 | `tool_response.status` が **`async_launched`** のとき、`10_doing/` にチケットが残り未コミット差分があっても **WF811〜813 を出さず**、代わりに **WF814** を出す。`completed` のときは従来どおり WF811〜813 を出す（同じ作業領域での対照） |
| SP-T08 | 正常系 | **縮退時に自分で判定する**: `decisions.jsonl` に `subagent-start-check` の記録が 1 件も無く、`tool_input.subagent_type` が `task-executor`・チケットの `executor` が `sub-opus`・`tool_input.model` が `sonnet` のとき **WF801** が出る。`skip` の記録があるとき / `notify` の記録があるときは**出ない**（負のコントロール 2 件）。`tool_response.agentId`（camelCase）で記録を引くこと — `agent_id` では引けない |
| SP-T05 | 正常系 | SubagentStop で記録し、PostToolUse(Agent) で同じ内容が additionalContext に出る。**WF801 の再掲は縮退時だけ**: `subagent-start-check` の WF801 の `notify` 記録が `decisions.jsonl` に**ある**とき（通常経路）は再掲**しない**、**無い**とき（PreToolUse の経路が使えない縮退）だけ再掲する |
| SP-T06 | 正常系 | `git` 不在で無出力・終了 0 |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 作業中残り・未コミット・範囲外差分の検知と通知 | 制御方式 2、WF811〜813 |
| メイン: 該当なしは何も伝えない | 制御方式 2 |
| メイン: 対処 3 点を含める | 制御方式 3 |
| メイン: 実態の報告として書く | 禁止事項、制御方式 3 |
| メイン: 破壊的操作をしない | 禁止事項 |
| メイン: 記録（振り返り用）・識別子・対象の明記 | 記録、エラー識別子 |
| 代替: 緊急停止 | 制御方式 1 |
| 例外: 取得失敗・入力不正は通す | 制御方式 4・5 |
| 前提: メインエージェント側で動かす | 呼出条件（PostToolUse Agent） |
