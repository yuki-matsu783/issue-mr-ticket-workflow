---
type: spec
title: 20-common-step-shell-script スキル 仕様
description: sh ファイル作成の共通ステップの内部仕様。雛形（script / test）の構成、作成手順と検査、共通 logger（scripts/logger.sh）の関数 API・行フォーマット・出力先・レベル制御・失敗時の黙殺、テスト観点を定める
tags: [spec, skill, common-step]
keywords: [shell-script, logger.sh, log_info, log_debug, LOG_LEVEL, logs/sh, 行フォーマット, 雛形, bash -n, shellcheck, テスト]
---

# 20-common-step-shell-script スキル 仕様

## 概要・禁止事項

シェルスクリプト作成の共通ステップの内部仕様。対応する要件は [00_requirement/skills/20-common-step-shell-script.md](../../00_requirement/skills/20-common-step-shell-script.md)。

共通 logger の実体は `.claude/skills/20-common-step-shell-script/scripts/logger.sh`。**logger の内部仕様（関数 API・行フォーマット・出力先・失敗時の振る舞い）はこの仕様が正**で、`rules/logger.md` は sh を書く AI 向けの要点（使用義務・使い方・レベルの使い分け・禁止事項）を持つ。

禁止事項:

- 白紙からの sh 作成（雛形をコピーする）
- logger のコピーや独自ログ方式（source して使う）
- ログの標準出力・標準エラーへの出力（logger はファイルにのみ書く）
- テストの無効化・期待値の書き換えによる合格
- 利用中の logger の変更（AI アセットのフェーズで、全利用者の回帰テストとともに行う）

## 呼出条件

- `20-common-step-ai-asset-creator` がスクリプト・フックを含むアセットを作成・変更するとき
- フックの実装、既存スクリプトの変更のとき

## IN / OUT

| IN | OUT |
|----|----|
| 対象スクリプトの仕様書（インターフェース・判定順・エラー識別子・テスト観点）、置き場所（スキルの `scripts/` またはフックのイベントディレクトリ） | 雛形由来の sh、対応するテスト（`scripts/tests/` またはフックのテストディレクトリ）、検査結果とテスト結果（作業ログ） |

## IN / OUT サンプル

```bash
# 雛形から作成
cp .claude/skills/20-common-step-shell-script/assets/script.template.sh .claude/skills/20-common-step-ticket/scripts/ticket.sh
cp .claude/skills/20-common-step-shell-script/assets/test.template.sh  .claude/skills/20-common-step-ticket/scripts/tests/test_ticket.sh

# 作成した sh の冒頭（雛形に含まれる）
source "$(git rev-parse --show-toplevel)/.claude/skills/20-common-step-shell-script/scripts/logger.sh"
log_info "start 0003 を受け付けた"
log_debug "HEAD=5c19f25 doing=empty"   # LOG_LEVEL=DEBUG のときだけ書かれる

# logs/sh/ticket.log
2026-09-01T14:03:12+09:00 [INFO] [ticket] [pid:4172] start 0003 を受け付けた
2026-09-01T14:03:12+09:00 [DEBUG] [ticket] [pid:4172] HEAD=5c19f25 doing=empty
```

## 処理フロー

1. 対象の仕様書を読み、インターフェース・判定順・エラー識別子・テスト観点を確認する（無ければ設計が先として返す）
2. `assets/script.template.sh` を置き場所へコピーし、雛形の `{{名前}}` を埋める（雛形は shebang・`set -euo pipefail`・logger の source・引数解析の骨格・`OK:` / `<ID>:` の結果出力の型を含む）
3. bash 規約（`rules/` bash-script）と logger ルールに従って実装する。ログはレベルの使い分けに従う
4. `assets/test.template.sh` からテストを作り、仕様書のテスト ID ごとにケースを書く（正常系・境界・異常系）。実行して結果を作業ログに残す。既存テストも回帰させる
5. 検査: `bash -n` による構文検査、`shellcheck` が導入されていれば静的検査。結果を作業ログに残す（shellcheck 不在なら省略の事実を記録）
6. 既存 sh の変更では 2 を行わず、既存構成に合わせて差分を小さくする

## OUT ひな形

- `assets/script.template.sh`: shebang（`#!/usr/bin/env bash`）、`set -euo pipefail`、リポジトリルートの解決、logger の source、`usage` 関数、サブコマンド／オプションの解析骨格（順不同）、結果出力の型（成功 `OK: ...` / 失敗 `<接頭辞><番号>: ...` を最終行に）、終了コードの規約（0 / 1 / 2）
- `assets/test.template.sh`: テストの骨格（一時ディレクトリの用意と後始末、ケース関数の型、`assert_eq` / `assert_exit` の最小ヘルパ、全ケースの集計と非 0 終了）

## 参照ナレッジ

- bash 規約の中身: `rules/`（bash-script ルール）
- ログの規約（使用義務・使い分け・禁止）: `rules/logger.md`
- `logs/` の位置づけ: DDR `i0001-28`
- 呼び出し元の手順: `10_spec/skills/20-common-step-ai-asset-creator.md`

## Script 処理

### logger.sh（source 専用）

`.claude/skills/20-common-step-shell-script/scripts/logger.sh`。実行しても何もしない。

1. **初期化（source 時）**: リポジトリルート（`git rev-parse --show-toplevel`）を解決し `logs/sh/` を `mkdir -p` する（失敗は無視）。`LOGGER_NAME` があればそれを、無ければ `$0` の basename（拡張子なし）を出どころとする。`LOG_LEVEL` を読み、無効値・未設定は `INFO` に正規化する
2. **提供する関数**: `log_debug` / `log_info` / `log_warn` / `log_error`（各 1 引数。複数引数はスペース連結）
3. **レベル判定**: DEBUG(10) < INFO(20) < WARN(30) < ERROR(40)。現在のレベル未満の呼び出しは何もせず 0 を返す
4. **行フォーマット**: `<ISO 8601 タイムスタンプ（秒・タイムゾーン付き）> [<LEVEL>] [<出どころ>] [pid:<PID>] <メッセージ>`。改行を含むメッセージは 1 行に畳む（改行を `\n` リテラルに置換）
5. **書き込み**: `logs/sh/<出どころ>.log` へ追記する。書き込みの失敗（権限・ディスク・ディレクトリ不在）はすべて握りつぶし、関数は常に 0 を返す（`set -e` の利用側を巻き込まない）。標準出力・標準エラーには何も出さない
6. ローテーションは持たない（`logs/` はローカル限りで、必要なら人間が消す。肥大が問題になったら日付別ファイルへの変更をこの仕様で決める）

### テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| LG-T01 | 正常系 | 既定（LOG_LEVEL 未設定）で INFO が書かれ DEBUG が書かれない |
| LG-T02 | 正常系 | LOG_LEVEL=DEBUG で DEBUG も書かれ、行フォーマット（時刻・レベル・出どころ・pid）が一致する |
| LG-T03 | 異常系 | logs/ が作成不能でも source と関数呼び出しが成功し（終了コード 0）、標準出力・標準エラーに何も出ない |
| LG-T04 | 境界 | 無効な LOG_LEVEL が INFO に正規化される。改行入りメッセージが 1 行になる |
| LG-T05 | 正常系 | LOGGER_NAME による出どころの上書き |
| SS-T01 | 正常系 | 雛形からコピーした sh が `bash -n` を通り、logger を source して結果出力の型で終了する |
| SS-T02 | 異常系 | テスト雛形が失敗ケースを検出して非 0 で終了する |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 雛形から作る・白紙禁止 | 処理フロー 2、OUT ひな形、禁止事項 |
| メイン: 規約と logger ルールに従い共通 logger を読み込む | 処理フロー 3、logger.sh |
| メイン: テストの作成・実行・記録 | 処理フロー 4、OUT ひな形（test.template） |
| メイン: 機械的な検査と記録 | 処理フロー 5 |
| メイン: logger の読み込みは 1 行・コピー禁止 | サンプル、禁止事項 |
| 代替: 既存 sh は差分小さく・逸脱は直すか記録 | 処理フロー 6 |
| 代替: 静的検査ツール不在は省略を記録 | 処理フロー 5 |
| 例外: テスト失敗は直すか仕様の誤りとして返す | 禁止事項 |
| 例外: 仕様書・テスト観点が無ければ作らない | 処理フロー 1 |
| logger の提供: 実体と雛形はこのスキル配下・重複禁止 | 概要（パス）、OUT ひな形 |
| logger の提供: 利用中に変更しない・回帰 | 禁止事項 |
| 整合: ai-asset-creator からの利用・手順の再掲禁止 | 呼出条件、参照ナレッジ |
