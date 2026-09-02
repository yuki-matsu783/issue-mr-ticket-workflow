/**
 * 走査の結果を列と件数を持つボードに組み立てる。
 * 仕様: docs/10_spec/vscode-ticket-board.md「データの形 / 処理フロー（ボードの組み立て）」
 */
import { STATE_COLUMNS, type ScanResult, type StateColumnDef } from "./scan.js";
import type { Ticket } from "./ticket.js";

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

/** 残チケットとして数える状態。着手前と作業中 */
const REMAINING_STATES = ["todo", "doing"] as const;

export function buildBoard(scan: ScanResult): Board {
  // 該当するチケットが無くても列を落とさない
  const columns: BoardColumn[] = STATE_COLUMNS.map((column) => {
    const tickets = scan.ticketsByState.get(column.state) ?? [];
    return { ...column, tickets, count: tickets.length };
  });

  const all = columns.flatMap((column) => column.tickets);
  const remainingCount = columns
    .filter((column) => (REMAINING_STATES as readonly string[]).includes(column.state))
    .reduce((sum, column) => sum + column.count, 0);

  return {
    columns,
    totalCount: all.length,
    remainingCount,
    issueCount: all.filter((ticket) => ticket.issues.length > 0).length,
  };
}

/**
 * ボードに載っているチケットのパスと完全に一致するときだけ true。
 * Webview から届くパスを開く前の検証に使う（表示していないファイルを開かせない）。
 */
export function isKnownTicketPath(board: Board, filePath: string): boolean {
  if (filePath === "") {
    return false;
  }
  return board.columns.some((column) =>
    column.tickets.some((ticket) => ticket.filePath === filePath),
  );
}
