---
type: spec
title: post-push-usage-report フック 仕様
description: push の成功時に前回 push からの対応工数（トークン・ツール実行回数・応答回数・実作業時間）をセッションの記録（transcript）と蓄積状態から集計し、MR に投稿するレポート本文を組み立てて logs/ に記録し AI に渡すフックの内部仕様。Stop での蓄積、transcript 解析の 1 か所化、boundary.sh による投稿とリセット、WF91x を定める
tags: [spec, hook, post-push-usage-report]
keywords: [PostToolUse, Stop, 対応工数, トークン, ツール実行回数, 応答回数, 実作業時間, transcript, usage.json, 蓄積, 繰り越し, レポート本文, boundary.sh, 通常コメント, WF911]
---

# post-push-usage-report フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/22-PostToolUse/post-push-usage-report.md](../../../00_requirement/hooks/22-PostToolUse/post-push-usage-report.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)。push 検知は `post-push-compact-prompt` の `lib/push-detect.sh` を共有する。

同じスクリプトを 2 つの契機で使う: `--accumulate`（Stop: 応答完了ごとにそのセッションの使用量を `logs/usage/<branch>.json` に蓄積）と既定（PostToolUse: push 成功時に前回 push 以降を集計しレポート本文を `logs/usage/report-<branch>-<count>.md` に書く）。MR への投稿は `boundary.sh request` / `note` が行い（本文を通常コメントとして添える）、投稿成功で `boundary.sh` がリセットの印を書く。

禁止事項:

- AI・ユーザーの申告からの集計
- 評価・推測の記載（事実の数値だけ）
- 投稿の実行（提供コマンドの責務）
- transcript の形式依存を複数箇所に散らすこと（解析は `lib/transcript.sh` の 1 関数）

## 呼出条件（イベント・matcher・登録）

- PostToolUse、matcher `Bash|PowerShell`（compact-prompt の後）: push 検知を通過したとき集計
- Stop: `--accumulate` で蓄積（サブエージェントの Stop は SubagentStop で同じ蓄積を `agent_id` 付きで行う）

## 入出力

- 入力: `transcript_path`、`session_id`、（Stop）`stop_hook_active`。参照: `logs/usage/<branch>.json`（`{"since_sha","since_at","sessions":{"<session_id>":{"input","output","cache_read","cache_write","tool_calls","responses","active_seconds","last_offset"}},"subagents":{...},"posted":false}`）、`logs/push-state.json`、`logs/mr.json`
- 出力: additionalContext（WF911: レポート本文と置き場）、`logs/usage/report-<branch>-<count>.md`

## 制御方式

### `--accumulate`（Stop / SubagentStop）

1. 停止中 → 何もしない
2. `lib/transcript.sh` で `transcript_path` の `last_offset` 以降を読み、assistant メッセージの `usage`（input / output / cache_read_input_tokens / cache_creation_input_tokens）、`tool_use` ブロック数、assistant ターン数、タイムスタンプ列を得る
3. 実作業時間: 連続する assistant / tool_result のタイムスタンプ差を合計し、ユーザー入力待ち（user メッセージ直前の間隔）と 10 分を超える間隔を除く
4. `logs/usage/<branch>.json` の該当セッション（サブエージェントは `subagents[agent_id]`）に加算し `last_offset` を更新する（二重計上防止）。`last_offset` の単位は transcript の**処理済み行数**（空行・壊れた行を含む総行数。`lib/transcript.sh` が返す `new_offset`）
5. 読めない・形式不明 → 何もしない（読めた分だけ加算し `parse_errors` を +1）

### 既定（push 成功時）

1. 停止中 → `disabled` を記録して抜ける。push 検知を通過しなければ抜ける
2. 現在セッションの未蓄積分を `--accumulate` と同じ関数で取り込む（ターン途中の push でも漏らさない）
3. `logs/usage/<branch>.json` を合算し、レポート本文を組み立てる:

```
## 対応工数（AI 集計）
- 集計期間: <since_sha 短縮>（<since_at>）→ <head 短縮>（<now>） / ブランチ <b> / このブランチで <count> 回目の push
- トークン: 入力 12,345 / 出力 6,789 / キャッシュ読取 100,000 / キャッシュ書込 20,000
- ツール実行: 87 回 / 応答: 23 回 / 実作業時間: 1 時間 12 分
- サブエージェント: 2 体分を含む（含められなかった: 無し）
- 注記: <期間の一部が集計できなかった旨 / 状態破損で今回を起点にした旨>
— この集計は Claude Code のセッション記録から機構が機械的に算出したものです
```

4. `logs/usage/report-<branch>-<count>.md` に書き、additionalContext（WF911）で本文と「`boundary.sh request` / `note` が通常コメントとして投稿する（`--usage-report <path>` を渡す）」ことを伝える
5. リセットはしない。`boundary.sh` が投稿に成功したら `posted: true` と `since_sha = head` を書き（`boundary.sh` の責務。usage-report は `posted` を見て次回の起点を決める）、失敗時は `posted: false` のまま次回に繰り越す（本文は再生成し「前回の投稿に失敗したため繰り越し」を注記）
6. 状態が壊れている → 今回の push を起点として作り直し、注記を添える（WF913）
7. 単独実行モード（MR 無し）→ 組み立てと記録まで行い「投稿先が無い」を注記
8. transcript が読めない → 何もしない（WF912 を記録のみ）

## エラー識別子とメッセージ

| ID | 種別 | 内容 |
|----|------|------|
| WF911 | 情報 | レポート本文と投稿の案内 |
| WF912 | 情報 | 記録が読めない（集計なし。記録のみ） |
| WF913 | 情報 | 状態破損（今回を起点に再開。レポートに注記） |

## 回復手順

- 投稿失敗: 次回 push で繰り越される。手で `usage.json` を直さない（`logs/` の直接編集は state_files に含めないが、集計の正確性が失われるため）
- 集計漏れの疑い: `logs/sh/hook-post-push-usage-report.log` の `parse_errors` を確認

## 記録（logs/）

- `logs/usage/<branch>.json`、`logs/usage/report-<branch>-<count>.md`
- `decisions.jsonl`: `inject`（WF911。`note` に集計値の要約）/ `skip`（WF912）
- 実行ログ: `logs/sh/hook-post-push-usage-report.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| UR-T01 | 正常系 | 固定の transcript から集計値（4 指標）が期待値と一致し、桁区切り・「H 時間 M 分」で本文が出る |
| UR-T02 | 正常系 | `--accumulate` を 2 回呼んでも二重計上されない（`last_offset`） |
| UR-T03 | 正常系 | 2 セッション分の蓄積が合算され、サブエージェント分が含まれる |
| UR-T04 | 正常系 | `posted:false` のまま次の push でレポートに繰り越しの注記が付く。`posted:true` なら `since_sha` から |
| UR-T05 | 異常系 | 状態破損で WF913 と今回起点、transcript 不読で無出力・終了 0 |
| UR-T06 | 正常系 | MR 無しで「投稿先が無い」注記 |
| UR-T07 | 正常系 | push 以外では何もしない（push-detect を共有） |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: push 成功で働く（検知は compact-prompt と同じ） | 呼出条件、push-detect |
| メイン: 失敗・他コマンドは何もしない | 既定 1 |
| メイン: 4 指標の集計 | `--accumulate` 2・3 |
| メイン: 蓄積状態と transcript から（申告不可）・一部欠落の注記 | 禁止事項、既定 3 |
| メイン: サブエージェント分 | `--accumulate`（SubagentStop）、本文 |
| メイン: ターン途中の push も反映 | 既定 2 |
| メイン: 投稿完了までリセットしない・コミット対象外 | 既定 5、logs/ |
| メイン: 応答完了・終了時の蓄積（別契機・登録） | `--accumulate`、呼出条件 |
| メイン: レポート本文の項目と署名 | 既定 3 |
| メイン: 提供コマンドが通常コメントとして投稿 | 既定 4・5（boundary.sh） |
| メイン: 成功でリセット・失敗で繰り越し | 既定 5 |
| メイン: 桁区切り・時間表記 | 既定 3、UR-T01 |
| メイン: 記録（トークン文字列なし） | 記録 |
| 代替: 単独実行モード | 既定 7 |
| 代替: 緊急停止 | 既定 1 |
| 例外: transcript 不読 | 既定 8、WF912 |
| 例外: 状態破損 | 既定 6、WF913 |
