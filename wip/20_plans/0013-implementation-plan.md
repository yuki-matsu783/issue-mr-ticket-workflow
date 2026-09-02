---
type: plan
title: 実装・テスト計画 — 拡張のソースとビルド設定を apl/ へ移す
description: VS Code チケットボード拡張のソース・テスト・ビルド設定を src/vscode-ticket-board/ から apl/vscode-ticket-board/ へディレクトリごと移し、ソースのヘッダコメントと README の参照をアプリルート相対に直す実装の手順・検証・巻き戻し
tags: [plan, implementation, apl]
keywords: [実装計画, アプリルート, apl, 移行, vscode-ticket-board, npm test, ヘッダコメント, 巻き戻し, WF202, commands.build-test]
---

# 実装・テスト計画 — 拡張のソースとビルド設定を apl/ へ移す

## 対象

- issue: #20（設計文書スキルをアプリ（apl/ 配下）に対応させる）
- MR: `claude/design-docs-app-support-6a9cyj`
- フェーズ: 4（実装・テスト）。正史はフェーズ 2・3 で更新済みで、この計画はそれに実体を合わせる

## この計画で何をするか

- 拡張のソース・テスト・ビルド設定を `src/vscode-ticket-board/` から `apl/vscode-ticket-board/` へ**ディレクトリごと**移す
- 移動で古くなる参照（ソース 5 ファイルのヘッダコメント、README の 3 か所）をアプリルート相対に直す
- `npm test` が通ることを確かめる

設計文書（`docs/`）はこのフェーズでは動かさない。`implementation` の許可範囲が `apl/*/docs/**` を deny しているため、フェーズ 6（design-feedback）が担当する（DDR `i0020-01`、フック共通仕様 §8 の「旧置き場」の段落）。

## 移動するファイル

`src/vscode-ticket-board/` の 18 ファイルを、階層を変えずに `apl/vscode-ticket-board/` へ移す。

| 移動元 | 移動先 | 内容の変更 |
|---|---|---|
| `src/vscode-ticket-board/package.json` | `apl/vscode-ticket-board/package.json` | なし |
| `src/vscode-ticket-board/package-lock.json` | `apl/vscode-ticket-board/package-lock.json` | なし |
| `src/vscode-ticket-board/tsconfig.json` | `apl/vscode-ticket-board/tsconfig.json` | なし |
| `src/vscode-ticket-board/.gitignore` | `apl/vscode-ticket-board/.gitignore` | なし |
| `src/vscode-ticket-board/README.md` | `apl/vscode-ticket-board/README.md` | あり（1 行） |
| `src/vscode-ticket-board/src/*.ts`（2 ファイル） | `apl/vscode-ticket-board/src/*.ts` | なし |
| `src/vscode-ticket-board/src/core/*.ts`（5 ファイル） | `apl/vscode-ticket-board/src/core/*.ts` | なし（下の「更新する参照」を参照） |
| `src/vscode-ticket-board/test/*.ts`（5 ファイル） | `apl/vscode-ticket-board/test/*.ts` | なし |
| `src/vscode-ticket-board/test/fixtures/*.md`（1 ファイル） | `apl/vscode-ticket-board/test/fixtures/*.md` | なし |

ビルド設定は中身を変えない。`tsconfig.json` は `tsc -p .`、`package.json` の `main` は `./out/src/extension.js`、テストは `node --test out/test/*.test.js` と、すべてアプリルート相対で書かれている。アプリルートの位置が変わっても解決先は変わらない。

## 更新する参照

| ファイル | 行 | 現在 | 更新後 |
|---|---|---|---|
| `src/core/board.ts` | 3 | `仕様: docs/10_spec/vscode-ticket-board.md「…」` | `仕様: docs/10_spec/vscode-ticket-board.md「…」`（アプリルート相対のまま。変更なし） |
| `src/core/frontmatter.ts` | 4 | 同上 | 同上 |
| `src/core/render.ts` | 3 | 同上 | 同上 |
| `src/core/scan.ts` | 3 | 同上 | 同上 |
| `src/core/ticket.ts` | 4 | 同上 | 同上 |
| `README.md` | 5・6 | `docs/00_requirement/…` / `docs/10_spec/…` | 同上（アプリルート相対のまま） |
| `README.md` | 30 | `このディレクトリ（`src/vscode-ticket-board/`）で実行する。` | `このディレクトリ（`apl/vscode-ticket-board/`）で実行する。` |

判断: ヘッダコメントと README の要件・仕様への参照はもともと `docs/10_spec/...` と書かれており、リポジトリルート相対とも**アプリルート相対**とも読める。フェーズ 6 で設計文書が `apl/vscode-ticket-board/docs/` へ移ると、これらはアプリルート相対として正しくなる。したがって**文字列は変えない**。変えるのは README 30 行目の自分の置き場だけ（1 か所）。

この読み替えが成立するのは、フェーズ 6 の移動が完了したときだけ。フェーズ 4 単独では参照が一時的に切れる。この 1 コミット分の不整合は許容し、フェーズ 6 の完了をもって解消する（フェーズ 4 と 6 を分けたのは許可範囲の制約によるもので、DDR `i0020-01` に記録済み）。

DDR `i0020-01` の「影響」は「ソース 5 ファイルのヘッダコメントと README の参照は、アプリルート相対に更新する」と書いている。実際には既にアプリルート相対と同じ文字列なので、更新は 0 か所で満たされる（意図した状態と現物が一致している）。DDR の本文は変えない（`design-docs` の「マージ済み DDR は本文を変更しない」に倣い、同じ MR の中でも決定の記録は書き換えず、差分はこの計画書で説明する）。

## 方法とステップ

1. `git mv src/vscode-ticket-board apl/vscode-ticket-board` でディレクトリごと移す（履歴を保つ）
2. `apl/vscode-ticket-board/README.md` の 30 行目を直す
3. `apl/vscode-ticket-board/` で `npm test` を実行する
4. `src/` にファイルが残っていないことを確かめる（空ディレクトリは git が追わないので、ディレクトリ自体が消えていてもよい）

## 検証

| # | 検査 | 期待値 |
|---|---|---|
| V1 | `find apl/vscode-ticket-board -type f \| wc -l` | 18 |
| V2 | `find src -type f 2>/dev/null \| wc -l` | 0（`src/` 自体が消えていてもよい） |
| V3 | `cd apl/vscode-ticket-board && npm test` | `tsc` がエラー 0、`node --test` が全件 pass |
| V4 | `grep -rn 'src/vscode-ticket-board' apl/` | 0 件 |
| V5 | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids` | 14 本すべて PASS（機構側の回帰が無いこと） |

V3 の前提: `npm test` は `commands.build-test` に列挙されていないと判定順の分類で `build-test` にならず WF204 で止まる（現在 `commands.build-test` は `[]`）。列挙の追加は `.claude/hooks/config/scope-limits.json` への書き込みで、`implementation` は `.claude/**` を deny しているため実装チケットからは行えない。**先に ai-asset-implementation チケットで列挙を足す**（チケット T1）。

## ロックアウト対策

| リスク | 起きること | 対策 |
|---|---|---|
| 移動先が判定順 (7) の ask WF202 に落ちる | `apl/vscode-ticket-board/**` は `implementation` の allow に入っているので allow。移動**元**の削除が ask になる | 承認単位はアプリルートではなく `src/vscode-ticket-board`。一度きりの移行としてこの ask を承認する（フック共通仕様 §8「旧置き場」） |
| `commands.build-test` の変更で機構が壊れる | 列挙の追加は既存の分類を狭めない（前方一致の追加のみ） | 追加後に `run-tests.sh --ids` を実行し、14 本の PASS を確認してから実装チケットに進む |
| `git mv` が履歴を失う | 拡張の由来が追えなくなる | `git mv` を使う（`rm` + 新規作成をしない）。移動後に `git log --follow apl/vscode-ticket-board/src/core/scan.ts` が移動前のコミットを含むことを確かめる |
| `npm test` が移動後に落ちる | 移動が原因か既存の不具合か切り分けられない | 移動**前**に `src/vscode-ticket-board/` で `npm test` を 1 度通し、基準を取ってから移す |
| 巻き戻し | 移動後に問題が出たとき | `git mv apl/vscode-ticket-board src/vscode-ticket-board` で戻せる（`commands.build-test` の追加は残してよい。害が無く、戻すと V3 が実行できなくなる） |

## チケット

| # | 種類 | 内容 | 依存 |
|---|---|---|---|
| T1 | ai-asset-implementation | `commands.build-test` に `npm test`（および `npm --prefix apl/vscode-ticket-board test`）を列挙する。`run-tests.sh --ids` 全通過を確認 | 0013 |
| T2 | implementation | 移動・README の 1 行・`npm test`・V1〜V5 の検査 | T1 |
| T3 | feedback-plan | 次のフェーズ（5）の計画チケット | T2 |

## スコープ外

- 設計文書（`docs/`）の移動 — フェーズ 6（design-feedback）
- `docs/10_spec/vscode-ticket-board.md` の「配置」節に書かれた `src/vscode-ticket-board/` の書き換え — 同じくフェーズ 6（設計文書の本文）
- DDR `i0013-01`（成果物の置き場を src 配下にする）の frontmatter を置き換え済みにする — フェーズ 6
- 旧置き場（`src/**` `docs/**`）を `scope-limits.json` の deny から削除する — フェーズ 6 の完了後。フェーズ 4 の時点で消すと、まだ移動していない `docs/` を計画・調査タスクが書けてしまう
- 拡張の機能変更・依存更新 — issue #20 の受け入れ条件の外

## 保留した点

- なし
