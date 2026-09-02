import { test } from "node:test";
import assert from "node:assert/strict";
import { parseTicket, KNOWN_TICKET_TYPES } from "../src/core/ticket.js";

const HEAD = [
  "---",
  "type: ticket",
  "ticket_type: investigation",
  'predecessors: ["0002"]',
  "executor: main",
  'human_review: {required: true, reason: "理由"}',
  'adversarial_review: {required: false, reason: "基準どおり"}',
  "allow:",
  '  write: ["wip/**"]',
  '  ops: ["read"]',
  'started_at: ""',
  'completed_at: ""',
  'base_sha: ""',
  "---",
];
const body = (heading: string) => [...HEAD, "", heading, "", "## 目的", "", "調べる"].join("\n");
const NORMAL = body("# 0004 ビルド環境の調査");

test("TB-T06 正常なチケットから 6 項目を取り出し issues が空になる", () => {
  const t = parseTicket("/w/wip/10_tickets/00_todo/0004-investigation.md",
    "0004-investigation.md", "todo", NORMAL);
  assert.equal(t.number, "0004");
  assert.equal(t.title, "ビルド環境の調査");
  assert.equal(t.state, "todo");
  assert.equal(t.ticketType, "investigation");
  assert.equal(t.executor, "main");
  assert.equal(t.humanReview, true);
  assert.equal(t.adversarialReview, false);
  assert.deepEqual(t.issues, []);
});

test("TB-T07 frontmatter が無いとき TB001 を付け、他の処理を続ける", () => {
  const t = parseTicket("/w/x/0009-design.md", "0009-design.md", "doing",
    "# 0009 見出しだけ\n\n本文");
  assert.deepEqual(t.issues.map((i) => i.code), ["TB001"]);
  assert.equal(t.title, "見出しだけ");   // 本文の読み取りは続く
  assert.equal(t.number, "0009");
  assert.equal(t.ticketType, undefined);
});

test("TB-T08 必須キーの欠落で TB002 を付ける", () => {
  const withoutExecutor = body("# 0004 題").replace("executor: main\n", "");
  const t = parseTicket("/w/x/0004-investigation.md", "0004-investigation.md", "todo",
    withoutExecutor);
  const codes = t.issues.map((i) => i.code);
  assert.ok(codes.includes("TB002"));
  assert.ok(t.issues.some((i: { code: string; detail: string }) => i.code === "TB002" && i.detail.includes("executor")));
  assert.equal(t.ticketType, "investigation");   // 他の項目は取れている
});

test("TB-T08 真偽値でない値で TB003 を付ける", () => {
  const broken = body("# 0004 題").replace("{required: true,", "{required: yes,");
  const t = parseTicket("/w/x/0004-investigation.md", "0004-investigation.md", "todo", broken);
  const issue = t.issues.find((i) => i.code === "TB003");
  assert.ok(issue);
  assert.ok(issue.detail.includes("human_review.required"));
  assert.ok(issue.detail.includes("yes"));
  assert.equal(t.humanReview, undefined);
});

test("TB-T09 未知の ticket_type で TB004 を付け、値はそのまま保持する", () => {
  const unknown = body("# 0004 題").replace("ticket_type: investigation", "ticket_type: mystery");
  const t = parseTicket("/w/x/0004-mystery.md", "0004-mystery.md", "todo", unknown);
  const issue = t.issues.find((i) => i.code === "TB004");
  assert.ok(issue);
  assert.ok(issue.detail.includes("mystery"));
  assert.equal(t.ticketType, "mystery");
});

test("TB-T09 既知の種類は 15 種で、すべて TB004 にならない", () => {
  assert.equal(KNOWN_TICKET_TYPES.length, 15);
  for (const type of KNOWN_TICKET_TYPES) {
    const text = body("# 0004 題").replace("ticket_type: investigation", `ticket_type: ${type}`);
    const t = parseTicket("/w/x/0004-x.md", "0004-x.md", "todo", text);
    assert.equal(t.issues.some((i: { code: string; detail: string }) => i.code === "TB004"), false, type);
  }
});

test("TB-T10 見出しが無いとき TB005 を付けてファイル名をタイトルにする", () => {
  const noHeading = [...HEAD, "", "## 目的", "", "調べる"].join("\n");
  const t = parseTicket("/w/x/0004-investigation.md", "0004-investigation.md", "todo", noHeading);
  assert.ok(t.issues.some((i: { code: string; detail: string }) => i.code === "TB005"));
  assert.equal(t.title, "0004-investigation.md");
});

test("TB-T10 番号の食い違いで TB006 を付け、ファイル名の番号を採る", () => {
  const t = parseTicket("/w/x/0004-investigation.md", "0004-investigation.md", "todo",
    body("# 0007 ずれた番号"));
  const issue = t.issues.find((i) => i.code === "TB006");
  assert.ok(issue);
  assert.ok(issue.detail.includes("0004"));
  assert.ok(issue.detail.includes("0007"));
  assert.equal(t.number, "0004");
  assert.equal(t.title, "ずれた番号");
});
