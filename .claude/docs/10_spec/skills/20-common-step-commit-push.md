---
type: spec
title: 20-common-step-commit-push スキル 仕様
description: コミット・push の提供コマンド（commit.sh / push.sh）の内部仕様。メッセージ検査、対象ファイルの明示と自動除外、push 前チェックの項目定義と意図的スキップの記録、エラー識別子（CP0xx）を定める
tags: [spec, skill, common-step]
keywords: [commit.sh, push.sh, 提供コマンド, メッセージ検査, 除外リスト, push 前チェック, スキップ記録, allow-empty, CP0xx]
---

# 20-common-step-commit-push スキル 仕様

## 概要・禁止事項

コミット・push の共通ステップの内部仕様。対応する要件は [00_requirement/skills/20-common-step-commit-push.md](../../00_requirement/skills/20-common-step-commit-push.md)。

コミットと push の提供コマンドの実体はこのスキルの `scripts/commit.sh` と `scripts/push.sh`。`git commit` / `git push` の直接実行はフック（`block-direct-git`）が拒否し、提供コマンド経由の実行だけが通る（識別の仕組みはフックの仕様が正）。

禁止事項:

- `git commit` / `git push` の直接実行、フックの無効化、検知を避ける書き方
- 全ファイルの一括ステージ（`-A` / `.` / glob）— コマンドが受け付けない
- 直前コミットの書き換え（amend）— 訂正は新規コミット
- AI 生成を示すフッター・モデル名のメッセージへの混入 — コマンドが拒否する
- 失敗時の自動ロールバック（reset 等）
- 除外されたファイルを黙って落とすこと — 出力の除外一覧を必ず報告する

## 呼出条件

- すべてのスキルが、成果物・状態変更のコミットと push を行うときに読み込む
- `20-common-step-ticket` の `ticket.sh`・片付けの提供コマンドが、状態変更のコミットに内部から `commit.sh` を使う
- `20-common-step-feature-mr` が空コミット（`--allow-empty`）と初回 push に使う

## IN / OUT

| 操作 | IN | OUT |
|------|----|----|
| コミット | メッセージ（`<prefix>: <日本語>`）、対象ファイルのパス列 | コミット SHA、コミットされたファイル一覧、自動除外されたファイル一覧 |
| push | なし（現在ブランチ） | push 結果、実施された前チェックの項目と結果、スキップされた項目（あれば） |

## IN / OUT サンプル

```bash
bash .claude/skills/20-common-step-commit-push/scripts/commit.sh \
  -m "docs: 調査結果レポートを追加" wip/30_reports/0002-investigation.md wip/30_reports/0002-investigation.html
# => OK: 2 ファイルをコミットした（a1b2c3d）。除外: なし

bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "feat: ログイン検証を追加" src/auth.ts .env
# => OK: 1 ファイルをコミットした（d4e5f6a）。除外: .env（クレデンシャル類）

bash .claude/skills/20-common-step-commit-push/scripts/push.sh
# => CP005: push できない。未充足: 未コミットの変更が 2 件（src/a.ts, src/b.ts） / レポートの対が不揃い（0003-design.md に .html が無い）
```

## OUT ひな形

- 除外パターン一覧: `assets/exclude-patterns.txt`。1 行 1 パターン（glob）。クレデンシャル類（`.env*`・秘密鍵・トークンを含む名前）と開発副産物（ビルド出力・依存ディレクトリ・OS 固有ファイル）を初期収録し、追加はこのファイルの編集で行う
- スキップ記録: `wip/push-check-skip.md`。意図的に飛ばす検査項目と理由を書いてコミットする（MR の差分に見える）。`push.sh` はこのファイルに列挙された項目だけを飛ばし、飛ばした事実を出力する（項目 4 はスキップ不可）

## 参照ナレッジ

- prefix の一覧と使い分け・コミットのタイミング: 要件書（Conventional Commits + `ai-asset`。タイミングの既定はチケット完了時）
- 直接実行の検知・拒否の仕組み: `10_spec/hooks/20-PreToolUse/block-direct-git.md`
- 空コミットが許される場面: `20-common-step-feature-mr`（MR 作成時の差分作り）

## Script 処理

終了コードは成功 0 / 検査未充足 1 / 引数・環境の誤り 2。出力の最終行は `OK:` または `CPxxx:`。オプション（`-m`・`--allow-empty` など）は順不同で受け付ける。ログ: 共通 logger（`20-common-step-shell-script` の `scripts/logger.sh`。内部仕様は `10_spec/skills/20-common-step-shell-script.md`）を使う。使い分けは `rules/logger.md`。

`block-direct-git` フックが拒否するのは AI による `git` の直接実行であり、提供コマンド（このスキルと各スキルのスクリプト）の内部からの `git` 実行は拒否の対象外（識別方法はフックの仕様が正）。

### commit.sh -m "<メッセージ>" [--allow-empty] <ファイル>...

1. メッセージを検査する: `^(feat|fix|docs|chore|refactor|test|perf|build|ci|ai-asset): .+` に一致し 1 行であること。AI フッター・モデル名（`Co-Authored-By`・`Generated with`・モデル名の既知パターン）を含むと CP002
2. 対象ファイルの指定を検査する: 未指定（`--allow-empty` 時を除く）・`-A`・`.`・glob は CP001
3. 各対象を除外パターンと突き合わせ、一致したものを除外一覧に移す。全対象が除外されたら CP003
4. 残った対象だけを `git add --` でステージし、ステージされた差分が空なら CP004（`--allow-empty` 時は空のままコミットする）
5. `git commit` を実行し（amend・`--no-verify` に相当するオプションは存在しない）、コミット時の検査（フック）が失敗したらその出力を返して停止する（例外として、除外一覧は成功時も失敗時も出力する）
6. SHA・コミットしたファイル・除外一覧を出力する

### push.sh

1. push 前チェックを**全項目**実施し、未充足を全件列挙して CP005 で拒否する（1 件目で止めない）。項目の定義（この表が正）:

| # | 項目 | 判定 |
|---|------|------|
| 1 | 未コミットの変更が無い | `git status --porcelain` が空 |
| 2 | 作業中のチケットが無い | `wip/10_tickets/10_doing/` が空。ただし作業中チケットの「やってよいこと」に push が宣言されていれば通す |
| 3 | レポート・計画書の対が揃っている | `wip/30_reports/`・`wip/20_plans/` の `.md` と `.html` が同じベース名で対になっている（内容の同期は HTML 検査とレビューが担う） |
| 4 | draft 解除後の作業領域が空 | `logs/` の記録が draft 解除済みを示すとき、`wip/` に `.gitkeep` 以外が無い |

2. `wip/push-check-skip.md` に列挙された項目は飛ばし、飛ばした項目名を出力に含める（記録ファイル自体が未コミットなら項目 1 で止まる = 記録は必ず MR の差分になる）。ただし項目 4（draft 解除後の作業領域が空）は安全性の項目のため**スキップできない**（記録に書かれていても無視して検査する）
3. `git push`（上流未設定なら `--set-upstream origin <現在ブランチ>`）を実行し、リモートに拒否されたら CP006 で出力をそのまま返す（force しない）
4. 成功時は push した範囲（前回 push からのコミット数）を出力する

### エラー識別子

| ID | 条件 | メッセージに含める内容 |
|----|------|----------------------|
| CP001 | 対象未指定・一括指定 | 対象をパスで明示すること。自分が変更したファイルだけを渡すことの注意 |
| CP002 | メッセージ規約違反 | 期待する形式（`<prefix>: <日本語 1 行>`）と検出した違反（フッター等） |
| CP003 | 全対象が除外 | 除外されたファイルと一致したパターン |
| CP004 | 差分なし | 空コミットは `--allow-empty`（MR 作成時のみ）に限ることの案内 |
| CP005 | push 前チェック未充足 | 未充足の全件と解消方法。意図的に飛ばすなら `wip/push-check-skip.md` に理由を書いてコミットすることの案内 |
| CP006 | リモート拒否 | git の出力。force しないこと・状況を報告することの案内 |

### テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| CP-T01 | 正常系 | 対象指定コミットと SHA・一覧の出力 |
| CP-T02 | 異常系 | フッター入りメッセージが CP002 |
| CP-T03 | 正常系 | 除外パターン一致が除外一覧に出て残りがコミットされる |
| CP-T04 | 異常系 | 全除外が CP003、差分なしが CP004 |
| CP-T05 | 異常系 | push 前チェック未充足が CP005 で全件列挙 |
| CP-T06 | 正常系 | スキップ記録がある項目だけ飛び、出力に明記される |
| CP-T07 | 境界 | 宣言済み作業中チケットがあるときの push が項目 2 を通る |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 対象を明示・一括ステージ不可・自分のファイルのみ | commit.sh 2（CP001） |
| メイン: prefix とまとまりの判定・複数コミットへの分割 | 処理は AI（スキル本文）。コマンドは 1 回 1 まとまりを受ける |
| メイン: `<prefix>: <日本語>` 1 行・AI フッター禁止 | commit.sh 1（CP002） |
| メイン: 自動除外の報告 | commit.sh 3・6（除外一覧の常時出力） |
| メイン: push 前チェックと未充足時の拒否 | push.sh 1（項目定義の表・CP005） |
| メイン: コミット・push の結果を記録に残す | 出力（SHA・件数・チェック結果）を作業ログへ（AI） |
| 代替: まとまりごとに分けて順にコミット | commit.sh を複数回呼ぶ（スキル本文の手順） |
| 代替: 意図的スキップは MR の差分に見える形で記録 | push.sh 2（wip/push-check-skip.md） |
| 代替: 他セッションの変更を含めない | commit.sh 2 の注意文 + AI の対象選定 |
| 例外: 拒否の迂回禁止 | 禁止事項 + フック（block-direct-git） |
| 例外: 対象なしはコミットしない・空コミットの限定 | CP004・`--allow-empty` |
| 例外: 失敗時の自動ロールバック禁止 | 禁止事項（コマンドは巻き戻しをしない） |
| 例外: 検査失敗は原因を直す | commit.sh 5（フック出力の透過） |
| 例外: amend せず訂正コミット | commit.sh（amend オプション不在） |
| 規約: prefix 一覧・除外リスト外の新種の扱い | 参照ナレッジ・assets/exclude-patterns.txt への追加提案（AI） |
| 整合: 手順の再掲禁止・タイミングは呼び出し元 | 参照ナレッジ |
