/**
 * CookieJar — port of Go CookieJar from client.go.
 * Host-scoped cookie storage with Set-Cookie parsing and serialization.
 */

export interface SerializedCookie {
  name: string;
  value: string;
}

export class CookieJar {
  private _store: Map<string, Map<string, string>> = new Map();

  /**
   * Parse Set-Cookie header values and store them for the given host.
   * Format: "name=value; Path=/; ..." — takes only name=value.
   */
  setCookies(host: string, setCookieHeaders: string[]): void {
    if (!this._store.has(host)) {
      this._store.set(host, new Map());
    }
    const hostCookies = this._store.get(host)!;

    for (const raw of setCookieHeaders) {
      const parts = raw.split(";", 2);
      const nv = parts[0].trim();
      const idx = nv.indexOf("=");
      if (idx < 0) continue;

      const name = nv.slice(0, idx).trim();
      const val = nv.slice(idx + 1).trim();

      if (val === "" || val === "delete" || val === "null") {
        hostCookies.delete(name);
        continue;
      }
      hostCookies.set(name, val);
    }
  }

  /** Inject pre-known cookies (from a serialized session) for a host. */
  seedCookies(host: string, cookies: Record<string, string>): void {
    if (!this._store.has(host)) {
      this._store.set(host, new Map());
    }
    const hostCookies = this._store.get(host)!;
    for (const [name, val] of Object.entries(cookies)) {
      if (val) hostCookies.set(name, val);
    }
  }

  /** Returns a "name1=val1; name2=val2" string for the host. */
  cookieHeader(host: string): string {
    const hostCookies = this._store.get(host);
    if (!hostCookies || hostCookies.size === 0) return "";
    const parts: string[] = [];
    for (const [name, val] of hostCookies) {
      parts.push(`${name}=${val}`);
    }
    return parts.join("; ");
  }

  /** Returns all cookies for a host as a map (for serialization). */
  cookies(host: string): Map<string, string> {
    const hostCookies = this._store.get(host);
    if (!hostCookies) return new Map();
    return new Map(hostCookies);
  }

  /** Returns serialized cookie array for JSON transport. */
  serialize(host: string): SerializedCookie[] {
    const hostCookies = this._store.get(host);
    if (!hostCookies) return [];
    const out: SerializedCookie[] = [];
    for (const [name, value] of hostCookies) {
      out.push({ name, value });
    }
    return out;
  }

  /** Checks if a named cookie exists for the host. */
  hasCookie(host: string, name: string): boolean {
    return this._store.get(host)?.has(name) ?? false;
  }

  /** Returns a single cookie value, or "". */
  getCookie(host: string, name: string): string {
    return this._store.get(host)?.get(name) ?? "";
  }
}
