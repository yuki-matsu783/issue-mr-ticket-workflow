---
type: spec
title: 共通 logger 仕様
description: .claude/lib/logger.sh の内部仕様。source して使う関数 API（log_debug / log_info / log_warn / log_error）、行フォーマット、logs/sh/ 配下の出力先、LOG_LEVEL によるレベル制御、失敗時の黙殺を定める
tags: [spec, lib]
keywords: [logger.sh, log_info, log_debug, LOG_LEVEL, logs/sh, 行フォーマット, タイムスタンプ, source, 黙殺, fail-open]
---

# 共通 logger 仕様

## 概要・禁止事項

共通 logger の内部仕様。対応する要件は [00_requirement/lib/logger.md](../../00_requirement/lib/logger.md)。実体は `.claude/lib/logger.sh` で、スクリプト・フックが source して関数を呼ぶ。

禁止事項:

- 標準出力・標準エラーへのログ出力（ファイルのみ。フックの応答・スクリプトの結果出力と混ざらない）
- 書き込み失敗時のエラー伝播（本体を止めない。黙って捨てる）
- 環境変数の値・トークン・クレデンシャル・個人情報のログ出力（書き手の責務。logger はメッセージを加工しない）
- 利用側での独自ログファイルの作成・独自フォーマットの発明

## 呼出条件

- すべてのスキルのスクリプト（`scripts/*.sh`）とフック（`.claude/hooks/**/*.sh`）が、冒頭で source する:

```bash
source "$(git rev-parse --show-toplevel)/.claude/lib/logger.sh"
```

- source 時に `logs/sh/` を（無ければ）作成する。作成に失敗しても source は成功し、以後のログは捨てられる

## IN / OUT

| IN | OUT |
|----|----|
| 関数呼び出し `log_debug\|log_info\|log_warn\|log_error "<メッセージ>"`、環境変数 `LOG_LEVEL`（任意） | `logs/sh/<出どころ>.log` への追記行（呼び出し元には何も返さない・出力しない） |

- 出どころは呼び出し元スクリプトのファイル名（`$0` の basename から拡張子を除いたもの）。上書きしたい場合のみ `LOGGER_NAME` 環境変数で指定できる
- `LOG_LEVEL` の有効値: `DEBUG` / `INFO` / `WARN` / `ERROR`（未設定・無効値は `INFO`）。指定レベル未満の行は書かれない

## IN / OUT サンプル

```bash
log_info "start 0003 を受け付けた"
log_debug "HEAD=5c19f25 doing=empty"   # LOG_LEVEL=DEBUG のときだけ書かれる

# logs/sh/ticket.log
2026-09-01T14:03:12+09:00 [INFO] [ticket] [pid:4172] start 0003 を受け付けた
2026-09-01T14:03:12+09:00 [DEBUG] [ticket] [pid:4172] HEAD=5c19f25 doing=empty
```

## 参照ナレッジ

- `logs/` の位置づけ（gitignore・片付け対象外・唯一の正にしない）: DDR `i0001-28`
- bash の書き方の規約: `rules/`（bash-script ルール）

## Script 処理

`.claude/lib/logger.sh`（source 専用。実行しても何もしない）:

1. **初期化（source 時）**: リポジトリルートを解決し `logs/sh/` を `mkdir -p` する（失敗は無視）。`LOGGER_NAME` があればそれを、無ければ `$0` の basename（拡張子なし）を出どころとする。`LOG_LEVEL` を読み、無効値・未設定は `INFO` に正規化する
2. **行フォーマット**: `<ISO 8601 タイムスタンプ（秒・タイムゾーン付き）> [<LEVEL>] [<出どころ>] [pid:<PID>] <メッセージ>`。改行を含むメッセージは 1 行に畳む（改行を `\n` リテラルに置換）
3. **レベル判定**: DEBUG(10) < INFO(20) < WARN(30) < ERROR(40)。現在のレベル未満の呼び出しは何もせず 0 を返す
4. **書き込み**: `logs/sh/<出どころ>.log` へ追記する。書き込みの失敗（権限・ディスク・ディレクトリ不在）はすべて握りつぶし、関数は常に 0 を返す（`set -e` の利用側を巻き込まない）
5. **提供する関数**: `log_debug` / `log_info` / `log_warn` / `log_error`（各 1 引数。複数引数はスペース連結）

- ローテーションは持たない（`logs/` はローカル限りで、必要なら人間が消す。肥大が問題になったら日付別ファイルへの変更をこの仕様で決める）

### テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| LG-T01 | 正常系 | 既定（LOG_LEVEL 未設定）で INFO が書かれ DEBUG が書かれない |
| LG-T02 | 正常系 | LOG_LEVEL=DEBUG で DEBUG も書かれ、行フォーマット（時刻・レベル・出どころ・pid）が一致する |
| LG-T03 | 異常系 | logs/ が作成不能でも source と関数呼び出しが成功し（終了コード 0）、標準出力・標準エラーに何も出ない |
| LG-T04 | 境界 | 無効な LOG_LEVEL が INFO に正規化される。改行入りメッセージが 1 行になる |
| LG-T05 | 正常系 | LOGGER_NAME による出どころの上書き |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 共通 logger 経由で logs/ 配下・独自方式禁止 | 呼出条件、禁止事項（利用側） |
| メイン: タイムスタンプ・レベル・出どころの自動付与 | Script 処理 2 |
| メイン: 既定は INFO 以上 | Script 処理 1・3（LG-T01） |
| メイン: LOG_LEVEL=DEBUG で DEBUG も出力 | Script 処理 3（LG-T02） |
| 代替: 出力先が無ければ作成 | Script 処理 1 |
| 例外: 書き込み失敗は黙殺し本体を止めない | Script 処理 4（LG-T03） |
| 細部: 標準出力・標準エラーに出さない | 禁止事項（LG-T03） |
| 細部: 機密情報を書かない | 禁止事項（書き手の責務として明記） |
| 細部: gitignore・片付け対象外 | 参照ナレッジ（i0001-28 の logs/ 規定） |
