---
type: eval
title: logger の eval 定義
description: logger（ルール）の指示文の効果を確かめるための評価シナリオ・比較条件・判定基準。定義のみで、実行は人間の明示的な依頼時に限る
tags: [eval, ルール]
keywords: [eval, logger, with-without, 効果測定, ログ, 読み込み行, redact]
---

# logger の eval 定義

## 目的

`.claude/rules/logger.md`（sh を書くときのログの規約）が `paths` に一致するファイルの編集時に読み込まれているときに、新しく書くスクリプトが共通 logger を読み込み行で使い、レベルを使い分け、標準出力に混ぜず、秘密情報をログに書かない振る舞いが安定するかを確かめる。

## 評価シナリオ

各行は仕様書「テスト観点（eval）」の行と 1:1 に対応する（eval ID が対応の鍵）。

| eval ID | 入力プロンプトと状況 | 期待する振る舞い | 判定方法 | 添付ファイル |
|---------|--------------------|-----------------|---------|-------------|
| LR-E01 | 「`.claude/skills/x/scripts/do.sh` を新しく作って。進捗をログに残したい」。ai-asset-implementation チケットが作業中 | 雛形 `script.template.sh` から作り、独自の `echo "[INFO] ..."` や `logger` コマンドを使わず、読み込み行 `__ss_load logger nop` と `log_info` / `log_warn` を使う。結果の最終行（`OK:` / `<接頭辞><番号>:`）は標準出力、ログはファイル | 作成物に `__ss_load logger` があり、`log_*` 以外のログ出力（`echo` / `printf` による `[INFO]` 等）が無いこと。最終行の型が守られていること | `.claude/rules/logger.md`、`.claude/skills/20-common-step-shell-script/assets/script.template.sh` |
| LR-E02 | 「このフックの deny 理由に、拒否したコマンド全文を残して」。コマンドに `token=...` を含む例を添える | `log_*` に渡す前に `redact` を通す（フック共通ライブラリの `redact` を使い、自前のマスクを書かない） | 変更後のコードで `log_*` の引数が `redact` 済みの値であること。生の `HOOK_COMMAND` を直接ログに書いていないこと | `.claude/rules/logger.md`、`.claude/hooks/lib/hook-common.sh` |
| LR-E03 | 「ログが多すぎるので DEBUG を消して」 | `log_debug` の呼び出しを消さず、レベル（`LOGGER_LEVEL` 相当）で絞る方法を提案する。DEBUG / INFO / WARN / ERROR の使い分けの規約を根拠にする | 返答が「レベルで絞る」を提案し、`log_debug` の行を一括削除していないこと | `.claude/rules/logger.md`、`.claude/skills/20-common-step-shell-script/scripts/logger.sh` |

## 比較条件

- with: `.claude/rules/logger.md` が `paths`（`.claude/skills/*/scripts/**/*.sh`、`.claude/hooks/**/*.sh`）の一致で読み込まれている状態で各シナリオのプロンプトを与える
- without: `logger.md` を読み込まない状態（`paths` 一致の注入を外す）で、CLAUDE.md と shell-script の仕様書だけを文脈に置いて同じプロンプトを与える
- 実施回数: シナリオごとに with / without を各 3 回

## 効果ありの判定基準

- LR-E01: with の 3 回すべてで `__ss_load logger` と `log_*` だけを使い、without で 1 回以上独自のログ出力がある
- LR-E02: with の 3 回すべてで `redact` を通し、without で 1 回以上生のコマンドをログに書く
- LR-E03: with の 3 回すべてでレベルで絞る提案になり、without で 1 回以上 `log_debug` を一括削除する
- 3 シナリオのうち 2 つ以上で上記を満たせば効果あり。差が出ないシナリオはルールの該当章の文言を見直す対象として記録する

## 実行状況

**未実行**（定義のみ）。実行は人間が明示的に依頼したときに行い、結果はこの節に日付・回数・判定を追記する。
