---
type: rule
title: logger — sh のログは共通 logger で書く
description: スキルの scripts とフックの sh が書くログの規約。共通 logger（20-common-step-shell-script の scripts/logger.sh）を雛形の読み込み行で読み、レベルは既定 INFO・LOG_LEVEL=DEBUG で詳細、時刻・レベル・出どころは logger が自動で付与し、標準出力・標準エラーには出さず、書けなくても本体を止めない
tags: [rule, artifact, sh, logger]
keywords: [logger, ログ, sh, LOG_LEVEL, INFO, DEBUG, logs/sh, 読み込み行, 標準出力禁止, fail-open, 機密情報, redact]
category: artifact
paths: [".claude/skills/*/scripts/**/*.sh", ".claude/hooks/**/*.sh"]
---

# logger — sh のログは共通 logger で書く

sh（スキルの `scripts/` とフック）のログは、共通 logger を読み込んで `log_*` で書く。独自のログ方式・独自のログファイルを作らない。ログは補助であり、本体（コミット・push・フックの判定）を止めない。行フォーマット・出力先・出どころの導出・失敗時の振る舞いの正は `.claude/docs/10_spec/skills/20-common-step-shell-script.md`「logger.sh」で、ここには書き手が守る要点だけを置く。

## 適用範囲

- `.claude/skills/*/scripts/**/*.sh`（提供コマンド・ライブラリ・テスト）と `.claude/hooks/**/*.sh`（フック本体・ライブラリ・テスト）を作成・変更するとき
- 何をログに書くかは各スクリプト・フックの仕様が定める。`logs/` の他の記録（進行状態・判定記録 `decisions.jsonl`）は機構の仕様が定め、このルールの対象外

## 構造・配置

- 冒頭で、`20-common-step-shell-script` の雛形（`assets/script.template.sh` / `assets/test.template.sh`）が持つ**読み込み行 1 行**（`__ss_load <lib> <policy>`）で共通 logger を読み込む。引数だけを変え、行の中身を自作・改変しない。フックの共有ライブラリ（`hook-common.sh`）を読むフックは `hook_init` が logger を読む
- 関数は `log_debug` / `log_info` / `log_warn` / `log_error`（各 1 引数。複数引数はスペース連結）。これ以外のログ用関数を定義しない
- 出力先は `logs/sh/<出どころ>.log`（出どころは `$0` の basename、フックは `LOGGER_NAME=hook-<名前>`）。`logs/` は `.gitignore` 済みで片付けの対象外
- `source` 専用のライブラリは自分で logger を読まず、呼び手のログに書く（出どころが呼び手になる）

## 書式・可読性

- 時刻・レベル・出どころは logger が自動で付ける。書き手は本文だけを渡し、時刻やスクリプト名を自分で書かない
- 1 行 1 事象。本文の改行は `\n` に畳まれる。「何を・どうした」+ 判断に要る値（識別子・パス・件数）を書く。日本語でよい
- レベルの使い分け: **INFO** = 受け付けた操作・判定結果・拒否理由・最終結果（`OK:` / `<接頭辞><番号>:`）/ **DEBUG** = 判定の材料（比較した値・走査したファイル・分岐の途中経過）/ **WARN** = 続行できる異常（縮退・記録の失敗）/ **ERROR** = 処理を止める失敗
- `LOG_LEVEL` の有効値は 4 レベル名。未設定・無効値は INFO に正規化される。既定（INFO）でノイズが出ない量にし、調査に要る詳細は DEBUG に置く

## セキュリティ

- 環境変数の値・トークン・クレデンシャル・個人情報・ファイルの中身をログに書かない。値が要る場面は「有無」や「長さ」を書く
- フックがコマンド文字列・パス・本文をログや記録に載せるときは、`hook-common.sh` の `redact` を通す（マスクは最後の砦。一次防御は値を出さないこと。パターンはフック共通仕様 §3）
- 拒否理由・通知の文面とログの本文を同じ変数から作るとき、redact 前の値をログに先に書かない（issue #6 の申し送り H1）

## 堅牢性

- 書き込みに失敗（権限・ディスク・`logs/` を作れない）したとき logger は黙って捨てる（fail-open）。書き手が `|| true` などで包む必要はなく、ログの成否で分岐しない
- `logs/` が無ければ logger が作る。存在確認を書き手が行わない
- 読み込み行の失敗時ポリシー（`nop` / `fatal` / `deny`）は呼び手の種類で決める（提供コマンドは `logger nop`。表は仕様「読み込み行」が正）。`nop` では `log_*` が無音のスタブになるので、logger の有無で本体の振る舞いが変わらないように書く
- 標準出力・標準エラーにログを出さない（フックの応答は stdout の JSON、提供コマンドの結果は最終行の `OK:` / `<接頭辞><番号>:`。混ぜると機械が読めない）

## パフォーマンス

- logger は時刻の取得に外部プロセスを使わない（`printf '%()T'`）。ホットパス（毎ツール呼び出しで走るフック）から呼んでよい
- ただし `log_debug` に渡す文字列の組み立てで外部コマンド（`git` / `jq` 等）を起動しない。引数は `LOG_LEVEL` に関わらず評価される（DEBUG を切っても fork は残る）

## テスト・機械的検査

- logger 自体の振る舞い（レベル・フォーマット・出力先・失敗時の黙殺）は `20-common-step-shell-script` のテスト LG-T01〜05 が固定する。各スクリプトのテストでログの中身を検査しない（ログは補助で、契約は stdout の結果行）
- 各スクリプトのテストは「標準出力にログが混ざっていない」ことを結果行の検査（`assert_eq` / 最終行の型）で間接に確かめる
- 独自のログ方式（`echo "[INFO] ..."` や自前のログファイル）の機械検出は未整備。当面はコードレビューで見る（将来のルール検査に統合）
