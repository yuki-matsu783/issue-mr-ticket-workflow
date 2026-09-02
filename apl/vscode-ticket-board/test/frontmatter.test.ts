import { test } from "node:test";
import assert from "node:assert/strict";
import { parseFrontmatter } from "../src/core/frontmatter.js";

/** 仕様「データの形」の 5 形式をすべて含む frontmatter */
const FULL = [
  "---",
  "type: ticket",
  "ticket_type: investigation",
  'predecessors: ["0002", "0003"]',
  "executor: main",
  'human_review: {required: true, reason: "理由 A"}',
  "adversarial_review: {required: false, reason: \"引用符 \\\" を含む\"}",
  "allow:",
  '  write: ["wip/**"]',
  '  ops: ["read", "build-test"]',
  'started_at: "2026-09-02T05:00:00+00:00"',
  'completed_at: ""',
  "---",
  "",
  "# 0004 見出し",
].join("\n");

test("TB-T01 5 形式をすべて解釈できる", () => {
  const doc = parseFrontmatter(FULL);
  assert.ok(doc);
  // フラットなスカラー
  assert.deepEqual(doc.entries.get("ticket_type"), { kind: "scalar", value: "investigation" });
  // クォート付きスカラー
  assert.deepEqual(doc.entries.get("started_at"), {
    kind: "scalar",
    value: "2026-09-02T05:00:00+00:00",
  });
  assert.deepEqual(doc.entries.get("completed_at"), { kind: "scalar", value: "" });
  // フロー配列
  assert.deepEqual(doc.entries.get("predecessors"), { kind: "list", items: ["0002", "0003"] });
  // インラインマップ（子は常に scalar）
  assert.deepEqual(doc.entries.get("human_review.required"), { kind: "scalar", value: "true" });
  assert.deepEqual(doc.entries.get("human_review.reason"), { kind: "scalar", value: "理由 A" });
  // 入れ子マッピング（子の値にも手順 4 の分岐を適用するので list になる）
  assert.deepEqual(doc.entries.get("allow.write"), { kind: "list", items: ["wip/**"] });
  assert.deepEqual(doc.entries.get("allow.ops"), { kind: "list", items: ["read", "build-test"] });
});

test("TB-T02 frontmatter が無い / 終端が無い / 空で undefined を返す", () => {
  assert.equal(parseFrontmatter("# 見出しだけ\n\n本文\n"), undefined);
  assert.equal(parseFrontmatter("---\nticket_type: investigation\n"), undefined);
  assert.equal(parseFrontmatter(""), undefined);
  assert.equal(parseFrontmatter("\n---\na: b\n---\n"), undefined);
});

test("TB-T03 二重引用符が閉じていない値はキーごと登録しない", () => {
  const doc = parseFrontmatter(
    ['---', 'ticket_type: investigation', 'title: "閉じ忘れ', 'executor: main', '---'].join("\n"),
  );
  assert.ok(doc);
  assert.equal(doc.entries.has("title"), false);
  assert.deepEqual(doc.entries.get("ticket_type"), { kind: "scalar", value: "investigation" });
  assert.deepEqual(doc.entries.get("executor"), { kind: "scalar", value: "main" });
});

test("TB-T03 インラインマップの中に閉じていない値があってもそのキーだけ落ちる", () => {
  const doc = parseFrontmatter(
    ['---', 'human_review: {required: true, reason: "閉じ忘れ}', 'executor: main', '---'].join("\n"),
  );
  assert.ok(doc);
  assert.deepEqual(doc.entries.get("human_review.required"), { kind: "scalar", value: "true" });
  assert.equal(doc.entries.has("human_review.reason"), false);
  assert.deepEqual(doc.entries.get("executor"), { kind: "scalar", value: "main" });
});

test("TB-T04 ブロック配列は登録せず、他のキーの解釈を壊さない", () => {
  const doc = parseFrontmatter(
    ["---", "ticket_type: investigation", "allow:", '  write:', '    - "wip/**"',
     '  ops: ["read"]', "executor: main", "---"].join("\n"),
  );
  assert.ok(doc);
  assert.equal(doc.entries.has("allow.write"), false);
  assert.deepEqual(doc.entries.get("allow.ops"), { kind: "list", items: ["read"] });
  assert.deepEqual(doc.entries.get("executor"), { kind: "scalar", value: "main" });
});

test("TB-T04 空のフロー配列は要素 0 個で登録する", () => {
  const doc = parseFrontmatter(["---", "predecessors: []", "---"].join("\n"));
  assert.ok(doc);
  assert.deepEqual(doc.entries.get("predecessors"), { kind: "list", items: [] });
});

test("TB-T05 CRLF でも解釈でき、エスケープを戻す", () => {
  const doc = parseFrontmatter(FULL.replace(/\n/g, "\r\n"));
  assert.ok(doc);
  assert.deepEqual(doc.entries.get("ticket_type"), { kind: "scalar", value: "investigation" });
  assert.deepEqual(doc.entries.get("adversarial_review.reason"), {
    kind: "scalar",
    value: '引用符 " を含む',
  });
});

test("TB-T05 バックスラッシュのエスケープを戻す", () => {
  const doc = parseFrontmatter(["---", 'reason: "a\\\\b"', "---"].join("\n"));
  assert.ok(doc);
  assert.deepEqual(doc.entries.get("reason"), { kind: "scalar", value: "a\\b" });
});

test("TB-T02 BOM 付きでも frontmatter を読み取れる", () => {
  const doc = parseFrontmatter(`﻿${FULL}`);
  assert.ok(doc);
  assert.deepEqual(doc.entries.get("ticket_type"), { kind: "scalar", value: "investigation" });
});

test("TB-T02 区切り行の末尾に空白があっても読み取れる", () => {
  const doc = parseFrontmatter(
    ["--- ", "ticket_type: investigation", "---\t", "", "# 0004 見出し"].join("\n"),
  );
  assert.ok(doc);
  assert.deepEqual(doc.entries.get("ticket_type"), { kind: "scalar", value: "investigation" });
  assert.equal(doc.body.trim(), "# 0004 見出し");
});

test("TB-T04 2 段字下げの孫は親の値を上書きしない", () => {
  const doc = parseFrontmatter(
    ["---", "human_review:", "  required: true", "  meta:", "    required: false",
     "executor: main", "---"].join("\n"),
  );
  assert.ok(doc);
  assert.deepEqual(doc.entries.get("human_review.required"), { kind: "scalar", value: "true" });
  assert.equal(doc.entries.has("human_review.meta"), false);
  assert.deepEqual(doc.entries.get("executor"), { kind: "scalar", value: "main" });
});

test("TB-T01 body は終端の区切りより後ろだけを返す", () => {
  const doc = parseFrontmatter(
    ["---", "# 0999 これは YAML コメント", "executor: main", "---", "", "# 0004 本物の見出し"].join("\n"),
  );
  assert.ok(doc);
  assert.equal(doc.body.includes("YAML コメント"), false);
  assert.ok(doc.body.includes("# 0004 本物の見出し"));
});
