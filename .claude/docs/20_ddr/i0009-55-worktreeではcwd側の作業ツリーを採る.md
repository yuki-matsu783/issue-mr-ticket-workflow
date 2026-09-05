---
type: ddr
title: i0009-55. worktree では cwd 側の作業ツリーを採る
description: CLAUDE_PROJECT_DIR が worktree に追随せず機構が worktree の中で丸ごと無効になることが公式で分かり、cwd から .claude を上向きに探して作業ツリーを決めると定めた判断
tags: [ddr, hooks, worktree, ロックアウト, 無効化]
keywords: [worktree, CLAUDE_PROJECT_DIR, cwd, HOOK_ROOT, LOGGER_ROOT, git rev-parse, i0009-20, i0009-22]
status: 一部置き換え済み
superseded_by: i0050-02-進行状態とロックと集計は共有ルートに一本化する.md
superseded_scope: 「logs/ は作業ツリー側に置く」という置き場の決定（進行状態・ロック・集計は共有ルートへ移す）。作業ツリーの解決順と wip/ の置き場は有効
---

# i0009-55. worktree では `cwd` 側の作業ツリーを採る

## 背景

`i0009-20` は登録を `${CLAUDE_PROJECT_DIR}` 基準の絶対パスにしてロックアウト経路を 1 つ塞ぎ、`i0009-22` は「フック本体から `git rev-parse --show-toplevel` を呼ばない」（約 95 ms/回でホットパスの上限に反する）と決めた。作業ツリーの基準は「読み込み行が解決したリポジトリルート」（`LOGGER_ROOT` / `HOOK_ROOT`。`BASH_SOURCE` からの上向き探索）に一本化した。

ワーク境界の 2 巡目レビューで、この組み合わせが worktree で破綻することが分かった。公式の Note にこうある（`hooks.md:598-601`）。

> **Worktrees are different.** If Claude enters a worktree during the session, Claude Code keeps `${CLAUDE_PROJECT_DIR}` where it was and passes the worktree path to your hooks a different way:
> - **`${CLAUDE_PROJECT_DIR}` stays put**: it still points at the project root where the session started, so a command such as `${CLAUDE_PROJECT_DIR}/.claude/hooks/check-style.sh` still runs the script in the main checkout.
> - **`cwd` follows Claude**: the `cwd` field in the hook's input JSON is the worktree root after Claude enters a worktree, and the new directory after Claude runs `cd`. Read it when a hook needs to know which directory Claude is working in.

つまり Claude が worktree に入ると、フックのスクリプトは本流から起動され、`BASH_SOURCE` 由来の `HOOK_ROOT` も本流を指す。その結果:

- `workflow-guard` は**本流の空の `wip/10_tickets/10_doing/`** を見て「0 枚 → 即座に許可」となり、**すべての書き込みと実行が素通りする**
- `workflow-entry` の継続条件も `workflow-state-guard` の置き場保護も、本流側の状態で判定される
- 旧仕様（`cwd` で `git rev-parse --show-toplevel` を実行）なら worktree 側に解決していたので、**0019 の改定で悪化した**

しかも要件は並行作業の手段として worktree を明示的に挙げている。0019 の結果報告はこれを「確かめられなかったこと」に挙げていたが、答えは取得済みの原本の中にあった。

## 決定

フックは次の順で**作業ツリー**を決める（共通仕様 §2）。

1. 入力 JSON の `cwd` が `HOOK_ROOT` と異なり、かつ `cwd` から上向きに探して `.claude` を持つディレクトリが見つかるなら、**そのディレクトリを作業ツリーとする**
2. そうでなければ `HOOK_ROOT`

- 上向き探索は純 bash の `[ -d ]` の繰り返しで行い、**`git` を呼ばない**（`i0009-22` の上限に影響しない）
- **スクリプトの置き場（`lib/` の `source` 元）は常に `HOOK_ROOT`** で、作業ツリーとは別に扱う。worktree 側に `.claude/hooks/` の実体が無くても本流の実体で動く
- `logs/` と `wip/` は**作業ツリー側**に置く（worktree ごとに進行状態が分かれる）
- フェーズ 4c に実測項目を置く（worktree に入って `workflow-guard` が worktree 側のチケットを見るか）

## 理由

- **無効化はロックアウトと同じくらい悪い**。ロックアウトは「気づいて直せる」が、無効化は**静かに全部通る**。worktree に入った瞬間に機構が消えることに、誰も気づかない
- **公式が `cwd` を読めと明記している**。「Read it when a hook needs to know which directory Claude is working in」がまさにこの用途で、機構は「Claude がどのディレクトリで作業しているか」を知る必要がある
- **`git` を呼ばずに解決できる**。`.claude` の存在を上向きに探すのはディレクトリの `[ -d ]` を数回で、fork ゼロ。`i0009-22` の制約と両立する
- **スクリプトと作業ツリーを分けるのが正しい**。`${CLAUDE_PROJECT_DIR}` が動かないのは公式の設計意図（スクリプトは常に本流の実体で動く）で、これは機構にとっても都合がよい。worktree ごとにフックの実体が分岐しない
- **`cwd` は信頼してよい**。フックの入力はユーザーや AI が書き換えられるものではなく、Claude Code が渡す

## 却下した案

- **`git rev-parse --show-toplevel` を `cwd` で実行して解決する**（旧仕様に戻す）: worktree では正しく解決するが、`i0009-22`（約 95 ms/回・ホットパスの fork 上限）に反する。ホットパス 5 本が同時に走ると 475 ms を毎ツール呼び出しで払う
- **`cwd` をそのまま作業ツリーとして使う**: Claude が `cd` でサブディレクトリに入っただけのときに、そこを作業ツリーとみなしてしまう。`.claude` の上向き探索が要る
- **worktree を要件から外す（使わせない）**: 要件が並行作業の手段として挙げており、実際に複数セッションが同じリポジトリで動く運用がある。機構の都合で運用を狭めない
- **worktree 側にも `.claude/` の実体を置く（コピーする）**: 実体が 2 つになり、`i0009-36`（読み込み行のバイト一致）と同じドリフトの問題が worktree の数だけ増える
- **`HOOK_ROOT` と `cwd` が違うときは判定せずに通す**: 無効化と同じ

## 影響

- `10_spec/フック共通仕様.md` §2（作業ツリーの決め方に worktree の項を追加）
- `wip/00_overall_plan/overall-plan.md` フェーズ 4c（worktree の実測）
- `20_ddr/i0009-20`（`${CLAUDE_PROJECT_DIR}` の絶対パス登録は維持。スクリプトの置き場としては正しい）・`i0009-22`（`git` を呼ばない制約は維持）
- **実装フェーズへ**: 上向き探索は `[ -d "$d/.claude" ]` の繰り返し。ルートまで見つからなければ `HOOK_ROOT` に倒す
- 0019 の結果報告が「確かめられなかったこと」に挙げた `${CLAUDE_PROJECT_DIR}` の worktree での挙動は、**公式で確定**した
