---
type: ddr
title: i0006-04. テストは素の bash に共通ヘルパ test-lib.sh とランナー run-tests.sh を足す形にし、bats は導入しない
description: 機構のシェルスクリプトのテスト方式を、参考実装と同じ素の bash に統一し、assert 群を 1 ファイルの共通ヘルパに集約、2 つの置き場のテストを 1 コマンドで回すランナーを提供コマンドとして設ける判断。テスト ID を出力に載せて仕様表と突合する
tags: [ddr, test, shell-script, bats, run-tests]
keywords: [テスト方式, 素の bash, bats, test-lib.sh, run-tests.sh, テスト ID, PASS, FAIL, 突合, Windows, Git Bash, symlink, 性能閾値]
---

# i0006-04. テストは素の bash に共通ヘルパ test-lib.sh とランナー run-tests.sh を足す形にし、bats は導入しない

## 背景

調査（issue #6 チケット 0004）で参考実装のテスト 32 本を Git Bash で実行し、素の bash のテストが Windows / Linux の両方で実績を持つこと、失敗は方式ではなく symlink PATH・native jq × 日本語パス・fork 遅延（性能閾値）といった環境要因であることを確認した。bats は環境に無く、導入すると `.bats` 拡張子・`@test` 記法で仕様の雛形とフックの許可 glob（`hook-test`）を書き換えることになる。参考実装はファイルごとに assert を複製しており、テスト ID を出力に載せているのは agent-workflow 側だけだった。

## 決定

- 素の bash を踏襲する。assert（`assert_eq` / `assert_exit` / `assert_contains` / `assert_not_contains`）・`run_cmd`・`make_tmp_repo`・`hook_payload`・`finish` を `20-common-step-shell-script/scripts/test-lib.sh` に集約し、`test.template.sh` はこれを `source` する骨格にする
- assert の第 1 引数は仕様書のテスト ID（`TICKET-T01` 等。枝番は `-T02a`）で、出力は `PASS <ID>` / `FAIL <ID>: <理由>` の 1 行 1 ケース
- `run-tests.sh`（提供コマンド。識別子 TR001〜005）が `.claude/hooks/**/tests/` と `.claude/skills/*/scripts/tests/` のテストを列挙・実行し、ID の一覧を出して仕様の「テスト観点」表と突合できるようにする
- テストは `set -uo pipefail`（`-e` なし）で書き、終了コードは `run_cmd` が取る
- Windows 対策（symlink ではなくラッパースクリプト、jq 出力の CR 除去、性能閾値の無効化フラグ、非 ASCII を含まない一時パス）はヘルパに集約する

## 理由

- 依存を増やさない（導入先プロジェクトにも bats を要求しない）。仕様の雛形と許可 glob をそのまま使える
- ID 付き出力なら、仕様表とのカバレッジ突合が grep だけでできる
- assert の集約で DRY を守り、Windows 対策を 1 箇所で直せる

## 却下した案

- **bats-core の導入**: `--filter` と TAP 連携は楽だが、依存追加と雛形・許可 glob の変更が要り、現規模（テスト ID 数十）では過剰。MSYS での速度も未計測
- **参考実装どおりファイルごとに assert を複製する**: DRY 違反で Windows 対策が散る
- **テスト ID を書かない（説明文だけ）**: 仕様表との突合が人手になる

## 影響

- `10_spec/skills/20-common-step-shell-script.md`（OUT ひな形・Script 処理 run-tests.sh・テスト観点 TR-T / SS-T03〜04）
- `10_spec/フック共通仕様.md` §6（接頭辞 TR）
- `00_requirement/skills/20-common-step-shell-script.md`（共通ライブラリの提供）
