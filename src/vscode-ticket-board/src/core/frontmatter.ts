/**
 * チケットの frontmatter を、提供コマンド ticket.sh が書き出し提供ライブラリ
 * frontmatter.sh が読み取る 5 形式の範囲だけ解釈する。
 * 仕様: docs/10_spec/vscode-ticket-board.md「処理フロー / frontmatter の解析」
 * 設計の経緯: docs/20_ddr/i0013-03-frontmatterを自前のサブセットパーサで読む.md
 */

const DELIMITER = "---";
/** frontmatter のキーとして認める文字。ticket.sh が書き出す範囲に合わせる */
const KEY_LINE = /^([A-Za-z0-9_-]+)\s*:\s*(.*)$/;

export type FrontmatterEntry =
  | { readonly kind: "scalar"; readonly value: string }
  | { readonly kind: "list"; readonly items: readonly string[] };

export interface FrontmatterDocument {
  readonly entries: ReadonlyMap<string, FrontmatterEntry>;
}

/**
 * frontmatter ブロックを取り出して解釈する。
 * 1 行目が区切りでない・終端の区切りが無い・空のときは undefined を返し、例外は投げない。
 */
export function parseFrontmatter(text: string): FrontmatterDocument | undefined {
  const lines = text.split(/\r?\n/);
  if (lines[0] !== DELIMITER) {
    return undefined;
  }
  const end = lines.indexOf(DELIMITER, 1);
  if (end < 0) {
    return undefined;
  }

  const entries = new Map<string, FrontmatterEntry>();
  // 直前に現れた「値を持たないトップレベルのキー」。入れ子マッピングの親
  let parentKey: string | undefined;

  for (const raw of lines.slice(1, end)) {
    const line = raw.replace(/\s+$/, "");
    if (line.trim() === "") {
      continue;
    }
    const indented = /^\s/.test(line);
    const matched = KEY_LINE.exec(line.trim());

    if (!indented) {
      parentKey = undefined;
      if (!matched) {
        continue;
      }
      const [, key, rawValue] = matched;
      if (rawValue === "") {
        // 入れ子マッピングの親。子はインデントのある行で読む
        parentKey = key;
        continue;
      }
      if (isInlineMap(rawValue)) {
        readInlineMap(key, rawValue, entries);
        continue;
      }
      const entry = toEntry(rawValue);
      if (entry) {
        entries.set(key, entry);
      }
      continue;
    }

    // インデントのある行。親が確定しているときだけ子として読む
    if (parentKey === undefined) {
      continue;
    }
    const child = line.trim();
    if (child.startsWith("-")) {
      // ブロック配列は解釈の対象外。キーを登録せず読み飛ばす
      continue;
    }
    const childMatched = KEY_LINE.exec(child);
    if (!childMatched) {
      continue;
    }
    const [, childKey, childValue] = childMatched;
    if (childValue === "") {
      continue;
    }
    const entry = toEntry(childValue);
    if (entry) {
      entries.set(`${parentKey}.${childKey}`, entry);
    }
  }

  return { entries };
}

function isInlineMap(value: string): boolean {
  return value.startsWith("{") && value.endsWith("}");
}

/** インラインマップ {k: v, k2: "v2"} を <親>.<子> のキーで登録する。子の値は常にスカラー */
function readInlineMap(
  parent: string,
  rawValue: string,
  entries: Map<string, FrontmatterEntry>,
): void {
  const inner = rawValue.slice(1, -1);
  for (const item of splitOutsideQuotes(inner, ",")) {
    const separator = indexOfOutsideQuotes(item, ":");
    if (separator < 0) {
      continue;
    }
    const key = item.slice(0, separator).trim();
    if (!/^[A-Za-z0-9_-]+$/.test(key)) {
      continue;
    }
    const value = unquote(item.slice(separator + 1).trim());
    if (value === undefined) {
      continue;
    }
    entries.set(`${parent}.${key}`, { kind: "scalar", value });
  }
}

/** 値の形（フロー配列 / スカラー）から entry を作る。解釈できない値は undefined */
function toEntry(rawValue: string): FrontmatterEntry | undefined {
  if (rawValue.startsWith("[") && rawValue.endsWith("]")) {
    const inner = rawValue.slice(1, -1).trim();
    if (inner === "") {
      return { kind: "list", items: [] };
    }
    const items: string[] = [];
    for (const item of splitOutsideQuotes(inner, ",")) {
      const value = unquote(item.trim());
      if (value === undefined) {
        return undefined;
      }
      items.push(value);
    }
    return { kind: "list", items };
  }
  if (rawValue.startsWith("{")) {
    // 親のキーで登録する形なので、ここには来ない値。解釈しない
    return undefined;
  }
  const value = unquote(rawValue);
  return value === undefined ? undefined : { kind: "scalar", value };
}

/**
 * 引用符を外す。二重引用符の中では \" と \\ を元に戻す。
 * 引用符で始まるのに閉じていない値は undefined を返す（呼び出し元は登録しない）。
 */
function unquote(raw: string): string | undefined {
  const value = raw.trim();
  if (value.startsWith('"')) {
    if (!endsWithUnescapedQuote(value)) {
      return undefined;
    }
    return unescapeDoubleQuoted(value.slice(1, -1));
  }
  if (value.startsWith("'")) {
    if (value.length < 2 || !value.endsWith("'")) {
      return undefined;
    }
    return value.slice(1, -1);
  }
  return value;
}

function endsWithUnescapedQuote(value: string): boolean {
  if (value.length < 2 || !value.endsWith('"')) {
    return false;
  }
  // 末尾の引用符の直前に続くバックスラッシュが偶数個なら、その引用符はエスケープされていない
  let backslashes = 0;
  for (let i = value.length - 2; i >= 0 && value[i] === "\\"; i--) {
    backslashes += 1;
  }
  return backslashes % 2 === 0;
}

function unescapeDoubleQuoted(inner: string): string {
  let out = "";
  for (let i = 0; i < inner.length; i++) {
    const char = inner[i];
    if (char === "\\" && i + 1 < inner.length) {
      const next = inner[i + 1];
      if (next === '"' || next === "\\") {
        out += next;
        i += 1;
        continue;
      }
    }
    out += char;
  }
  return out;
}

/** 引用符の外に現れる区切り文字だけで分割する */
function splitOutsideQuotes(text: string, separator: string): string[] {
  const parts: string[] = [];
  let current = "";
  let quote: string | undefined;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (quote) {
      current += char;
      if (quote === '"' && char === "\\" && i + 1 < text.length) {
        current += text[i + 1];
        i += 1;
        continue;
      }
      if (char === quote) {
        quote = undefined;
      }
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
      current += char;
      continue;
    }
    if (char === separator) {
      parts.push(current);
      current = "";
      continue;
    }
    current += char;
  }
  parts.push(current);
  return parts;
}

/** 引用符の外に現れる最初の区切り文字の位置。無ければ -1 */
function indexOfOutsideQuotes(text: string, separator: string): number {
  let quote: string | undefined;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (quote) {
      if (quote === '"' && char === "\\") {
        i += 1;
        continue;
      }
      if (char === quote) {
        quote = undefined;
      }
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
      continue;
    }
    if (char === separator) {
      return i;
    }
  }
  return -1;
}
