import { test } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { scanTickets, STATE_COLUMNS, TICKETS_DIR } from "../src/core/scan.js";
import type { TicketState } from "../src/core/ticket.js";

function ticketText(number: string, type: string, title: string): string {
  return [
    "---",
    "type: ticket",
    `ticket_type: ${type}`,
    "executor: main",
    'human_review: {required: true, reason: "理由"}',
    'adversarial_review: {required: false, reason: "基準どおり"}',
    "---",
    "",
    `# ${number} ${title}`,
  ].join("\n");
}

/** 使い捨てのワークスペースを作る。tickets が undefined の状態ディレクトリは作らない */
function makeWorkspace(
  tickets: Partial<Record<TicketState, readonly string[]>>,
  options: { readonly withTicketsDir?: boolean } = {},
): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "ticket-board-"));
  if (options.withTicketsDir === false) {
    return root;
  }
  fs.mkdirSync(path.join(root, TICKETS_DIR), { recursive: true });
  for (const column of STATE_COLUMNS) {
    const names: readonly string[] | undefined = tickets[column.state];
    if (names === undefined) {
      continue;
    }
    const dir = path.join(root, TICKETS_DIR, column.dir);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, ".gitkeep"), "");
    for (const name of names) {
      const number = name.slice(0, 4);
      fs.writeFileSync(path.join(dir, name), ticketText(number, "investigation", `題 ${number}`));
    }
  }
  return root;
}

test("TB-T11 wip/10_tickets が無いとき found: false を返す", () => {
  const root = makeWorkspace({}, { withTicketsDir: false });
  const result = scanTickets(root);
  assert.equal(result.found, false);
  assert.equal(result.ticketsByState.size, 0);
  fs.rmSync(root, { recursive: true, force: true });
});

test("TB-T11 4 桁で始まらないファイルと .gitkeep を除外する", () => {
  const root = makeWorkspace({ todo: ["0004-investigation.md"] });
  const dir = path.join(root, TICKETS_DIR, "00_todo");
  fs.writeFileSync(path.join(dir, "README.md"), "# 説明");
  fs.writeFileSync(path.join(dir, "notes.txt"), "x");
  fs.writeFileSync(path.join(dir, "012-short.md"), "x");
  const result = scanTickets(root);
  assert.equal(result.found, true);
  assert.deepEqual(result.ticketsByState.get("todo")?.map((t) => t.fileName),
    ["0004-investigation.md"]);
  fs.rmSync(root, { recursive: true, force: true });
});

test("TB-T12 状態ディレクトリが 1 つ欠けていても他の列を返す", () => {
  const root = makeWorkspace({ todo: ["0002-design.md"], done: ["0001-overall-plan.md"] });
  const result = scanTickets(root);
  assert.equal(result.found, true);
  assert.equal(result.ticketsByState.get("todo")?.length, 1);
  assert.equal(result.ticketsByState.get("done")?.length, 1);
  assert.deepEqual(result.ticketsByState.get("doing"), []);
  assert.deepEqual(result.ticketsByState.get("cancelled"), []);
  fs.rmSync(root, { recursive: true, force: true });
});

test("TB-T12 番号の昇順に並び、同番号はファイル名の辞書順になる", () => {
  const root = makeWorkspace({
    todo: ["0010-implementation.md", "0002-design.md", "0002-copy.md", "0009-design-plan.md"],
  });
  const result = scanTickets(root);
  assert.deepEqual(result.ticketsByState.get("todo")?.map((t) => t.fileName), [
    "0002-copy.md",
    "0002-design.md",
    "0009-design-plan.md",
    "0010-implementation.md",
  ]);
  fs.rmSync(root, { recursive: true, force: true });
});

test("TB-T12 読み取れないファイルに TB007 を付けて走査を続ける", () => {
  const root = makeWorkspace({ todo: ["0004-investigation.md"] });
  const dir = path.join(root, TICKETS_DIR, "00_todo");
  // ディレクトリはチケット名に一致するが readFileSync が失敗する
  fs.mkdirSync(path.join(dir, "0005-broken.md"));
  const result = scanTickets(root);
  const tickets = result.ticketsByState.get("todo") ?? [];
  assert.equal(tickets.length, 2);
  const broken = tickets.find((t: { fileName: string }) => t.fileName === "0005-broken.md");
  assert.ok(broken);
  assert.deepEqual(broken.issues.map((i) => i.code), ["TB007"]);
  assert.equal(broken.title, "0005-broken.md");
  assert.deepEqual(
    tickets.find((t: { fileName: string }) => t.fileName === "0004-investigation.md")?.issues, []);
  fs.rmSync(root, { recursive: true, force: true });
});

test("TB-T16 別の状態ディレクトリへ移した後の再走査で列が入れ替わる", () => {
  const root = makeWorkspace({ todo: ["0004-investigation.md"], doing: [] });
  const before = scanTickets(root);
  assert.equal(before.ticketsByState.get("todo")?.length, 1);
  assert.equal(before.ticketsByState.get("doing")?.length, 0);

  fs.renameSync(
    path.join(root, TICKETS_DIR, "00_todo", "0004-investigation.md"),
    path.join(root, TICKETS_DIR, "10_doing", "0004-investigation.md"),
  );

  const after = scanTickets(root);
  assert.equal(after.ticketsByState.get("todo")?.length, 0);
  assert.deepEqual(after.ticketsByState.get("doing")?.map((t) => t.fileName),
    ["0004-investigation.md"]);
  fs.rmSync(root, { recursive: true, force: true });
});
