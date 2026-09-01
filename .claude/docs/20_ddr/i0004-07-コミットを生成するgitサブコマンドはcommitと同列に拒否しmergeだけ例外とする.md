---
type: ddr
title: i0004-07. コミットを生成する git サブコマンドは commit と同列に拒否し、merge だけ例外とする
description: block-direct-git の拒否対象を `git commit` / `git push` だけでなく、コミットを生成する revert / cherry-pick / am / rebase にも広げ、default ブランチの取り込みに使う merge だけを例外として受容する判断
tags: [ddr, hook, block-direct-git, commit]
keywords: [block-direct-git, revert, cherry-pick, am, rebase, merge, 規約検査の迂回, commit.sh, merge-base]
---

# i0004-07. コミットを生成する git サブコマンドは commit と同列に拒否し、merge だけ例外とする

## 背景

敵対的レビュー（フック仕様）で、`block-direct-git` が `git commit` / `git push` だけを見ているため、`git revert` / `cherry-pick` / `am` / `rebase --continue` がコミットを生成するのに `commit.sh` のメッセージ規約・除外パターン・対象ファイルの明示をすべて迂回できると指摘された。要件 E 節は「コミットまたは push を行うとき、提供コマンド経由でのみ」と定めており、生成経路を問わずコミットは対象と読むのが自然。

## 決定

- `block-direct-git` は、実行位置の `git` の第 1 サブコマンドが `commit` / `revert` / `cherry-pick` / `am` / `rebase`（`--continue` を含む）/ `commit-tree` のとき WF401 で拒否する（メッセージには「コミットを生成するサブコマンド」と明記）
- `git merge` は例外として拒否しない。default ブランチの取り込み（`git merge origin/<default>`）は `00-workflow-issue-mr-driven` の手順に組み込まれており、`workflow-guard` の `merge-base` 分類で「取り込みに限る」統制を行う。マージコミットのメッセージは git 生成を受容する（`commit.sh` の規約検査を経ない唯一の経路として共通仕様 §13 に明記）
- `git stash` は対象外（stash はコミットオブジェクトを作るが履歴に載らない）

## 理由

- 拒否の根拠は「ツールへ渡された文字列に、履歴に載るコミットを作る操作があるか」であり、サブコマンド名で列挙できる
- `merge` まで拒否すると衝突解消の手順が回らず、取り込みのためだけの提供コマンドを増やすことになる。取り込み以外の `merge`（ブランチ間の統合）は `merge-base` 分類で `origin/<default>` 以外を拒否できる

## 却下した案

- **`commit` / `push` だけを見る（現状維持）**: 規約検査を迂回する経路が残り、`revert` が普通に使われる場面（差し戻し）で規約外のコミットが履歴に載る
- **`merge` も拒否して取り込み用の提供コマンドを設ける**: コマンドが 1 本増え、衝突解消（対話が要る）をスクリプトに閉じ込められない
- **`revert` / `cherry-pick` に `--no-commit` を付けさせて `commit.sh` で確定する**: 迂回の拒否ではなく手順の推奨にとどまり、フックで強制できない（`--no-commit` の有無で許可を分ける案は、オプションで例外を作らない要件と衝突）

## 影響

- `10_spec/hooks/20-PreToolUse/block-direct-git.md`（制御方式 3・BG-T10・禁止事項）
- `10_spec/フック共通仕様.md` §13（`git merge` の受容）
- `00_requirement/hooks/20-PreToolUse/block-direct-git.md` は「コミット・push 以外の `git` 操作の統制は含まない」としているが、コミットを生成する操作はコミットの統制に含まれると解釈する（要件の文言変更は不要）
