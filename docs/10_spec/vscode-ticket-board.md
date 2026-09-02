---
type: spec
title: チケットボード拡張 仕様
description: 走査・解析・組み立て・描画を VS Code API に依存しない層に置き、拡張ホストに触れる層を薄く保つ構成と、モジュールごとの入出力・不備の識別子・テスト観点を定める
tags: [spec, vscode, extension]
keywords: [モジュール構成, frontmatter パーサ, 走査, ボード組み立て, HTML 生成, CSP, nonce, FileSystemWatcher, TB001, テスト ID]
---

# チケットボード拡張 仕様

対応する要件は [00_requirement/vscode-ticket-board.md](../00_requirement/vscode-ticket-board.md)。

## 概要・禁止事項

`wip/10_tickets/` 配下のチケット Markdown を読み、状態ディレクトリを列としたカンバンボードの HTML を組み立てて VS Code の Webview に表示する。VS Code の API に触れる層と触れない層を分け、後者だけを単体テストの対象にする。

禁止事項:

- チケットのファイル・状態・ワークスペースのいかなるファイルへの書き込み（読み取り専用）
- チケットの状態を frontmatter から判定すること（状態はディレクトリが正）
- Webview からの外部ネットワーク資源の読み込み（`localResourceRoots` は空、`asWebviewUri` は使わない）
- `core/` 配下から `vscode` を import すること（単体テストが不可能になる）
- チケット由来の文字列をエスケープせずに HTML へ埋め込むこと

## 配置

```
src/vscode-ticket-board/
  package.json          拡張のマニフェスト
  package-lock.json     依存の固定
  tsconfig.json         コンパイル設定
  .gitignore            node_modules/ と out/
  README.md             ビルドとテストの手順、実機確認の手順
  src/
    extension.ts        vscode 依存層。activate / deactivate、コマンド登録、watcher
    board-panel.ts      vscode 依存層。Webview パネルの生成・更新・破棄
    core/
      frontmatter.ts    frontmatter のサブセットパーサ
      ticket.ts         チケットの内部表現・検証・本文の読み取り
      scan.ts           状態ディレクトリの走査
      board.ts          ボードの組み立て（列・件数）
      render.ts         HTML の生成
  test/
    frontmatter.test.ts
    ticket.test.ts
    scan.test.ts
    board.test.ts
    render.test.ts
    fixtures/
      0011-implementation.md   ticket.sh が実際に書き出したチケットの写し
```

`test/fixtures/` には実物のチケットを 1 枚置く。テンプレート（`ticket.sh` の `assets/ticket.template.md`）が変わって解析が誤検知を出すようになったとき、単体テストで気づけるようにするため。

`out/` は `tsc` の出力先。`main` は `./out/src/extension.js`。

`tsconfig.json` は次のとおり。`rootDir` を `.` にすることで `src/` と `test/` の階層が `out/` にそのまま写り、`main` の `./out/src/extension.js` と テストの `out/test/*.test.js` が同時に成立する。

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "lib": ["ES2022"],
    "outDir": "out",
    "rootDir": ".",
    "strict": true,
    "sourceMap": false,
    "declaration": false
  },
  "include": ["src/**/*.ts", "test/**/*.ts"]
}
```

`module: Node16` では相対 import の指定子に `.js` 拡張子が要る（`import { parseTicket } from "./ticket.js"`）。TypeScript のソースは `.ts` だが指定子は `.js` と書く。

開発依存のバージョン範囲。`@types/vscode` の版は `engines.vscode` と揃える。

| パッケージ | 範囲 |
|---|---|
| `typescript` | `^5.9.0` |
| `@types/node` | `^22.0.0` |
| `@types/vscode` | `^1.90.0` |

## 起動と入口

`package.json` の要点。

| フィールド | 値 |
|---|---|
| `name` | `vscode-ticket-board` |
| `version` | `0.1.0` |
| `publisher` | `local` |
| `engines.vscode` | `^1.90.0` |
| `main` | `./out/src/extension.js` |
| `activationEvents` | `[]`（VS Code 1.74 以降、`contributes.commands` から `onCommand:` が自動生成される） |
| `scripts.compile` | `tsc -p .` |
| `scripts.test` | `tsc -p . && node --test out/test/*.test.js` |
| `devDependencies` | `typescript` / `@types/node` / `@types/vscode` の 3 つのみ |

`contributes.commands`。

| command | title |
|---|---|
| `ticketBoard.open` | `チケットボード: ボードを開く` |
| `ticketBoard.refresh` | `チケットボード: ボードを更新` |

`extension.ts` は `activate(context: vscode.ExtensionContext): void` と `deactivate(): void` を export する。`activate` は次を行い、**コマンド登録の `Disposable` を** `context.subscriptions` に積む。パネル由来の `Disposable`（`onDidReceiveMessage` / `onDidChangeViewState` / `onDidDispose` / watcher）は積まず、パネルの寿命に紐づける（「表示と更新 7」が後始末を担うため。両方に積むと破棄の経路が二重になる）。

1. `vscode.commands.registerCommand("ticketBoard.open", …)` を登録する
2. `vscode.commands.registerCommand("ticketBoard.refresh", …)` を登録する
3. watcher の登録は `ticketBoard.open` が成功したときに行う（ボードが無い間は監視しない）

`deactivate` は何もしない（後始末は `context.subscriptions` が担う）。

### `ticketBoard.open` の判定順

1. `vscode.workspace.workspaceFolders?.[0]` を取る。無ければ `vscode.window.showInformationMessage` で「ワークスペースが開かれていないため、チケットボードを表示できない」と伝えて終了する。**見るのは最初のフォルダだけ**で、マルチルートワークスペースの 2 つ目以降は対象にしない。ワークスペースのフォルダ構成が開いた後に変わっても追随しない
2. `scanTickets(folder.uri.fsPath)` を呼ぶ。`found` が `false` なら「`wip/10_tickets` が見つからないため、チケットボードを表示できない」と伝えて終了する
3. 既にパネルがあれば `panel.reveal(panel.viewColumn)` して内容を更新する。無ければ新しく作る

### `ticketBoard.refresh` の判定順

1. パネルが無ければ `showInformationMessage` で「チケットボードが開かれていない」と伝えて終了する
2. あれば走査からやり直して内容を更新する

## モジュール構成

依存の向きは一方向で、`core/` は `vscode` にも上位層にも依存しない。

```
extension.ts ─→ board-panel.ts ─→ core/board.ts ─→ core/scan.ts ─→ core/ticket.ts ─→ core/frontmatter.ts
                       ├────────→ core/scan.ts
                       └────────→ core/render.ts

型だけの参照（実行時の依存を作らない）
  core/render.ts ┈→ core/board.ts / core/ticket.ts
  core/board.ts  ┈→ core/ticket.ts / core/scan.ts
```

| 層 | モジュール | `vscode` への依存 | 単体テスト |
|---|---|---|---|
| 拡張ホスト層 | `extension.ts` / `board-panel.ts` | あり | 対象外。実機確認 |
| 中核層 | `core/*.ts` | 無し（ファイル読み取りは `node:fs`） | 対象 |

## データの形

`core/frontmatter.ts`。

```ts
export type FrontmatterEntry =
  | { readonly kind: "scalar"; readonly value: string }
  | { readonly kind: "list"; readonly items: readonly string[] };

export interface FrontmatterDocument {
  readonly entries: ReadonlyMap<string, FrontmatterEntry>;
  /** 終端の区切りより後ろの本文。見出しの探索を frontmatter の外に限るために持つ */
  readonly body: string;
}

export function parseFrontmatter(text: string): FrontmatterDocument | undefined;
```

キーはドット区切りに平坦化する（`human_review.required` / `allow.write` など）。`body` を返すのは、区切りの探索を `parseTicket` 側で重ねて書かないためである（見出しの探索範囲は「処理フロー（チケットの解析）」手順 6）。

`core/ticket.ts`。

```ts
export type TicketState = "todo" | "doing" | "done" | "cancelled";

export type TicketIssueCode =
  | "TB001" | "TB002" | "TB003" | "TB004" | "TB005" | "TB006" | "TB007";

export interface TicketIssue {
  readonly code: TicketIssueCode;
  readonly detail: string;
}

export interface Ticket {
  readonly filePath: string;
  readonly fileName: string;
  readonly state: TicketState;
  readonly number: string;
  readonly title: string;
  readonly ticketType?: string;
  readonly executor?: string;
  readonly humanReview?: boolean;
  readonly adversarialReview?: boolean;
  readonly issues: readonly TicketIssue[];
}

/** 既知のチケットの種類。実体は as const の 15 要素（下の「既知のチケットの種類」） */
export const KNOWN_TICKET_TYPES: readonly string[];

export function isKnownTicketType(value: string): boolean;

export function parseTicket(
  filePath: string, fileName: string, state: TicketState, text: string,
): Ticket;

/** ファイルを読み取れなかったときの代替表現。issues は TB007 の 1 件だけ */
export function unreadableTicket(
  filePath: string, fileName: string, state: TicketState,
): Ticket;
```

読み取り失敗を `parseTicket` の分岐にせず独立した関数にする。`parseTicket` の入力は本文の文字列であり、「本文が無い」場合を同じ関数で扱うと引数の意味が二重になるため。

`core/scan.ts`。

```ts
export interface StateColumnDef {
  readonly state: TicketState;
  readonly dir: string;
  readonly label: string;
}

/** 走査に使うパス。OS の区切りに合わせるため path.join で作る */
export const TICKETS_DIR = path.join("wip", "10_tickets");
export const STATE_COLUMNS: readonly StateColumnDef[] = [
  { state: "todo",      dir: "00_todo",      label: "未着手" },
  { state: "doing",     dir: "10_doing",     label: "作業中" },
  { state: "done",      dir: "20_done",      label: "完了" },
  { state: "cancelled", dir: "30_cancelled", label: "取り消し" },
];
export const TICKET_FILE_PATTERN = /^(\d{4})-.*\.md$/;

export interface ScanResult {
  readonly found: boolean;
  readonly ticketsByState: ReadonlyMap<TicketState, readonly Ticket[]>;
}

export function scanTickets(workspaceRoot: string): ScanResult;
```

`core/board.ts`。

```ts
export interface BoardColumn extends StateColumnDef {
  readonly tickets: readonly Ticket[];
  readonly count: number;
}

export interface Board {
  readonly columns: readonly BoardColumn[];
  readonly totalCount: number;
  readonly remainingCount: number;
  readonly issueCount: number;
}

export function buildBoard(scan: ScanResult): Board;

/** ボードに載っているチケットのパスと完全に一致するときだけ true。Webview から届くパスの検証に使う */
export function isKnownTicketPath(board: Board, filePath: string): boolean;
```

`core/render.ts`。

```ts
export interface RenderOptions {
  readonly nonce: string;
}

export function renderBoard(board: Board, options: RenderOptions): string;
export function escapeHtml(text: string): string;
```

### 既知のチケットの種類

`core/ticket.ts` に定数として持つ。`.claude/hooks/config/task-types.tsv` の 2 列目 15 種。

```
overall-plan / investigation-plan / investigation / design-plan / design /
implementation-plan / implementation / feedback-plan / design-feedback-plan /
design-feedback / ai-asset-design-plan / ai-asset-design /
ai-asset-implementation-plan / ai-asset-implementation / overall-summary
```

一覧は拡張の定数として持つ（`task-types.tsv` を読まない）。一覧に無い値は表示したうえで TB004 を付け、拒否しない。決定の経緯は DDR [i0013-04](../20_ddr/i0013-04-チケットの種類を拡張に焼き込む.md)。

## 処理フロー

### frontmatter の解析（`parseFrontmatter`）

1. 入力の先頭に BOM（`\uFEFF`）があれば剥がし、`\r?\n` で分割する。1 行目が区切り行でなければ `undefined` を返す。区切り行の判定は前後の空白を落とした結果が `---` であること（BOM 付きで保存されたファイルや行末に空白の入ったファイルを「読み取れない」にしないため）
2. 2 行目以降で最初に現れる区切り行を終端とする。見つからなければ `undefined` を返す。終端より後ろの全体を `body` として返す
3. 終端までの各行について、インデント 0 の行は `^([A-Za-z0-9_-]+)\s*:\s*(.*)$` で分解する。一致しない行は無視する
4. 値の形で分岐する
   - 空 → 入れ子マッピングの親。以降のインデントのある行を子として読む
   - `{` で始まり `}` で終わる → インラインマップ。**先頭の `{` と末尾の `}` を先に取り除いてから** `,` で分割し（引用符の外に現れる `,` だけを区切りとみなす）、各要素を最初の `:` で分け、左をキー、右を値として `<親>.<子>` のキーで登録する。子の値は常に `kind: "scalar"` とし、引用符を外す
   - `[` で始まり `]` で終わる → フロー配列。**先頭の `[` と末尾の `]` を先に取り除いてから** `,` で分割し（同上）、各要素の引用符を外して `kind: "list"` で登録する。空の `[]` は要素 0 個のリストとして登録する
   - それ以外 → スカラー。引用符を外して `kind: "scalar"` で登録する
5. インデントのある行は、直前のインデント 0 の行が値を持たない親であるときだけ `^([A-Za-z0-9_-]+)\s*:\s*(.*)$` で分解し、`<親>.<子>` のキーで登録する。**子として認めるのは 1 段だけ**で、その親について最初に現れた子と同じインデント幅の行に限る。それより深い行（孫）はキーを登録せずに読み飛ばす（孫が同じ名前を持つと親の値を上書きしてしまうため）。**子の値には手順 4 の分岐をそのまま適用する**（`allow:` の下の `write: ["wip/**"]` はフロー配列として `kind: "list"` で登録される）。`-` で始まる行（ブロック配列）はキーを登録せずに読み飛ばす
6. 引用符の外し方: `"` で始まり `"` で終わる場合は外し、`\"` は `"` に、`\\` は `\` に戻す。`'` で始まり `'` で終わる場合は引用符を外すだけでエスケープの復元はしない。**引用符（`"` / `'`）で始まるのに閉じていない値は登録しない**（欠落として扱う）

インラインマップの子のキーは `^[A-Za-z0-9_-]+$` に一致するものだけを登録する。フロー配列は、要素が 1 つでも引用符を外せなければ（閉じていない）そのキーごと登録しない。いずれも「読めない値を通さない」という手順 6 と同じ方針による。

YAML のコメント（`#` 以降）は解釈しない。`ticket_type: implementation # メモ` の値は `implementation # メモ` になる。`ticket.sh` は値の後ろにコメントを書かないため、サブセットの範囲に含めない。

手順 6 の「閉じていない値は登録しない」は、提供ライブラリ `frontmatter.sh` の挙動に対する意図的な差異である。経緯は DDR [i0013-03](../20_ddr/i0013-03-frontmatterを自前のサブセットパーサで読む.md)。

### チケットの解析（`parseTicket`）

不備は見つけるたびに `issues` へ追加し、途中で処理を止めない。

1. `number` はファイル名の先頭 4 桁を採る（呼び出し元が `TICKET_FILE_PATTERN` で選別済み）。`predecessors` / `started_at` / `completed_at` / `base_sha` は表示しないので読まない
2. `parseFrontmatter(text)` を呼ぶ。`undefined` なら TB001 を追加し、frontmatter 由来の項目をすべて未設定のままにして手順 6 へ進む
3. 必須の 4 項目（`ticket_type` / `executor` / `human_review.required` / `adversarial_review.required`）をスカラーとして取り出す。**スカラーとして取れなかったものはすべて TB002 とする**。キー自体が無い場合と、キーはあるが形が違う場合（フロー配列・入れ子マッピング）を区別して `detail` に書く（不備が 1 件も出ないまま項目だけが消えるのを防ぐため）。TB002 は次の手順の TB003 より先に `issues` へ積む
4. `human_review.required` / `adversarial_review.required` の値が `true` / `false` のいずれかなら真偽値にする。それ以外の値なら TB003（`detail` にキー名と実際の値）
5. `ticket_type` が既知の 15 種に無ければ TB004（`detail` に実際の値）
6. **本文（`FrontmatterDocument.body`。frontmatter が読めなかった場合は入力全体）** から最初の `^#[ \t]+(\S+)[ \t]+(.+)$` を探す（区切りは半角空白とタブだけ。全角空白は見出しの区切りにしない。`ticket.sh` は半角しか書かない）。コードフェンス（前後の空白を落とした結果が ``` または ~~~ で始まる行）に囲まれた行は本文の見出しとして扱わない。frontmatter の YAML コメント行やシェル片の中の `#` をタイトルに採らないため
   - 見つからなければ TB005 を追加し、`title` をファイル名にする
   - 見つかった場合、1 つ目の捕捉が `number` と異なれば TB006（`detail` に両方の値）。`title` は 2 つ目の捕捉の前後の空白を落として採る
7. `Ticket` を返す

### 走査（`scanTickets`）

1. `path.join(workspaceRoot, TICKETS_DIR)` が存在しディレクトリであることを確認する。そうでなければ `{ found: false, ticketsByState: 空 }` を返す
2. `STATE_COLUMNS` の各要素について、`<tickets>/<dir>` を `fs.readdirSync` で読む。ディレクトリが無い場合は空として扱う（不備としない）
3. `TICKET_FILE_PATTERN` に一致する名前だけを対象にする。ファイルかどうかは種別で判定せず、手順 4 の読み取りが成功するかで決める。シンボリックリンクを実体と区別しない（`ticket.sh` はリンクを作らないため、区別する仕組みを持たない）。リンクが読めれば通常のチケットとして扱い、読めなければ（壊れたリンク・ディレクトリ・権限）手順 4 の読み取り失敗に合流して TB007 になる。リンク先がワークスペースの外を指す場合もその内容を表示する
4. 各ファイルを `fs.readFileSync(…, "utf8")` で読む。読み取りに例外が出た場合は、`number` をファイル名の先頭 4 桁、`title` をファイル名、`state` を走査中の状態とし、`issues` に TB007 だけを持つチケットとして扱い、走査を止めない。他のすべての項目は未設定にする
5. `parseTicket` を呼び、番号の昇順に並べる。番号が同じものが同じ列にある場合はファイル名の辞書順（`String` の比較）で並べる
6. `{ found: true, ticketsByState }` を返す

### ボードの組み立て（`buildBoard`）

1. `STATE_COLUMNS` の順に列を作る。該当するチケットが無くても列を落とさない（`count: 0`）
2. `totalCount` は全列の合計、`remainingCount` は `todo` と `doing` の合計、`issueCount` は `issues` が空でないチケットの数

### 表示と更新（`board-panel.ts`）

1. パネルは 1 つだけ持つ（モジュール内の変数で保持する）。デバウンスのタイマーと watcher も同じ変数の組で持つ
2. 生成は `vscode.window.createWebviewPanel("ticketBoard", "チケットボード", vscode.ViewColumn.One, { enableScripts: true, enableForms: false, localResourceRoots: [], retainContextWhenHidden: false })`
3. watcher は**パネルを新しく作ったときだけ**登録する。既にパネルがある経路（`reveal`）では登録しない。二重登録を防ぐため
4. 更新は `panel.webview.html = renderBoard(board, { nonce })`。nonce は更新のたびに `crypto.randomBytes(16).toString("base64")`（`node:crypto`）で生成する。CSP は nonce だけで閉じるため `webview.cspSource` は渡さない
5. 更新の前に `scanTickets` を呼び、`found` が `false` なら HTML を差し替えず、`showInformationMessage` で対象が失われた旨を伝えて `panel.dispose()` する
6. `panel.webview.onDidReceiveMessage` で `{ type: "open", filePath: string }` を受ける。受け取った値は `unknown` として扱い、`type` が `"open"` であることと `filePath` が文字列であることを確かめてから使う（Webview は改ざんされうる入力元のため、型注釈で通さない）。`isKnownTicketPath(board, filePath)` が `false` なら**何もしない**（不正なパスを開かない）。`true` なら `vscode.workspace.openTextDocument(filePath)` → `vscode.window.showTextDocument(doc)` を呼ぶ。`openTextDocument` は対象が存在しない・読み込めない場合に reject するので、捕まえて `showInformationMessage` で開けなかった旨を伝え、続けてボードを読み直す
7. `panel.onDidDispose` で、デバウンスのタイマーを取り消し、watcher を破棄し、パネルの保持を解く
8. `panel.onDidChangeViewState` で `panel.visible` が偽から真へ**変わったとき**に更新する。このイベントは `active` の変化でも発火するため、直前の `visible` を保持して遷移だけを見る（隣のエディタへフォーカスを移すたびに Webview を作り直さないため）。`ticketBoard.open` の `reveal` 経路では、`reveal` の前に「表」として記録してから明示的に更新し、二重に読み直さない
9. watcher は `vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(folder, "wip/10_tickets/**/*.md"))`。glob は OS によらず `/` 区切りのため、`path.join` で作る `TICKETS_DIR` は使わず、`board-panel.ts` に `/` 区切りの定数を別に持つ。`onDidCreate` / `onDidChange` / `onDidDelete` のいずれでも同じ更新処理を予約する
10. 予約は 120 ミリ秒のデバウンス。予約済みのタイマーがあれば取り消して張り直す。タイマーが発火したとき、パネルが既に破棄されていれば何もしない

値の決定の経緯は DDR [i0013-05](../20_ddr/i0013-05-デバウンスの値.md)。

## HTML の構造と CSP

`renderBoard` が返す文字列の骨格。

```html
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none'; base-uri 'none'; form-action 'none';
               style-src 'nonce-{nonce}'; script-src 'nonce-{nonce}';">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>チケットボード</title>
<style nonce="{nonce}"> … </style>
</head>
<body>
  <header class="summary">
    <span class="remaining">残り {remainingCount} 件</span>
    <span class="total">全 {totalCount} 件</span>
    <span class="issues">不備 {issueCount} 件</span>
  </header>
  <p class="board-empty">チケットが 1 枚もありません</p>   <!-- 全体で 0 件のときだけ -->
  <div class="board">
    <section class="column" data-state="todo">
      <h2>未着手 <span class="count">3</span></h2>
      <ul class="cards">
        <li class="card" data-path="…" tabindex="0">
          <div class="card-head"><span class="num">0004</span><span class="title">…</span></div>
          <div class="badges">
            <span class="badge type">investigation</span>
            <span class="badge executor">main</span>
            <span class="badge review-human">人 要</span>
            <span class="badge review-adv">敵 要</span>
          </div>
          <ul class="issues"><li>TB002: executor が読み取れない</li></ul>
        </li>
      </ul>
      <p class="empty">チケットはありません</p>   <!-- 0 件のときだけ。ul.cards とは排他 -->
    </section>
    …（4 列）
  </div>
<script nonce="{nonce}">
  const vscode = acquireVsCodeApi();   // Webview 内で 1 回だけ呼べる
  // カードの click と Enter キーで vscode.postMessage({ type: "open", filePath }) を送る
</script>
</body>
</html>
```

決めごと。

- 色は VS Code のテーマ変数（`var(--vscode-editor-background)` など）だけを使い、独自の固定色を持たない
- `p.empty` はその列のチケットが 0 件のときだけ出す。列そのものは常に 4 つ出す
- ボード全体で 0 件のときは、`header` に加えてボード上部に「チケットが 1 枚もありません」を出す
- `ul.issues` は不備のあるカードだけに出す。不備のあるカードには `class="card has-issue"` を付ける
- レビュー要否のバッジは `要` / `不要` / `不明`（値が読み取れなかったとき）の 3 通り
- `ticket_type` / `executor` が読み取れなかったカードには、バッジに「種類不明」「実行者不明」と出す（バッジそのものを消さない。何が読めなかったかが `ul.issues` の TB002 と対応して見えるようにするため）
- DoD のチェック進捗（`- [x]` の数）はカードに出さない。本文の走査が要り、frontmatter だけを読む方針から外れるため（調査 0003 の申し送りに対する決定）
- タイトルは折り返して全文を出す（`overflow-wrap: anywhere`）。省略記号で切らない。列の幅は固定し、ボード全体を横スクロールさせる
- スクリプトは `nonce` 付きインライン 1 つだけ。冒頭で `acquireVsCodeApi()` を 1 回だけ呼び、カードの `click` と `Enter` キーで `vscode.postMessage({ type: "open", filePath })` を送る
- `<style>` も `nonce` 付きにする。`style-src` に `'unsafe-inline'` を許さない（調査 0007 章 2 が挙げた `style-src ${webview.cspSource}` は外部のスタイルシートを許す形で、埋め込みの `<style>` 1 つには nonce のほうが狭い）
- `base-uri 'none'` と `form-action 'none'` を明示する。どちらも `default-src` の対象外のため
- Webview の `enableForms` は `false` にする（既定はスクリプト有効時に `true`）。フォームを使わないため
- チケット由来の文字列（タイトル・種類・実行者・不備の詳細・パス）はすべて `escapeHtml` を通す

`escapeHtml` の変換は次のとおり固定する。

| 入力 | 出力 |
|---|---|
| `&` | `&amp;` |
| `<` | `&lt;` |
| `>` | `&gt;` |
| `"` | `&quot;` |
| `'` | `&#39;` |

`&` を最初に変換する（後続の変換が生む `&` を二重変換しないため）。

## 不備の識別子とメッセージ

識別子は `TB` + 3 桁。機構のフック・スキルの識別子台帳（`.claude/docs/10_spec/フック共通仕様.md` §6）はアセット用で、アプリの識別子は対象外のため、この仕様書が台帳を兼ねる。

| 識別子 | 意味 | カードに出す文言の型 |
|---|---|---|
| TB001 | frontmatter が読み取れない | `TB001: frontmatter を読み取れない` |
| TB002 | 必須の項目が欠けている、または scalar として読み取れない | `TB002: {キー名} が読み取れない` / `TB002: {キー名} が読み取れない（scalar でない）` |
| TB003 | 真偽値として解釈できない | `TB003: {キー名} が true/false でない（{値}）` |
| TB004 | チケットの種類が既知の一覧に無い | `TB004: 未知のチケットの種類（{値}）` |
| TB005 | 本文の見出しが読み取れない | `TB005: 見出しが読み取れない。ファイル名を表示している` |
| TB006 | ファイル名と見出しの番号が食い違う | `TB006: 番号が食い違う（ファイル名 {A} / 見出し {B}）` |
| TB007 | ファイルを読み取れない | `TB007: ファイルを読み取れない` |

必須の項目は `ticket_type` / `executor` / `human_review.required` / `adversarial_review.required` の 4 つ。表示しない項目（`predecessors` / `started_at` / `completed_at` / `base_sha`）は読まないので、欠けていても不備にならない。

## テスト観点

テスト ID は `TB-T<2 桁>`。すべて `core/` に対する単体テストで、`node --test` で実行する。

| ID | 対象 | 観点 |
|---|---|---|
| TB-T01 | `parseFrontmatter` | 5 種類の形（フラットスカラー / クォート付きスカラー / フロー配列 / インラインマップ / 入れ子マッピング）をすべて解釈できる。インラインマップの子が `scalar`、入れ子マッピングの下のフロー配列が `list` になる。`body` が終端の区切りより後ろだけを返す |
| TB-T02 | `parseFrontmatter` | frontmatter が無い / 終端の `---` が無い / 空ファイルで `undefined` を返し、例外を投げない。BOM 付きのファイルと、区切り行の末尾に空白があるファイルは読み取れる |
| TB-T03 | `parseFrontmatter` | 二重引用符が閉じていない値をキーごと登録しない |
| TB-T04 | `parseFrontmatter` | ブロック配列（`- x`）のキーを登録せず、他のキーの解釈を壊さない。空のフロー配列 `[]` を要素 0 個で登録する。2 段字下げの孫が親の値を上書きしない |
| TB-T05 | `parseFrontmatter` | CRLF 改行でも解釈できる。`\"` と `\\` のエスケープを戻す |
| TB-T06 | `parseTicket` | 正常なチケットから 6 つの表示項目を取り出し、`issues` が空になる。`test/fixtures/` に置いた実物のチケットの写しでも `issues` が空になる |
| TB-T07 | `parseTicket` | frontmatter が無いとき TB001 を付け、他の処理を続ける |
| TB-T08 | `parseTicket` | 必須キーの欠落で TB002、真偽値でない値で TB003 を付ける。キーはあるが scalar でない（フロー配列・入れ子マッピング）場合も TB002 を付ける。`issues` の並びは TB002 が TB003 より先になる |
| TB-T09 | `parseTicket` | 未知の `ticket_type` で TB004 を付け、値はそのまま保持する |
| TB-T10 | `parseTicket` | 見出しが無いとき TB005 を付けてファイル名をタイトルにする。番号の食い違いで TB006 を付け、ファイル名の番号を採る。frontmatter の中の `#` 行とコードフェンスの中の `#` 行を見出しとして採らない |
| TB-T11 | `scanTickets` | `wip/10_tickets` が無いとき `found: false` を返す。4 桁で始まらないファイルと `.gitkeep` を除外する |
| TB-T12 | `scanTickets` | 状態ディレクトリが 1 つ欠けていても他の列を返す。番号の昇順に並び、同番号はファイル名の辞書順になる。読み取れないファイルに TB007 を付けて走査を続ける |
| TB-T13 | `buildBoard` | 0 件でも 4 列を返す。`remainingCount` が todo + doing、`issueCount` が不備のあるチケット数に一致する |
| TB-T14 | `renderBoard` | 4 列と件数を出す。0 件のとき空の表示を出す。不備のあるカードに識別子を出す。タイトルに `<script>` や `&` を含むチケットで 5 文字が仕様の表どおりに変換される。不備の `detail` と列のラベルもエスケープを通る。`ticket_type` / `executor` が未設定のカードに「種類不明」「実行者不明」が出る。CSP の `script-src` と `style-src` に渡した nonce が入り、外部資源を読む要素・URL・`@import`・`url(` を含まない |
| TB-T15 | `isKnownTicketPath` | ボードに載っているパスだけ `true` を返す。載っていないパス・空文字・上位ディレクトリを含むパスで `false` を返す |
| TB-T16 | `scanTickets` | 同じファイルを別の状態ディレクトリへ移した後に再走査すると、そのチケットが元の列から消えて移動先の列に現れる |
| TB-T17 | `scanTickets` / `buildBoard` | 取り消し（`30_cancelled`）のチケットが取り消し列に現れ、`remainingCount` に数えられない |

VS Code の API に触れる `extension.ts` と `board-panel.ts` は単体テストの対象にしない（`vscode` が拡張ホストの外で解決できないため。調査 0004 章 3）。要件の制約条件の 1 つ目（VS Code を起動しなければ観察できない）が列挙する 10 件の受け入れ基準は、README に手動確認の手順を書いて利用者の環境で確認する。

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 | テスト |
|---|---|---|
| メイン: コマンドで 4 状態の列を持つボードを表示する | 起動と入口（`ticketBoard.open`）、処理フロー（ボードの組み立て）、HTML の構造 | TB-T13・TB-T14（手動: 表示） |
| メイン: 各チケットの 6 項目をカードとして置く | データの形（`Ticket`）、HTML の構造 | TB-T06・TB-T14 |
| メイン: 列ごとの件数と残件数を表示する | `buildBoard`、HTML の構造（`header.summary`） | TB-T13・TB-T14 |
| メイン: カードの選択でファイルを開く | 表示と更新 6 | TB-T15（検証部分）。開く動作は手動 |
| メイン: ファイルの変化でボードを更新する | 表示と更新 9・10 | TB-T16（再走査）。通知は手動 |
| メイン: 更新コマンドで読み直す | 起動と入口（`ticketBoard.refresh`） | 手動 |
| メイン: 既に開かれていれば増やさず前面に出す | 起動と入口（判定順 3）、表示と更新 1・3 | 手動 |
| 代替: 0 件のとき空であることを示す | HTML の構造（ボード全体の 0 件表示） | TB-T13・TB-T14 |
| 代替: 空の列も件数 0 で表示する | `buildBoard` 1、HTML の構造（`p.empty`） | TB-T13・TB-T14 |
| 代替: 見出しが無ければファイル名を表示する | `parseTicket` 6 | TB-T10 |
| 代替: 未表示で更新コマンドを実行したら伝える | 起動と入口（`ticketBoard.refresh` 判定順 1） | 手動 |
| 代替: 再び見える状態になったら読み直す | 表示と更新 8 | 手動 |
| 例外: 解析できなくても続け、不備を示す | `parseTicket` 冒頭、不備の識別子、HTML の構造（`ul.issues`） | TB-T07・TB-T08 |
| 例外: 未知の種類はそのまま出したうえで示す | `parseTicket` 5、TB004 | TB-T09 |
| 例外: 番号の食い違いはファイル名を採り不備として示す | `parseTicket` 6、TB006 | TB-T10 |
| 例外: 対象が無いとき伝えて終了する | 起動と入口（判定順 1・2）、`scanTickets` 1 | TB-T11（走査側）。伝達は手動 |
| 例外: 表示中に対象が失われたら伝えて閉じる | 表示と更新 5 | 手動 |
| 例外: 選択したファイルが無ければ伝えて読み直す | 表示と更新 6（reject の捕捉） | 手動 |
| 例外: 1 枚の失敗で他の表示を取りやめない | `scanTickets` 4（TB007）、`parseTicket` 冒頭 | TB-T07・TB-T12 |
| 例外: 表示中のいずれとも一致しないファイルを開かない | 表示と更新 6（`isKnownTicketPath`） | TB-T15 |
| 例外: いかなるファイルも変更しない | 禁止事項。`core/` は `fs.readFileSync` と `fs.readdirSync` のみ使う | — |
| 整合: 状態をディレクトリから判定する | `scan.ts` の `STATE_COLUMNS`、禁止事項 | TB-T17 |
| 整合: 4 桁で始まる Markdown だけを扱う | `TICKET_FILE_PATTERN`、`scanTickets` 3 | TB-T11 |
| 整合: frontmatter を 5 形式の範囲で解釈する | 処理フロー（frontmatter の解析） | TB-T01〜TB-T05 |
| 整合: 単体テストを備え、実行方法を README に記載する | 配置（`README.md` / `test/`）、起動と入口（`scripts.test`） | — |
| 整合: README の手順でビルドとテストが成功する | 配置（`tsconfig.json`）、起動と入口（`scripts.compile` / `scripts.test` / `devDependencies`） | — |

要件の受け入れ基準は 26 件（メイン 7 / 代替 5 / 例外 9 / 整合 5）で、上表の行数と一致する。実現箇所の無い行は無く、どの行からも参照されない節も無い。
