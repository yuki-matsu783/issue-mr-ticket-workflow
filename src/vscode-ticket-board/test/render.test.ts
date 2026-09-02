import { test } from "node:test";
import assert from "node:assert/strict";
import { renderBoard, escapeHtml } from "../src/core/render.js";
import { buildBoard } from "../src/core/board.js";
import type { ScanResult } from "../src/core/scan.js";
import type { Ticket, TicketState } from "../src/core/ticket.js";

const OPTIONS = { nonce: "TEST-NONCE-123", cspSource: "vscode-resource://x" };

function ticket(overrides: Partial<Ticket> = {}): Ticket {
  return {
    filePath: "/w/wip/10_tickets/00_todo/0004-investigation.md",
    fileName: "0004-investigation.md",
    state: "todo",
    number: "0004",
    title: "ビルド環境の調査",
    ticketType: "investigation",
    executor: "main",
    humanReview: true,
    adversarialReview: false,
    issues: [],
    ...overrides,
  };
}

function scan(tickets: Partial<Record<TicketState, readonly Ticket[]>>): ScanResult {
  const map = new Map<TicketState, readonly Ticket[]>();
  for (const state of ["todo", "doing", "done", "cancelled"] as const) {
    map.set(state, tickets[state] ?? []);
  }
  return { found: true, ticketsByState: map };
}

test("TB-T14 4 列と件数を出す", () => {
  const html = renderBoard(buildBoard(scan({ todo: [ticket()], doing: [ticket()] })), OPTIONS);
  for (const label of ["未着手", "作業中", "完了", "取り消し"]) {
    assert.ok(html.includes(label), label);
  }
  assert.equal((html.match(/class="column"/g) ?? []).length, 4);
  assert.ok(html.includes("残り 2 件"));
  assert.ok(html.includes("全 2 件"));
});

test("TB-T14 0 件のとき空の表示を出す", () => {
  const html = renderBoard(buildBoard(scan({})), OPTIONS);
  assert.ok(html.includes("チケットが 1 枚もありません"));
  assert.equal((html.match(/class="empty"/g) ?? []).length, 4);
  assert.equal((html.match(/class="card/g) ?? []).length, 0);
});

test("TB-T14 カードに 6 項目を出す", () => {
  const html = renderBoard(buildBoard(scan({ todo: [ticket()] })), OPTIONS);
  assert.ok(html.includes("0004"));
  assert.ok(html.includes("ビルド環境の調査"));
  assert.ok(html.includes("investigation"));
  assert.ok(html.includes("main"));
  assert.ok(html.includes("人 要"));
  assert.ok(html.includes("敵 不要"));
});

test("TB-T14 読み取れなかったレビュー要否は不明と出す", () => {
  const html = renderBoard(
    buildBoard(scan({ todo: [ticket({ humanReview: undefined, adversarialReview: undefined })] })),
    OPTIONS,
  );
  assert.ok(html.includes("人 不明"));
  assert.ok(html.includes("敵 不明"));
});

test("TB-T14 不備のあるカードに識別子を出す", () => {
  const html = renderBoard(
    buildBoard(scan({
      todo: [ticket({ issues: [{ code: "TB002", detail: "executor が読み取れない" }] })],
    })),
    OPTIONS,
  );
  assert.ok(html.includes("has-issue"));
  assert.ok(html.includes("TB002: executor が読み取れない"));
  assert.ok(html.includes("不備 1 件"));
});

test("TB-T14 チケット由来の文字列をエスケープする", () => {
  const html = renderBoard(
    buildBoard(scan({
      todo: [ticket({
        title: `<script>alert("x")</script> & 'q'`,
        ticketType: "<b>",
        filePath: `/w/a"b.md`,
      })],
    })),
    OPTIONS,
  );
  assert.equal(html.includes("<script>alert"), false);
  assert.ok(html.includes("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; &#39;q&#39;"));
  assert.ok(html.includes("&lt;b&gt;"));
  assert.ok(html.includes('data-path="/w/a&quot;b.md"'));
});

test("TB-T14 escapeHtml が 5 文字を仕様どおりに変換する", () => {
  assert.equal(escapeHtml(`&<>"'`), "&amp;&lt;&gt;&quot;&#39;");
  assert.equal(escapeHtml("&amp;"), "&amp;amp;");   // & を最初に変換するので二重変換しない
  assert.equal(escapeHtml(""), "");
});

test("TB-T14 CSP の script-src と style-src に nonce が入り、外部を許さない", () => {
  const html = renderBoard(buildBoard(scan({ todo: [ticket()] })), OPTIONS);
  assert.ok(html.includes(`script-src 'nonce-TEST-NONCE-123'`));
  assert.ok(html.includes(`style-src 'nonce-TEST-NONCE-123'`));
  assert.ok(html.includes(`default-src 'none'`));
  assert.ok(html.includes(`base-uri 'none'`));
  assert.ok(html.includes(`form-action 'none'`));
  assert.ok(html.includes(`<script nonce="TEST-NONCE-123">`));
  assert.ok(html.includes(`<style nonce="TEST-NONCE-123">`));
  assert.ok(html.includes("acquireVsCodeApi()"));
  // 外部資源を読まない
  assert.equal(/<(img|link|iframe)\b/.test(html), false);
  assert.equal(html.includes("http://"), false);
});
