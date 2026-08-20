/**
 * DOM parsing helper — re-exports deno-dom for HTML parsing.
 * Replaces goquery from the Go scrapers.
 */

export { DOMParser, type Document, type Element, type Node } from "jsr:@b-fuze/deno-dom@0.1";

/**
 * Parse an HTML string into a Document.
 */
export function parseHTML(html: string): Document {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) throw new Error("Failed to parse HTML");
  return doc;
}
