---
type: plan
title: チケットボード拡張の実装・テスト計画
description: 仕様書のモジュール構成をテスト ID で合否が決まる 6 ステップに分け、2 枚の実装チケットに割り付ける
tags: [plan, implementation-plan]
---

# チケットボード拡張の実装・テスト計画

## 対象

- 対象 issue: #13 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/13
- PR: #14 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/14
- チケット: 0009-implementation-plan
- 根拠とする設計書: `docs/00_requirement/vscode-ticket-board.md` / `docs/10_spec/vscode-ticket-board.md` / `docs/20_ddr/i0013-01` / `i0013-02`

## この計画で何をするか

仕様書の中核層を、テスト ID で合否が決まる単位に分けて実装する。VS Code に依存する層は最後にまとめ、単体テストの対象外であることを README に明記する。

決めたこと。

- ステップは 6 つ。1 ステップ = 対応するテスト ID で合否が決まる
- 実装チケットは 2 枚（中核層 5 ステップ + 拡張ホスト層 1 ステップ）
- TDD。テストを先に書いて失敗を確認してから実装する
- テスト ID は仕様書のテスト観点 TB-T01〜TB-T14 をそのまま使う。設計書にテスト ID があるので設計差し戻しは不要

## 変更対象

| ファイル | 追加 / 変更 | 理由（仕様書の節） |
|---|---|---|
| `src/vscode-ticket-board/package.json` | 追加 | 起動と入口（マニフェスト・スクリプト・開発依存） |
| `src/vscode-ticket-board/package-lock.json` | 追加 | 起動と入口（依存の固定） |
| `src/vscode-ticket-board/tsconfig.json` | 追加 | 配置（`out/` への出力、strict） |
| `src/vscode-ticket-board/.gitignore` | 追加 | 配置（`node_modules/` と `out/` の除外。DDR i0013-01） |
| `src/vscode-ticket-board/README.md` | 追加 | テスト観点（手動確認の手順） |
| `src/vscode-ticket-board/src/core/frontmatter.ts` | 追加 | データの形 / 処理フロー（frontmatter の解析） |
| `src/vscode-ticket-board/src/core/ticket.ts` | 追加 | データの形 / 処理フロー（チケットの解析）/ 不備の識別子 |
| `src/vscode-ticket-board/src/core/scan.ts` | 追加 | データの形 / 処理フロー（走査） |
| `src/vscode-ticket-board/src/core/board.ts` | 追加 | データの形 / 処理フロー（ボードの組み立て） |
| `src/vscode-ticket-board/src/core/render.ts` | 追加 | HTML の構造と CSP |
| `src/vscode-ticket-board/src/board-panel.ts` | 追加 | 表示と更新 |
| `src/vscode-ticket-board/src/extension.ts` | 追加 | 起動と入口 |
| `src/vscode-ticket-board/test/*.test.ts` | 追加 | テスト観点（TB-T01〜TB-T14） |

`.claude/` 配下・リポジトリ直下の `.gitignore`・`docs/` は変更しない。

## 許可範囲案

| ステップ | 書き込み先 | 実行コマンド |
|---|---|---|
| 1〜5（チケット 0010） | `src/vscode-ticket-board/**`, `wip/**` | `npm install`, `npx tsc -p .`, `node --test out/test/*.test.js`, `npm test` |
| 6（チケット 0011） | 同上 | 同上 |

`npm install` は初回のみ。開発依存は `typescript` / `@types/node` / `@types/vscode` の 3 つに限る。他のパッケージを足す必要が出たら、足さずに理由を作業ログに書いて計画へ戻す。

## テスト方針

TDD。各ステップで、対応するテストを先に書いて失敗を確認してから実装する。

| ステップ | テスト ID | 何が通れば合格か |
|---|---|---|
| 1 frontmatter パーサ | TB-T01〜TB-T05 | 5 形式の解釈、frontmatter 無し・終端無し・空での `undefined`、閉じていない引用符の非登録、ブロック配列の読み飛ばし、CRLF とエスケープ |
| 2 チケットの解析 | TB-T06〜TB-T10 | 6 項目の取り出し、TB001〜TB006 の付与、タイトルのフォールバック |
| 3 走査 | TB-T11・TB-T12 | 対象ディレクトリ無しの `found: false`、ファイル名での選別、欠けた状態ディレクトリの許容、番号昇順 |
| 4 ボードの組み立て | TB-T13 | 0 件でも 4 列、`remainingCount`・`issueCount` の一致 |
| 5 HTML の生成 | TB-T14 | 4 列と件数、0 件表示、不備の識別子、エスケープ、nonce |
| 6 拡張ホスト層 | なし（対象外） | `npm test` が全通過し、`tsc` が警告なく通る |

実行方法。

```
cd src/vscode-ticket-board
npm install          # 初回のみ
npm test             # tsc -p . && node --test out/test/*.test.js
```

`node --test` にディレクトリを渡すと `MODULE_NOT_FOUND` になるので、glob でファイルを渡す（調査 0004 章 2）。

ステップ 6 は単体テストの対象にできない。`vscode` が拡張ホストの外で解決できないため（調査 0004 章 3）。受け入れ条件 4（カードの選択）と 8（ワークスペースが無い場合）の確認は README に手順を書き、利用者の環境で行う。

## ステップ

依存順。前のステップが通ってから次に進む。

1. **プロジェクトの土台と frontmatter パーサ**: `package.json` / `tsconfig.json` / `.gitignore` を置き、`npm install` して `core/frontmatter.ts` を実装する（TB-T01〜TB-T05）
2. **チケットの解析**: `core/ticket.ts`。既知の種類 15 種の定数と TB001〜TB006 の付与（TB-T06〜TB-T10）
3. **走査**: `core/scan.ts`。`node:fs` のみを使う（TB-T11・TB-T12）
4. **ボードの組み立て**: `core/board.ts`（TB-T13）
5. **HTML の生成**: `core/render.ts`。`escapeHtml` を含む（TB-T14）
6. **拡張ホスト層と README**: `src/extension.ts` / `src/board-panel.ts` / `README.md`

| チケット | ステップ | 先行 |
|---|---|---|
| 0010 | 1〜5（中核層） | 0009 |
| 0011 | 6（拡張ホスト層と README） | 0010 |
| 0012 | フィードバック計画 | 0011 |

中核層を 1 枚にまとめたのは、5 つのモジュールが 1 本の依存の鎖（frontmatter → ticket → scan → board → render）で、途中で切るとレビューできる単位にならないためである。

## 検証方法

全ステップ完了時に次を実施する。

1. `cd src/vscode-ticket-board && npm test` が成功し、TB-T01〜TB-T14 が全通過する
2. `npx tsc -p .` が警告なく通る（`strict: true`）
3. `git status --porcelain` に `node_modules` と `out` が現れない
4. リポジトリのルートで `bash .claude/skills/20-common-step-commit-push/scripts/push.sh` の push 前チェック 4 項目が通る
5. `core/` のいずれのファイルにも `from "vscode"` が無いことを `grep` で確認する
6. 仕様書の「要件との対応」表の各行について、実現箇所が実際のコードに存在することを確認する

既存のテスト（`.claude/skills/*/scripts/tests/`）は変更しない。念のため `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh` を回して、拡張の追加が機構のテストを壊していないことを確認する。

## リスク

| リスク | 影響 | 対処・巻き戻し |
|---|---|---|
| `npm install` が失敗する | ステップ 1 が進まない | 調査 0004 で到達を確認済み。失敗したら理由を作業ログに書いて計画へ戻す。依存を足して回避しない |
| `node_modules` が未追跡で残り検査を止める | `ticket.sh complete` と `push.sh` が通らない | ステップ 1 で `.gitignore` を先に置く。DDR i0013-01 のとおり |
| 仕様の穴が実装中に見つかる | 推測で埋めると設計とずれる | 埋めずに作業ログの「仕様からの逸脱」に書き、設計の追加チケットを提案する |
| 開発依存を増やしたくなる | 受け入れ条件 10 の確実性が下がる | 足さずに理由を作業ログに書く。判断は次のワーク境界へ回す |
| 実機で動かない | 受け入れ条件 1〜8 が満たせない | この環境では確認できない。README に手動確認の手順を書き、全体まとめで人間に依頼する |

## 保留した点

| 項目 | 決める時期・根拠 |
|---|---|
| 拡張のアイコン・表示名の細部 | 実装時。受け入れ条件に無い |
| 実機確認を誰がいつ行うか | 全体まとめ。この環境に VS Code の GUI が無い |
