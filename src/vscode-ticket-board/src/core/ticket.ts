/**
 * チケット Markdown 1 枚を内部表現に変換する。
 * 不備は見つけるたびに issues へ足し、途中で処理を止めない（要件の例外フロー）。
 * 仕様: docs/10_spec/vscode-ticket-board.md「データの形 / 処理フロー（チケットの解析）」
 */
import { parseFrontmatter, type FrontmatterDocument } from "./frontmatter.js";

export type TicketState = "todo" | "doing" | "done" | "cancelled";

export type TicketIssueCode =
  | "TB001" | "TB002" | "TB003" | "TB004" | "TB005" | "TB006" | "TB007";

export interface TicketIssue {
  readonly code: TicketIssueCode;
  readonly detail: string;
}

export interface Ticket {
  readonly filePath: string;
  readonly fileName: string;
  readonly state: TicketState;
  readonly number: string;
  readonly title: string;
  readonly ticketType?: string;
  readonly executor?: string;
  readonly humanReview?: boolean;
  readonly adversarialReview?: boolean;
  readonly issues: readonly TicketIssue[];
}

/**
 * 既知のチケットの種類。.claude/hooks/config/task-types.tsv の 2 列目に対応する。
 * 実行時に読まず定数として持つ理由は DDR i0013-04。
 */
export const KNOWN_TICKET_TYPES = [
  "overall-plan",
  "investigation-plan",
  "investigation",
  "design-plan",
  "design",
  "implementation-plan",
  "implementation",
  "feedback-plan",
  "design-feedback-plan",
  "design-feedback",
  "ai-asset-design-plan",
  "ai-asset-design",
  "ai-asset-implementation-plan",
  "ai-asset-implementation",
  "overall-summary",
] as const;

/** 必須の項目。欠けていれば TB002 */
const REQUIRED_KEYS = [
  "ticket_type",
  "executor",
  "human_review.required",
  "adversarial_review.required",
] as const;

/** 本文の見出し `# <4 桁番号> <タイトル>` */
const HEADING = /^#[ \t]+(\S+)[ \t]+(.+)$/m;

export function parseTicket(
  filePath: string,
  fileName: string,
  state: TicketState,
  text: string,
): Ticket {
  const issues: TicketIssue[] = [];
  // 呼び出し元が 4 桁で始まるファイル名だけを渡す。番号はファイル名を正とする
  const numberFromFileName = fileName.slice(0, 4);

  const document = parseFrontmatter(text);
  if (!document) {
    issues.push({ code: "TB001", detail: "frontmatter を読み取れない" });
  }

  const ticketType = document ? readScalar(document, "ticket_type") : undefined;
  const executor = document ? readScalar(document, "executor") : undefined;
  const humanReview = document
    ? readBoolean(document, "human_review.required", issues)
    : undefined;
  const adversarialReview = document
    ? readBoolean(document, "adversarial_review.required", issues)
    : undefined;

  if (document) {
    for (const key of REQUIRED_KEYS) {
      if (!document.entries.has(key)) {
        issues.push({ code: "TB002", detail: `${key} が読み取れない` });
      }
    }
  }

  if (ticketType !== undefined && !isKnownTicketType(ticketType)) {
    issues.push({ code: "TB004", detail: `未知のチケットの種類（${ticketType}）` });
  }

  const heading = HEADING.exec(text);
  let title: string;
  if (!heading) {
    issues.push({ code: "TB005", detail: "見出しが読み取れない。ファイル名を表示している" });
    title = fileName;
  } else {
    const [, numberInHeading, headingTitle] = heading;
    if (numberInHeading !== numberFromFileName) {
      issues.push({
        code: "TB006",
        detail: `番号が食い違う（ファイル名 ${numberFromFileName} / 見出し ${numberInHeading}）`,
      });
    }
    title = headingTitle.trim();
  }

  return {
    filePath,
    fileName,
    state,
    number: numberFromFileName,
    title,
    ticketType,
    executor,
    humanReview,
    adversarialReview,
    issues,
  };
}

/** ファイルを読み取れなかったときのチケット。走査を止めないための代替表現 */
export function unreadableTicket(
  filePath: string,
  fileName: string,
  state: TicketState,
): Ticket {
  return {
    filePath,
    fileName,
    state,
    number: fileName.slice(0, 4),
    title: fileName,
    issues: [{ code: "TB007", detail: "ファイルを読み取れない" }],
  };
}

export function isKnownTicketType(value: string): boolean {
  return (KNOWN_TICKET_TYPES as readonly string[]).includes(value);
}

function readScalar(document: FrontmatterDocument, key: string): string | undefined {
  const entry = document.entries.get(key);
  return entry?.kind === "scalar" ? entry.value : undefined;
}

/** true / false のいずれかなら真偽値にする。それ以外の値があれば TB003 */
function readBoolean(
  document: FrontmatterDocument,
  key: string,
  issues: TicketIssue[],
): boolean | undefined {
  const value = readScalar(document, key);
  if (value === undefined) {
    return undefined;
  }
  if (value === "true") {
    return true;
  }
  if (value === "false") {
    return false;
  }
  issues.push({ code: "TB003", detail: `${key} が true/false でない（${value}）` });
  return undefined;
}
