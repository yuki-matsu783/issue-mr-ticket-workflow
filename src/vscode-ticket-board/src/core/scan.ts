/**
 * 状態ディレクトリを走査してチケットを読む。VS Code の API には依存しない。
 * 仕様: docs/10_spec/vscode-ticket-board.md「データの形 / 処理フロー（走査）」
 */
import * as fs from "node:fs";
import * as path from "node:path";
import { parseTicket, unreadableTicket, type Ticket, type TicketState } from "./ticket.js";

export interface StateColumnDef {
  readonly state: TicketState;
  readonly dir: string;
  readonly label: string;
}

/** ワークスペース直下からチケットの置き場までの相対パス */
export const TICKETS_DIR = path.join("wip", "10_tickets");

/** 状態はディレクトリで表される。列の並びもこの順 */
export const STATE_COLUMNS: readonly StateColumnDef[] = [
  { state: "todo", dir: "00_todo", label: "未着手" },
  { state: "doing", dir: "10_doing", label: "作業中" },
  { state: "done", dir: "20_done", label: "完了" },
  { state: "cancelled", dir: "30_cancelled", label: "取り消し" },
];

/** チケットとして扱うファイル名。4 桁の番号で始まる Markdown だけ */
export const TICKET_FILE_PATTERN = /^(\d{4})-.*\.md$/;

export interface ScanResult {
  readonly found: boolean;
  readonly ticketsByState: ReadonlyMap<TicketState, readonly Ticket[]>;
}

const NOT_FOUND: ScanResult = { found: false, ticketsByState: new Map() };

export function scanTickets(workspaceRoot: string): ScanResult {
  const ticketsRoot = path.join(workspaceRoot, TICKETS_DIR);
  if (!isDirectory(ticketsRoot)) {
    return NOT_FOUND;
  }

  const ticketsByState = new Map<TicketState, readonly Ticket[]>();
  for (const column of STATE_COLUMNS) {
    ticketsByState.set(column.state, readColumn(path.join(ticketsRoot, column.dir), column.state));
  }
  return { found: true, ticketsByState };
}

function readColumn(dir: string, state: TicketState): readonly Ticket[] {
  let fileNames: string[];
  try {
    fileNames = fs.readdirSync(dir);
  } catch {
    // 状態ディレクトリが無い場合も空として扱う（不備にしない）
    return [];
  }

  const tickets: Ticket[] = [];
  for (const fileName of fileNames) {
    if (!TICKET_FILE_PATTERN.test(fileName)) {
      continue;
    }
    const filePath = path.join(dir, fileName);
    let text: string;
    try {
      text = fs.readFileSync(filePath, "utf8");
    } catch {
      tickets.push(unreadableTicket(filePath, fileName, state));
      continue;
    }
    tickets.push(parseTicket(filePath, fileName, state, text));
  }

  // 番号の昇順。同番号はファイル名の辞書順
  return tickets.sort((a, b) =>
    a.number === b.number ? compare(a.fileName, b.fileName) : compare(a.number, b.number),
  );
}

function compare(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

function isDirectory(target: string): boolean {
  try {
    return fs.statSync(target).isDirectory();
  } catch {
    return false;
  }
}
