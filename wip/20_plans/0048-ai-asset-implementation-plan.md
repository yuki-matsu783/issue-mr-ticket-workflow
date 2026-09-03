---
type: ai-asset-implementation-plan
title: 0048 AI アセット実装・テストの計画
description: 設計 0047 の決定「フックのコマンド検査に外部の字句解析器を使わない」を実装に反映する計画。本番コードは据え置きで、据え置きの確認とヒアドキュメント終端後の検出を固定するテスト 1 件の追加を実装対象とする
tags: [ai-asset-implementation-plan, issue-15, cmdpos, shlex, テスト]
keywords: [実装計画, cmdpos.sh, test_cmdpos.sh, HK-T05, HK-T12, run-tests, ロックアウト対策, 参照更新, 据え置き]
---

# 0048 AI アセット実装・テストの計画

## 対象

- 対象 issue: #15 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/15
- PR: #36 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/36
- 根拠とする設計: `.claude/docs/20_ddr/i0015-01-フックのコマンド検査に外部の字句解析器を使わない.md`、`.claude/docs/10_spec/フック共通仕様.md` §1・§7・§11
- 設計結果レポート: `wip/30_reports/0047-ai-asset-design.md`
- 満たす受け入れ条件: #15 の条件 5「決定した方針が実装され、既存の `cmdpos` テストが同じ検査 ID・同じ結果で通る」

## 変更対象

決定は「採用しない（`cmdpos.sh` は純 bash のまま据え置く）」なので、**本番コードの変更は無い**。DDR `i0015-01` の「影響」節が挙げる変更先は仕様書 §1・§7 の 2 箇所だけで、いずれも設計フェーズ（0047）で済んでいる。

| # | 対象 | 区分 | 内容 |
|---|---|---|---|
| 1 | `.claude/hooks/lib/cmdpos.sh` | 変更しない | 据え置きが決定。差分が空であることを検査で示す |
| 2 | `.claude/hooks/lib/tests/test_cmdpos.sh` | 更新 | HK-T05 に「ヒアドキュメント終端の後に続くコマンドを検出する」1 件を足す。ID は既存のまま増やさない |
| 3 | `.claude/hooks/config/scope-limits.json` | 変更しない | 0045 で足した 2 行（`python3 wip/tmp/probe.py` / `bash wip/tmp/bench.sh`）は DDR `i0015-02` の決定どおり残す |
| 4 | 仕様書 `.claude/docs/**` | 変更しない | `ai-asset-implementation` の型が deny。0047 で反映済み |

### テストを 1 件足す理由

0046 の A-3 が見つけた「`shlex` が誤る 7 件」のうち 6 件は `test_cmdpos.sh` が既に固定している。固定されていないのは 1 件だけである。

| 入力 | 現行実装 | `shlex` 版 | 既存テスト |
|---|---|---|---|
| `echo "$(git commit -m x)"` | 検出 | 見落とし | HK-T05 複合 |
| `` echo `git commit` `` | 検出 | 見落とし | HK-T05 複合 |
| `echo $((1<<2)); git commit` | 検出 | 見落とし | HK-T05 負のケース |
| `foo#bar git status` | `exe=foo#bar` | 切り詰め | HK-T05 負のケース |
| `cat <<EOF⏎foo; git push⏎EOF` | 本文はデータ | 誤検知 | HK-T05 負のケース |
| `git 'commit'` | `sub=_`（既知の制約） | 正しく解く | HK-T05 opaque |
| **`cat <<EOF⏎EOF⏎git push`** | **検出（2 段）** | **見落とし** | **無し** |

仕様書 §7 は今回の追記で「ヒアドキュメントの終わりの後に続くコマンドが吸い込まれる」を、外部の字句解析器では代替できない働きの具体例として名指しした。仕様が振る舞いを主張している以上、それを固定するテストが要る。§11 の HK-T05 の観点には「ヒアドキュメント」が既に含まれるので、仕様の変更は不要で、観点の中の入力が 1 件増えるだけになる。

**新しいテスト ID は作らない。** 受け入れ条件 5 の「同じ検査 ID」を保つため、追加は HK-T05 の中に置く。

## 許可範囲案

実装チケット 0049 に与える範囲。`scope-limits.json` の `ai-asset-implementation` の既定（`.claude/hooks/**` を含む）より狭く取る。

| ステップ | 書き込み先 | 実行コマンド |
|---|---|---|
| 1〜3 | `.claude/hooks/lib/tests/**`、`wip/**`、`logs/**` | `run-tests.sh`（hook-test）、`git diff`（read）、`check-html.sh`（read） |

- `allow.write`: `[".claude/hooks/lib/tests/**", "wip/**"]`
- `allow.ops`: `["read", "hook-test"]`
- `build-test` は宣言しない。npm も `wip/tmp/` の計測スクリプトも今回は使わない
- `.claude/hooks/lib/cmdpos.sh` を書き込み先に**入れない**。据え置きが決定なので、書けないほうが決定に沿う

## テスト方針

| テスト ID | ステップ | 種別 | 実行方法・確認内容 |
|---|---|---|---|
| HK-T05 | 2・3 | 機械 | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*cmdpos*' --ids`。追加した入力を含めて PASS |
| HK-T12 | 3 | 機械 | 同上。提供コマンドの識別。変更しないが ID の一覧に残ることを確認 |
| HK-T02 | 3 | 機械 | `--filter '*config_integrity*'`。`commands.build-test` の 2 行追加が形式検査を壊していないことの再確認 |
| HK-T15・T16 | 3 | 機械 | `--filter '*scope*'`。分類の振る舞い |
| 全体 | 3 | 機械 | `run-tests.sh --ids`（フィルタ無し）。ID の集合と PASS / FAIL 件数を 0045 時点（`test_config_integrity.sh` 95 / `test_scope.sh` 312 / `test_workflow_guard.sh` 147 / `test_cmdpos.sh` 281、いずれも失敗 0）と突き合わせる |

eval の定義は無い。今回の変更は機械テストで全量が見られる範囲に収まる。

## ステップ

固定順（設定・定義 → 中核 → 中核の機械テスト → スキル・ルール → 参照更新）に当てはめると、設定・定義とスキル・ルールは対象なし、中核は「変更しない」の確認になる。

| # | 区分 | 内容 | 依存 | チケット |
|---|---|---|---|---|
| 1 | 中核 | `cmdpos.sh` が基準点から変わっていないことを `git diff origin/main -- .claude/hooks/lib/cmdpos.sh` が空であることで示す | なし | 0049 |
| 2 | 中核の機械テスト | `test_cmdpos.sh` の HK-T05 に `cat <<EOF⏎EOF⏎git push` を足す。期待は 2 段・`exe=git sub=push`（`cat` の段が消えないことも併せて見る） | 1 | 0049 |
| 3 | 中核の機械テスト | `run-tests.sh --ids` を全体とフィルタ別に実行し、ID の集合と件数を 0045 時点と突き合わせる | 2 | 0049 |
| 4 | 参照更新 | 下表の検索を実施し、更新箇所が無いことを記録する | 3 | 0049 |

ステップ 1〜4 は 1 チケット（0049）に収める。中核の変更が無く、テストの追加が 1 件だけで、分割すると確認の単位が細かくなりすぎるため。

## 参照更新一覧

名称・パスの変更は無い。「変更が無いこと」を検索で示す。

| 対象 | 検索語 | 現時点のヒット | 除外 | 実装後の期待 |
|---|---|---|---|---|
| `shlex` の言及 | `grep -rln "shlex" .claude/` | 3 件（`20_ddr/i0015-01`、`20_ddr/i0015-02`、`10_spec/フック共通仕様.md`） | なし | 同じ 3 件。増減があれば書き漏れか書きすぎ |
| DDR の被参照 | `grep -rln "i0015" .claude/` | 3 件（同上） | なし | 同じ 3 件 |
| テスト ID | `grep -rn "HK-T05\|HK-T12" .claude/` | 仕様書 §11 の定義行と `test_cmdpos.sh` の assert | DDR・用語辞書の別名（該当なし） | ID の集合が変わらない |
| DDR 一覧 | `ls .claude/docs/20_ddr/` | 127 件。手書きの索引ファイルは存在しない | なし | 索引の更新作業は不要 |

用語辞書への追加は無い。`i0015-01` が使う「外部の字句解析器」は一般語で、機構が導入した概念ではないため（`ai-asset-design-docs` ルールの「載せる語は機構固有語に限る」に当たらない）。

## ロックアウト対策

中核（フック・`settings.json`・入口ガード）を**変更しない**ので、自分が止まる経路は原理的に無い。念のため境界を示す。

| 変えるもの | ホットパスへの影響 | 復旧手順 |
|---|---|---|
| `test_cmdpos.sh`（テストファイル） | 無し。`settings.json` から起動されず、フックの実行経路に入らない | `git checkout <0049 の base_sha> -- .claude/hooks/lib/tests/test_cmdpos.sh` |

- `WORKFLOW_ENTRY_ENFORCE=0` は使わない（ユーザーの明示が無い）
- 基準点は 0049 の `base_sha`。テストファイル 1 本を戻せば元に戻る

## リスク

| リスク | 影響 | 見つけ方・巻き戻し方 |
|---|---|---|
| 追加したテストが落ちる（現行実装がヒアドキュメント終端後を検出していない） | 0046 A-3 の c50 の観測（現行実装は 2 段で `git:push` を検出）と食い違う | ステップ 2 の実行時点で分かる。落ちたら**テストを緩めず**、観測と実装のどちらが誤りかを切り分けて結果報告に書く。仕様 §7 の記述の訂正が要るなら設計への差し戻しになる |
| ID の集合が 0045 時点と変わる | 受け入れ条件 5 の「同じ検査 ID」を満たせない | ステップ 3 の `--ids` の突き合わせで検出。追加は既存 ID の中に置くので、変われば書き方の誤り |
| `scope-limits.json` の 2 行が残ることへの異論 | `wip/tmp/` は追跡外なので、実質は任意の Python / bash 実行を通す | DDR `i0015-02`「残る弱点」に明記済みで、決定として残す。異論はフィードバック計画（フェーズ 8）で扱う |

## 保留した点

| 項目 | 決める時期 |
|---|---|
| `cmdpos.sh` の既知の制約（`git 'commit'` のサブコマンドが `_` になる）を別 issue にするか | フェーズ 8 フィードバック計画。#15 の受け入れ条件に無く、本 PR の範囲外 |
| `scope.sh` / `hook-common.sh` の移行判断 | #15 の別の受け入れ条件。本 PR では `i0015-01` の「影響」節に見込みを書くに留めた |
| `wip/10_tickets/20_done` に残る #9 のチケット 39 枚の削除 | フェーズ 9。WF303 のため人間の手が要る |
