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

案内側のフック。同じスクリプトを 2 つのイベントに登録する: SubagentStop（検査して `logs/` に記録）と PostToolUse `Agent`（メインエージェント側で直前の記録を additionalContext として伝える。加えて `subagent-start-check` の WF801 記録も再掲する）。検査はいずれも同じ関数。

WF801 の再掲は**縮退時の唯一の通知経路**であり、通常経路では出さない（同じ不一致を 2 回通知しない。DDR i0009-31）。**再掲の条件**: 同じ `agent_id`（取れなければ同じセッションの直近）について、`decisions.jsonl` に `subagent-start-check` の WF801 の `notify` 記録が**無い**とき（= PreToolUse の経路が使えず縮退しているとき）だけ再掲する。実行者の不一致の検知は `subagent-start-check` が PreToolUse `Agent` で起動前に行う（DDR i0009-06）。PreToolUse の経路が使えない縮退のときだけ、この再掲が唯一の通知経路になる。

禁止事項:

- チケットの移動・完了、差分の巻き戻し
- 異常の断定（実態の報告として書き、判断は AI に委ねる）
- 結果報告の真偽の判定
- 独自の許可範囲（`scope.sh` を使う）

## 呼出条件（イベント・matcher・登録）

- SubagentStop（全サブエージェント）: 検査 → `logs/sessions/<session_id>/subagent-<agent_id>.json` に結果を記録
- PostToolUse、matcher `Agent`: 直近の記録（`tool_response` の `agent_id` に対応するもの。無ければ最新）を読み、該当があれば additionalContext で伝える。記録が無ければその場で検査する

## 入出力

- 入力: `agent_id`、`agent_transcript_path`（使わない）/ PostToolUse では `tool_response`。参照: `wip/10_tickets/10_doing/`、`git status --porcelain -z`、作業中（または直近で完了）チケットの frontmatter、`scope-limits.json`
- 出力: PostToolUse `Agent` の additionalContext（WF811 / 812 / 813、WF801 の再掲）

## 制御方式

1. 停止中 → `disabled` を記録して何もしない
2. 検査（SubagentStop 時、または PostToolUse で記録が無いとき）:
   - `10_doing/` に `.md` がある → **WF811**（番号・種類・作業ログ「現在地」の有無）
   - `git status` に未コミットの変更・未追跡がある（`logs/**`、`wip/tmp/**` を除く）→ **WF812**（パス一覧。件数が 20 を超えれば先頭 20 件 + 件数）
   - 作業中チケットがあり、その差分に `scope.sh` で deny / 未承認 ask となるパスがある → **WF813**
   - いずれも無ければ「該当なし」を記録し、何も伝えない
3. PostToolUse `Agent` で伝えるとき、文面に必ず含める: 「サブエージェントの結果報告と突き合わせること」「完了していれば `ticket.sh complete` で完了の手続きを行うこと（サブエージェントが完了まで行う運用なら作業中のまま残るのは異常）」「失敗・中断なら作業中のまま残ったチケットをユーザーに報告し、勝手に完了にしないこと」
4. 作業領域・差分の取得に失敗 → 何も伝えない
5. 入力不正 → 何もしない（終了処理を止めない）

## エラー識別子とメッセージ

| ID | 種別 | 内容 |
|----|------|------|
| WF811 | 通知 | 作業中のまま残ったチケット（番号・種類・現在地の有無）+ 対処 3 点 |
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
