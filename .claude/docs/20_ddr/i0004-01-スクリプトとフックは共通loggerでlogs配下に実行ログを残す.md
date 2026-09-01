---
type: ddr
title: i0004-01. スクリプトとフックは共通 logger で logs/ 配下に実行ログを残す
description: スキルのスクリプトとフックのログ出力を 20-common-step-shell-script の scripts/logger.sh に一本化し、logs/sh/ 配下へ書く。既定 INFO・LOG_LEVEL=DEBUG で詳細、タイムスタンプ等は自動付与、ファイルのみに書き失敗は黙殺（本体を止めない）
tags: [ddr, logging, lib]
keywords: [logger, 共通ライブラリ, shell-script, logs, LOG_LEVEL, INFO, DEBUG, 標準出力禁止, fail-open, lib]
---

# i0004-01. スクリプトとフックは共通 logger で logs/ 配下に実行ログを残す

## 背景

基本設計（issue #4）で各スクリプト（ticket.sh・commit.sh・push.sh・finalize.sh・check-html.sh）とフックの仕様を書き進める中で、実行ログの残し方が各仕様の裁量になっていた。拒否・失敗の原因調査には「いつ・何が・どこまで動いたか」の記録が要り、ユーザーから共通 logger の導入（logs/ 配下・既定 INFO・環境変数で DEBUG・タイムスタンプ自動付与）が指示された。

## 決定

- 共通 logger を `20-common-step-shell-script` スキルの `scripts/logger.sh` として提供し（`.claude/lib/` は設けない — DDR `i0004-06`）、すべてのスキルのスクリプトとフックは source して使う（独自のログ方式を持たない）
- 出力先は `logs/sh/<出どころ>.log`（出どころはスクリプト名から自動導出）。`logs/` の既存の扱い（gitignore・片付け対象外・唯一の正にしない — `i0001-28`）に従う
- 既定レベルは INFO。環境変数 `LOG_LEVEL=DEBUG` で DEBUG も出力する
- 行にはタイムスタンプ（ISO 8601）・レベル・出どころ・PID を logger が自動付与する
- ログは**ファイルにのみ**書く（フックの標準出力は応答チャネル、スクリプトの標準出力は AI が読む結果のため、混ぜない）
- 書き込み失敗は黙殺し、logger の関数は常に成功を返す（ログは補助であり、本体のコミット・push・フック判定を止めない）
- 設計文書は「sh ファイルを書くときのルール」として `00_requirement/rules/logger.md` に置く（ルールのため仕様書は作らない。関数 API・行フォーマット・出力先などルール本文の必須項目は要件書が列挙する。当初はライブラリ用に lib/ ディレクトリを設けたが、ログの書き方は sh を書くたびに効く規約なのでルールに一本化した）

## 理由

- 出力先とフォーマットが揃っていないログは調査に使えない。1 本の source で全スクリプトが同じ形式になる
- フックの stdout は Claude Code への応答そのものなので、「stdout に絶対出さない」を logger の側で保証する必要がある
- ログ機構の不具合で提供コマンドが失敗すると、機構全体がログのせいで止まる。fail-open（捨てる）が正しい縮退方向

## 却下した案

- **各スクリプトが個別にログを書く**: フォーマット・出力先が発散し、stdout への誤出力の危険が仕様ごとに残る
- **標準エラーへの併記**: デバッグには便利だが、フックでは stderr も Claude Code に読まれる場面があり、チャネル汚染の危険が利益を上回る
- **ローテーション内蔵**: logs/ はローカル限りで容量問題が起きてから考えればよい。初版の複雑さを増やさない

## 影響

- `00_requirement/rules/logger.md`（新規）・`rules/ルール体系.md`（logger 行の追加）
- スクリプトを持つ仕様書（ticket / commit-push / report-view / overall-summary）と今後のフック仕様に「ログは共通 logger」の参照を追加
- 自己改善ワークフロー機構.md の logs/ の列挙に実行ログを追加
- AI アセット実装フェーズで logger.sh を最初に作る（他のスクリプトが依存するため）
