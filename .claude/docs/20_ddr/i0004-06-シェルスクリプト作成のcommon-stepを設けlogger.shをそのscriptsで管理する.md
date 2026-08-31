---
type: ddr
title: i0004-06. シェルスクリプト作成の common-step を設け、logger.sh をその scripts で管理する
description: sh ファイル（スキルの scripts・フック）の作成手順を 20-common-step-shell-script として標準化し、共通 logger の実体と雛形をそのスキル配下に置く。.claude/lib/ のような無所属の置き場は設けない
tags: [ddr, skill, shell-script, logger]
keywords: [20-common-step-shell-script, logger.sh, scripts, 雛形, テスト, .claude/lib, 置き場, common-step]
---

# i0004-06. シェルスクリプト作成の common-step を設け、logger.sh をその scripts で管理する

## 背景

共通 logger（`i0004-01`）の実体を当初 `.claude/lib/logger.sh` に置く設計にしていたが、`.claude/lib/` はどのアセット種別にも属さない置き場で、要件 : 仕様 : スキルの 1:1:1 対応から外れる。また sh の書き方（雛形・規約の適用・テストの型・検査）は、チケット操作やコミットと同じく多くのタスクから共通で使う手順でありながら、専用の common-step が無かった。ユーザーから「シェルスクリプト作成の common-step を作り、その scripts で logger.sh を管理する」よう指示された。

## 決定

- 共通ステップ `20-common-step-shell-script` を新設する。役割は sh ファイルの作成・変更の標準手順（雛形からの作成・規約の適用・共通 logger の組み込み・テストの作成と実行・構文/静的検査）
- 共通 logger の実体は `.claude/skills/20-common-step-shell-script/scripts/logger.sh`、sh とテストの雛形は同スキルの `assets/` に置く。`.claude/lib/` は設けない
- logger の内部仕様（関数 API・行フォーマット・出力先・失敗時の黙殺）の正は同スキルの仕様書。`rules/logger.md` は sh を書く AI 向けの要点（使用義務・source の 1 行・レベルの使い分け・禁止事項）を持ち、詳細を再掲しない
- `20-common-step-ai-asset-creator` はスクリプト・フックを含むアセットの sh 作成をこのスキルに委ねる

## 理由

- 実体をスキル配下に置けば、要件・仕様・スキル・テストが 1 か所に揃い、logger の変更が「そのスキルの AI アセットフェーズ」として扱える
- sh の作成手順を common-step にすると、雛形と検査で書き手ごとのぶれ（stdout 汚染・set -e 漏れ・結果出力の型の不統一）を構造的に減らせる
- ルールと common-step の役割分担が明確になる: ルールは「常に守る規約」、common-step は「作るときの手順と道具」

## 却下した案

- **`.claude/lib/` に置く（当初案）**: 無所属の置き場が増え、要件・仕様の対応先が無い
- **logger をルール本文にインライン（source 不要のスニペット）**: 各 sh にコピーが散らばり、変更が全ファイルに波及する
- **logger を `20-common-step-commit-push` など既存スキルに同居**: 用途が無関係で、フック作成時の依存先として不自然

## 影響

- `00_requirement/skills/20-common-step-shell-script.md`・`10_spec/skills/20-common-step-shell-script.md`（新規）
- `rules/logger.md` の要件（実体のパス・詳細の参照先）、`rules/ルール体系.md` の logger 行
- スクリプトを持つ仕様 4 本の logger 参照、`20-common-step-ai-asset-creator` の仕様（sh 作成の委譲）
- DDR `i0004-01`（置き場の記述を更新）、用語辞書のスキル名一覧
