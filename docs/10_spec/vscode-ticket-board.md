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
```

`out/` は `tsc` の出力先。`main` は `./out/src/extension.js`。

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

`extension.ts` は `activate(context: vscode.ExtensionContext): void` と `deactivate(): void` を export する。`activate` は次を行い、戻り値の `Disposable` をすべて `context.subscriptions` に積む。

1. `vscode.commands.registerCommand("ticketBoard.open", …)` を登録する
2. `vscode.commands.registerCommand("ticketBoard.refresh", …)` を登録する
3. watcher の登録は `ticketBoard.open` が成功したときに行う（ボードが無い間は監視しない）

`deactivate` は何もしない（後始末は `context.subscriptions` が担う）。

### `ticketBoard.open` の判定順

1. `vscode.workspace.workspaceFolders?.[0]` を取る。無ければ `vscode.window.showInformationMessage` で「ワークスペースが開かれていないため、チケットボードを表示できない」と伝えて終了する
2. `scanTickets(folder.uri.fsPath)` を呼ぶ。`found` が `false` なら「`wip/10_tickets` が見つからないため、チケットボードを表示できない」と伝えて終了する
3. 既にパネルがあれば `panel.reveal(panel.viewColumn)` して内容を更新する。無ければ新しく作る

### `ticketBoard.refresh` の判定順

1. パネルが無ければ `showInformationMessage` で「チケットボードが開かれていない」と伝えて終了する
2. あれば走査からやり直して内容を更新する

## モジュール構成

依存の向きは一方向で、`core/` は `vscode` にも上位層にも依存しない。

```
extension.ts ─→ board-panel.ts ─→ core/board.ts ─→ core/scan.ts ─→ core/ticket.ts ─→ core/frontmatter.ts
                       └────────→ core/render.ts ─→ core/board.ts（型のみ）
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
}

export function parseFrontmatter(text: string): FrontmatterDocument | undefined;
```

キーはドット区切りに平坦化する（`human_review.required` / `allow.write` など）。

`core/ticket.ts`。

```ts
export type TicketState = "todo" | "doing" | "done" | "cancelled";

export type TicketIssueCode =
  | "TB001" | "TB002" | "TB003" | "TB004" | "TB005" | "TB006";

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
  readonly predecessors: readonly string[];
  readonly startedAt?: string;
  readonly completedAt?: string;
  readonly issues: readonly TicketIssue[];
}

export function parseTicket(
  filePath: string, fileName: string, state: TicketState, text: string,
): Ticket;
```

`core/scan.ts`。

```ts
export interface StateColumnDef {
  readonly state: TicketState;
  readonly dir: string;
  readonly label: string;
}

export const TICKETS_DIR = "wip/10_tickets";
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
```

`core/render.ts`。

```ts
export interface RenderOptions {
  readonly nonce: string;
  readonly cspSource: string;
}

export function renderBoard(board: Board, options: RenderOptions): string;
export function renderMissingWorkspace(options: RenderOptions): string;
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

拡張が読み込むのではなく焼き込む。読み込む場合は `.claude/` への読み取り依存が増え、拡張が機構の内部配置に結び付くため。一覧に無い値は表示したうえで TB004 を付ける（拒否しない）ので、機構側で種類が増えても表示は壊れない。

## 処理フロー

### frontmatter の解析（`parseFrontmatter`）

1. 入力を `\r?\n` で分割する。1 行目が `---` でなければ `undefined` を返す
2. 2 行目以降で最初に現れる `---` の行を終端とする。見つからなければ `undefined` を返す
3. 終端までの各行について、インデント 0 の行は `^([A-Za-z0-9_-]+)\s*:\s*(.*)$` で分解する。一致しない行は無視する
4. 値の形で分岐する
   - 空 → 入れ子マッピングの親。以降のインデントのある行を子として読む
   - `{` で始まる → インラインマップ。`,` で分割し（引用符の外だけを区切りとみなす）、各要素を `:` の最初の 1 つで分け、`<親>.<子>` のキーで登録する
   - `[` で始まる → フロー配列。`,` で分割し（同上）、各要素の引用符を外して `kind: "list"` で登録する
   - それ以外 → スカラー。引用符を外して `kind: "scalar"` で登録する
5. インデントのある行は、直前のインデント 0 の行が値を持たない親であるときだけ `^([A-Za-z0-9_-]+)\s*:\s*(.*)$` で分解し、`<親>.<子>` のキーで登録する。`-` で始まる行（ブロック配列）はキーを登録せずに読み飛ばす
6. 引用符の外し方: `"` で始まり `"` で終わる場合だけ外し、`\"` は `"` に、`\\` は `\` に戻す。`"` で始まるのに閉じていない値は**登録しない**（欠落として扱う）。`'` で始まり `'` で終わる場合は引用符を外すだけでエスケープの復元はしない

手順 6 の「閉じていない値は登録しない」は、提供ライブラリ `frontmatter.sh` がゴミの値を返す挙動（調査 0003 章 4 のパターン 4）に対する意図的な差異である。読み手として不正な値を通すより欠落として示すほうが、要件の例外フローに合う。

### チケットの解析（`parseTicket`）

不備は見つけるたびに `issues` へ追加し、途中で処理を止めない。

1. `number` はファイル名の先頭 4 桁を採る（呼び出し元が `TICKET_FILE_PATTERN` で選別済み）
2. `parseFrontmatter(text)` を呼ぶ。`undefined` なら TB001 を追加し、frontmatter 由来の項目をすべて未設定のままにして手順 5 へ進む
3. 各項目を取り出す
   - `ticket_type` / `executor`: スカラーとして取る。無ければ TB002（`detail` に欠けたキー名）
   - `human_review.required` / `adversarial_review.required`: スカラーとして取り、`true` / `false` のいずれかなら真偽値にする。無ければ TB002、それ以外の値なら TB003（`detail` にキー名と実際の値）
   - `predecessors`: リストとして取る。無ければ空配列（不備としない。先行の無いチケットは正常）
   - `started_at` / `completed_at`: スカラーとして取る。空文字はその段階に達していないことを意味するので不備としない
4. `ticket_type` が既知の 15 種に無ければ TB004（`detail` に実際の値）
5. 本文から最初の `^#\s+(\S+)\s+(.+)$` を探す
   - 見つからなければ TB005 を追加し、`title` をファイル名にする
   - 見つかった場合、1 つ目の捕捉が `number` と異なれば TB006（`detail` に両方の値）。`title` は 2 つ目の捕捉を採る
6. `Ticket` を返す

### 走査（`scanTickets`）

1. `path.join(workspaceRoot, TICKETS_DIR)` が存在しディレクトリであることを確認する。そうでなければ `{ found: false, ticketsByState: 空 }` を返す
2. `STATE_COLUMNS` の各要素について、`<tickets>/<dir>` を `fs.readdirSync` で読む。ディレクトリが無い場合は空として扱う（不備としない）
3. `TICKET_FILE_PATTERN` に一致するファイルだけを対象にする
4. 各ファイルを `fs.readFileSync(…, "utf8")` で読む。読み取りに例外が出た場合はそのファイルを TB001 だけを持つチケットとして扱い、走査を止めない
5. `parseTicket` を呼び、番号の昇順に並べる
6. `{ found: true, ticketsByState }` を返す

### ボードの組み立て（`buildBoard`）

1. `STATE_COLUMNS` の順に列を作る。該当するチケットが無くても列を落とさない（`count: 0`）
2. `totalCount` は全列の合計、`remainingCount` は `todo` と `doing` の合計、`issueCount` は `issues` が空でないチケットの数

### 表示と更新（`board-panel.ts`）

1. パネルは 1 つだけ持つ（モジュール内の変数で保持する）
2. 生成は `vscode.window.createWebviewPanel("ticketBoard", "チケットボード", vscode.ViewColumn.One, { enableScripts: true, localResourceRoots: [], retainContextWhenHidden: false })`
3. 更新は `panel.webview.html = renderBoard(board, { nonce, cspSource: panel.webview.cspSource })`。nonce は更新のたびに生成する
4. `panel.webview.onDidReceiveMessage` で `{ type: "open", filePath: string }` を受け、`vscode.workspace.openTextDocument(filePath)` → `vscode.window.showTextDocument` を呼ぶ。`filePath` は走査で得たチケットのパスと一致するものだけを受け付ける（一致しないものは無視する）
5. `panel.onDidDispose` でパネルの保持を解き、watcher を破棄する
6. `panel.onDidChangeViewState` で `panel.visible` が真になったときに更新する
7. watcher は `vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(folder, "wip/10_tickets/**/*.md"))`。`onDidCreate` / `onDidChange` / `onDidDelete` のいずれでも同じ更新処理を予約する
8. 予約は 120 ミリ秒のデバウンス。予約済みのタイマーがあれば取り消して張り直す

デバウンスを 120 ミリ秒にした根拠。状態変更は `git mv` で `onDidDelete` と `onDidCreate` の 2 イベントが数ミリ秒以内に届き、`ticket.sh complete` では frontmatter の書き換えも重なって 3 イベント以上になる（調査 0007 章 3・4）。まとめるには数ミリ秒では足りず、100 ミリ秒程度あれば実測される連続イベントを 1 回にできる。一方 200 ミリ秒を超えると利用者が更新の遅れを感じ始める。両者の間で余裕のある 120 ミリ秒を採る。

## HTML の構造と CSP

`renderBoard` が返す文字列の骨格。

```html
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none'; style-src {cspSource} 'unsafe-inline'; script-src 'nonce-{nonce}';">
<title>チケットボード</title>
<style> … </style>
</head>
<body>
  <header class="summary">
    <span class="remaining">残り {remainingCount} 件</span>
    <span class="total">全 {totalCount} 件</span>
    <span class="issues">不備 {issueCount} 件</span>
  </header>
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
      <p class="empty">チケットはありません</p>
    </section>
    …（4 列）
  </div>
<script nonce="{nonce}"> … </script>
</body>
</html>
```

決めごと。

- 色は VS Code のテーマ変数（`var(--vscode-editor-background)` など）だけを使い、独自の固定色を持たない
- `p.empty` はその列のチケットが 0 件のときだけ出す。列そのものは常に 4 つ出す
- ボード全体で 0 件のときは、`header` に加えてボード上部に「チケットが 1 枚もありません」を出す
- `ul.issues` は不備のあるカードだけに出す。不備のあるカードには `class="card has-issue"` を付ける
- レビュー要否のバッジは `要` / `不要` / `不明`（値が読み取れなかったとき）の 3 通り
- スクリプトは `nonce` 付きインライン 1 つだけ。カードのクリックと `Enter` キーで `vscode.postMessage({ type: "open", filePath })` を送る
- チケット由来の文字列（タイトル・種類・実行者・不備の詳細・パス）はすべて `escapeHtml` を通す。`&` `<` `>` `"` `'` を実体参照にする
- `style-src` に `'unsafe-inline'` を許すのは `<style>` を 1 つ埋め込むため。`script-src` は nonce のみで `'unsafe-inline'` を許さない

`renderMissingWorkspace` は使わない場合がある（対象が無いときはパネルを開かず情報メッセージで終えるため）。要件の例外フローが「ボードを開かず伝えて終了する」なので、実装では情報メッセージを採り、この関数は用意しない。

## 不備の識別子とメッセージ

識別子は `TB` + 3 桁。機構のフック・スキルの識別子台帳（`.claude/docs/10_spec/フック共通仕様.md` §6）はアセット用で、アプリの識別子は対象外のため、この仕様書が台帳を兼ねる。

| 識別子 | 意味 | カードに出す文言の型 |
|---|---|---|
| TB001 | frontmatter が読み取れない | `TB001: frontmatter を読み取れない` |
| TB002 | 必須の項目が欠けている | `TB002: {キー名} が読み取れない` |
| TB003 | 真偽値として解釈できない | `TB003: {キー名} が true/false でない（{値}）` |
| TB004 | チケットの種類が既知の一覧に無い | `TB004: 未知のチケットの種類（{値}）` |
| TB005 | 本文の見出しが読み取れない | `TB005: 見出しが読み取れない。ファイル名を表示している` |
| TB006 | ファイル名と見出しの番号が食い違う | `TB006: 番号が食い違う（ファイル名 {A} / 見出し {B}）` |

必須の項目は `ticket_type` / `executor` / `human_review.required` / `adversarial_review.required` の 4 つ。`predecessors` / `started_at` / `completed_at` / `base_sha` は欠けても不備としない。

## テスト観点

テスト ID は `TB-T<2 桁>`。すべて `core/` に対する単体テストで、`node --test` で実行する。

| ID | 対象 | 観点 |
|---|---|---|
| TB-T01 | `parseFrontmatter` | 5 種類の形（フラットスカラー / クォート付きスカラー / フロー配列 / インラインマップ / 入れ子マッピング）をすべて解釈できる |
| TB-T02 | `parseFrontmatter` | frontmatter が無い / 終端の `---` が無い / 空ファイルで `undefined` を返し、例外を投げない |
| TB-T03 | `parseFrontmatter` | 二重引用符が閉じていない値をキーごと登録しない |
| TB-T04 | `parseFrontmatter` | ブロック配列（`- x`）のキーを登録せず、他のキーの解釈を壊さない |
| TB-T05 | `parseFrontmatter` | CRLF 改行でも解釈できる。`\"` と `\\` のエスケープを戻す |
| TB-T06 | `parseTicket` | 正常なチケットから 6 つの表示項目と `predecessors` を取り出し、`issues` が空になる |
| TB-T07 | `parseTicket` | frontmatter が無いとき TB001 を付け、他の処理を続ける |
| TB-T08 | `parseTicket` | 必須キーの欠落で TB002、真偽値でない値で TB003 を付ける |
| TB-T09 | `parseTicket` | 未知の `ticket_type` で TB004 を付け、値はそのまま保持する |
| TB-T10 | `parseTicket` | 見出しが無いとき TB005 を付けてファイル名をタイトルにする。番号の食い違いで TB006 を付け、ファイル名の番号を採る |
| TB-T11 | `scanTickets` | `wip/10_tickets` が無いとき `found: false` を返す。4 桁で始まらないファイルと `.gitkeep` を除外する |
| TB-T12 | `scanTickets` | 状態ディレクトリが 1 つ欠けていても他の列を返す。番号の昇順に並ぶ |
| TB-T13 | `buildBoard` | 0 件でも 4 列を返す。`remainingCount` が todo + doing、`issueCount` が不備のあるチケット数に一致する |
| TB-T14 | `renderBoard` | 4 列と件数を出す。0 件のとき空の表示を出す。不備のあるカードに識別子を出す。タイトルに `<script>` を含むチケットでエスケープされる。CSP の `script-src` に渡した nonce が入る |

VS Code の API に触れる `extension.ts` と `board-panel.ts` は単体テストの対象にしない（`vscode` が拡張ホストの外で解決できないため。調査 0004 章 3）。要件の受け入れ基準のうち「カードを選択したとき」「ワークスペースが開かれていないとき」は README に手動確認の手順を書き、利用者の環境で確認する。

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|---|---|
| メイン: コマンドで 4 状態の列を持つボードを表示する | 起動と入口（`ticketBoard.open`）、処理フロー（ボードの組み立て）、HTML の構造。TB-T13・TB-T14 |
| メイン: 各チケットの 6 項目をカードとして置く | データの形（`Ticket`）、HTML の構造。TB-T06・TB-T14 |
| メイン: 列ごとの件数と残件数を表示する | `buildBoard`、HTML の構造（`header.summary`）。TB-T13・TB-T14 |
| メイン: カードの選択でファイルを開く | 表示と更新 4 |
| メイン: ファイルの変化でボードを更新する | 表示と更新 7・8 |
| メイン: 更新コマンドで読み直す | 起動と入口（`ticketBoard.refresh`） |
| メイン: 既に開かれていれば増やさず前面に出す | 起動と入口（`ticketBoard.open` 判定順 3）、表示と更新 1 |
| 代替: 0 件のとき空であることを示す | HTML の構造（ボード全体の 0 件表示）。TB-T13・TB-T14 |
| 代替: 空の列も件数 0 で表示する | `buildBoard` 1、HTML の構造（`p.empty`）。TB-T13・TB-T14 |
| 代替: 見出しが無ければファイル名を表示する | `parseTicket` 5。TB-T10 |
| 例外: 解析できなくても続け、不備を示す | `parseTicket` 冒頭、不備の識別子、HTML の構造（`ul.issues`）。TB-T07・TB-T08 |
| 例外: 未知の種類はそのまま出したうえで示す | `parseTicket` 4、TB004。TB-T09 |
| 例外: 番号の食い違いはファイル名を採り不備として示す | `parseTicket` 5、TB006。TB-T10 |
| 例外: 対象が無いとき伝えて終了する | 起動と入口（`ticketBoard.open` 判定順 1・2）、`scanTickets` 1。TB-T11 |
| 例外: 1 枚の失敗で他の表示を取りやめない | `scanTickets` 4、`parseTicket` 冒頭。TB-T07・TB-T12 |
| 例外: いかなるファイルも変更しない | 禁止事項。`core/` は `fs.readFileSync` と `fs.readdirSync` のみ使う |
| 整合: 状態をディレクトリから判定する | `scan.ts` の `STATE_COLUMNS`、禁止事項 |
| 整合: 4 桁で始まる Markdown だけを扱う | `TICKET_FILE_PATTERN`、`scanTickets` 3。TB-T11 |
| 整合: frontmatter をサブセットの範囲で解釈する | 処理フロー（frontmatter の解析）。TB-T01〜TB-T05 |
