---
type: ddr
title: i0009-01. サブコマンドを特定できない git は bash 経路でも拒否側に倒す
description: git 'commit' のようにクォートで語が割れて第 1 サブコマンドが _ になる呼び出しを、block-direct-git が PowerShell 経路だけでなく bash 経路でも WF403 で拒否すると決めた判断
tags: [ddr, hooks, block-direct-git, cmdpos]
keywords: [git commit, クォート, CP_SUBCMD, _, WF403, 特定できない, cmdpos.sh, 素通り, WF204]
---

# i0009-01. サブコマンドを特定できない git は bash 経路でも拒否側に倒す

## 背景

フック共通仕様 §7-9 は「`CP_SUBCMD[i]`（第 1 サブコマンド。…クォートで割った語（`git 'commit'`）は `_` になり、呼び出し側は『特定できない』として扱う）」と定める。`cmdpos.sh` の実装もそのとおりで、`git 'commit'` は `exe=git` / `subcmd=_` になる。ところが `block-direct-git` の制御方式 3 で「サブコマンドが特定できないときに拒否側に倒す」と書いてあるのは PowerShell の入力についてだけで、bash 経路には `subcmd == "_"` の規定が無く `opaque` でもないため、仕様どおりに実装すると許可される（issue #9 の調査 0007 f9）。

機構全体では素通りしない。作業中チケットがある間は `workflow-guard` の `scope_classify` が `_` をどの読み取り系分類にも当てられず `unknown` → WF204（分類外コマンド）で止める。真に抜けるのは「作業中チケットが 0 枚の窓」（共通仕様 §13 の意図的な緩和）と `workflow-guard` を止めているときだけ。

## 決定

- `block-direct-git` の制御方式 3 に「実行体が `git` 系（`CP_GITLIKE` を含む）で第 1 サブコマンドが特定できない（`CP_SUBCMD[i]` が `_`）→ **deny WF403**」を加える。bash 経路も PowerShell 経路も同じ扱いにする
- WF403 のメッセージに「サブコマンドをクォートで割らずに書く」という対処を足す
- テストは BG-T01 に `git 'commit'` と `git "push"` のケースを足し、期待する識別子は WF403（他のケースは WF401 / WF402）とする

## 理由

- §7-9 と issue #9 の申し送り D2 が「特定できない = 拒否側に倒す」という意図で書かれており、bash 経路だけ例外にする根拠が無い
- 誤検知の害が小さい。`git 'commit'` のようにサブコマンドをクォートで割る書き方は、実運用でほぼ起きない（起きても言い換えれば通る）
- WF204 で止まる現状は「メッセージが不適切」（分類外コマンドと言われる）で、AI が提供コマンドへ戻る導線にならない

## 却下した案

- **現状維持（`workflow-guard` の WF204 に任せる）**: チケットが 0 枚の窓で抜ける。メッセージも不適切
- **`cmdpos.sh` 側でクォートを剥がして `commit` と解釈する**: 「実行位置の語をそのまま見る」という §7 の原則を崩す。`git $(echo commit)` のような形まで追う羽目になる
- **WF401 で拒否する**: 「コミットの直接実行」と断定できないのに commit 用の識別子を出すことになり、記録の意味が濁る

## 影響

- `10_spec/hooks/20-PreToolUse/block-direct-git.md` 制御方式 3・エラー識別子 WF403・テスト観点 BG-T01・要件との対応
- `00_requirement/hooks/20-PreToolUse/block-direct-git.md` 受け入れ基準（メインフロー）
