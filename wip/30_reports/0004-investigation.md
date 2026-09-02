---
type: report
title: VS Code 拡張のビルド・テスト環境の成立性調査結果
description: npm レジストリへの到達可否、tsc でのコンパイル、Node 標準テストランナーでの実行を実測し、テストランナーと依存構成を確定した
tags: [report, investigation]
---

# VS Code 拡張のビルド・テスト環境の成立性調査結果

## 対象

- 対象 issue: #13 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/13
- PR: #14 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/14
- チケット: 0004-investigation
- 担当した問い: Q3（依存の取得可否）・Q4（依存ゼロの退避路）

## サマリ

npm レジストリに到達でき、拡張の開発依存は問題なく取得できた。TypeScript でのコンパイルと Node 標準テストランナーでの実行も実測で通った。**TypeScript + `tsc` + `node --test` の構成を採る**のが妥当で、退避路（Q4）を使う必要はない。

一方で、`vscode` モジュールは VS Code ホストの外では解決できない。純ロジックを `vscode` に依存しない層に分離しなければ単体テストが書けないため、これは**設計上の制約**として扱う必要がある。

- ◎良 3 件 / △注意 2 件 / ✕問題 0 件

### ◆特に見てほしい

- `vscode` に触れる層を薄く保つ設計（パーサとボードの組み立てを純関数に寄せ、拡張のエントリだけが `vscode` を触る）でよいか。受け入れ条件 9・10 を満たすうえでほぼ必須の制約

### ◇承認が欲しい

- `@vscode/test-electron` を使わず `node --test` だけにする判断。VS Code の実ホストを起動する統合テストは書かない

### ・細かいレビューは不要

- npm が使えること、Node と npm のバージョン

## 確かめられなかったこと

- `@vscode/test-electron` は npm 上に存在することを確認しただけで、実際に走らせていない。VS Code バイナリのダウンロードが必要で、この環境で成立するかは未確認
- 拡張を VS Code に読み込ませて実際に Webview が描画されるかは確認していない。この環境に VS Code の GUI が無い。受け入れ条件 1〜8 の最終確認は人間の手元で行う必要がある
- `npm ci` での再現性は `package-lock.json` が生成されることを確認しただけで、別環境での再現は試していない

## 実施条件

- リポジトリ `/home/user/issue-mr-ticket-workflow`、作業は使い捨ての `wip/tmp/npm-probe/` 内のみ
- Node v22.22.2 / npm 10.9.7 / npx 10.9.7
- npm レジストリは `https://registry.npmjs.org/`。環境変数のプロキシ設定（`https_proxy` / `npm_config_https_proxy`）が入った状態

## 実施した内容と結果

### 1. npm レジストリへの到達と依存の取得 ◎良

根拠: `npm view` と `npm install` の実行結果

`npm view typescript version` が `7.0.2` を返し、レジストリに到達できることを確認した。続けて開発依存 3 つを実際に入れた。

```
$ npm install --no-audit --no-fund typescript@5 @types/node@22 @types/vscode@1.90
added 4 packages in 2s

$ ./node_modules/.bin/tsc --version
Version 5.9.3

$ ls node_modules/@types/vscode/index.d.ts
node_modules/@types/vscode/index.d.ts
```

`package-lock.json` も生成された（5 エントリ）。

**結論**: Q3 の答えは「取得できる」。退避路（Q4）に倒れる必要はない。

### 2. tsc でのコンパイルと Node 標準テストランナー ◎良

根拠: `tsc -p .` と `node --test` の実行結果

`target: ES2022` / `module: Node16` / `strict: true` の `tsconfig.json` で、`src/` と `test/` を `out/` にコンパイルし、コンパイル結果に対して Node 標準のテストランナーを走らせた。

```
$ ./node_modules/.bin/tsc -p .
（出力なし。exit=0）

$ node --test out/test/*.test.js
# tests 3
# pass 3
# fail 0
```

なお `node --test out/test/` のようにディレクトリを渡すと `MODULE_NOT_FOUND` で落ちる。glob でファイルを渡す必要がある。

**結論**: `tsc` でビルドし、`node --test` でテストする構成が成立する。外部のテストランナーは要らない。

### 3. `vscode` モジュールはホスト外で解決できない △注意

根拠: `require('./out/src/uses-vscode.js')` の実行結果

`import * as vscode from "vscode"` を含むモジュールは、型としてはコンパイルが通るが、素の Node では読み込めない。

```
$ ./node_modules/.bin/tsc -p .
（出力なし。exit=0 — 型は @types/vscode で解決される）

$ node -e "require('./out/src/uses-vscode.js')"
Error: Cannot find module 'vscode'
  code: 'MODULE_NOT_FOUND',
```

`vscode` は VS Code の拡張ホストが実行時に注入するモジュールで、npm には実体が無い（`@types/vscode` は型定義だけ）。

**結論**: 単体テストの対象にできるのは `vscode` を import しないコードだけ。チケットの走査・frontmatter の解析・ボードの組み立て・HTML の生成を `vscode` に依存しない純粋な層に置き、`vscode` を触るのは拡張のエントリ（コマンド登録・Webview の生成・FileSystemWatcher）だけにする。ファイル読み取りは `node:fs` を使えば `vscode` に依存しない。

### 4. 依存ゼロの退避路（Q4） ◎良

根拠: `node --experimental-strip-types --test` の実行結果

Q3 が肯定だったので採らないが、退避路が実在することは確認した。Node 22 の型注釈除去で TypeScript をコンパイルせず直接テストできる。

```
$ node --experimental-strip-types --test test/parse.ts.test.ts
# tests 3
# pass 3
# fail 0
```

ただし import 指定子を `../src/parse.ts` と書く必要があり、`tsc` の `Node16` 解決とは両立しない（`allowImportingTsExtensions` が要る）。

```
$ ./node_modules/.bin/tsc -p .
test/parse.ts.test.ts(3,34): error TS5097: An import path can only end with a '.ts'
extension when 'allowImportingTsExtensions' is enabled.
```

**結論**: Q4 の答えは「満たせる」。ただし `tsc` によるビルドと同時には使えないので、Q3 が肯定である以上こちらは採らない。

### 5. テストランナー候補の入手性 △注意

根拠: `npm view <pkg> version` の出力

| パッケージ | バージョン | 判断 |
|---|---|---|
| `@vscode/test-cli` | 0.0.15 | 採らない |
| `@vscode/test-electron` | 3.1.0 | 採らない。VS Code バイナリのダウンロードが要り、この環境で未検証 |
| `mocha` | 12.0.0 | 採らない。Node 標準で足りる |
| `vitest` | 4.1.11 | 採らない。Node 標準で足りる |
| `esbuild` | 0.28.2 | 採らない。バンドルは不要 |

いずれも入手はできるが、どれも Node 標準のテストランナーで代替できる。依存は少ないほうが受け入れ条件 10（ローカルで通る）を満たしやすい。

**結論**: 開発依存は `typescript` / `@types/node` / `@types/vscode` の 3 つに絞る。

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| プロキシ環境なので npm レジストリに届かない可能性がある | 問題なく到達し、4 パッケージが 2 秒で入った | Q4 の退避路は確認だけして採らないことにした |
| `@types/vscode` を入れれば `vscode` を使うコードもテストできる | 型は解決されるが実行時には解決されない | `vscode` に依存しない層への分離を設計の制約として明記した（章 3） |
| `node --test` にディレクトリを渡せる | ディレクトリだと `MODULE_NOT_FOUND` になる | glob でファイルを渡す。npm スクリプトに書いて固定する |

## 設計への反映

1. 開発依存は `typescript` / `@types/node` / `@types/vscode` の 3 つに絞る（章 1・5）
2. ビルドは `tsc -p .`、テストは `node --test out/test/*.test.js` を npm スクリプトに固定する（章 2）
3. `vscode` を import する層と、しない層を分ける。パーサ・走査・ボード組み立て・HTML 生成は `vscode` に依存させず、`node:fs` で読む（章 3）
4. VS Code の実ホストを起動する統合テストは書かない。受け入れ条件 1〜8 のうち画面の確認は人間の手元で行う前提を README に書く（章 5・「確かめられなかったこと」）
5. `package-lock.json` をコミットして再現性を確保する（章 1）

## 残課題

- 拡張を VS Code に読み込ませた実機確認をこの環境で行えない。受け入れ条件 1〜8 のうち Webview の見た目に関わる部分は、実装フェーズで自動テスト可能な形（HTML 生成関数の出力の検査）に落とし、実機確認は人間に委ねる
- `@vscode/test-electron` をこの環境で走らせられるかは未確認。将来 CI を組む際に再検討する
