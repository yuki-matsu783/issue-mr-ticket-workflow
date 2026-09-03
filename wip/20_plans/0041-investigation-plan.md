---
type: investigation-plan
title: 0041 shlex 調査の計画
description: cmdpos.sh を Python の shlex に寄せられるかを判断するための調査計画。shlex の守備範囲の切り分け、ホットパスの起動コストの実測、実行環境の前提の 3 観点を立て、2 枚の調査チケットに割り付ける
tags: [investigation-plan, issue-15, cmdpos, shlex]
keywords: [調査計画, shlex, cmdpos, ホットパス, 起動コスト, DDR i0009-22, DDR i0001-14, punctuation_chars]
---

# 0041 shlex 調査の計画

## 対象

- 対象 issue: #15 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/15（2026-09-03 の追記分）
- PR: #36 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/36（draft）
- 全体計画: `wip/00_overall_plan/overall-plan.md` フェーズ 3（調査実施）の準備

## 調査観点

全体計画書「保留した点」の 3 項目（shlex の置き場・DDR i0009-22 の扱い・uv 導入の要否）を決めるために必要な問いだけを立てる。答えが設計フェーズの判断に効かない問いは含めない。

| 観点 | 問い | 効く判断点 | 受け入れ条件 |
|---|---|---|---|
| A-1 | `shlex` は `cmdpos.sh` の出力 10 項目（`CP_EXE` / `CP_ARGS` / `CP_SUBCMD` / `CP_REDIRECTS` / `CP_WRITE_TARGETS` / `CP_OPAQUE` / `CP_PROVIDED` / `CP_DATA` / `CP_GITLIKE` / `CP_DEGRADED`）のうち、どれをそのまま供給できるか | shlex の置き場 | 1 |
| A-2 | `shlex` が扱えない構文はどれか。ヒアドキュメント本文・`$( )` とバッククォートの入れ子・`&>` と `2>&1` の fd 複製・コメント・PowerShell のヒアストリングと行継続の 5 つについて、追加実装がどれだけ残るか | shlex の置き場 | 1 |
| A-3 | `shlex` を通した結果と現行 `cmdpos.sh` の結果に差が出る入力はあるか。差があるなら、どちらが bash の実際の解釈に近いか | shlex の置き場（テスト照合役案の価値） | 1 |
| B-1 | ホットパス 5 本が毎ツール呼び出しで同時起動する条件で、`cmdpos.sh` を Python 実装に替えた場合の 1 ツール呼び出しあたりの増分は何ミリ秒か | DDR i0009-22 の上書き可否 | 2 |
| B-2 | Python 実装にする場合、`.claude/` に何が要るか（インタプリタの解決方法・起動オプション・import するモジュール）。DDR i0001-14「全実行環境でアクセスできるものだけを判定材料にする」を満たすために何が前提になるか | uv 導入の要否 | 2 |

A-3 は「shlex をテストの照合役として置く」案の価値を測るための観点。差が 1 件も出ないなら照合役案の価値は低く、差が出るなら現行の自作パーサに実在するバグが見つかったことになる。

含めなかった問い:

- **Windows / Git Bash で `python3` が実際に使えるか**: この実行環境（Linux コンテナ）から測れない。B-2 で「前提として何が必要か」を列挙するに留め、実測は保留する
- **提供コマンド層を Python 化した場合の効果**: 本 PR のスコープ外（#15 の別の受け入れ条件）
- **`scope.sh` / `hook-common.sh` の移行可否**: 全体計画書のスコープ外

## 対象と方法

書き込みは `wip/` 配下だけ。`.claude/` 配下は読むだけで変更しない。

| 観点 | 読む場所 | 確かめ方 |
|---|---|---|
| A-1 | `.claude/hooks/lib/cmdpos.sh`、`.claude/docs/10_spec/フック共通仕様.md` §7、`.claude/hooks/lib/tests/test_cmdpos.sh` | `cmdpos.sh` の公開 API の定義（ヘッダコメントの 10 項目）を表に起こし、`shlex.shlex(punctuation_chars=True)` の出力と 1 項目ずつ突き合わせる |
| A-2 | 同上、および Python 標準ライブラリ `shlex` のソース（`python3 -c "import shlex, inspect"` で参照） | 5 つの構文それぞれについて最小入力を作り、`shlex` に食わせて何が起きるかを記録する |
| A-3 | `.claude/hooks/lib/tests/test_cmdpos.sh` のテスト入力 | `wip/tmp/` に置いた差分スクリプトで、同じ入力を現行 `cmdpos.sh` と `shlex` 版の試作に食わせて出力を比べる |
| B-1 | `.claude/hooks/lib/cmdpos.sh`、`.claude/hooks/20-PreToolUse/` の 4 本と `10-UserPromptSubmit/workflow-entry.sh` | `wip/tmp/` の計測スクリプトで、(1) `bash` で `cmdpos_parse` を 1 回、(2) `python3` を起動して同等の解析を 1 回、をそれぞれ 50 回測る。5 本同時起動の条件は 1 本あたりの差 × 5 で見積もる |
| B-2 | `.claude/docs/20_ddr/i0001-14-*.md`、`.claude/hooks/lib/hook-common.sh` の読み込み行、`.claude/settings.json` | 読み取りのみ。Python 実装にした場合に解決が必要になる項目を列挙する |

計測スクリプトと試作は `wip/tmp/` に置き、リポジトリの追跡ファイルには残さない（全体計画書「やってよいこと」の合意どおり）。外部への問い合わせ（`curl` / `wget` / Web 検索）は行わない。`shlex` は Python 標準ライブラリで、この環境の `python3` 3.11.15 に同梱されている。

## 調査チケット

| 番号 | 種類 | 担う観点 | 先行 | やってよいこと |
|---|---|---|---|---|
| 0042 | investigation | A-1・A-2・A-3 | 0041 | `read` / `build-test`（`python3` と `bash` の実行。書き込みは `wip/` のみ） |
| 0043 | investigation | B-1・B-2 | 0041 | `read` / `build-test`（同上） |

2 枚は同じ type なので 1 ワークとして 1 回のレビュー境界にまとまる。0042 と 0043 に依存関係は置かない（B-1 の計測は A の切り分け結果を待たずにできる）。

次の計画チケット 0044（`ai-asset-design-plan`）の `predecessors` に 0042・0043 の両方を入れる。

## 成果物の形

調査結果レポート `wip/30_reports/0042-investigation.md` と `wip/30_reports/0043-investigation.md`（各々 HTML の対つき）に、次が書かれていれば設計フェーズが判断できる。

- **0042**: `CP_*` 10 項目 × 「shlex が供給する / 追加実装が残る」の表。扱えない構文 5 つそれぞれの最小入力と `shlex` の実際の出力。現行実装との差分の有無と、差があった入力の一覧
- **0043**: `bash` 版と `python3` 版の 1 回あたりの所要時間（各 50 回の中央値）。ホットパス 5 本ぶんの見積り増分。Python 実装にした場合に `.claude/` に必要になる前提の一覧
- 両方: 答えが出なかった問いは、理由付きで「残課題」に残す

設計フェーズはこの 2 本を材料に、置き場を 3 案（本番置換 / テストの照合役 / 採用しない）から選び、DDR に書く。

## 保留した点

| 保留した項目 | 決める時期 |
|---|---|
| Windows / Git Bash での `python3` の可用性の実測 | 本 PR では行わない。B-2 の前提の列挙で代え、実測が要ると設計フェーズが判断したらフィードバック計画で別 issue にする |
| `shlex` 版の試作をどこまで作り込むか | 0042 の中で判断する。A-3 の差分を取れる最小限に留め、本番実装は AI アセット実装フェーズに回す |
