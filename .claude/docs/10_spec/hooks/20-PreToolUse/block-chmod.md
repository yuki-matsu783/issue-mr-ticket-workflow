---
type: spec
title: block-chmod フック 仕様
description: 禁止コマンド一覧（初期値 chmod）に載るコマンドの実行を拒否するフックの内部仕様。一覧ファイル、cmdpos.sh による実行位置の判定、opaque の扱い、WF50x を定める
tags: [spec, hook, block-chmod]
keywords: [chmod, 禁止コマンド, 一覧, blocked-commands.txt, cmdpos.sh, 実行権限, bash パス, WF501]
---

# block-chmod フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/20-PreToolUse/block-chmod.md](../../../00_requirement/hooks/20-PreToolUse/block-chmod.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)（§7 コマンド位置）。

禁止コマンドの一覧 `.claude/hooks/config/blocked-commands.txt`（1 行 1 コマンド。初期値 `chmod`。`#` はコメント）を読み、実行位置に一覧のコマンドがあれば拒否する。判定は `cmdpos.sh` を共有する。

禁止事項:

- 一覧に無いコマンドの拒否（許可・拒否は `workflow-guard`）
- 提供コマンドの内部処理を見に行くこと
- 一覧をコードに埋めること

## 呼出条件（イベント・matcher・登録）

- PreToolUse、matcher: `Bash|PowerShell`（state-guard の後、block-direct-git の前）。常時

## 入出力

- 入力: `tool_input.command`。参照: `blocked-commands.txt`
- 出力: deny（WF501 / WF509）または許可

## 制御方式

1. 停止中 → `disabled` を記録して許可
2. 高速前置判定: コマンド文字列に一覧のいずれの語も含まなければ即許可（外部プロセスなし）
3. `cmdpos.sh` でコマンド列を得て、提供コマンドを除く各セグメントの実行体（basename。`/bin/chmod` → `chmod`）が一覧に一致 → **deny WF501**
4. `opaque` / `degraded` で一覧の語を含む → **deny WF501**（判定不能で拒否側であることを明記）
5. 入力不正 → **deny WF509**
6. それ以外 → 許可

## エラー識別子とメッセージ

| ID | 条件 | メッセージに含める内容 |
|----|------|----------------------|
| WF501 | 一覧のコマンドの実行（opaque 含む） | コマンド名 / 実行権限の変更は不要で `bash <パス>` で実行すること / 本当に必要ならユーザーに提案 / opaque なら判定不能であること |
| WF509 | 入力不正 | 機構の不調 / ユーザーへの報告 |

## 回復手順

- `bash <パス>` で実行する。権限変更が本当に必要ならユーザーに提案する（別コマンド・別実行系での迂回はしない）
- 禁止コマンドの追加・削除は一覧の編集（AI アセット実装のチケットで）

## 記録（logs/）

- `decisions.jsonl` に deny のみ（`target`: コマンド名とコマンドの先頭）
- 実行ログ: `logs/sh/hook-block-chmod.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| BC-T01 | 異常系 | `chmod +x a.sh`、`x && chmod`、`sudo chmod`、`/usr/bin/chmod` が WF501 |
| BC-T02 | 正常系 | `grep chmod`、`echo "chmod"`、ヒアドキュメント・コメント・地の文の `chmod` は通る |
| BC-T03 | 異常系 | `bash -c "chmod +x a"`、`xargs chmod` が WF501 |
| BC-T04 | 正常系 | 一覧に `chown` を足すと `chown` も同じ規則で拒否され、外すと通る |
| BC-T05 | 正常系 | 一覧の語を含まないコマンドが `cmdpos.sh` を呼ばずに通る |
| BC-T06 | 異常系 | 入力不正で WF509 |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: chmod の拒否と案内 | WF501 |
| メイン: 複合・ラッパー・パス付き | 制御方式 3（cmdpos） |
| メイン: クォート・コメント・ヒアドキュメント・検索語・地の文では拒否しない | 制御方式 3、BC-T02 |
| メイン: opaque は拒否側 | 制御方式 4 |
| メイン: 提供コマンドの内部は対象外 | 制御方式 3 |
| メイン: 一覧への追加で拡張・同じ規則 | 一覧ファイル、BC-T04 |
| メイン: 一覧に無いコマンドは拒否しない | 禁止事項 |
| メイン: 記録・識別子 | 記録、エラー識別子 |
| 代替: 緊急停止 | 制御方式 1 |
| 例外: 入力不正は拒否側 | WF509 |
| 例外: 迂回しない | 回復手順 |
