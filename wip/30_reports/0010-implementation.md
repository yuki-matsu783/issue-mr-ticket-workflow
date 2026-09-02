---
type: report
title: チケットボード拡張の実装結果レポート
description: 中核層・拡張ホスト層・単体テスト 46 件を作った実装フェーズの結果。仕様からの逸脱 6 件と、敵対的レビューが挙げた重要 5 件の修正を含む
tags: [report, implementation]
---

# チケットボード拡張の実装結果レポート

## 対象

- 対象 issue: #13 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/13
- PR: #14 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/14
- チケット: 0010-implementation（中核層）、0011-implementation（拡張ホスト層と README）、0015-implementation（敵対的レビュー指摘の反映）
- 根拠とする計画: `wip/20_plans/0009-implementation-plan.md`

このレポートは実装フェーズの完了時に作られるべきものだったが、当時作られなかった。フィードバック計画の敵対的レビューで欠落が判明したため、チケット 0017 で作業ログとコミット差分から復元した（候補 F17）。

## サマリ

| 結論 | 内容 |
|---|---|
| ◎ | 中核層 5 モジュールと拡張ホスト層 2 モジュールを仕様どおりに実装し、単体テスト 46 件が全通過した |
| ◎ | `core/` から `vscode` への import が 0 件であることを `grep` で確認した |
| ◎ | 実在のチケット 15 枚を走査して不備の誤検知が 0 件であることを確認した |
| △ | 仕様からの逸脱が 6 件あり、いずれも設計反映で仕様側に書き戻す必要がある |
| ✕ | 拡張ホストがこの環境に無く、README の手動確認 12 項目は 1 つも実施できていない |

## 変更したファイルの一覧

| ファイル | 仕様書の節 | 担当ステップ |
|---|---|---|
| `src/vscode-ticket-board/package.json` | 起動と入口 | ステップ 1 |
| `src/vscode-ticket-board/tsconfig.json` | 配置 | ステップ 1 |
| `src/vscode-ticket-board/.gitignore` | 配置 | ステップ 1 |
| `src/vscode-ticket-board/src/core/frontmatter.ts` | 処理フロー（frontmatter の解析） | ステップ 2 |
| `src/vscode-ticket-board/src/core/ticket.ts` | データの形 / 処理フロー（チケットの解析） | ステップ 3 |
| `src/vscode-ticket-board/src/core/scan.ts` | 処理フロー（走査） | ステップ 4 |
| `src/vscode-ticket-board/src/core/board.ts` | 処理フロー（ボードの組み立て） | ステップ 4 |
| `src/vscode-ticket-board/src/core/render.ts` | HTML の構造と CSP | ステップ 5 |
| `src/vscode-ticket-board/src/extension.ts` | 起動と入口 | ステップ 6 |
| `src/vscode-ticket-board/src/board-panel.ts` | 表示と更新 | ステップ 6 |
| `src/vscode-ticket-board/test/*.test.ts`（5 本） | テスト観点 | ステップ 2〜6 |
| `src/vscode-ticket-board/test/fixtures/0011-implementation.md` | テスト観点（実物での回帰） | 0015 で追加 |
| `src/vscode-ticket-board/README.md` | 配置 | ステップ 6 |

## テスト結果

| 項目 | 結果 |
|---|---|
| 実行コマンド | `cd src/vscode-ticket-board && npm test`（`tsc -p .` のあと `node --test out/test/*.test.js`） |
| テスト件数 | 46 件（0010 完了時 35 件 → 0015 で 11 件追加） |
| 結果 | `# tests 46 / # pass 46 / # fail 0` |
| テスト ID の網羅 | TB-T01〜TB-T17 の 17 件すべてに対応するテストが実在する |
| 失敗ケース | 各 ID に負のケースを含む（frontmatter 無し / 終端の区切り無し / 空ファイル / 引用符の閉じ忘れ / 未知の種類 / 番号の食い違い / 読めないファイル / 不一致パス） |
| 型検査 | `tsc -p .` が `strict: true` で無警告 |
| 中核層の独立 | `grep -rn 'from "vscode"' src/core/` → 0 件 |
| ビルド生成物 | `git status --porcelain` に `node_modules/` と `out/` が現れない |
| 実データでの確認 | 実在のチケット 15 枚を走査 → `total 15 / remaining 2 / issue 0` |

## 仕様からの逸脱の一覧（設計反映で書き戻すべき点）

| # | 逸脱 | 出所 | フィードバック計画の候補 |
|---|---|---|---|
| 1 | `unreadableTicket` を `parseTicket` から独立した関数として切り出した | 0010 | F11 |
| 2 | HTML に仕様の骨格に無い `<meta name="viewport">` を足した | 0010 | F09 |
| 3 | 監視の glob 用に `/` 区切りの `TICKETS_PATH` を `TICKETS_DIR` と別に持った（`path.join` では Windows で glob が壊れるため） | 0011 | F12 |
| 4 | パネル由来の Disposable を `context.subscriptions` に積まず、パネルの寿命に紐づけた | 0011 | F13 |
| 5 | `FrontmatterDocument` に `body`（終端の区切りより後ろ）を足した | 0015 | F01 |
| 6 | TB002 の文言に「（scalar でない）」の型を足し、コードフェンスの中の見出しを本文の見出しとして扱わないことにした | 0015 | F02・F03 |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 計画のステップはすべてテスト ID で合否が決まる | 拡張ホスト層（ステップ 6）だけ対応するテスト ID が無い | 合否を「`npm test` の全通過と `tsc` の無警告」で代え、README の手動確認に逃がした（候補 B4-2） |
| 読み取り失敗（TB007）のテストはパーミッションで作れる | root 実行ではパーミッションが効かない | チケット名に一致する**ディレクトリ**を置いて `readFileSync` を失敗させた |
| `strict` の型は素直に推論される | `Partial<Record<...>>` のインデックスと `find` のコールバックで 3 回落ちた | テスト側に型注釈を足した |
| 仕様どおりに書けば実在のチケットは全件正しく読める | 初版は frontmatter の YAML コメントやコードフェンスの中の `#` をタイトルに採り、必須キーが配列だと不備 0 件のまま項目が消えた | 敵対的レビューで判明し、0015 で 5 件を修正して回帰テストを 11 件足した |

## 設計への反映

1. 逸脱 1〜6 を仕様書に書き戻す（設計反映フェーズ。候補 F01〜F03・F09・F11〜F13）
2. `RenderOptions.cspSource` は宣言されているが使われていない。型から削るか、受け取るだけと仕様に書くかを決める（候補 F07）
3. 単一ルートのみを見る制約とシンボリックリンクを区別しない旨を仕様に明記する（候補 F14・F15）
4. 未設定の `ticket_type` / `executor` を「種類不明」「実行者不明」と出す表示、YAML コメントを解釈しない挙動を仕様に明記する（候補 F08・F10）

## 残課題

- README の手動確認 12 項目が 1 つも実施できていない。拡張ホスト（VS Code の GUI）がこの環境に無いため、利用者の環境での確認に委ねる
- `.vscode/launch.json` を置けないため、`F5` での起動は利用者が「拡張機能」の構成を選ぶ前提になっている（候補 B2-3）
- `commands.build-test` が空のままで、フックが有効化されると `npm test` の実行が拒否される見込み（候補 B2-1）
