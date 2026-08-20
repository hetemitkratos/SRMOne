/**
 * Academia data-page parsers — port of Go loginprobe/parsers.go.
 * Parses decoded HTML fragments for attendance, student info, marks,
 * personal timetable, unified timetable slot map, and academic calendar.
 * Uses deno-dom (via dom.ts) instead of goquery.
 */

import { parseHTML, type Document, type Element } from "./dom.ts";

// ─── Types ───────────────────────────────────────────────────────────────────

export interface AttendanceRecord {
  courseCode: string;
  courseTitle: string;
  category: string;
  facultyName: string;
  slot: string;
  roomNo: string;
  hoursConducted: string;
  hoursAbsent: string;
  attendancePct: string;
}

export interface MarkTest {
  testName: string;
  maxScore: string;
  score: string;
}

export interface MarkRecord {
  courseCode: string;
  courseType: string;
  tests: MarkTest[];
}

export interface Advisor {
  name: string;
  role: string;
  email: string;
  phone: string;
}

export interface ScheduleEntry {
  day: string;
  hourIndex: number;
  timing: string;
  slotToken: string;
}

export interface TimetableCourse {
  courseCode: string;
  courseTitle: string;
  credit: string;
  category: string;
  courseType: string;
  facultyName: string;
  slot: string;
  roomNo: string;
  schedule: ScheduleEntry[];
}

export interface TimetableResult {
  batch: string;
  courses: TimetableCourse[];
  advisors: Advisor[];
}

export interface CalendarDay {
  date: string;
  day: string;
  event: string;
  dayOrder: string;
}

export interface CalendarMonth {
  name: string;
  days: CalendarDay[];
}

export interface CalendarResult {
  sem: string;
  title: string;
  months: CalendarMonth[];
}

export interface FetchData {
  studentInfo: Record<string, string>;
  attendance: AttendanceRecord[];
  marks: MarkRecord[];
  timetable: TimetableResult | null;
  calendars: Record<string, CalendarResult>;
  errors: Record<string, string>;
}

// ─── HTML helpers (port of extractCellText, walkNodeText, etc.) ──────────────

const BLOCK_TAGS = new Set([
  "div", "p", "section", "article", "header", "footer", "li", "tr", "table",
]);
const LINE_BREAK_TAGS = new Set(["br", "hr"]);

function walkNodeText(node: Node, b: string[]): void {
  if (!node) return;
  if (node.nodeType === Node.TEXT_NODE) {
    b.push(node.textContent ?? "");
    return;
  }
  if (node.nodeType === Node.ELEMENT_NODE) {
    const el = node as Element;
    const tag = el.tagName.toLowerCase();
    if (LINE_BREAK_TAGS.has(tag) && (b.length === 0 || !b[b.length - 1].endsWith("\n"))) {
      b.push("\n");
    }
  }
  for (let child = node.firstChild; child; child = child.nextSibling) {
    walkNodeText(child, b);
  }
  if (node.nodeType === Node.ELEMENT_NODE) {
    const el = node as Element;
    const tag = el.tagName.toLowerCase();
    if (BLOCK_TAGS.has(tag) && (b.length === 0 || !b[b.length - 1].endsWith("\n"))) {
      b.push("\n");
    }
  }
}

export function extractCellText(cell: Element): string {
  const parts: string[] = [];
  for (let child = cell.firstChild; child; child = child.nextSibling) {
    walkNodeText(child, parts);
  }
  let text = parts.join("");
  const lines = text.split("\n");
  for (let i = 0; i < lines.length; i++) {
    lines[i] = lines[i].replace(/\s+/g, " ").trim();
  }
  text = lines.join("\n").trim();
  while (text.includes("\n\n")) {
    text = text.replace(/\n\n/g, "\n");
  }
  return text;
}

function extractCells(row: Element): string[] {
  const cells: string[] = [];
  row.querySelectorAll("th, td").forEach((cell) => {
    cells.push(extractCellText(cell));
  });
  return cells;
}

function extractHeaders(table: Element): string[] {
  const firstRow = table.querySelector("tr");
  if (!firstRow) return [];
  return extractCells(firstRow);
}

function extractTableMatrix(table: Element): string[][] {
  const rows: string[][] = [];
  table.querySelectorAll("tr").forEach((row) => {
    rows.push(extractCells(row));
  });
  return rows;
}

function extractDirectRows(table: Element): Element[] {
  const rows: Element[] = [];
  let containers = table.querySelectorAll(":scope > tbody");
  if (containers.length === 0) {
    containers = [table];
  }
  containers.forEach((container) => {
    container.querySelectorAll(":scope > tr").forEach((row) => {
      rows.push(row);
    });
  });
  return rows;
}

function extractDirectCells(row: Element): Element[] {
  const cells: Element[] = [];
  row.querySelectorAll(":scope > th, :scope > td").forEach((cell) => {
    cells.push(cell);
  });
  return cells;
}

function containsString(values: string[], want: string): boolean {
  return values.some((v) => v.trim() === want);
}

function valueAt(items: string[], index: number): string {
  if (index < 0 || index >= items.length) return "";
  return items[index];
}

function splitNonEmpty(raw: string, separator: RegExp): string[] {
  return raw
    .split(separator)
    .map((s) => s.trim())
    .filter((s) => s !== "");
}

function splitSlotTokens(raw: string): string[] {
  return raw
    .split(/\s*\/\s*|\n+/)
    .map((s) => s.trim())
    .filter((s) => s !== "");
}

function splitCourseSlotTokens(raw: string): string[] {
  return raw
    .split("-")
    .map((s) => s.trim())
    .filter((s) => s !== "");
}

function parseDayNumber(day: string): number {
  const match = day.match(/(\d+)/);
  if (!match) return 999;
  return parseInt(match[1], 10);
}

// ─── JS string / sanitize payload decoders ───────────────────────────────────

function hexNibble(ch: string): number {
  const code = ch.charCodeAt(0);
  if (code >= 48 && code <= 57) return code - 48;
  if (code >= 97 && code <= 102) return code - 97 + 10;
  if (code >= 65 && code <= 70) return code - 65 + 10;
  return 0;
}

export function decodeJSString(s: string): string {
  let result = "";
  for (let i = 0; i < s.length; i++) {
    if (s[i] !== "\\") {
      result += s[i];
      continue;
    }
    i++;
    if (i >= s.length) throw new Error("unterminated escape");
    switch (s[i]) {
      case "x": {
        if (i + 2 >= s.length) throw new Error("short hex escape");
        const hex = s.slice(i + 1, i + 3);
        result += String.fromCharCode(
          hexNibble(hex[0]) * 16 + hexNibble(hex[1]),
        );
        i += 2;
        break;
      }
      case "u": {
        if (i + 4 >= s.length) throw new Error("short unicode escape");
        const hex = s.slice(i + 1, i + 5);
        let code = 0;
        for (let j = 0; j < 4; j++) {
          code = code * 16 + hexNibble(hex[j]);
        }
        result += String.fromCharCode(code);
        i += 4;
        break;
      }
      case "n": result += "\n"; break;
      case "r": result += "\r"; break;
      case "t": result += "\t"; break;
      case "b": result += "\b"; break;
      case "f": result += "\f"; break;
      case "\\": result += "\\"; break;
      case "'": result += "'"; break;
      case '"': result += '"'; break;
      case "/": result += "/"; break;
      default: result += s[i];
    }
  }
  return result;
}

export function extractSanitizePayload(raw: string): string {
  const marker = "pageSanitizer.sanitize('";
  const start = raw.indexOf(marker);
  if (start < 0) throw new Error("pageSanitizer payload marker not found");
  let i = start + marker.length;
  let result = "";
  while (i < raw.length) {
    const ch = raw[i];
    if (ch === "\\") {
      if (i + 1 >= raw.length) {
        throw new Error("unterminated escape sequence in sanitize payload");
      }
      result += raw[i] + raw[i + 1];
      i += 2;
      continue;
    }
    if (ch === "'") return result;
    result += ch;
    i++;
  }
  throw new Error("unterminated sanitize payload");
}

export function decodeSanitizedHTML(raw: string): { decoded: string; payload: string } {
  const payload = extractSanitizePayload(raw);
  const decoded = decodeJSString(payload);
  return { decoded, payload };
}

export function decodeZMLValueHTML(raw: string): { decoded: string; payload: string } {
  const doc = parseHTML(raw);
  const el = doc.querySelector("[zmlvalue]");
  if (!el) throw new Error("zmlvalue payload marker not found");
  const found = el.getAttribute("zmlvalue") ?? "";
  if (!found.trim()) throw new Error("zmlvalue payload marker not found");
  const decoded = decodeHTMLEntities(found);
  if (!decoded.toLowerCase().includes("<table")) {
    throw new Error("zmlvalue payload did not decode into table HTML");
  }
  return { decoded, payload: found };
}

function decodeHTMLEntities(s: string): string {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ");
}

export function looksLikeUnauthenticatedPage(pageUrl: string, body: string): boolean {
  const lowerUrl = pageUrl.toLowerCase();
  const lowerBody = body.toLowerCase();
  if (lowerUrl.includes("/accounts/") || lowerUrl.includes("signin")) return true;
  return (
    lowerBody.includes("sign in to continue") ||
    lowerBody.includes("zoho accounts") ||
    lowerBody.includes("academic web services login")
  );
}

export function extractHTMLTitle(html: string): string {
  try {
    const doc = parseHTML(html);
    const title = doc.querySelector("title");
    return title?.textContent?.trim() ?? "";
  } catch {
    return "";
  }
}

// ─── Fragment decoder (tries sanitized → zml → raw HTML) ─────────────────────

export interface DecodedFragment {
  html: string;
  statusCode: number;
  contentType: string;
  payloadFound: boolean;
  payloadLength: number;
}

export function decodeFragmentBody(body: string): { html: string; via: string } {
  try {
    const { decoded } = decodeSanitizedHTML(body);
    return { html: decoded, via: "sanitized" };
  } catch {
    // try zml
  }
  try {
    const { decoded } = decodeZMLValueHTML(body);
    return { html: decoded, via: "zml" };
  }
  catch {
    // try raw
  }
  const lower = body.toLowerCase();
  if (lower.includes("<table") || lower.includes("<html")) {
    return { html: body, via: "raw" };
  }
  throw new Error("could not decode fragment body");
}

// ─── Attendance parser ───────────────────────────────────────────────────────

export function parseAttendance(
  decodedHTML: string,
): { records: Record<string, string>[]; headers: string[] } {
  const doc = parseHTML(decodedHTML);
  let targetTable: Element | null = null;
  let headers: string[] = [];

  doc.querySelectorAll("table").forEach((table) => {
    if (targetTable) return;
    const rowHeaders = extractHeaders(table);
    if (rowHeaders.length < 2) return;
    if (containsString(rowHeaders, "Attn %")) {
      targetTable = table;
      headers = rowHeaders;
    }
  });

  if (!targetTable) throw new Error("attendance table not found in decoded HTML");

  const records: Record<string, string>[] = [];
  let rowIndex = 0;
  targetTable.querySelectorAll("tr").forEach((row) => {
    if (rowIndex === 0) {
      rowIndex++;
      return;
    }
    rowIndex++;
    const cells = extractCells(row);
    if (cells.length === 0 || cells[0].trim() === "") return;
    const record: Record<string, string> = {};
    for (let i = 0; i < headers.length; i++) {
      record[headers[i]] = i < cells.length ? cells[i] : "";
    }
    records.push(record);
  });

  if (records.length === 0) {
    throw new Error("attendance table parsed but contained no data rows");
  }
  return { records, headers };
}

export function mapAttendanceRows(
  rows: Record<string, string>[],
): AttendanceRecord[] {
  return rows.map((row) => {
    let courseCode = (row["Course Code"] ?? "").trim();
    const newlineIdx = courseCode.indexOf("\n");
    if (newlineIdx >= 0) courseCode = courseCode.slice(0, newlineIdx).trim();
    return {
      courseCode,
      courseTitle: (row["Course Title"] ?? "").trim(),
      category: (row["Category"] ?? "").trim(),
      facultyName: (row["Faculty Name"] ?? "").trim(),
      slot: (row["Slot"] ?? "").trim(),
      roomNo: (row["Room No"] ?? "").trim(),
      hoursConducted: (row["Hours Conducted"] ?? "").trim(),
      hoursAbsent: (row["Hours Absent"] ?? "").trim(),
      attendancePct: (row["Attn %"] ?? "").trim(),
    };
  });
}

// ─── Student info parser ─────────────────────────────────────────────────────

export function parseStudentInfoHTML(
  decodedHTML: string,
): Record<string, string> {
  const doc = parseHTML(decodedHTML);
  let targetTable: Element | null = null;

  doc.querySelectorAll("table").forEach((table) => {
    if (targetTable) return;
    const headers = extractHeaders(table);
    if (containsString(headers, "Registration Number:")) {
      targetTable = table;
    }
  });

  if (!targetTable) throw new Error("student info table not found");

  const info: Record<string, string> = {};
  targetTable.querySelectorAll("tr").forEach((row) => {
    const cells = extractCells(row);
    for (let i = 0; i < cells.length; i++) {
      let key = cells[i].trim();
      if (key === "" || key === ":") continue;
      key = key.replace(/:$/, "").trim();
      if (key === "") continue;

      let valueIndex = i + 1;
      while (valueIndex < cells.length && cells[valueIndex].trim() === "") {
        valueIndex++;
      }
      if (valueIndex < cells.length && cells[valueIndex].trim() === ":") {
        valueIndex++;
      }
      while (valueIndex < cells.length && cells[valueIndex].trim() === "") {
        valueIndex++;
      }
      if (valueIndex >= cells.length) continue;

      const value = cells[valueIndex].trim();
      if (value !== "" && value !== ":") {
        info[key] = value;
      }
    }
  });

  if (Object.keys(info).length === 0) {
    throw new Error("student info table parsed but contained no data");
  }
  return info;
}

// ─── Marks parser ────────────────────────────────────────────────────────────

export function parseMarksHTML(decodedHTML: string): MarkRecord[] {
  const doc = parseHTML(decodedHTML);
  let targetTable: Element | null = null;

  doc.querySelectorAll("table").forEach((table) => {
    if (targetTable) return;
    const headers = extractHeaders(table);
    if (containsString(headers, "Test Performance")) {
      targetTable = table;
    }
  });

  if (!targetTable) throw new Error("marks table not found");

  const result: MarkRecord[] = [];
  const rows = extractDirectRows(targetTable);
  for (let index = 0; index < rows.length; index++) {
    if (index === 0) continue;
    const cells = extractDirectCells(rows[index]);
    if (cells.length < 2 || extractCellText(cells[0]).trim() === "") continue;

    const record: MarkRecord = {
      courseCode: extractCellText(cells[0]).trim(),
      courseType: extractCellText(cells[1]).trim(),
      tests: [],
    };

    if (cells.length >= 3) {
      cells[2].querySelectorAll("td").forEach((inner) => {
        const test = parseMarkTestCell(inner);
        if (test.testName !== "" || test.score !== "" || test.maxScore !== "") {
          record.tests.push(test);
        }
      });
    }
    result.push(record);
  }

  if (result.length === 0) {
    throw new Error("marks table parsed but contained no data rows");
  }
  return result;
}

function parseMarkTestCell(cell: Element): MarkTest {
  const lines = splitNonEmpty(extractCellText(cell), /[\n\t]+/);
  if (lines.length === 0) return { testName: "", maxScore: "", score: "" };

  const spec = lines[0].trim();
  const score = lines.length > 1 ? lines.slice(1).join(" ").trim() : "";

  const test: MarkTest = { testName: spec, maxScore: "", score };
  const slashIdx = spec.lastIndexOf("/");
  if (slashIdx >= 0) {
    test.testName = spec.slice(0, slashIdx).trim();
    test.maxScore = spec.slice(slashIdx + 1).trim();
  }
  return test;
}

// ─── Personal timetable parser ───────────────────────────────────────────────

export function parsePersonalTimetableHTML(
  decodedHTML: string,
): { batch: string; courses: Record<string, string>[]; advisors: Advisor[] } {
  const doc = parseHTML(decodedHTML);

  let batch = "1";
  try {
    const info = parseStudentInfoHTML(decodedHTML);
    if (info["Batch"]?.trim()) batch = info["Batch"].trim();
  } catch {
    // student info not available — default batch
  }

  let advisorTable: Element | null = null;
  let courseTable: Element | null = null;

  doc.querySelectorAll("table").forEach((table) => {
    const headers = extractHeaders(table);
    if (!advisorTable && containsString(headers, "Counselor")) {
      advisorTable = table;
    }
    if (!courseTable && containsString(headers, "Course Code") && containsString(headers, "Slot")) {
      courseTable = table;
    }
  });

  const advisors: Advisor[] = [];
  if (advisorTable) {
    const firstRow = advisorTable.querySelector("tr");
    if (firstRow) {
      const cells = extractCells(firstRow);
      for (let i = 2; i < cells.length; i++) {
        const lines = splitNonEmpty(cells[i], /\n+/);
        if (lines.length === 0) continue;
        advisors.push({
          name: valueAt(lines, 0),
          role: valueAt(lines, 1),
          email: valueAt(lines, 2),
          phone: valueAt(lines, 3),
        });
      }
    }
  }

  if (!courseTable) {
    return { batch, courses: [], advisors };
  }

  const headers = extractHeaders(courseTable);
  const courses: Record<string, string>[] = [];
  let rowIndex = 0;
  courseTable.querySelectorAll("tr").forEach((row) => {
    if (rowIndex === 0) {
      rowIndex++;
      return;
    }
    rowIndex++;
    const cells = extractCells(row);
    if (cells.length < 2 || cells[1].trim() === "") return;
    const record: Record<string, string> = {};
    for (let i = 0; i < headers.length; i++) {
      record[headers[i]] = i < cells.length ? cells[i].trim() : "";
    }
    courses.push(record);
  });

  if (courses.length === 0) {
    throw new Error("personal timetable parsed but contained no courses");
  }
  return { batch, courses, advisors };
}

// ─── Unified timetable (batch slot map) parser ───────────────────────────────

export function parseBatchSlotMapHTML(
  decodedHTML: string,
): Record<string, ScheduleEntry[]> {
  const doc = parseHTML(decodedHTML);
  let targetTable: Element | null = null;

  doc.querySelectorAll("table").forEach((table) => {
    if (targetTable) return;
    const rows = extractTableMatrix(table);
    if (rows.length > 0 && rows[0].length > 0 && rows[0][0].trim() === "FROM") {
      targetTable = table;
    }
  });

  if (!targetTable) throw new Error("unified timetable grid not found");

  const rows = extractTableMatrix(targetTable);
  if (rows.length === 0 || rows[0].length < 2) {
    throw new Error("unified timetable grid was empty");
  }

  const timings = rows[0].slice(1);
  const slotMap: Record<string, ScheduleEntry[]> = {};

  for (let r = 1; r < rows.length; r++) {
    const row = rows[r];
    if (row.length === 0) continue;
    const day = row[0].trim();
    if (!day.startsWith("Day")) continue;

    for (let col = 1; col < row.length && col - 1 < timings.length; col++) {
      const cellText = row[col].trim();
      if (cellText === "") continue;
      const timing = timings[col - 1].trim();
      const tokens = splitSlotTokens(cellText);
      for (const token of tokens) {
        if (!slotMap[token]) slotMap[token] = [];
        slotMap[token].push({
          day,
          hourIndex: col,
          timing,
          slotToken: token,
        });
      }
    }
  }

  if (Object.keys(slotMap).length === 0) {
    throw new Error("unified timetable grid parsed but contained no slot mappings");
  }
  return slotMap;
}

// ─── Merge timetable courses ─────────────────────────────────────────────────

export function mergeTimetableCourses(
  rawCourses: Record<string, string>[],
  slotMap: Record<string, ScheduleEntry[]>,
): TimetableCourse[] {
  return rawCourses.map((course) => {
    const rawSlot = (course["Slot"] ?? "").trim();
    const schedule: ScheduleEntry[] = [];
    for (const token of splitCourseSlotTokens(rawSlot)) {
      const entries = slotMap[token] ?? [];
      for (const entry of entries) {
        schedule.push({
          day: entry.day,
          hourIndex: entry.hourIndex,
          timing: entry.timing,
          slotToken: token,
        });
      }
    }
    schedule.sort((a, b) => {
      const dayA = parseDayNumber(a.day);
      const dayB = parseDayNumber(b.day);
      if (dayA !== dayB) return dayA - dayB;
      return a.hourIndex - b.hourIndex;
    });

    return {
      courseCode: (course["Course Code"] ?? "").trim(),
      courseTitle: (course["Course Title"] ?? "").trim(),
      credit: (course["Credit"] ?? "").trim(),
      category: (course["Category"] ?? "").trim(),
      courseType: (course["Course Type"] ?? "").trim(),
      facultyName: (course["Faculty Name"] ?? "").trim(),
      slot: rawSlot,
      roomNo: (course["Room No."] ?? "").trim(),
      schedule,
    };
  });
}

// ─── Academic calendar parser ────────────────────────────────────────────────

const MONTH_RE =
  /^(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)\b/i;

export function parseAcademicCalendarHTML(
  decodedHTML: string,
  sem: string,
): CalendarResult {
  const doc = parseHTML(decodedHTML);

  let bestScore = 0;
  let bestHeaderRow = 0;
  let bestTable: string[][] = [];

  doc.querySelectorAll("table").forEach((table) => {
    const rows = extractTableMatrix(table);
    for (let rowIndex = 0; rowIndex < rows.length && rowIndex < 5; rowIndex++) {
      let hits = 0;
      for (const cell of rows[rowIndex]) {
        if (MONTH_RE.test(cell.trim())) hits++;
      }
      if (hits > bestScore) {
        bestScore = hits;
        bestHeaderRow = rowIndex;
        bestTable = rows;
      }
    }
    if (bestScore === 0 && rows.length > bestTable.length) {
      bestTable = rows;
      bestHeaderRow = 0;
    }
  });

  if (bestTable.length === 0) throw new Error("calendar table not found");

  const headerCells = bestTable[bestHeaderRow];

  interface MonthGroup {
    name: string;
    dtCol: number;
    dayCol: number;
    eventCol: number;
    doCol: number;
  }

  const monthGroups: MonthGroup[] = [];
  for (let i = 0; i < headerCells.length; i++) {
    if (MONTH_RE.test(headerCells[i].trim()) && i >= 2) {
      monthGroups.push({
        name: headerCells[i].trim(),
        dtCol: i - 2,
        dayCol: i - 1,
        eventCol: i,
        doCol: i + 1,
      });
    }
  }

  if (monthGroups.length === 0 && headerCells.length >= 4) {
    for (let i = 0; i + 3 < headerCells.length; i += 5) {
      let name = `Month${monthGroups.length + 1}`;
      for (const cell of headerCells.slice(i, Math.min(i + 5, headerCells.length))) {
        if (MONTH_RE.test(cell.trim())) {
          name = cell.trim();
          break;
        }
      }
      monthGroups.push({
        name,
        dtCol: i,
        dayCol: i + 1,
        eventCol: i + 2,
        doCol: i + 3,
      });
    }
  }

  const months: CalendarMonth[] = [];
  for (const group of monthGroups) {
    const days: CalendarDay[] = [];
    for (let rowIndex = bestHeaderRow + 1; rowIndex < bestTable.length; rowIndex++) {
      const row = bestTable[rowIndex];
      const date = valueAt(row, group.dtCol);
      if (date.trim() === "") continue;
      days.push({
        date: date.trim(),
        day: valueAt(row, group.dayCol).trim(),
        event: valueAt(row, group.eventCol).trim(),
        dayOrder: valueAt(row, group.doCol).trim(),
      });
    }
    months.push({ name: group.name.trim(), days });
  }

  let title = "";
  for (const selector of ["h1", "h2", "h3", ".page-title", '[class*="title"]']) {
    let found = false;
    doc.querySelectorAll(selector).forEach((el) => {
      if (found) return;
      const text = extractCellText(el).trim();
      if (text.length > 3 && text.length < 200) {
        title = text;
        found = true;
      }
    });
    if (title) break;
  }

  if (months.length === 0) {
    throw new Error("calendar parsed but contained no month groups");
  }
  return { sem, title, months };
}

// ─── Student photo helpers ───────────────────────────────────────────────────

export function extractStudentPhotoSource(decodedHTML: string): string {
  try {
    const doc = parseHTML(decodedHTML);
    const img = doc.querySelector(
      'img[src*="Photo_Upload_Student_Report"], img[src*="Your_Photo/image/"]',
    );
    if (img) {
      const src = (img.getAttribute("src") ?? "").trim();
      if (src) return src;
    }
    // Fallback: scan td cells for img tags
    const tds = doc.querySelectorAll("td");
    for (const td of tds) {
      const innerImg = td.querySelector("img");
      if (innerImg) {
        const src = (innerImg.getAttribute("src") ?? "").trim();
        if (src && (src.includes("Photo_Upload") || src.includes("Your_Photo"))) {
          return src;
        }
      }
    }
  } catch {
    // ignore
  }
  return "";
}

export function extractStudentPhotoDownloadURL(decodedHTML: string): string {
  try {
    const doc = parseHTML(decodedHTML);
    const link = doc.querySelector(
      'a[href*="download-file?filepath="][href*="Photo_Upload"]',
    );
    if (link) {
      const href = (link.getAttribute("href") ?? "").trim();
      if (href) return href;
    }
  } catch {
    // ignore
  }
  return "";
}

export function guessImageContentType(url: string): string {
  const lower = url.toLowerCase();
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".gif")) return "image/gif";
  if (lower.endsWith(".webp")) return "image/webp";
  if (lower.endsWith(".bmp")) return "image/bmp";
  if (lower.endsWith(".svg")) return "image/svg+xml";
  return "image/jpeg";
}
