---
type: spec
title: block-direct-git フック 仕様
description: git のコミット・push の直接実行を拒否し提供コマンド（commit.sh / push.sh）と 20-common-step-commit-push を案内するフックの内部仕様。cmdpos.sh（コマンド位置判定の正）による判定、複合コマンド・ラッパー・パス付き・opaque・縮退の扱い、WF40x を定める
tags: [spec, hook, block-direct-git]
keywords: [git commit, git push, 直接実行, 拒否, commit.sh, push.sh, cmdpos.sh, コマンド位置, 複合コマンド, ヒアドキュメント, opaque, 縮退, PowerShell, WF401, WF402, WF403]
---

# block-direct-git フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/20-PreToolUse/block-direct-git.md](../../../00_requirement/hooks/20-PreToolUse/block-direct-git.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)。**コマンド位置の判定（`cmdpos.sh`）の正はこのフック**で、規則は共通仕様 §7 に置く。

ツールへ渡されたコマンド文字列の実行位置に `git commit` / `git push` があれば拒否する。判定は純 bash で外部プロセスを起動しない。

禁止事項:

- 部分一致（語の有無）だけでの拒否（縮退時を除く）
- コミットを生成しない `git` サブコマンドの拒否（`status` / `log` / `diff` / `add` / `fetch` / `merge` 等）
- オプションによる例外（`--amend` `--force` `--no-verify` も拒否）
- 提供コマンドの呼び出し文字列以外（内部処理）を見に行くこと

## 呼出条件（イベント・matcher・登録）

- PreToolUse、matcher: `Bash|PowerShell`（共通仕様 §1 の PreToolUse 5 行目。**位置であって実行順ではない**（フックは並列に走る — §1））
- 作業中チケット・レビュー状態を問わず常時

## 入出力

- 入力: `tool_name`、`tool_input.command`
- 出力: deny（WF401 / WF402 / WF403 / WF409）または許可

## 制御方式

1. 停止中 → `disabled` を記録して許可
2. `cmdpos.sh` でコマンド列を得る（共通仕様 §7。PowerShell は §7-6 の前処理）
3. 各セグメントについて:
   - 提供コマンド（§7-8）→ 対象外
   - 実行体 `git` かつ第 1 サブコマンド（`-C <dir>` / `-c k=v` / `--git-dir` 等のグローバルオプションを飛ばした後）が `commit` → **deny WF401**、`push` → **deny WF402**。**コミットを生成する他のサブコマンド**（`revert`、`cherry-pick`、`am`、`rebase`（`--continue` 含む）、`commit-tree`、`stash` は対象外、`merge` は例外として許可 — `workflow-guard` の `merge-base` 分類で統制し、マージコミットのメッセージは git 生成を受容する。DDR i0004-07）も `commit.sh` の規約検査を迂回するため **deny WF401**（メッセージに「コミットを生成するサブコマンド」と明記）
   - 実行体が `git` 系（`CP_GITLIKE` を含む）で、**第 1 サブコマンドが特定できない**（`CP_SUBCMD[i]` が `_`。`git 'commit'` のようにクォートで語が割れた場合）→ **deny WF403**。Bash 経路も PowerShell 経路も同じ扱いにする（共通仕様 §7-9 の「呼び出し側は『特定できない』として扱う」の実装。DDR i0009-01）
   - PowerShell の入力で実行位置のトークンが `git` を含む場合は、第 1 サブコマンドが上記の対象か特定できないときだけ拒否側に倒す（`git status` 等は通す — 共通仕様 §7-6）
   - ダブルクォート内の `$(git commit ...)` も実行位置として同じ判定
   - `opaque` かつ文字列に `commit` または `push` を含む → **deny WF403**（判定不能で拒否側）
4. `degraded`（bash < 4.3、4096 文字超）→ 文字列に `git` と `commit` / `push` の語が共に含まれれば **deny WF403**（縮退した判定であること・`ai-command-style` ルールの言い換えを案内）
5. 入力が解釈できない → **deny WF409**
6. いずれにも該当しない → 許可（記録しない）

- `permissions.deny` の設定と併用してよいが依存しない
- 外部委任モードでも判定は同じ（コミット・push は常に提供コマンド）

## エラー識別子とメッセージ

| ID | 条件 | メッセージに含める内容 |
|----|------|----------------------|
| WF401 | `git commit` の直接実行 | `bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "<件名>" <files>` と `20-common-step-commit-push` / 提供コマンド経由でやり直す |
| WF402 | `git push` の直接実行 | `push.sh` と同スキル / push 前チェックを飛ばすなら `wip/push-check-skip.md`（緊急停止は不可） |
| WF403 | opaque / **第 1 サブコマンドが特定できない `git`** / 縮退での拒否 | 縮退した判定で拒否した可能性 / サブコマンドをクォートで割らずに書く（`git 'commit'` → `git commit`。ただし実行が目的なら提供コマンド）/ 言い換え（`ai-command-style`） |
| WF409 | 入力不正 | 機構の不調 / ユーザーへの報告 |

## 回復手順

- 提供コマンドでやり直す。コマンド文字列の分割・別の実行系（`eval`、PowerShell）・権限設定の変更・フックの登録解除で迂回しない
- 縮退で誤って止まった場合は語を言い換える（例: コミットメッセージ中の「push」→「反映」）

## 記録（logs/）

- `decisions.jsonl` に deny（種類と `target`: コマンドの先頭 80 文字。トークン様の文字列はマスク）。許可は記録しない
- 実行ログ: `logs/sh/hook-block-direct-git.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| BG-T01 | 異常系 | 機械テスト。`git commit -m x`、`cd a && git commit`、`x; git push`、`a \| git push`、`sudo git push`、`if true; then git commit; fi`、`/usr/bin/git commit`、`./git push`、`git.exe commit`、`git -C . commit`、`git push --force` がすべて拒否。**`git 'commit'` と `git "push"`（クォートで語が割れてサブコマンドが `_` になる形）は WF403 で拒否**（他は WF401 / WF402） |
| BG-T02 | 正常系 | ヒアドキュメント本文・シングル / ダブルクォート内・`#` コメント・`grep "git commit"`・日本語の地の文に `commit` / `push` があるだけでは通る |
| BG-T03 | 正常系 | `git status` / `log` / `diff` / `add` / `merge` / `fetch` が通る |
| BG-T04 | 異常系 | `echo "$(git commit -m x)"` が WF401 |
| BG-T05 | 異常系 | `eval "git commit"`、`bash -c 'git push'`、`xargs git push`、`find . -exec git commit ;` が WF403 |
| BG-T06 | 正常系 | `bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "docs: x" a.md` と `push.sh` が通る |
| BG-T07 | 境界 | 4097 文字のコマンドで `git` と `commit` を含めば WF403、含まなければ通る |
| BG-T08 | 異常系 | PowerShell: `& git commit`、`git push; ls`、`.\git.exe commit` が拒否 |
| BG-T09b | 正常系 | PowerShell: ヒアストリング内の `git commit`、`git status`、`git diff` は通る |
| BG-T10 | 異常系 | `git revert HEAD`、`git cherry-pick abc`、`git rebase --continue`、`git am x.patch` が WF401。`git merge origin/main` は通る |
| BG-T09 | 異常系 | 入力 JSON 不正で WF409 |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: コミットの直接実行を拒否し提供コマンドとスキルを案内 | WF401 |
| メイン: push の直接実行を拒否し案内 | WF402 |
| メイン: 複合コマンド・ラッパー・予約語の後 | cmdpos §7-2・7-3、BG-T01 |
| メイン: パス付き・.exe | §7-4 |
| メイン: オプションで例外を作らない | 禁止事項 |
| メイン: 提供コマンドは拒否しない・内部処理は対象外 | 制御方式 3、§7-8 |
| メイン: ヒアドキュメント・クォート・コメント・検索語・地の文で拒否しない | §7-1、BG-T02 |
| メイン: 他のサブコマンドは拒否しない | 制御方式 3、BG-T03 |
| メイン: `$( )` 内は実行として扱う | §7-1、BG-T04 |
| メイン: opaque は拒否側 | WF403 |
| メイン: サブコマンドが特定できない `git` は拒否側 | 制御方式 3、WF403、BG-T01（DDR i0009-01） |
| メイン: 依存不足は縮退して継続・明示 | 制御方式 4 |
| メイン: 長さ超過は縮退 | 制御方式 4、BG-T07 |
| メイン: 記録・識別子（commit / push を区別）・縮退の案内 | 記録、エラー識別子 |
| メイン: permissions.deny に依存しない | 制御方式（併用） |
| メイン: コマンド位置の判定を state-guard と共有 | 共通仕様 §1（lib）・§7 |
| メイン: 提供コマンド内部のコミットは対象外 | §7-8（DDR i0004-05） |
| 代替: push 前チェックのスキップは push.sh の手段 | WF402 のメッセージ |
| 代替: 外部委任モードでも同じ | 制御方式 |
| 代替: 緊急停止 | 制御方式 1 |
| 例外: 拒否されたら迂回しない | 回復手順 |
| 例外: 入力不正は拒否側 | WF409 |
