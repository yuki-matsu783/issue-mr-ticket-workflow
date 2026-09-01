---
name: 20-common-step-commit-push
description: >
  コミットと push を提供コマンド commit.sh / push.sh 経由でだけ行う共通ステップ。commit.sh は対象を明示した
  コミット（メッセージ規約の検査・クレデンシャルや副産物の自動除外・除外一覧の出力）、push.sh は push 前チェック
  4 項目（未コミットなし / 作業中チケットなし / md と html の対 / draft 解除後の wip が空）を全件実施してから push する。
  Use when committing artifacts or ticket state changes, when pushing the current branch ("コミットして",
  "push して"), when a skill or provided command needs to commit internally, or when push is refused by CP005.
---

# 20-common-step-commit-push — コミットは commit.sh、push は push.sh

`git commit` / `git push` を直接実行しない（フック `block-direct-git` が拒否する）。全ファイルの一括ステージ・amend・`--no-verify`・AI 生成を示すフッターは、コマンドが受け付けない。

- 要件: `.claude/docs/00_requirement/skills/20-common-step-commit-push.md`
- 仕様（正。判定順・除外パターン・push 前チェックの定義・エラー識別子 CP001〜008）: `.claude/docs/10_spec/skills/20-common-step-commit-push.md`

## 手順

### コミット

```bash
bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "<prefix>: <日本語 1 行>" <ファイル>...
```

1. メッセージは `<prefix>: <日本語 1 行>`（prefix: `feat` / `fix` / `docs` / `chore` / `refactor` / `test` / `perf` / `build` / `ci` / `ai-asset`）。フッター・モデル名を含めない（CP002）
2. 対象は自分が変更したファイルを**ファイル単位**のパスで明示する（リポジトリルート相対）。`-A` / `.` / glob / ディレクトリは CP001（対象の指定の誤り。終了 2）。`-m` の値が無い・不明なオプションは CP007（終了 2）。オプションは順不同
3. 除外パターン（`assets/exclude-patterns.txt`。クレデンシャル類・開発副産物）に一致したファイルは除外一覧に移され、残りだけがコミットされる。対象はファイル単位で渡す（ディレクトリは CP001。除外パターンはファイル単位でしか当たらない）。**除外一覧は必ず報告する**（黙って落とさない）。全部が除外なら CP003（ステージ後の実パスに除外パターンが当たったときも CP003）、ステージした差分が無ければ CP004。`git commit` 自体が失敗したら CP008（git の出力そのまま。amend・`--no-verify` に当たるものは無い）
4. 空コミットは `--allow-empty`（MR 作成時の差分作りのみ。`20-common-step-feature-mr`）
5. 出力の最終行 `OK: N ファイルをコミットした（<SHA>）。除外: ...` を作業ログに残す。コミットのタイミングの既定はチケット完了時（完了検査が未コミットを拒否する）

### push

```bash
bash .claude/skills/20-common-step-commit-push/scripts/push.sh
```

0. 引数は取らない。`git` / `jq` の不在・detached HEAD・リポジトリルートに移れないときは CP007（終了 2）で止まる（検査の未充足ではないので、スキップ記録では解消しない）
1. 前チェックを全項目実施し、未充足を全件列挙して CP005 で止まる: (1) 未コミットの変更が無い / (2) 作業中のチケットが無い（宣言 `remote-write:push` があれば通す）/ (3) `wip/30_reports/`・`wip/20_plans/` の `.md` と `.html` が対（付録 `*-appendix-*.md` は対象外）/ (4) draft 解除後（`logs/merge-state.json` が `ready`）は `wip/` に `.gitkeep` 以外が無い
2. 意図的に飛ばす項目は `wip/push-check-skip.md` に `- 項目 N: <理由>` と書いて**コミットしてから**実行する（読まれるのは **`HEAD` にある版**だけで、未コミットの記録は無視され項目 1 で止まる = 記録は必ず MR の差分になる）。項目 4 は飛ばせない。飛ばした項目は出力に明記される
3. 上流が未設定なら `--set-upstream origin <現在ブランチ>` で push する。リモートに拒否されたら CP006（force しない。状況を報告する）
4. 出力の最終行 `OK: push した（<ブランチ>、N コミット）。スキップ: ...` を作業ログに残す

## 参照

- 提供コマンド: `scripts/commit.sh`、`scripts/push.sh`
- 除外パターン: `assets/exclude-patterns.txt`（1 行 1 glob。`/` を含まないパターンは basename、含むパターンはルート相対パスに一致。追加はこのファイルの編集）
- スキップ記録: `wip/push-check-skip.md`
- 直接実行の検知: `.claude/docs/10_spec/hooks/20-PreToolUse/block-direct-git.md`
- 状態変更のコミットを内部から行う呼び手: `20-common-step-ticket`（`ticket.sh`）、片付けの提供コマンド
- HTML の対の作り方: `20-common-step-report-view`

## エラー時の対処

| 状況 | 対処 |
|------|------|
| `CP001:` 対象未指定・一括指定・glob・ディレクトリ・ステージできないパス（終了 2） | ファイルのパスを 1 つずつ明示する（ディレクトリは配下を 1 つずつ）。綴り・未追跡のまま削除したファイル・`.gitignore` 対象を確認 |
| `CP002:` メッセージ規約違反 | `<prefix>: <日本語 1 行>` に直す。フッター（`Co-Authored-By:` 等）・モデル名を外す |
| `CP003:` 全対象が除外 | 除外されたファイルとパターンを見る。本当に必要なら除外パターンの見直しを提案する（黙って回避しない） |
| `CP004:` 差分なし | 変更が無い（既にコミット済み）。空コミットは `--allow-empty`（MR 作成時のみ） |
| `CP005:` push 前チェック未充足 | 列挙された全件を解消する。意図的に飛ばすなら `wip/push-check-skip.md` に理由を書いてコミット（項目 4 は不可） |
| `CP006:` リモート拒否 | force しない。git の出力を添えて報告する（fetch → `git merge origin/<default>` の要否は人間の判断） |
| `CP007:` 引数・環境の誤り（終了 2） | 呼び方（`-m` の値・不明なオプション・push.sh への引数）か環境（`git` / `jq` の不在・detached HEAD・ルートに移れない）を直す。検査の未充足ではないので `wip/push-check-skip.md` では解消しない |
| `CP008:` `git commit` 自体の失敗 | git の出力（コミット時の検査の失敗など）を読んで原因を直し、再実行する。amend・`--no-verify` は無い |
