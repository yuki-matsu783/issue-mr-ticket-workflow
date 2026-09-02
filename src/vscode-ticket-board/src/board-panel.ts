import * as crypto from "node:crypto";
import * as vscode from "vscode";

import { Board, buildBoard, isKnownTicketPath } from "./core/board.js";
import { renderBoard } from "./core/render.js";
import { scanTickets } from "./core/scan.js";

/**
 * 監視とメッセージで使うチケット置き場の表示パス。glob は OS によらず `/` 区切りのため、
 * `path.join` を使う `core/scan.ts` の TICKETS_DIR とは別に持つ。
 */
const TICKETS_PATH = "wip/10_tickets";

/** ファイルの変化を束ねる待ち時間（ミリ秒）。DDR i0013-05 */
const DEBOUNCE_MS = 120;

/** Webview から受け取るメッセージの型 */
interface OpenTicketMessage {
  readonly type: "open";
  readonly filePath: string;
}

/**
 * パネルは 1 つだけ持つ。パネル・watcher・デバウンスのタイマー・直近のボードを
 * 1 組として扱い、パネルの破棄時にまとめて解く。
 */
interface PanelState {
  readonly panel: vscode.WebviewPanel;
  readonly folder: vscode.WorkspaceFolder;
  watcher?: vscode.FileSystemWatcher;
  timer?: NodeJS.Timeout;
  board?: Board;
  /** 直前に観測した panel.visible。裏から表へ変わったときだけ読み直すために持つ */
  wasVisible: boolean;
}

let state: PanelState | undefined;

/** `ticketBoard.open` の本体 */
export function openBoard(): void {
  const folder = vscode.workspace.workspaceFolders?.[0];
  if (folder === undefined) {
    vscode.window.showInformationMessage(
      "ワークスペースが開かれていないため、チケットボードを表示できない",
    );
    return;
  }

  if (!scanTickets(folder.uri.fsPath).found) {
    vscode.window.showInformationMessage(
      `${TICKETS_PATH} が見つからないため、チケットボードを表示できない`,
    );
    return;
  }

  if (state !== undefined) {
    // 既に開かれていれば増やさず前面に出す。reveal が誘発する
    // onDidChangeViewState で二重に読み直さないよう、先に「表」として記録しておく
    state.wasVisible = true;
    state.panel.reveal(state.panel.viewColumn);
    update();
    return;
  }

  const panel = createPanel();
  state = { panel, folder, wasVisible: panel.visible };
  registerPanelHandlers(state);
  update();
}

/** `ticketBoard.refresh` の本体 */
export function refreshBoard(): void {
  if (state === undefined) {
    vscode.window.showInformationMessage("チケットボードが開かれていない");
    return;
  }
  update();
}

function createPanel(): vscode.WebviewPanel {
  return vscode.window.createWebviewPanel(
    "ticketBoard",
    "チケットボード",
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      enableForms: false,
      localResourceRoots: [],
      retainContextWhenHidden: false,
    },
  );
}

/** パネルを新しく作ったときだけ呼ぶ。watcher の二重登録を防ぐため */
function registerPanelHandlers(current: PanelState): void {
  const { panel, folder } = current;

  panel.webview.onDidReceiveMessage((message: unknown) => {
    handleMessage(message);
  });

  // onDidChangeViewState は active の変化でも発火する。false → true の遷移でだけ読み直し、
  // 隣のエディタへフォーカスを移すたびに Webview を作り直さない
  panel.onDidChangeViewState(() => {
    const becameVisible = panel.visible && !current.wasVisible;
    current.wasVisible = panel.visible;
    if (becameVisible) {
      update();
    }
  });

  panel.onDidDispose(() => {
    if (current.timer !== undefined) {
      clearTimeout(current.timer);
      current.timer = undefined;
    }
    current.watcher?.dispose();
    current.watcher = undefined;
    if (state === current) {
      state = undefined;
    }
  });

  const watcher = vscode.workspace.createFileSystemWatcher(
    new vscode.RelativePattern(folder, `${TICKETS_PATH}/**/*.md`),
  );
  // 移動は create / delete の対の通知として届く。いずれの種類でも全走査をやり直す
  watcher.onDidCreate(scheduleUpdate);
  watcher.onDidChange(scheduleUpdate);
  watcher.onDidDelete(scheduleUpdate);
  current.watcher = watcher;
}

/** 変化が続く間はまとめ、静まってから 1 回だけ更新する */
function scheduleUpdate(): void {
  const current = state;
  if (current === undefined) {
    return;
  }
  if (current.timer !== undefined) {
    clearTimeout(current.timer);
  }
  current.timer = setTimeout(() => {
    current.timer = undefined;
    if (state !== current) {
      // 待っている間にパネルが破棄された
      return;
    }
    update();
  }, DEBOUNCE_MS);
}

/** 走査からやり直して Webview の内容を差し替える */
function update(): void {
  const current = state;
  if (current === undefined) {
    return;
  }

  const scan = scanTickets(current.folder.uri.fsPath);
  if (!scan.found) {
    vscode.window.showInformationMessage(
      `${TICKETS_PATH} が失われたため、チケットボードを閉じる`,
    );
    current.panel.dispose();
    return;
  }

  const board = buildBoard(scan);
  current.board = board;
  current.panel.webview.html = renderBoard(board, {
    nonce: crypto.randomBytes(16).toString("base64"),
    cspSource: current.panel.webview.cspSource,
  });
}

function handleMessage(message: unknown): void {
  const open = asOpenMessage(message);
  if (open === undefined) {
    return;
  }

  const current = state;
  const board = current?.board;
  if (board === undefined || !isKnownTicketPath(board, open.filePath)) {
    // 表示中のいずれのチケットとも一致しないパスは開かない
    return;
  }

  const filePath = open.filePath;
  void vscode.workspace.openTextDocument(filePath).then(
    (document) => vscode.window.showTextDocument(document),
    () => {
      vscode.window.showInformationMessage(
        `チケットのファイルを開けなかった: ${filePath}`,
      );
      // 消えた・読めなくなった可能性があるので、ボードを最新の状態に合わせる
      update();
    },
  );
}

function asOpenMessage(message: unknown): OpenTicketMessage | undefined {
  if (typeof message !== "object" || message === null) {
    return undefined;
  }
  const candidate = message as { type?: unknown; filePath?: unknown };
  if (candidate.type !== "open" || typeof candidate.filePath !== "string") {
    return undefined;
  }
  return { type: "open", filePath: candidate.filePath };
}
