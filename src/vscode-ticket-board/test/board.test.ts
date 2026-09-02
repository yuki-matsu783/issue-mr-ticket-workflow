import { test } from "node:test";
import assert from "node:assert/strict";
import { buildBoard, isKnownTicketPath } from "../src/core/board.js";
import type { ScanResult } from "../src/core/scan.js";
import type { Ticket, TicketState } from "../src/core/ticket.js";

function ticket(number: string, state: TicketState, hasIssue = false): Ticket {
  return {
    filePath: `/w/wip/10_tickets/${state}/${number}-x.md`,
    fileName: `${number}-x.md`,
    state,
    number,
    title: `題 ${number}`,
    ticketType: "investigation",
    executor: "main",
    humanReview: true,
    adversarialReview: false,
    issues: hasIssue ? [{ code: "TB002", detail: "executor が読み取れない" }] : [],
  };
}

function scan(tickets: Partial<Record<TicketState, readonly Ticket[]>>): ScanResult {
  const map = new Map<TicketState, readonly Ticket[]>();
  for (const state of ["todo", "doing", "done", "cancelled"] as const) {
    map.set(state, tickets[state] ?? []);
  }
  return { found: true, ticketsByState: map };
}

test("TB-T13 0 件でも 4 列を返す", () => {
  const board = buildBoard(scan({}));
  assert.equal(board.columns.length, 4);
  assert.deepEqual(board.columns.map((c) => c.count), [0, 0, 0, 0]);
  assert.deepEqual(board.columns.map((c) => c.label), ["未着手", "作業中", "完了", "取り消し"]);
  assert.equal(board.totalCount, 0);
  assert.equal(board.remainingCount, 0);
  assert.equal(board.issueCount, 0);
});

test("TB-T13 remainingCount が todo + doing、issueCount が不備のあるチケット数に一致する", () => {
  const board = buildBoard(scan({
    todo: [ticket("0004", "todo"), ticket("0005", "todo", true)],
    doing: [ticket("0003", "doing")],
    done: [ticket("0001", "done"), ticket("0002", "done", true)],
    cancelled: [ticket("0006", "cancelled")],
  }));
  assert.equal(board.totalCount, 6);
  assert.equal(board.remainingCount, 3);   // todo 2 + doing 1
  assert.equal(board.issueCount, 2);
  assert.deepEqual(board.columns.map((c) => c.count), [2, 1, 2, 1]);
});

test("TB-T17 取り消しのチケットは取り消し列に現れ、remainingCount に数えない", () => {
  const board = buildBoard(scan({
    todo: [ticket("0001", "todo")],
    cancelled: [ticket("0002", "cancelled"), ticket("0003", "cancelled")],
  }));
  const cancelled = board.columns.find((c) => c.state === "cancelled");
  assert.ok(cancelled);
  assert.equal(cancelled.count, 2);
  assert.deepEqual(cancelled.tickets.map((t) => t.number), ["0002", "0003"]);
  assert.equal(board.remainingCount, 1);
  assert.equal(board.totalCount, 3);
});

test("TB-T15 ボードに載っているパスだけ true を返す", () => {
  const known = ticket("0004", "todo");
  const board = buildBoard(scan({ todo: [known], done: [ticket("0001", "done")] }));
  assert.equal(isKnownTicketPath(board, known.filePath), true);
  assert.equal(isKnownTicketPath(board, "/w/wip/10_tickets/done/0001-x.md"), true);
});

test("TB-T15 載っていないパス・空文字・上位を含むパスで false を返す", () => {
  const board = buildBoard(scan({ todo: [ticket("0004", "todo")] }));
  assert.equal(isKnownTicketPath(board, "/etc/passwd"), false);
  assert.equal(isKnownTicketPath(board, ""), false);
  assert.equal(isKnownTicketPath(board, "/w/wip/10_tickets/todo/../../../etc/passwd"), false);
  assert.equal(isKnownTicketPath(board, "/w/wip/10_tickets/todo/0004-x.md "), false);
  assert.equal(isKnownTicketPath(board, "/w/wip/10_tickets/todo/0099-x.md"), false);
});
