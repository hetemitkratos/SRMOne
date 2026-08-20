/**
 * HTTP client wrapper — port of Go FHClient.DoRequest.
 * Uses Deno fetch with redirect: "manual" to capture cookies and
 * follow redirects manually (matching Go behavior).
 */

import { CookieJar } from "./cookies.ts";

export interface RequestSnapshot {
  name: string;
  method: string;
  url: string;
  statusCode: number;
  location: string;
  body: string;
  headers: Record<string, string>;
}

export interface HttpClientOptions {
  userAgent: string;
  host: string;
  csrfParam?: string;
  csrfCookie?: string;
  defaultReferer?: string;
}

function isRedirect(status: number): boolean {
  return status >= 301 && status <= 308;
}

function shouldSwitchToGet(status: number, method: string): boolean {
  if (method === "GET" || method === "HEAD") return false;
  return status === 301 || status === 302 || status === 303;
}

function resolveURL(base: string, location: string): string {
  try {
    return new URL(location, base).href;
  } catch {
    return location;
  }
}

function getHostname(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return "";
  }
}

export class HttpClient {
  jar: CookieJar;
  private userAgent: string;
  private host: string;
  csrfParam: string;
  csrfCookie: string;
  defaultReferer: string;

  constructor(opts: HttpClientOptions) {
    this.jar = new CookieJar();
    this.userAgent = opts.userAgent;
    this.host = opts.host;
    this.csrfParam = opts.csrfParam ?? "";
    this.csrfCookie = opts.csrfCookie ?? "";
    this.defaultReferer = opts.defaultReferer ?? "";
  }

  csrfHeaderValue(): string {
    const val = this.jar.getCookie(this.host, this.csrfCookie);
    if (!val) return "";
    return `${this.csrfParam}=${val}`;
  }

  async doRequest(
    name: string,
    method: string,
    rawUrl: string,
    body: BodyInit | null,
    contentType: string,
    extraHeaders: Record<string, string>,
    followRedirects: boolean,
  ): Promise<RequestSnapshot> {
    let currentURL = rawUrl;
    let currentMethod = method;
    let currentBody = body;
    let currentContentType = contentType;

    for (let redirects = 0; redirects < 10; redirects++) {
      const hostname = getHostname(currentURL);

      const headers: Record<string, string> = {
        "User-Agent": this.userAgent,
        "Accept": "*/*",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive",
      };

      if (this.defaultReferer) {
        headers["Referer"] = this.defaultReferer;
      }
      if (currentContentType) {
        headers["Content-Type"] = currentContentType;
      }

      const cookieStr = this.jar.cookieHeader(hostname);
      if (cookieStr) {
        headers["Cookie"] = cookieStr;
      }

      if (this.csrfParam) {
        const csrfToken = this.csrfHeaderValue();
        if (csrfToken) {
          headers["X-ZCSRF-TOKEN"] = csrfToken;
        }
      }

      for (const [key, val] of Object.entries(extraHeaders)) {
        headers[key] = val;
      }

      const resp = await fetch(currentURL, {
        method: currentMethod,
        headers,
        body: currentMethod === "GET" || currentMethod === "HEAD"
          ? undefined
          : currentBody,
        redirect: "manual",
      });

      // Collect Set-Cookie headers
      const setCookies: string[] = [];
      resp.headers.forEach((value, key) => {
        if (key.toLowerCase() === "set-cookie") {
          setCookies.push(value);
        }
      });
      if (setCookies.length > 0) {
        this.jar.setCookies(hostname, setCookies);
      }

      const statusCode = resp.status;
      const location = resp.headers.get("location") ?? "";
      const respBody = await resp.text();

      const respHeaders: Record<string, string> = {};
      resp.headers.forEach((value, key) => {
        respHeaders[key] = value;
      });

      const snap: RequestSnapshot = {
        name,
        method: currentMethod,
        url: currentURL,
        statusCode,
        location,
        body: respBody,
        headers: respHeaders,
      };

      if (followRedirects && isRedirect(statusCode) && location) {
        const nextURL = resolveURL(currentURL, location);
        if (shouldSwitchToGet(statusCode, currentMethod)) {
          currentMethod = "GET";
          currentBody = null;
          currentContentType = "";
        }
        currentURL = nextURL;
        continue;
      }

      return snap;
    }

    throw new Error(`too many redirects for ${rawUrl}`);
  }
}
