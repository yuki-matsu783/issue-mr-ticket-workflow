---
type: report
title: VS Code 拡張 API の外部技術調査結果
description: 拡張の最小構成、Webview の生成と postMessage、FileSystemWatcher の通知の粒度を @types/vscode 1.90 の型定義と公式ドキュメントから確定した
tags: [report, investigation]
---

# VS Code 拡張 API の外部技術調査結果

## 対象

- 対象 issue: #13 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/13
- PR: #14 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/14
- チケット: 0007-investigation（敵対的レビューの指摘 2・14・15 で追加）
- 担当した問い: Q7（VS Code API の事実）

## サマリ

設計に必要な API 事実は確定した。拡張の最小構成は `package.json` の 6 フィールドとエントリの `activate` / `deactivate` で足りる。Webview は `window.createWebviewPanel` で作り、HTML を `webview.html` に文字列で与え、`webview.cspSource` と nonce で CSP を組む。ファイル変更の追従は `workspace.createFileSystemWatcher` で行える。

**受け入れ条件 5 に関わる重要な事実**: `FileSystemWatcher` は `onDidCreate` / `onDidChange` / `onDidDelete` の 3 イベントしか持たず、**ファイルの移動（リネーム）を表すイベントが無い**。チケットの状態変更は `00_todo/0003-x.md` → `10_doing/0003-x.md` の移動なので、watcher からは「削除 + 作成」の 2 イベントとして届く。ボードを差分更新すると一瞬カードが消える可能性があるため、イベントを受けたら全体を読み直す方式にするのが安全である。

- ◎良 3 件 / △注意 2 件 / ✕問題 0 件

### ◆特に見てほしい

- ファイル移動が「削除 + 作成」で届くことへの対処として、差分更新ではなく**イベントを合図に全体を読み直す**方式を採ること（章 3）

### ◇承認が欲しい

- CSP を `default-src 'none'` から組み、スクリプトは nonce 付きのインラインのみ許す方針（章 2）
- `retainContextWhenHidden` を使わない方針。状態はチケットのファイルが正なので、再表示時に読み直せば足りる（章 2）

### ・細かいレビューは不要

- `package.json` の必須フィールドと `activate` / `deactivate` の形（章 1）

## 確かめられなかったこと

- 公式ドキュメントサイト（code.visualstudio.com）へは実行環境のネットワーク制限で直接アクセスできなかった。API の署名と挙動は npm から取得した `@types/vscode@1.90.0` の型定義とその doc コメントを一次資料とし、慣行（CSP・nonce・activationEvents の自動生成）は Web 検索の結果で補った
- 実際に拡張を VS Code に読み込ませて動かしていない。ここに書いた API 事実は型定義とドキュメントの記述であって、実機での挙動の確認ではない
- `WebviewPanelSerializer`（VS Code 再起動をまたいで Webview を復元する仕組み）は今回の受け入れ条件に無いので調べていない

## 実施条件

- `@types/vscode@1.90.0` を `wip/tmp/api-probe/` に取得し、`index.d.ts` を直接読んだ。確認後に削除した
- Web 検索で慣行を確認した。参照した URL は各章に記載

## 実施した内容と結果

### 1. 拡張の最小構成 ◎良

根拠: `@types/vscode@1.90.0` の `index.d.ts`、および Extension Anatomy / Activation Events のドキュメント

`package.json` に要るフィールド。

| フィールド | 内容 |
|---|---|
| `name` / `version` / `publisher` | 拡張の識別 |
| `engines.vscode` | 対応する VS Code の最小バージョン。`@types/vscode` のバージョンと揃える |
| `main` | エントリの JS。`tsc` の出力先を指す（例 `./out/src/extension.js`） |
| `activationEvents` | いつ拡張を起こすか。**VS Code 1.74 以降、`contributes.commands` に宣言したコマンドの `onCommand:` は自動生成される**ので、コマンドだけで起動するなら空配列でよい |
| `contributes.commands` | コマンドパレットに出すコマンド。`command`（ID）と `title`（表示名） |

エントリが export するもの。

```ts
export function activate(context: vscode.ExtensionContext): void
export function deactivate(): void
```

コマンドの登録は `vscode.commands.registerCommand(command, callback)` が `Disposable` を返すので、それを `context.subscriptions` に積む。`ExtensionContext` は `subscriptions` と `extensionUri` を持つ。

```
$ grep -n "export function registerCommand" node_modules/@types/vscode/index.d.ts
10261: export function registerCommand(command: string, callback: (...args: any[]) => any, thisArg?: any): Disposable;
```

**結論**: `engines.vscode` を `^1.90.0` にして `activationEvents` を空配列にする。コマンドは 2 つ（ボードを開く / 手動更新）。

### 2. Webview の生成・HTML・メッセージ ◎良

根拠: `index.d.ts` の `window.createWebviewPanel` / `Webview` / `WebviewPanel` / `WebviewOptions` / `WebviewPanelOptions`

生成の署名。

```
$ sed -n '10800,10809p' node_modules/@types/vscode/index.d.ts
export function createWebviewPanel(viewType: string, title: string, showOptions: ViewColumn | {
    readonly viewColumn: ViewColumn;
    readonly preserveFocus?: boolean;
}, options?: WebviewPanelOptions & WebviewOptions): WebviewPanel;
```

`Webview` の主なメンバー。

| メンバー | 型・意味 |
|---|---|
| `html` | `string`。**HTML を文字列で代入する**。差し替えれば再描画される |
| `options` | `WebviewOptions` |
| `onDidReceiveMessage` | `Event<any>`。Webview から拡張へのメッセージ |
| `postMessage(message)` | `Thenable<boolean>`。拡張から Webview へ。**live なときだけ届く**（可視、または `retainContextWhenHidden` 付きの非表示） |
| `asWebviewUri(localResource)` | ローカルファイルを Webview から参照できる URI に変換する |
| `cspSource` | CSP に書くソース文字列 |

`WebviewOptions` は `enableScripts` / `enableForms` / `enableCommandUris` / `localResourceRoots`。`WebviewPanelOptions` は `enableFindWidget` と `retainContextWhenHidden` の 2 つで、後者は doc コメントが「メモリのオーバーヘッドが大きく、パネルの状態を素早く保存・復元できない場合にだけ使う」と明記している。

`WebviewPanel` の主なメンバーは `viewType` / `title` / `webview` / `viewColumn` / `active` / `visible` / `onDidChangeViewState` / `onDidDispose` / `reveal(viewColumn?, preserveFocus?)` / `dispose()`。

CSP の慣行（Web 検索より）。`default-src 'none'` から始め、スタイルは `webview.cspSource`、スクリプトは 1 回ごとに生成する nonce のみを許す。

```
default-src 'none'; style-src ${webview.cspSource}; img-src ${webview.cspSource} https:; script-src 'nonce-${nonce}';
```

**結論**:

- ボードは 1 枚の HTML 文字列として生成し、`webview.html` に代入する。更新はもう一度代入する
- 外部リソースを一切読まない自己完結 HTML にする。`localResourceRoots` を空配列にでき、`asWebviewUri` も不要になる
- スクリプトはカードのクリック（`postMessage` で拡張へファイルパスを送る）だけに使い、nonce 付きインラインで書く
- 拡張から Webview への `postMessage` は非表示時に届かないので、**状態の正はチケットのファイルに置き、可視になったら読み直す**。`retainContextWhenHidden` は使わない

参考: [Webview API](https://code.visualstudio.com/api/extension-guides/webview) / [vscode-extension-samples の webview-sample](https://github.com/microsoft/vscode-extension-samples/blob/main/webview-sample/src/extension.ts)

### 3. FileSystemWatcher にファイル移動のイベントが無い △注意

根拠: `index.d.ts` の `FileSystemWatcher` インターフェースと `workspace.createFileSystemWatcher` の doc コメント

```
$ grep -n "export interface FileSystemWatcher" -A 40 node_modules/@types/vscode/index.d.ts
1767: export interface FileSystemWatcher extends Disposable {
1773:   readonly ignoreCreateEvents: boolean;
1779:   readonly ignoreChangeEvents: boolean;
1785:   readonly ignoreDeleteEvents: boolean;
1790:   readonly onDidCreate: Event<Uri>;
1795:   readonly onDidChange: Event<Uri>;
1800:   readonly onDidDelete: Event<Uri>;
```

イベントは 3 つだけで、リネーム・移動を表すものが無い。チケットの状態変更は `ticket.sh` による `git mv` なので、watcher からは移動元の `onDidDelete` と移動先の `onDidCreate` として届く。順序も保証されていない。

生成の署名。

```
export function createFileSystemWatcher(globPattern: GlobPattern,
  ignoreCreateEvents?: boolean, ignoreChangeEvents?: boolean, ignoreDeleteEvents?: boolean): FileSystemWatcher;
```

doc コメントの注記で押さえておくべき点。

- 監視するパスはファイルシステム上に存在している必要がある。監視中のパスがリネーム・削除されると監視が止まることがある
- `globPattern` に文字列を渡すと、開いているワークスペースフォルダ全体を対象にする簡便形になる
- 再帰監視は資源を食うので最小限にする
- 使い終わったら `dispose()` する

**結論**: 監視対象は `wip/10_tickets/**/*.md` の 1 本にする。4 ディレクトリは同じ親の下なのでこれで足りる。3 イベントのいずれを受けても**差分更新はせず、4 ディレクトリを全部読み直してボードを作り直す**。チケットは多くて数十枚で、読み直しのコストは無視できる。これで移動が「削除 + 作成」に割れる問題も、順序が保証されない問題も消える。

### 4. 短時間に連続するイベントの扱い △注意

根拠: 章 3 の事実からの帰結

`git mv` 1 回で最低 2 イベント、`ticket.sh complete` のように frontmatter の書き換えと移動が続く操作では 3 イベント以上が短時間に届く。そのたびに全部読み直すと、1 回の操作でボードが数回再描画される。

**結論**: イベントを受けたら短い遅延（数十ミリ秒〜100 ミリ秒程度）でまとめてから 1 回だけ読み直す。値は設計で決める。

### 5. ワークスペースが無い場合の入口 ◎良

根拠: `index.d.ts` の `workspace.workspaceFolders` の doc コメント

`workspace.workspaceFolders` は「ワークスペースが開かれていない空のウィンドウでは空になりうる」と明記されている（`undefined` にもなる）。受け入れ条件 8（`wip/10_tickets` が無いときは静かに終わる）はここで判定できる。

**結論**: コマンド実行時に `workspace.workspaceFolders?.[0]` を見て、無ければ情報メッセージを出して終える。あっても `wip/10_tickets` が存在しなければ同様に扱う。

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 公式ドキュメントを直接読める | code.visualstudio.com へのアクセスがネットワーク制限で遮断された | `@types/vscode` の型定義を一次資料にし、慣行は Web 検索で補った。「確かめられなかったこと」に明記した |
| FileSystemWatcher にファイル移動のイベントがある | 3 イベントのみで移動は「削除 + 作成」に割れる | 差分更新をやめ、イベントを合図に全体を読み直す方式にした（章 3） |
| `activationEvents` に `onCommand:` を書く必要がある | VS Code 1.74 以降は `contributes.commands` から自動生成される | `engines.vscode` を 1.90 にして `activationEvents` を空配列にする（章 1） |

## 設計への反映

1. `package.json` は `engines.vscode: ^1.90.0`、`activationEvents: []`、`contributes.commands` にコマンド 2 つ（ボードを開く / 手動更新）（章 1）
2. エントリは `activate` / `deactivate` を export し、`registerCommand` の戻り値と watcher を `context.subscriptions` に積む（章 1）
3. ボードは外部リソースを読まない自己完結 HTML の文字列とし、`webview.html` に代入する。`localResourceRoots` は空、`asWebviewUri` は使わない（章 2）
4. CSP は `default-src 'none'` から組み、スタイルは `webview.cspSource`、スクリプトは nonce 付きインラインのみ（章 2）
5. `retainContextWhenHidden` は使わない。状態の正はチケットのファイルに置き、`onDidChangeViewState` で可視になったら読み直す（章 2）
6. watcher は `wip/10_tickets/**/*.md` の 1 本。3 イベントのいずれでも全体を読み直す（章 3）
7. 連続イベントは短い遅延でまとめて 1 回の読み直しにする。遅延の値は設計で決める（章 4）
8. `workspace.workspaceFolders` が空・`wip/10_tickets` が無い場合は情報メッセージを出して静かに終える（章 5）

## 残課題

- 公式ドキュメントに直接当たれていない。型定義とその doc コメントは一次資料だが、ガイドにしか書かれていない注意点を取りこぼしている可能性がある。実装フェーズで挙動が想定と違ったら、その時点で人間に確認を依頼する
- 実機で拡張を動かした確認ができていない。受け入れ条件 1〜8 のうち画面に関わる部分は、HTML 生成関数の出力を検査する自動テストに落とし、実機確認は人間に委ねる（0004 の結論と同じ）
- 連続イベントをまとめる遅延の具体値は決めていない。設計で決める
