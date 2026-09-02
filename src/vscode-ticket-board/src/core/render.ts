/**
 * ボードを外部資源に依存しない 1 枚の HTML に組み立てる。
 * 仕様: docs/10_spec/vscode-ticket-board.md「HTML の構造と CSP」
 */
import type { Board, BoardColumn } from "./board.js";
import type { Ticket } from "./ticket.js";

export interface RenderOptions {
  readonly nonce: string;
}

/** レビュー要否のバッジ。値が読み取れなかったときは「不明」 */
const REVIEW_LABELS = { true: "要", false: "不要", unknown: "不明" } as const;

export function renderBoard(board: Board, options: RenderOptions): string {
  const { nonce } = options;
  return `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; base-uri 'none'; form-action 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>チケットボード</title>
<style nonce="${nonce}">
${STYLE}
</style>
</head>
<body>
<header class="summary">
  <span class="remaining">残り ${board.remainingCount} 件</span>
  <span class="total">全 ${board.totalCount} 件</span>
  <span class="issues">不備 ${board.issueCount} 件</span>
</header>
${board.totalCount === 0 ? '<p class="board-empty">チケットが 1 枚もありません</p>\n' : ""}<div class="board">
${board.columns.map(renderColumn).join("\n")}
</div>
<script nonce="${nonce}">
${SCRIPT}
</script>
</body>
</html>
`;
}

function renderColumn(column: BoardColumn): string {
  const body =
    column.count === 0
      ? '    <p class="empty">チケットはありません</p>'
      : `    <ul class="cards">\n${column.tickets.map(renderCard).join("\n")}\n    </ul>`;
  return `  <section class="column" data-state="${escapeHtml(column.state)}">
    <h2>${escapeHtml(column.label)} <span class="count">${column.count}</span></h2>
${body}
  </section>`;
}

function renderCard(ticket: Ticket): string {
  const hasIssue = ticket.issues.length > 0;
  const issues = hasIssue
    ? `\n        <ul class="issues">\n${ticket.issues
        .map((issue) => `          <li>${escapeHtml(`${issue.code}: ${issue.detail}`)}</li>`)
        .join("\n")}\n        </ul>`
    : "";
  return `      <li class="card${hasIssue ? " has-issue" : ""}" data-path="${escapeHtml(
    ticket.filePath,
  )}" tabindex="0">
        <div class="card-head"><span class="num">${escapeHtml(
          ticket.number,
        )}</span><span class="title">${escapeHtml(ticket.title)}</span></div>
        <div class="badges">
          <span class="badge type">${escapeHtml(ticket.ticketType ?? "種類不明")}</span>
          <span class="badge executor">${escapeHtml(ticket.executor ?? "実行者不明")}</span>
          <span class="badge review-human">人 ${reviewLabel(ticket.humanReview)}</span>
          <span class="badge review-adv">敵 ${reviewLabel(ticket.adversarialReview)}</span>
        </div>${issues}
      </li>`;
}

function reviewLabel(value: boolean | undefined): string {
  if (value === undefined) {
    return REVIEW_LABELS.unknown;
  }
  return value ? REVIEW_LABELS.true : REVIEW_LABELS.false;
}

/** HTML の特殊文字を実体参照にする。& を最初に変換して二重変換を避ける */
export function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** 色は VS Code のテーマ変数だけを使い、独自の固定色を持たない */
const STYLE = `  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 12px;
    background: var(--vscode-editor-background);
    color: var(--vscode-editor-foreground);
    font-family: var(--vscode-font-family);
    font-size: var(--vscode-font-size);
  }
  .summary { display: flex; gap: 16px; padding: 0 4px 12px; font-weight: 600; }
  .summary .issues { color: var(--vscode-editorWarning-foreground); }
  .board-empty { padding: 4px; color: var(--vscode-descriptionForeground); }
  .board { display: flex; gap: 12px; align-items: flex-start; overflow-x: auto; }
  .column {
    flex: 0 0 260px; min-width: 260px;
    border: 1px solid var(--vscode-panel-border); border-radius: 6px; padding: 8px;
  }
  .column h2 { margin: 0 0 8px; font-size: 1em; display: flex; justify-content: space-between; }
  .column .count { color: var(--vscode-descriptionForeground); }
  .empty { margin: 0; color: var(--vscode-descriptionForeground); font-size: .92em; }
  .cards { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; }
  .card {
    border: 1px solid var(--vscode-panel-border); border-radius: 5px; padding: 8px;
    background: var(--vscode-editorWidget-background); cursor: pointer;
  }
  .card:hover, .card:focus {
    outline: 1px solid var(--vscode-focusBorder);
    background: var(--vscode-list-hoverBackground);
  }
  .card.has-issue { border-left: 3px solid var(--vscode-editorWarning-foreground); }
  .card-head { display: flex; gap: 6px; align-items: baseline; }
  .num { color: var(--vscode-descriptionForeground); font-variant-numeric: tabular-nums; }
  .title { overflow-wrap: anywhere; }
  .badges { display: flex; flex-wrap: wrap; gap: 4px; margin-top: 6px; }
  .badge {
    font-size: .82em; padding: 0 6px; border-radius: 999px;
    border: 1px solid var(--vscode-panel-border);
    color: var(--vscode-descriptionForeground);
  }
  .issues {
    list-style: none; margin: 6px 0 0; padding: 0;
    font-size: .82em; color: var(--vscode-editorWarning-foreground);
  }
  .issues li { overflow-wrap: anywhere; }`;

const SCRIPT = `  const vscode = acquireVsCodeApi();
  function open(card) {
    const filePath = card.getAttribute("data-path");
    if (filePath) { vscode.postMessage({ type: "open", filePath: filePath }); }
  }
  for (const card of document.querySelectorAll(".card")) {
    card.addEventListener("click", () => open(card));
    card.addEventListener("keydown", (event) => {
      if (event.key === "Enter") { event.preventDefault(); open(card); }
    });
  }`;
