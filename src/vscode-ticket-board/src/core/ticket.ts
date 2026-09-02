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
const HEADING = /^#[ \t]+(\S+)[ \t]+(.+)$/;
/** コードフェンスの開始・終了（``` または ~~~ が 3 つ以上） */
const FENCE = /^(`{3,}|~{3,})/;

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

  // 必須の 4 項目はまず生のスカラーとして取り、欠落（TB002）を真偽値の検査（TB003）より先に積む
  const rawValues = new Map<string, string | undefined>();
  for (const key of REQUIRED_KEYS) {
    rawValues.set(key, document ? readScalar(document, key) : undefined);
  }

  if (document) {
    for (const key of REQUIRED_KEYS) {
      if (rawValues.get(key) !== undefined) {
        continue;
      }
      // キーはあるが scalar でない（フロー配列・入れ子マッピング）場合も欠落として扱う
      const detail = document.entries.has(key)
        ? `${key} が読み取れない（scalar でない）`
        : `${key} が読み取れない`;
      issues.push({ code: "TB002", detail });
    }
  }

  const ticketType = rawValues.get("ticket_type");
  const executor = rawValues.get("executor");
  const humanReview = toBoolean(
    "human_review.required", rawValues.get("human_review.required"), issues,
  );
  const adversarialReview = toBoolean(
    "adversarial_review.required", rawValues.get("adversarial_review.required"), issues,
  );

  if (ticketType !== undefined && !isKnownTicketType(ticketType)) {
    issues.push({ code: "TB004", detail: `未知のチケットの種類（${ticketType}）` });
  }

  // 見出しは本文からだけ探す。frontmatter の YAML コメントやコードフェンスの中の
  // `#` 行をタイトルに採らないため（仕様「処理フロー / チケットの解析」手順 5）
  const heading = findHeading(document ? document.body : text);
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

/**
 * 本文の最初の見出しを返す。コードフェンスに囲まれた行は本文の見出しとして扱わない。
 */
function findHeading(body: string): RegExpExecArray | undefined {
  let inFence = false;
  for (const line of body.split(/\r?\n/)) {
    if (FENCE.test(line.trim())) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      continue;
    }
    const matched = HEADING.exec(line);
    if (matched) {
      return matched;
    }
  }
  return undefined;
}

function readScalar(document: FrontmatterDocument, key: string): string | undefined {
  const entry = document.entries.get(key);
  return entry?.kind === "scalar" ? entry.value : undefined;
}

/** true / false のいずれかなら真偽値にする。それ以外の値があれば TB003 */
function toBoolean(
  key: string,
  value: string | undefined,
  issues: TicketIssue[],
): boolean | undefined {
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
