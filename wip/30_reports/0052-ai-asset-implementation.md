---
type: ai-asset-implementation
title: 0052 shlex 据え置きの決定を実装に反映しテストで固定した結果
description: 決定「外部の字句解析器を使わない」に沿って cmdpos.sh が据え置きであることを差分で示し、決定の根拠のうちテストで固定されていなかった 1 件を HK-T05 に足して、テスト 25 本 165 ID が全通過したことを確かめた実装結果。issue #15 の受け入れ条件 5 に対応する
tags: [ai-asset-implementation, issue-15, cmdpos, shlex, テスト]
keywords: [HK-T05, HK-T12, run-tests, ヒアドキュメント, データ段, 据え置き, 参照更新, TR006]
---

# 0052 shlex 据え置きの決定を実装に反映しテストで固定した結果

- 対象 issue: #15 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/15
- PR: #36 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/36
- 計画: `wip/20_plans/0048-ai-asset-implementation-plan.md`
- 設計: `.claude/docs/20_ddr/i0015-01-フックのコマンド検査に外部の字句解析器を使わない.md`

## サマリ

**本番コードは 1 行も変えていない。** 決定が「据え置き」なので、変更しないことが実装の結果になる。実質の作業はテスト 1 件の追加である。

| 何を | 結果 |
|---|---|
| `cmdpos.sh` の差分 | `git diff origin/main` が 0 行 |
| `scope-limits.json` の差分 | 0045 で足した 2 行のみ（本チケットでは触れていない） |
| `test_cmdpos.sh` | HK-T05 に 1 入力・4 アサーションを追加（281 → 285 件） |
| テスト全体 | 25 本 / 165 ID が PASS、失敗 0 |
| 参照更新 | 4 つの検索を実施し、更新箇所ゼロを確認 |

## 作成・更新したアセットの一覧

| アセット | 区分 | 仕様書の節 |
|---|---|---|
| `.claude/hooks/lib/tests/test_cmdpos.sh` | 更新 | フック共通仕様 §11 `HK-T05`（観点に「ヒアドキュメント」を含む）。振る舞いの正は §7 |
| `.claude/hooks/lib/cmdpos.sh` | 変更なし | §7。DDR `i0015-01` の決定どおり据え置き |
| `.claude/hooks/config/scope-limits.json` | 変更なし | §8。0045 で足した 2 行は DDR `i0015-02` の決定どおり残す |

新規作成したアセットは無い。

## 追加したテスト

`test_cmdpos.sh` の `case_hk_t05_negative` の末尾に次を足した。新しいテスト ID は作っていない。

```bash
# ヒアドキュメントは区切り語で終わる。本文はデータ段（data=1）になり、区切り語の後に続くコマンドは本文に吸い込まれず実行位置として見える
run_cmd dump $'cat <<EOF\nEOF\ngit push'
assert_contains "HK-T05" "count=3"
assert_contains "HK-T05" "seg0: exe=cat"
assert_contains "HK-T05" "seg1: exe=_ sub= args=[] redir=[] write=[] opaque=0 provided= gitlike=1 data=1"
assert_contains "HK-T05" "seg2: exe=git sub=push args=[push] redir=[] write=[] opaque=0 provided= gitlike=0 data=0"
```

この入力は 0046 の A-3 が見つけた「`shlex` が誤る 7 件」のうち、唯一テストで固定されていなかったものである。仕様書 §7 は今回の追記でこの振る舞いを「外部の字句解析器では代替できない働き」の具体例として名指ししており、仕様が主張している以上テストで固定しておく必要があった。

### 期待値が計画と違った点

計画は「2 段」を期待すると書いていたが、実際は **3 段**だった。

```
count=3 degraded=0
seg0: exe=cat  sub=_    ... data=0
seg1: exe=_    sub=     ... gitlike=1 data=1   ← ヒアドキュメント本文（空）
seg2: exe=git  sub=push ... gitlike=0 data=0
```

0046 が「2 段」と書いたのは、調査で作った `shlex` 版の試作がヒアドキュメント本文をデータ段として出さなかったためである。`cmdpos.sh` は本文も 1 段として出し、`data=1` を立てて「実行位置ではない」と示す。**判定の結論（`git push` を実行位置として検出する）は 0046 の観測どおり**で、食い違ったのは段の数え方だけだった。

テストを緩めず、実際の 3 段構造をそのまま固定した。`seg1` のデータ段も明示的に書いてある。

`seg1` の `gitlike=1` は空のデータ段に立っているが、これは仕様どおりである。`CP_GITLIKE` は実行体が `_` のときに**コマンド文字列全体**（`CP_LOWER`）に語としての `git` があるかで決まる（`cmdpos.sh` 349 行）。拒否側に倒すための保守的な判定で、セグメント単位の判定ではない。

## テストの結果

`bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids --timeout 300`

**25 本すべて PASS、165 ID すべて PASS、FAIL 0。**

0045 時点の記録と突き合わせた 4 本。

| テスト | 0045 時点 | 今回 | 差 |
|---|---:|---:|---|
| `test_config_integrity.sh` | 95 | 95 | 変化なし |
| `test_scope.sh` | 312 | 312 | 変化なし |
| `test_workflow_guard.sh` | 147 | 147 | 変化なし |
| `test_cmdpos.sh` | 281 | 285 | +4（今回の追加分） |

検査 ID の集合は変わっていない。`test_cmdpos.sh` の ID は `HK-T05` と `HK-T12` の 2 つのままである。

## 参照更新

名称・パスの変更が無いことを検索で確かめた。

| 対象 | 検索語 | 結果 |
|---|---|---|
| `shlex` の言及 | `grep -rln "shlex" .claude/` | 3 件（`i0015-01` / `i0015-02` / フック共通仕様）。計画時と同じ |
| DDR の被参照 | `grep -rln "i0015" .claude/` | 3 件（同上）。計画時と同じ |
| テスト ID | `grep -rln "HK-T05\|HK-T12" .claude/` | 5 件（`test_cmdpos.sh`、フック共通仕様、DDR 3 本）。ID の集合は不変 |
| DDR 一覧 | `ls .claude/docs/20_ddr/` | 127 件。`i` で始まらないファイル（手書きの索引）は 0 件 |

更新すべき箇所は無かった。

## eval

**定義した eval は無い。** 今回の変更はテスト 1 件の追加で、機械テストで全量が見られる範囲に収まる。指示文の変更が無いため eval の対象が生じなかった。既存の eval も実行していない（実装フェーズは定義までで、実行は人間の判断）。

## 検査結果

| 検査 | コマンド | 件数 |
|---|---|---|
| プレースホルダ（テンプレート由来の二重波括弧 / `TODO` / `TBD`） | `grep -cE '\{\{[^}]+\}\}\|TODO\|TBD' <変更したファイル>` | **0 件**（`test_cmdpos.sh`・本レポート md/html・計画書 md/html のすべて） |
| frontmatter の必須項目 | — | **対象 0 件**。変更したアセットはシェルスクリプト 1 本で frontmatter を持たない |
| 参照更新（旧名の残存） | 上の「参照更新」の 4 検索 | **0 件**。名称・パスの変更が無く、検索結果は計画時と同じ |
| 許可範囲 | `git diff --stat dd953c7` | 変更は `.claude/hooks/lib/tests/**` と `wip/**` のみ。範囲外なし |

## 仕様からの逸脱

**無し。** 仕様どおりに作れない箇所は無かった。設計文書（`.claude/docs/**`）には触れていない（型の deny）。

## 受け入れ条件との対応

| # | 受け入れ条件 | 満たした箇所 |
|---|---|---|
| 5 | 決定した方針が実装され、既存の `cmdpos` テストが同じ検査 ID・同じ結果で通る | 方針の実装 = `cmdpos.sh` の差分 0 行（`git diff origin/main` で確認）。テストは `HK-T05` / `HK-T12` の 2 ID のまま全通過。全体でも 25 本 165 ID が PASS、失敗 0 |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| `allow.ops` は `read` と `hook-test` で足りる | `run-tests.sh` は自分の中で `build-test` を無条件に要求する（TR006）。`hook-test` は「テスト対象に `.claude/hooks/**` を含むとき追加で要る」もので、代わりにならない | 迂回せず計画書の許可範囲を訂正し、チケットを起こし直した（0049 取り消し） |
| `ticket.sh` の `--allow-ops` は繰り返し指定できる | カンマ区切りの 1 引数を取る。繰り返すと最後の 1 件だけが残る | もう一度起こし直した（0051 取り消し → 0052） |
| ヒアドキュメント終端後の入力は 2 段になる | 3 段（本文がデータ段として出る） | テストを緩めず 3 段構造をそのまま固定し、0046 の「2 段」との違いの理由を本レポートに書いた |

## 残課題

- **`cmdpos.sh` の既知の制約**（`git 'commit'` のサブコマンドが `_` になる）。`shlex` に頼らず直せる見込みがあるが #15 の受け入れ条件に無い。0050 フィードバック計画で別 issue にするか決める
- **テスト ID の重複**: `CP-T08` が `test_commit.sh` と `test_push.sh` の両方で使われている（`run-tests.sh --ids` の「重複 ID」欄）。本 PR の変更とは無関係の既存の状態で、テストは全通過している。0050 で扱いを決める
