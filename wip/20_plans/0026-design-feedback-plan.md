---
type: plan
title: 設計反映計画 — docs/ のアプリルートへの移動と旧置き場の片付け
description: 拡張の設計文書 7 ファイルを apl/vscode-ticket-board/docs/ へ移し、配置図・DDR の状態・仕様書の節名を揃え、旧置き場の deny と関連するテスト・仕様の記述を 1 回で落とす手順・順序・検証
tags: [plan, design-feedback, apl]
keywords: [設計反映計画, 設計文書の移動, 旧置き場, deny の削除, DDR の状態, 画面・出力の構造, 節名]
---

# 設計反映計画 — docs/ のアプリルートへの移動と旧置き場の片付け

## 対象

- issue: #20（設計文書スキルをアプリ（apl/ 配下）に対応させる）
- MR: `claude/design-docs-app-support-6a9cyj`
- フェーズ: 6（設計反映）。フィードバック計画（`0025`）の F1〜F6 を実施する

## この計画で何をするか

フェーズ 4 でソースが `apl/vscode-ticket-board/` へ移り、設計文書だけがリポジトリ直下の `docs/` に残っている。これをアプリルート配下へ移し、移動で古くなる記述を揃え、移行のために残していた旧置き場の仕掛けを外す。

## 移動するファイル

`docs/` の 7 ファイルを、階層を変えずに `apl/vscode-ticket-board/docs/` へ移す。

| 移動元 | 移動先 | 内容の変更 |
|---|---|---|
| `docs/00_requirement/vscode-ticket-board.md` | `apl/vscode-ticket-board/docs/00_requirement/vscode-ticket-board.md` | なし |
| `docs/10_spec/vscode-ticket-board.md` | `apl/vscode-ticket-board/docs/10_spec/vscode-ticket-board.md` | あり（28 行目の配置図、7 番目の節名） |
| `docs/20_ddr/i0013-01-…md` | `apl/vscode-ticket-board/docs/20_ddr/i0013-01-…md` | frontmatter のみ（状態と置き換え先） |
| `docs/20_ddr/i0013-02〜05-…md`（4 ファイル） | `apl/vscode-ticket-board/docs/20_ddr/` | なし |

文書どうしの相互参照（`../00_requirement/…`、`../20_ddr/i0013-0X-…`）はすべて `docs/` 配下の相対で書かれているので、ディレクトリごと移せば解決先は変わらない。`.claude/docs/10_spec/フック共通仕様.md` への参照はリポジトリルート相対の表記で本文中に置かれており、リンクではないので影響しない。

## 更新する記述

| # | 対象 | 現在 | 更新後 | 根拠 |
|---|---|---|---|---|
| F2 | 仕様書 28 行目の配置図の頂点 | `src/vscode-ticket-board/` | `apl/vscode-ticket-board/` | 実体と一致させる |
| F3 | DDR `i0013-01` の frontmatter | 状態の記載なし | 状態を「置き換え済み」、置き換え先を `.claude/docs/20_ddr/i0020-01-…` にする | 本文は変えない（`design-docs` 堅牢性） |
| F5a | 仕様書の 7 番目の節名 | `HTML の構造と CSP` | `画面・出力の構造` | `20-common-step-spec` のアプリの 10 節固定。DDR `i0013-02` が定めた名前からの変更なので、新しい DDR で置き換える |
| F6 | `apl/vscode-ticket-board/README.md` の暫定の 1 行 | 「設計文書はまだリポジトリ直下の `docs/` にある…」 | 削る（参照がアプリルート相対であることだけ残す） | 移動が済んで宙ぶらりんが解消する |

## 扱わないと判断した点（F5 の検査の結果）

| 観点 | 状態 | 判断 |
|---|---|---|
| 要件書の「issue の受け入れ条件との対応」の小節 | 無い | 足さない。規定は「新規作成、または受け入れ基準を追加・変更する更新」に限り、既存文書への遡及適用は求めない（`design-docs` 書式・可読性） |
| 要件書のメインフローの mermaid | 無い | 足さない。既存の要件定義書が新しい形に追随していない件は issue #8 の範囲（フィードバック計画 B13） |
| 仕様書「要件との対応」表の全件カバー | 受け入れ基準 26 件・表 26 行で一致 | 変更なし |
| 仕様書の節数 | 10 節 | F5a の改名のみ。数は変わらない |

## 旧置き場の片付け（F4）

3 か所を 1 回で落とす。片方ずつだと設定・テスト・仕様が途中の状態で食い違う（フック共通仕様 §8「現在の状況」）。

| 対象 | 変更 |
|---|---|
| `.claude/docs/10_spec/フック共通仕様.md` §8 | 「旧置き場」の段落と「現在の状況」の段落を落とし、初期値の表の計画・調査 7 type の `deny` から `src/**` `docs/**` を外す |
| `.claude/hooks/config/scope-limits.json` | 計画・調査 7 type の `deny` から `src/**` `docs/**` を外す |
| `.claude/hooks/tests/test_config_integrity.sh` | 旧置き場のアサーション 4 件を削除し、`docs/…` と `src/…` が判定順 (7) の ask WF202 に落ちること（= 特別扱いが無いこと）を 2 件で置き換える |

## 方法とステップ

1. **F1**: `git mv docs apl/vscode-ticket-board/docs`
2. **F2・F5a**: 仕様書の配置図と 7 番目の節名を直す
3. **F5a の経緯**: 新しい DDR `i0020-04`（アプリの仕様書の節名を機構の 10 節に揃える）を `apl/vscode-ticket-board/docs/20_ddr/` に起こす
4. **F3**: DDR `i0013-01` の frontmatter に状態と置き換え先を足す
5. **F6**: README の暫定の 1 行を削る
6. **F4**: 正史（§8）→ 設定 → テストの順で旧置き場を落とす
7. 検証 V1〜V6

## 検証

| # | 検査 | 期待値 |
|---|---|---|
| V1 | `find apl/vscode-ticket-board/docs -type f \| wc -l` | 7 |
| V2 | `ls docs 2>/dev/null` | 無し |
| V3 | `grep -rn 'src/vscode-ticket-board' apl/*/docs/` | 0 件（DDR `i0013-01` の本文は除く。本文は変えないため） |
| V4 | 仕様書の `^## ` の 7 番目 | `## 画面・出力の構造` |
| V5 | `grep -n 'src/\*\*\|docs/\*\*' .claude/hooks/config/scope-limits.json` | 0 件 |
| V6 | `run-tests.sh --ids` | 14 本すべて PASS |

V3 の例外について: DDR `i0013-01` の本文は当時の決定の記録で、`src/vscode-ticket-board/` と書かれている。マージ済み DDR の本文は変えない規約なので、frontmatter の状態で無効になったことを示す。

## ロックアウト対策

| リスク | 起きること | 対策 |
|---|---|---|
| F4 を F1 より先にやる | まだ移動していない `docs/` を計画・調査タスクが書けてしまう | 手順の順序を固定する（F1 → … → F4） |
| `docs/` の移動元の削除が判定順 (7) の ask WF202 に落ちる | 移動が止まる | 一度きりの移行としてこの ask を承認する（フック共通仕様 §8） |
| `commit.sh` が削除だけのコミットを作れない | フェーズ 4 と同じ壁に当たる | 既知（フィードバック計画 B3）。同じ手当（手で検査を満たして `git commit`）を取り、作業ログに記録する |
| F4 で deny を外した結果、計画・調査タスクが `apl/**` を書けてしまう | 計画タスクが成果物を触る | `apl/**` の deny は残す（外すのは `src/**` `docs/**` だけ）。テストで固定する |
| 節名の変更が DDR `i0013-02` と食い違う | 正史が 2 つになる | 新しい DDR `i0020-04` で置き換え、`i0013-02` の frontmatter に置き換え先を書く |

## チケット

`allow.ops` の共通の決まり: DoD に `run-tests.sh --ids` を含むチケットは `build-test` と `hook-test` の両方を宣言する。

| # | 種類 | 内容 | allow.write | 依存 |
|---|---|---|---|---|
| H1 | design-feedback | F1・F2・F3・F5a と DDR `i0020-04`（V1〜V4） | `apl/*/docs/**`、`docs/**`（移動元） | 0026 |
| H2 | implementation | F6（README の暫定の 1 行を削る） | `apl/**` | H1 |
| H3 | ai-asset-design | F4 のうちフック共通仕様 §8 | `.claude/docs/**` | H2 |
| H4 | ai-asset-implementation | F4 のうち設定とテスト（V5・V6） | `.claude/hooks/config/scope-limits.json`、`.claude/hooks/tests/**` | H3 |
| H5 | overall-summary | フェーズ 7（起票済み 0027） | `wip/**` | H4 |

## スコープ外

- 既存の要件定義書を新しい形（mermaid・規約節）に揃える — issue #8
- 設計文書の機械的検査 — issue #24
- フィードバック計画の別 issue（B1〜B5・B11）の起票 — フェーズ 7

## 保留した点

- なし
