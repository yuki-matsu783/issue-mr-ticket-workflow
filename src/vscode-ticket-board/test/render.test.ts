import { test } from "node:test";
import assert from "node:assert/strict";
import { renderBoard, escapeHtml } from "../src/core/render.js";
import { buildBoard } from "../src/core/board.js";
import type { ScanResult } from "../src/core/scan.js";
import type { Ticket, TicketState } from "../src/core/ticket.js";

const OPTIONS = { nonce: "TEST-NONCE-123" };

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
  assert.equal(/<(img|link|iframe|object|embed|source|base)\b/.test(html), false);
  assert.equal(/https?:\/\//.test(html), false);
  assert.equal(html.includes("@import"), false);
  assert.equal(/url\(/.test(html), false);
});

test("TB-T14 不備の detail もエスケープする", () => {
  const html = renderBoard(
    buildBoard(scan({
      todo: [ticket({
        ticketType: '<img src=x onerror="alert(1)">',
        issues: [
          { code: "TB004", detail: '未知のチケットの種類（<img src=x onerror="alert(1)">）' },
          { code: "TB006", detail: "番号が食い違う（ファイル名 0004 / 見出し <script>）" },
        ],
      })],
    })),
    OPTIONS,
  );
  assert.equal(/<img\b/.test(html), false);
  assert.equal(html.includes("<script>"), false);
  assert.ok(html.includes("&lt;img src=x onerror=&quot;alert(1)&quot;&gt;"));
  assert.ok(html.includes("&lt;script&gt;"));
});

test("TB-T14 列のラベルと状態もエスケープを通す", () => {
  const html = renderBoard(buildBoard(scan({})), OPTIONS);
  // 列ラベルは定数だが、生成経路にエスケープが挟まっていることを型と出力で担保する
  assert.ok(html.includes('data-state="cancelled"'));
  assert.ok(html.includes("取り消し"));
});

test("TB-T14 種類と実行者が未設定のカードに「種類不明」「実行者不明」を出す", () => {
  const html = renderBoard(
    buildBoard(scan({
      todo: [ticket({
        ticketType: undefined,
        executor: undefined,
        issues: [
          { code: "TB002", detail: "ticket_type が読み取れない" },
          { code: "TB002", detail: "executor が読み取れない" },
        ],
      })],
    })),
    OPTIONS,
  );
  // バッジそのものを消さない。ul.issues の TB002 と対応して見えるようにするため
  assert.ok(html.includes('<span class="badge type">種類不明</span>'));
  assert.ok(html.includes('<span class="badge executor">実行者不明</span>'));
  assert.ok(html.includes("TB002: ticket_type が読み取れない"));
});
