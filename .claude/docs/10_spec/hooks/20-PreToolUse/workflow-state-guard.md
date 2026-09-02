---
type: spec
title: workflow-state-guard フック 仕様
description: 進行状態ファイル（logs/ の mr / review-state / review-history / merge-state）とチケットの作業中・完了の置き場への直接操作、draft 解除の直接実行を、作業中チケットの有無を問わず拒否するフックの内部仕様。保護対象の一覧、書き込みを伴う操作の判定、提供コマンド経由の許可、WF30x を定める
tags: [spec, hook, workflow-state-guard]
keywords: [進行状態, state_files, review-state, merge-state, 10_doing, 20_done, 直接操作, git mv, draft 解除, gh pr ready, glab mr update --ready, 提供コマンド, WF301, WF304]
---

# workflow-state-guard フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/20-PreToolUse/workflow-state-guard.md](../../../00_requirement/hooks/20-PreToolUse/workflow-state-guard.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)。

`workflow-guard` と独立に常時働き、提供コマンド以外の経路で進行状態を作る操作を塞ぐ。保護対象は `scope-limits.json` の `common.state_files`（進行状態ファイル）と `wip/10_tickets/10_doing/`・`20_done/`（置き場）、および draft 解除コマンド。遷移の前提条件は判定しない（提供コマンドの責務）。

禁止事項:

- 前提条件の判定の複製（切れ目か・push 済みか等）
- 読み取り（表示・検索・差分）の拒否
- 未着手（`00_todo/`）への作成・編集、作業中チケット本文の編集の拒否（`workflow-guard` の責務）
- 保護対象の一覧をコードに埋めること（設定 `state_files` と置き場の定義を読む）。**ただし設定が読めないときの既定値は例外**（制御方式 0。設定 1 ファイルの破損でロックアウトしないため。DDR i0009-29）

## 呼出条件（イベント・matcher・登録）

- PreToolUse、matcher: 書き込み / 実行 / **`mcp__.*`**（共通仕様 §1 の登録表 PreToolUse の 3 行目。**位置であって実行順ではない** — フックは並列に走る（§1）ので、他のフックが先に判定した前提を置かない）。`mcp__.*` は MCP 経由の draft 解除（`draft:false`）と置き場宛の書き込みを捕まえるために要る
- 作業中チケットの有無・レビュー状態を問わず判定する

## 入出力

- 入力: `tool_name`、`tool_input.file_path`（書き込み）/ `tool_input.command`（実行）。参照: `scope-limits.json` の `common.state_files`
- 出力: deny（WF301〜304、WF309）または許可

## 制御方式

0. **`scope-limits.json` が読めない・解釈できない** → 判定をやめずに、`common.state_files` の**既定値** `logs/mr.json` / `logs/review-state.json` / `logs/review-history.jsonl` / `logs/merge-state.json` にフォールバックして続ける（`notify` で「既定値にフォールバックした」を記録）。置き場（`wip/10_tickets/10_doing/**`・`20_done/**`）と draft 解除の判定は設定に依存しないのでそのまま働く。**このフックは設定の破損では拒否に倒さない** — 倒すと `workflow-guard` が用意した WF210 の復旧経路（`scope-limits.json` 自身への ask 付きの書き込み）が潰れ、設定 1 ファイルの破損が完全なロックアウトになる（並列に走るので deny はどれか 1 つでも出れば成立する。DDR i0009-29）
1. 停止中 → `disabled` を記録して許可
2. **書き込みツール**: 対象パスが
   - `state_files` に一致 → **deny WF301**
   - `wip/10_tickets/10_doing/**` への新規作成（存在しないパスへの Write）→ **deny WF302**。既存ファイルの Edit / Write（本文の更新）は許可
   - `wip/10_tickets/20_done/**` への作成・編集 → **deny WF303**（完了済みは触らない）
   - それ以外 → 許可
3. **実行ツール**: `cmdpos.sh` で実行位置のコマンド列を得て、
   - 提供コマンド（共通仕様 §7-8）→ 許可（`ticket.sh` / `boundary.sh` / `finalize.sh` が唯一の書き換え経路。内部の処理はそもそも見えない）
   - `state_files` のパスが**書き込みを伴う位置**（リダイレクト先、`cp` / `mv` / `rm` / `tee` / `sed -i` / `truncate` / `git checkout --` / `git restore` の対象、`jq ... > file`）に現れる → **deny WF301**。引数以外の位置（`cat`、`grep`、`git diff`、地の文）は許可
   - `mv` / `cp` / `git mv` / `touch` / リダイレクトの**宛先**が `wip/10_tickets/10_doing/` → **deny WF302**、`20_done/` → **deny WF303**
   - `rm` / `git rm` / `mv` / `git mv` の**元**（消える側。`cmdpos_operands` で位置引数を取り、`rm` / `git rm` は全部を元、`mv` は最後を宛先・それ以外を元とする）が `wip/10_tickets/10_doing/**` → **deny WF302**、`20_done/**` → **deny WF303**。作業中の取り消しは `ticket.sh cancel`、完了済みは触らない。**宛先だけでなく元も見る**のは、削除が置き場から状態を消す操作だから（継続条件と先行チケットの判定材料が失われる。DDR i0009-30）
   - `gh pr ready` / `gh pr edit --ready`（引数順を問わず）/ `glab mr update ... --ready` / `glab api ... "draft=false"` / `... /merge_requests/... -X PUT` に `draft` を含む → **deny WF304**（提供コマンド `finalize.sh` 経由のみ）
   - `opaque` / `degraded` で対象語（`state_files` の basename、`10_doing`、`20_done`、`ready`、`draft`）を含む → **deny WF309**。含まなければ許可
4. **MCP ツール**（`mcp__` で始まる `tool_name`）: `mcp__*pull_request*` / `mcp__*merge_request*` で **`draft` を false にする入力** → **deny WF304**。**それ以外の MCP ツールは許可**（このフックが守るのは進行状態ファイル・置き場・draft 解除の 3 つで、MCP ツールがそのうち触り得るのは draft 解除だけ）。MCP ツールは書き込みツールでも実行ツールでもなく `file_path` も `command` も持たないので、制御方式 2・3 のどちらにも当たらない。この分岐が無いと 5 に落ちて**全 MCP 呼び出しが WF309 で拒否**され、外部委任モード（`gh` 不在時のフォールバック）が使えなくなる（DDR i0009-28）
5. 入力不正 → 保護対象に関わり得るか判断できないため **deny WF309**。ただし `tool_input` から対象パスが読め、保護対象と無関係と確定できる操作は許可

- 外部委任モード: 提供コマンド経由の操作は同じく許可。MCP ツールは制御方式 4 のとおり **draft 解除だけを塞ぎ、他は通す**（`mcp__github__get_issue` / `add_issue_comment` / `pull_request_read` などは働き続ける）。MCP 経由の**リモート書き込みの種別**（issue 作成・コメント・MR 編集）を宣言と突き合わせるのはこのフックの責務ではない（`workflow-guard` も強制しない — 共通仕様 §13・DDR i0009-27）

## エラー識別子とメッセージ

| ID | 条件 | メッセージに含める内容 |
|----|------|----------------------|
| WF301 | 進行状態ファイルの編集・削除・復元・上書き | 対象ファイル / 状態は提供コマンドでのみ遷移 / 進めたいなら該当コマンド（`boundary.sh` / `finalize.sh`）/ 前提が満たせないならユーザーに報告 |
| WF302 | 作業中の置き場への直接移動・作成 | 対象 / 着手は `ticket.sh start` |
| WF303 | 完了の置き場への直接移動・作成・編集 | 対象 / 完了は `ticket.sh complete`（全体まとめは `finalize.sh release`）/ 完了済みは触らない |
| WF304 | draft 解除の直接実行 | コマンド / `finalize.sh release` 経由のみ / MCP でも同じ |
| WF309 | 判定不能 | 機構の不調または不透明な実行系 / 言い換えまたは提供コマンドの使用 |

## 回復手順

- 状態を進めたい: 該当の提供コマンドを実行する（前提未充足はそのコマンドが列挙する）。満たせなければユーザーに報告し、ファイルを作って状態を作らない
- 確認を使わず拒否と案内だけで対処するため、ヘッドレスでも AI が提供コマンドで復旧できる

## 記録（logs/）

- `decisions.jsonl` に deny（WF301〜309）を記録（`target` に対象パスまたはコマンドの先頭）。許可は記録しない（ホットパス）
- 実行ログ: `logs/sh/hook-workflow-state-guard.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| SG-T01 | 異常系 | `logs/review-state.json` への Write / Edit / `echo > ` / `rm` / `git checkout --` が WF301。`cat` / `grep` / `git diff` は通る |
| SG-T02 | 異常系 | `mv wip/10_tickets/00_todo/0003.md wip/10_tickets/10_doing/` と `git mv` が WF302、`20_done/` 宛が WF303。**元**が `10_doing/**` の `rm` / `git rm` / `mv` は WF302、`20_done/**` の `rm` は WF303（`wip/tmp/` の `rm` は通る） |
| SG-T03 | 正常系 | `10_doing/` の既存チケットへの Edit（作業ログ）と `00_todo/` への Write が通る |
| SG-T04 | 異常系 | `gh pr ready 13`、`glab mr update 13 --ready`、MCP の draft:false が WF304。`gh pr view` は通る |
| SG-T05 | 正常系 | `bash .claude/skills/20-common-step-ticket/scripts/ticket.sh start 0003` と `finalize.sh release` が通る |
| SG-T06 | 異常系 | `bash -c "... review-state.json ..."` が WF309、対象語を含まない `bash -c` は通る |
| SG-T07 | 正常系 | 作業中チケットが無い状態でも SG-T01〜T04 が同じ結果になる |
| SG-T08 | 正常系 | 地の文・コメント中の `review-state.json` / `ready` では拒否しない |
| SG-T09 | 正常系 | **draft 解除以外の MCP ツール**（`mcp__github__get_issue` / `add_issue_comment` / `pull_request_read`）が**通る**（WF309 に落ちない）。`mcp__github__update_pull_request` の `draft:false` だけが WF304（負のコントロール付き） |
| SG-T10 | 異常系 | `scope-limits.json` が無い・壊れているとき、**拒否に倒さず**既定の `state_files` で判定を続ける。`scope-limits.json` 自身への Write が**このフックを通る**（`workflow-guard` の WF210 の復旧経路を潰さない）。既定値にフォールバックした旨が記録に残る |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 進行状態ファイルの編集・削除・復元・上書きを拒否（ツール・コマンド両方） | 制御方式 2・3、WF301 |
| メイン: 読むだけは拒否しない | 制御方式 3（書き込みを伴う位置のみ） |
| メイン: 提供コマンドの書き換えは許可 | 制御方式 3 |
| メイン: 名前が現れるだけでは拒否しない | 制御方式 3、SG-T08 |
| メイン: 作業中への直接移動・作成の拒否 | WF302 |
| メイン: 完了への直接移動・作成の拒否 | WF303 |
| メイン: 作業中チケット本文の編集は拒否しない | 制御方式 2、SG-T03 |
| メイン: 未着手への作成・編集は拒否しない | 制御方式 2 |
| メイン: draft 解除の直接実行を常に拒否 | WF304 |
| メイン: 提供コマンドの draft 解除は許可 | 制御方式 3 |
| メイン: 記録・識別子・提供コマンドの案内 | 記録、エラー識別子 |
| メイン: 確認ではなく拒否と案内 | 回復手順 |
| 代替: 緊急停止 | 制御方式 1 |
| 代替: 外部委任モード（MCP の draft 解除は拒否） | 制御方式（外部委任モード） |
| 例外: 判定不能は関係しうる操作だけ拒否側 | 制御方式 4、WF309 |
| 例外: 拒否されたら迂回せず提供コマンドか報告 | 回復手順 |
