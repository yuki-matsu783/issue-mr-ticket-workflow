import * as vscode from "vscode";

import { openBoard, refreshBoard } from "./board-panel.js";

export function activate(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.commands.registerCommand("ticketBoard.open", openBoard),
    vscode.commands.registerCommand("ticketBoard.refresh", refreshBoard),
  );
}

export function deactivate(): void {
  // 後始末は context.subscriptions とパネルの onDidDispose が担う
}
