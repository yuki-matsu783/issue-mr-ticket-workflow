---
type: ddr
title: i0006-06. logger の読み込み行はルートの解決順を持つ 1 行にし、git rev-parse 単独に頼らない
description: 共通 logger と frontmatter.sh の読み込みを、スクリプト自身の場所から .claude を持つ親を探す → CLAUDE_PROJECT_DIR → git rev-parse → 失敗時ポリシー、の順で解決する雛形の 1 行に統一し、当初の仕様サンプルにあった git rev-parse 単独の形を採らなかった判断
tags: [ddr, logger, shell-script, 読み込み行, hooks]
keywords: [読み込み行, logger.sh, frontmatter.sh, BASH_SOURCE, CLAUDE_PROJECT_DIR, git rev-parse, fork, set -e, no-op, 失敗時ポリシー, LOGGER_ROOT]
---

# i0006-06. logger の読み込み行はルートの解決順を持つ 1 行にし、git rev-parse 単独に頼らない

## 背景

当初の仕様サンプルと `rules/logger.md` は、共通 logger の読み込みを `source "$(git rev-parse --show-toplevel)/.claude/skills/20-common-step-shell-script/scripts/logger.sh"` の 1 行で示していた。調査（issue #6 チケット 0003、付録 B §2-2）で 2 つの弱点が分かった。(1) フックは毎ツール呼び出しで起動するため、読み込みのたびに git を fork する（Git Bash で約 95 ms/回）。(2) git 不在・リポジトリ外では `$(...)` が空になり `source "/.claude/..."` となって、`set -e` の下で本体が即死する（ログ機構の失敗が本体を止めない、という logger 要件に反する）。加えて、同じ行で `frontmatter.sh`（source 専用）も読む必要があり、こちらは読めないまま続行すると判定値が空になり危険側に倒れる。

## 決定

- 読み込み行は `<lib>` と失敗時ポリシー（`nop` / `fatal` / `deny`）を引数に取る 1 行とし、雛形 `assets/script.template.sh` を正として各スクリプトはコピーして引数だけ変える
- ルートの解決順: `${BASH_SOURCE[0]%/*}` から `.claude` を持つ親を上向きに探す（fork なし）→ `CLAUDE_PROJECT_DIR` → `git rev-parse --show-toplevel`（空なら不採用）。解決したルートは `LOGGER_ROOT` に置く
- 失敗時: logger は no-op で続行、提供コマンドの `frontmatter.sh` は終了 2、拒否側フックの `frontmatter.sh` は `WFx09` の deny、案内側は無出力で通す
- 要件（`rules/logger.md`）は「1 行で読み込む・自作しない・失敗しても本体を止めない」までを持ち、解決順と失敗ポリシーは仕様が正

## 理由

- fork ゼロの経路が最初に来るので、フックの起動コストが読み込みで増えない
- 失敗ポリシーをライブラリと呼び手で分けることで、「ログは止めない」と「判定値が読めないなら続行しない」を両立できる
- 1 行に閉じるので、要件の「コピー禁止・1 行」と衝突しない

## 却下した案

- **`git rev-parse` 単独（当初のサンプル）**: fork と `set -e` 即死
- **`CLAUDE_PROJECT_DIR` 単独**: フック以外（提供コマンドをユーザーが直接実行するとき・テスト）では設定されない
- **相対パスの段数固定（`../../..`）**: スキルの `scripts/`・フックのイベントディレクトリ・両者の `tests/` で深さが違い、置き場ごとに行が変わる
- **失敗時は常に no-op**: `frontmatter.sh` が読めないまま提供コマンドやフックが続行すると、`allow` が空 = 何も許可しない / 何でも許可する、のどちらかに黙って倒れる

## 影響

- `10_spec/skills/20-common-step-shell-script.md`（Script 処理「読み込み行」・SS-T03〜04）
- `00_requirement/rules/logger.md`「使い方」
- `10_spec/フック共通仕様.md` §1（`lib/` 外の依存）・§3（拒否側の deny）
