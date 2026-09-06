---
name: 20-common-step-worktree
description: >
  作業ツリーの作成・一覧・合流・片付けを提供コマンド worktree.sh（add / list / merge / remove）経由でだけ行う共通ステップ。
  置き場はリポジトリの外、サブブランチは本流のブランチから機械的に導き、作業ツリーには logs/hooks/ と logs/sh/ だけを
  用意して進行状態を複製しない。合流はタスクの切れ目に本流から行い、前提 6 項目を全件検査してから進め、解けない衝突は
  中断して人に返す。合流の試みは共有ルートの logs/worktree-merges.jsonl に 1 回 1 行で残る。
  「本流かどうかの判定」（.git がディレクトリか）の正はこのスキルにあり、ticket.sh / push.sh はこれを共有する。
  Use when 00-workflow-issue-mr-driven decides to run tickets in a separate 作業ツリー ("作業ツリーを切って", "並行して進めたい"),
  when a task boundary needs the results merged back ("合流して", "worktree を片付けて"), when a skill needs to know which
  worktrees exist or whether it is on 本流 ("今どの作業ツリーにいる", "list"), or when git worktree / git merge is refused by WF204.
---

# 20-common-step-worktree — 作業ツリーは提供コマンド経由で切り、切れ目で戻す

`git worktree` / `git merge`（ローカルブランチどうし）/ `git branch -d` / `cd` を直接実行して作業ツリーを操作しない（作業中チケットがある間は `WF204` で拒否され、タスクの切れ目では機構が止めないので**規約として守る**）。衝突の中身を見て一方に寄せて合流を続けない（内容の判断は人が行う）。`git worktree add --force` / `git checkout --ignore-other-worktrees` で同じブランチを 2 か所に開かない。`git worktree remove --force` で未コミットの差分ごと消さない。作業ツリー側の `logs/` に進行状態・承認の記憶・ロック・集計を複製しない。サブブランチを push しない。リポジトリの配下（とりわけ `.claude/` の配下）に作業ツリーを作らない。

## 目的

並行して進める作業ツリーを安全に切り、タスクの切れ目でその成果を本流へ戻す。実体は `scripts/worktree.sh` の 4 サブコマンドで、AI は判断（切るか・どれを合流するか）だけを行い、`git` の操作はこのコマンドに委ねる。

- 要件: `.claude/docs/00_requirement/skills/20-common-step-worktree.md`
- 仕様（正。判定順・引数・出力・エラー識別子 `WT001`〜`WT008`・テスト ID）: `.claude/docs/10_spec/skills/20-common-step-worktree.md`

## 手順

1. **切るかどうかを決めるのは呼び出し元**（`00-workflow-issue-mr-driven`）。既定は切らない。切ると決まったときだけ次へ進む
2. **切る**: `bash .claude/skills/20-common-step-worktree/scripts/worktree.sh add <名前> [<置き場>]`
   - `<名前>` は `[a-z0-9][a-z0-9-]*`。置き場の既定は `<リポジトリの親>/<リポジトリ名>-wt/<名前>`（リポジトリの外）、サブブランチは `<本流の現在ブランチ>--wt-<名前>`
   - 出力された置き場を**ツールの作業ディレクトリにして**そこで始める（`cd` は使えない）。移れるのはそのツールを動かしている主体自身だけで、サブエージェントをこの作業ツリーで動かす指定は現時点では無い
   - 作業ツリーには `logs/hooks/` と `logs/sh/` だけが作られる。進行状態（`mr.json` / `review-state.json` / `merge-state.json` / `push-state.json` / `locks/` / `usage/` / `sessions/`）は共有ルートのものが参照される
3. **確かめる**: `... worktree.sh list` は本流でも作業ツリーでも動き、`path` / `branch` / `main` / `managed` / `doing` / `dirty` の JSON 配列を返す。自分が本流にいるか、他にどの作業ツリーがあるかはこれで見る
4. **切れ目まで進める**: 作業ツリーで新しいチケットを起こさない（採番は本流。`20-common-step-ticket` の `create` と `TK009`）。サブブランチを push しない（`20-common-step-commit-push` の push 前チェック 項目 5）。どの作業ツリーも作業中 0 枚になったら次へ
5. **合流する（本流から）**: `... worktree.sh merge <名前>|<サブブランチ名>|--all [-m <件名>]`
   - 前提 6 項目（本流で実行 / 本流に未コミット無し / 本流が切れ目 / 対象に未コミット無し / 対象が切れ目 / 同じ issue のブランチ）を全件検査してから合流する。1 つでも欠ければ `WT003` で 1 つも合流しない
   - 取り込み済みの対象は `up-to-date` で成功に数える（二度呼んでも結果が変わらない）
   - `WT004`（解けない衝突）が返ったら**自分で解消しない**。`git merge --abort` は済んでいるので、衝突ファイルの一覧をそのまま呼び出し元へ返す
6. **片付ける**: `... worktree.sh remove <名前>|<置き場> [--force]`。未コミットの差分は `--force` でも消さない。未合流のコミットは `--force` のときだけ、失われる件数を出してから消す
7. **記録を報告に含める**: 合流の試みは共有ルートの `logs/worktree-merges.jsonl` に 1 回 1 行（`result` は `merged` / `up-to-date` / `aborted`）。このパスを切れ目の報告に書く

## 参照

- 判定順・引数・出力・`WT001`〜`WT008`・合流の記録の形（正）: `.claude/docs/10_spec/skills/20-common-step-worktree.md`
- 作業ツリーの三分（`HOOK_ROOT` / `HOOK_WORKTREE` / `HOOK_SHARED_ROOT`）・進行状態の置き場・コマンドの分類: `.claude/docs/10_spec/フック共通仕様.md` §2・§5・§7-8・§8・§13
- 作業ツリーの置き場を指す引数を書き込み判定の対象にしない例外: `.claude/docs/10_spec/hooks/20-PreToolUse/workflow-guard.md` 制御方式 5・6（`WG-T21`）
- チケットの採番の本流一本化: `20-common-step-ticket` / push の本流限定: `20-common-step-commit-push`
- 切るかどうかの判断と切れ目の処理: `00-workflow-issue-mr-driven`
- 合流の単位・実行者・記録の決定と却下した案: DDR `i0050-03`。採番の決定: DDR `i0050-05`
- スクリプトの作法・共通 logger・テスト: `20-common-step-shell-script`

## エラー時の対処

| 状況 | 対処 |
|------|------|
| `WT001:` 本流でない | 本流の置き場（メッセージに出る）をツールの作業ディレクトリにして実行し直す。`cd` で移らない |
| `WT002:` 置き場・名前を使えない | 別の名前か置き場を指すか、既にある作業ツリーをそのまま使う。置き場はリポジトリの外にする |
| `WT003:` 合流の前提未充足 | 列挙された全件を解消する（タスクの切れ目まで進める / コミットする）。検査を飛ばす手段は無い |
| `WT004:` 解けない衝突 | 自分で解消しない。`--abort` 済みなので、衝突ファイルの一覧と「`--all` の残りは未処理」を添えて人に返す |
| `WT005:` 対象が見つからない / 管理対象外 | `list` で管理対象（`managed:true`）を確かめ、正しい名前かサブブランチ名を指す。外部の仕組みが作った作業ツリーは対象にできない |
| `WT006:` 片付けの前提未充足 | 未コミットの差分はコミットする（`--force` でも消さない）。未合流のコミットは合流するか、捨ててよいと判断できたときだけ `--force` を使う |
| `WT007:` git の失敗 | git の出力をそのまま読む。`--force` / `--ignore-other-worktrees` で押し通さない |
| `WT008:` 引数・環境の誤り（終了 2） | `-h` の使い方を見て呼び直す。`git` / `jq` の不在、detached HEAD は環境を直す |
| `WF204` で `git worktree` / `git merge` / `cd` が拒否された | 迂回しない。このスキルの提供コマンドに置き換えて実行する |
