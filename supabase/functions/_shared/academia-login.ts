/**
 * Academia login flow — port of Go loginprobe/login.go + parsers.go.
 * Implements: signin page fetch → locate → lookup → password → post-login navigation.
 * Uses HttpClient (fetch wrapper) and deno-dom for HTML parsing.
 */

import { HttpClient, type RequestSnapshot } from "./http.ts";
import { parseHTML } from "./dom.ts";
import {
  decodeFragmentBody,
  looksLikeUnauthenticatedPage,
  guessImageContentType,
  type DecodedFragment,
} from "./academia-parsers.ts";

// ─── Constants ───────────────────────────────────────────────────────────────

const BASE_URL = "https://academia.srmist.edu.in";
const PORTAL_ID = "40-10002227248";
const SIGNIN_PATH = `/accounts/p/${PORTAL_ID}/signin`;
const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";

const CLASS_AUTHENTICATED = "authenticated_session_established";
const CLASS_INVALID_CREDS = "invalid_credentials";
const CLASS_CAPTCHA = "captcha_or_antibot_challenge";
const CLASS_JS_DEPENDENT = "js_dependent_flow_or_waf_block";
const CLASS_SESSIONS = "session_reminder_or_active_sessions";
const CLASS_DAILY_LIMIT = "daily_signin_warning";
const CLASS_UNKNOWN = "unknown_intermediate_page";

// ─── Types ───────────────────────────────────────────────────────────────────

export interface AcademiaLoginResult {
  success: boolean;
  classification: string;
  cookies: { name: string; value: string }[];
  hasJSessionId: boolean;
  finalUrl: string;
  error?: string;
}

interface SigninPageInfo {
  finalUrl: string;
  uriPathPrefix: string;
  serviceUrl: string;
  csrfParam: string;
  csrfCookieName: string;
  emailOnlySignin: boolean;
}

interface LookupResult {
  identifier: string;
  digest: string;
  code: string;
  errorCode: string;
  localizedMessage: string;
}

interface PasswordResult {
  redirectUri: string;
  code: string;
  errorCode: string;
  localizedMessage: string;
}

// ─── Helper functions ────────────────────────────────────────────────────────

function firstRegexGroup(raw: string, pattern: string): string {
  try {
    const re = new RegExp(pattern);
    const match = raw.match(re);
    return match && match.length >= 2 ? match[1] : "";
  } catch {
    return "";
  }
}

function unescapeJSLiteral(value: string): string {
  return value
    .replace(/\\\//g, "/")
    .replace(/\\'/g, "'")
    .replace(/\\"/g, '"');
}

function extractJSQuotedValue(raw: string, name: string): string {
  const patterns = [
    `var ${name}\\s*=\\s*"([^"]*)"`,
    `var ${name}\\s*=\\s*'([^']*)'`,
  ];
  for (const pattern of patterns) {
    const value = firstRegexGroup(raw, pattern);
    if (value) return unescapeJSLiteral(value);
  }
  return "";
}

function extractJSBooleanValue(raw: string, name: string): boolean {
  const value = firstRegexGroup(
    raw,
    `var ${name}\\s*=\\s*Boolean\\("([^"]*)"\\)`,
  );
  return value.toLowerCase() === "true";
}

function extractServiceUrl(raw: string, fallbackUrl: string): string {
  const value = firstRegexGroup(raw, `serviceUrl\\s*=\\s*'([^']+)'`);
  if (value) return unescapeJSLiteral(value);
  try {
    const parsed = new URL(fallbackUrl);
    return parsed.searchParams.get("serviceurl") ?? "";
  } catch {
    return "";
  }
}

function parseSigninPage(
  rawHtml: string,
  finalUrl: string,
  fallbackServiceUrl: string,
): SigninPageInfo {
  const info: SigninPageInfo = {
    finalUrl,
    uriPathPrefix: extractJSQuotedValue(rawHtml, "uriPrefix"),
    serviceUrl: fallbackServiceUrl,
    csrfParam: extractJSQuotedValue(rawHtml, "csrfParam"),
    csrfCookieName: extractJSQuotedValue(rawHtml, "csrfCookieName"),
    emailOnlySignin: extractJSBooleanValue(rawHtml, "emailOnlySignin"),
  };

  if (!info.serviceUrl) {
    info.serviceUrl = extractServiceUrl(rawHtml, finalUrl);
  }

  return info;
}

function parseLookupResponse(body: string): LookupResult {
  try {
    const payload = JSON.parse(body) as Record<string, unknown>;
    const code = String(payload.code ?? "");
    const resourceName = String(payload.resource_name ?? "");
    const localizedMessage = String(payload.localized_message ?? "");

    const errors = payload.errors as Array<Record<string, unknown>> | undefined;
    const errorCode = errors && errors.length > 0
      ? String(errors[0].code ?? "")
      : "";

    const resource = (payload[resourceName] ?? payload.lookup ?? {}) as Record<
      string,
      unknown
    >;
    const identifier = String(resource.identifier ?? "");
    const digest = String(resource.digest ?? "");

    return { identifier, digest, code, errorCode, localizedMessage };
  } catch {
    return {
      identifier: "",
      digest: "",
      code: "",
      errorCode: "",
      localizedMessage: "",
    };
  }
}

function parsePasswordResponse(body: string, location: string): PasswordResult {
  try {
    const payload = JSON.parse(body) as Record<string, unknown>;
    const code = String(payload.code ?? "");
    const resourceName = String(payload.resource_name ?? "");
    const localizedMessage = String(payload.localized_message ?? "");

    const errors = payload.errors as Array<Record<string, unknown>> | undefined;
    const errorCode = errors && errors.length > 0
      ? String(errors[0].code ?? "")
      : "";

    const resource = (payload[resourceName] ?? {}) as Record<
      string,
      unknown
    >;
    const redirectUri = String(resource.redirect_uri ?? "");

    return {
      redirectUri: redirectUri || location,
      code,
      errorCode,
      localizedMessage,
    };
  } catch {
    return {
      redirectUri: location,
      code: "",
      errorCode: "",
      localizedMessage: "",
    };
  }
}

function classifyFromMessage(message: string, errorCode: string): string {
  const lower = message.toLowerCase();
  if (
    lower.includes("incorrect password") ||
    lower.includes("invalid password") ||
    lower.includes("verify your email address") ||
    errorCode === "U401"
  ) {
    return CLASS_INVALID_CREDS;
  }
  if (lower.includes("captcha") || errorCode === "IN107" || errorCode === "IN108") {
    return CLASS_CAPTCHA;
  }
  if (
    lower.includes("throttle") ||
    lower.includes("too many") ||
    lower.includes("temporarily blocked")
  ) {
    return CLASS_JS_DEPENDENT;
  }
  return CLASS_UNKNOWN;
}

function classifyPage(pageUrl: string, body: string): string {
  const lowerUrl = pageUrl.toLowerCase();
  const lowerBody = body.toLowerCase();

  if (
    lowerUrl.includes("sessions-reminder") ||
    lowerUrl.includes("block-sessions") ||
    lowerUrl.includes("preannouncement/block-sessions") ||
    lowerUrl.includes("preannouncement/continue") ||
    lowerUrl.includes("announcement/sessions-reminder") ||
    lowerUrl.includes("announcement/continue")
  ) {
    return CLASS_SESSIONS;
  }

  if (
    lowerBody.includes("daily sign-in limit") ||
    (lowerBody.includes("signed in") && lowerBody.includes("times today")) ||
    lowerBody.includes("you are nearing your daily sign-in limit") ||
    (lowerUrl.includes("signin-block") && lowerBody.includes("i understand"))
  ) {
    return CLASS_DAILY_LIMIT;
  }

  return CLASS_UNKNOWN;
}

function deriveSessionContinueUrl(currentUrl: string): string {
  try {
    const parsed = new URL(currentUrl);
    if (parsed.pathname.includes("/preannouncement/block-sessions")) {
      return parsed.origin + parsed.pathname.replace(/\/$/, "") + "/next";
    }
    const nextPath = parsed.pathname.replace(/\/$/, "") + "/next";
    const params = new URLSearchParams(parsed.searchParams);
    params.set("status", "2");
    return parsed.origin + nextPath + "?" + params.toString();
  } catch {
    return "";
  }
}

function derivePreannouncementDeleteUrl(currentUrl: string): string {
  try {
    const parsed = new URL(currentUrl);
    const idx = parsed.pathname.indexOf("/preannouncement/");
    if (idx < 0) return "";
    const basePath = parsed.pathname.slice(0, idx).replace(/\/$/, "");
    return parsed.origin + basePath +
      "/webclient/v1/announcement/pre/blocksessions";
  } catch {
    return "";
  }
}

function extractSessionContinueUrl(
  rawHtml: string,
  currentUrl: string,
): string {
  try {
    const doc = parseHTML(rawHtml);
    const selectors = [
      '#continue_button[href]',
      '.continue_button[href]',
      'a[href*="/next?status=2"]',
      'a[href*="status=2"]',
      'button[href*="status=2"]',
    ];
    for (const selector of selectors) {
      const el = doc.querySelector(selector);
      const href = el?.getAttribute("href");
      if (href && href.trim()) {
        try {
          return new URL(href, currentUrl).href;
        } catch {
          return href;
        }
      }
    }
  } catch {
    // fall through to regex
  }

  const href = firstRegexGroup(
    rawHtml,
    `href="([^"]*\\/next\\?status=2[^"]*)"`,
  );
  if (href) {
    try {
      return new URL(href, currentUrl).href;
    } catch {
      return href;
    }
  }
  return "";
}

interface SessionAction {
  name: string;
  method: string;
  url: string;
  body?: string;
  contentType?: string;
}

function resolveSessionActionUrl(
  currentUrl: string,
  rawTarget: string,
): string | null {
  const target = rawTarget.trim().replace(/^["']|["']$/g, "");
  if (!target) return null;
  const lower = target.toLowerCase();
  const relevant =
    lower.includes("block-sessions") ||
    lower.includes("sessions-reminder") ||
    lower.includes("signin-block") ||
    lower.includes("terminate") ||
    lower.includes("status=2") ||
    lower.includes("continue") ||
    lower.includes("understand");
  if (!relevant) return null;
  try {
    return new URL(target, currentUrl).href;
  } catch {
    return null;
  }
}

function extractContinuationActions(
  rawHtml: string,
  currentUrl: string,
): SessionAction[] {
  const actions: SessionAction[] = [];
  const seen = new Set<string>();

  const addAction = (action: SessionAction) => {
    if (!action.url.trim()) return;
    if (!action.method) action.method = "GET";
    const key = `${action.method} ${action.url} ${action.body ?? ""}`;
    if (seen.has(key)) return;
    seen.add(key);
    actions.push(action);
  };

  try {
    const doc = parseHTML(rawHtml);

    doc.querySelectorAll("a[href], button[href], [data-href]").forEach((el) => {
      for (const attr of ["href", "data-href"]) {
        const target = el.getAttribute(attr);
        if (!target) continue;
        const resolved = resolveSessionActionUrl(currentUrl, target);
        if (resolved) {
          addAction({ name: "session_action_link", method: "GET", url: resolved });
        }
      }
    });

    doc.querySelectorAll("form").forEach((form) => {
      const actionUrl = form.getAttribute("action")?.trim() || currentUrl;
      const resolved = resolveSessionActionUrl(currentUrl, actionUrl);
      if (!resolved) return;

      const method = (form.getAttribute("method") || "GET").toUpperCase().trim();
      const params = new URLSearchParams();

      form.querySelectorAll("input, select, textarea").forEach((field) => {
        const name = field.getAttribute("name");
        if (!name || !name.trim()) return;
        const fieldType = (field.getAttribute("type") || "").toLowerCase().trim();
        if (fieldType === "submit" || fieldType === "button") return;
        const value = field.getAttribute("value") ?? "";
        params.append(name, value);
      });

      const action: SessionAction = {
        name: "session_action_form",
        method,
        url: resolved,
      };
      if (method !== "GET" && params.toString()) {
        action.body = params.toString();
        action.contentType = "application/x-www-form-urlencoded;charset=UTF-8";
      }
      addAction(action);
    });

    doc.querySelectorAll("[onclick]").forEach((el) => {
      const onclick = el.getAttribute("onclick") ?? "";
      const patterns = [
        /location\.href\s*=\s*['"]([^'"]+)['"]/g,
        /window\.location\s*=\s*['"]([^'"]+)['"]/g,
        /window\.open\(\s*['"]([^'"]+)['"]/g,
        /['"]([^'"]*(?:block-sessions|sessions-reminder|status=2|terminate|continue)[^'"]*)['"]/g,
      ];
      for (const pattern of patterns) {
        let match: RegExpExecArray | null;
        while ((match = pattern.exec(onclick)) !== null) {
          const candidate = match[1].trim();
          if (candidate) {
            const resolved = resolveSessionActionUrl(currentUrl, candidate);
            if (resolved) {
              addAction({
                name: "session_action_onclick",
                method: "GET",
                url: resolved,
              });
            }
          }
        }
      }
    });
  } catch {
    // HTML parse failed — return what we have
  }

  return actions;
}

// ─── LoginSession ────────────────────────────────────────────────────────────

export class AcademiaLoginSession {
  private client: HttpClient;
  private host: string;
  private signinUrl: string;
  private serviceUrl: string;
  private uriPrefix: string;
  private csrfParam: string;
  private csrfCookie: string;
  private cliTime: string;

  constructor() {
    this.host = "academia.srmist.edu.in";
    this.serviceUrl = BASE_URL;
    this.signinUrl = BASE_URL + SIGNIN_PATH + "?serviceurl=" +
      encodeURIComponent(this.serviceUrl);
    this.uriPrefix = "/accounts/p/" + PORTAL_ID;
    this.csrfParam = "iamcsrcoo";
    this.csrfCookie = "iamcsr";
    this.cliTime = String(Date.now());

    this.client = new HttpClient({
      userAgent: USER_AGENT,
      host: this.host,
      csrfParam: this.csrfParam,
      csrfCookie: this.csrfCookie,
      defaultReferer: this.signinUrl,
    });
  }

  isAuthenticated(): boolean {
    return this.client.jar.hasCookie(this.host, "JSESSIONID");
  }

  private looksAuthenticated(currentUrl: string): boolean {
    if (this.isAuthenticated()) return true;
    const lowerUrl = currentUrl.toLowerCase();
    return lowerUrl.startsWith(this.serviceUrl.toLowerCase()) &&
      !lowerUrl.includes("/accounts/p/") &&
      !lowerUrl.includes("/signin");
  }

  /**
   * Load the academia home page with seeded cookies so Zoho can refresh
   * CSRF / path cookies before XHR fragment fetches. Without this, the
   * portal WAF returns 403 on attendance/timetable pages.
   */
  async primePortalSession(): Promise<RequestSnapshot> {
    if (!this.isAuthenticated()) {
      throw new Error("session expired: JSESSIONID missing");
    }

    const snap = await this.client.doRequest(
      "portal_prime",
      "GET",
      this.serviceUrl + "/",
      null,
      "",
      { Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" },
      true,
    );

    if (looksLikeUnauthenticatedPage(snap.url, snap.body)) {
      throw new Error("session expired: portal redirected to sign-in");
    }
    if (snap.statusCode === 401 || snap.statusCode === 403) {
      throw new Error(`session expired: portal returned ${snap.statusCode}`);
    }
    if (snap.statusCode < 200 || snap.statusCode > 299) {
      throw new Error(`portal prime returned ${snap.statusCode}`);
    }
    return snap;
  }

  serializedCookies(): { name: string; value: string }[] {
    return this.client.jar.serialize(this.host);
  }

  seedCookies(cookies: { name: string; value: string }[]): void {
    if (!cookies.length) return;
    const map: Record<string, string> = {};
    for (const c of cookies) {
      if (c.name.trim()) map[c.name] = c.value;
    }
    this.client.jar.seedCookies(this.host, map);
  }

  private async fetchSigninPage(): Promise<SigninPageInfo> {
    const snap = await this.client.doRequest(
      "signin_page",
      "GET",
      this.signinUrl,
      null,
      "",
      { Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" },
      true,
    );

    const info = parseSigninPage(snap.body, snap.url, this.serviceUrl);

    if (info.uriPathPrefix) this.uriPrefix = info.uriPathPrefix;
    if (info.serviceUrl) this.serviceUrl = info.serviceUrl;
    if (info.csrfParam) {
      this.csrfParam = info.csrfParam;
      this.client.csrfParam = info.csrfParam;
    }
    if (info.csrfCookieName) {
      this.csrfCookie = info.csrfCookieName;
      this.client.csrfCookie = info.csrfCookieName;
    }

    return info;
  }

  private async runLocate(): Promise<void> {
    const locateUrl = this.serviceUrl + this.uriPrefix +
      "/accounts/public/api/locate?cli_time=" +
      encodeURIComponent(this.cliTime) + "&serviceurl=" +
      encodeURIComponent(this.serviceUrl);

    await this.client.doRequest(
      "locate",
      "POST",
      locateUrl,
      null,
      "application/x-www-form-urlencoded;charset=UTF-8",
      { Accept: "application/json,text/plain,*/*" },
      false,
    );
  }

  private async runLookup(email: string): Promise<LookupResult> {
    let fullEmail = email.trim();
    if (!fullEmail.includes("@")) fullEmail += "@srmist.edu.in";
    const encodedEmail = encodeURIComponent(fullEmail);
    const lookupUrl = this.serviceUrl + this.uriPrefix +
      "/signin/v2/lookup/" + encodedEmail;
    const body = "mode=primary&cli_time=" +
      encodeURIComponent(this.cliTime) + "&serviceurl=" +
      encodeURIComponent(this.serviceUrl);

    const snap = await this.client.doRequest(
      "lookup",
      "POST",
      lookupUrl,
      body,
      "application/x-www-form-urlencoded;charset=UTF-8",
      { Accept: "application/json,text/plain,*/*" },
      false,
    );

    const result = parseLookupResponse(snap.body);

    if (snap.statusCode < 200 || snap.statusCode > 299) {
      throw new Error(`lookup request returned ${snap.statusCode}`);
    }
    if (!result.identifier || !result.digest) {
      throw new Error(
        `lookup response did not contain identifier/digest (status=${snap.statusCode})`,
      );
    }
    return result;
  }

  private async runPassword(
    identifier: string,
    digest: string,
    password: string,
  ): Promise<PasswordResult> {
    const passwordUrl = this.serviceUrl + this.uriPrefix +
      "/signin/v2/primary/" + encodeURIComponent(identifier) +
      "/password?digest=" + encodeURIComponent(digest) +
      "&cli_time=" + encodeURIComponent(this.cliTime) +
      "&serviceurl=" + encodeURIComponent(this.serviceUrl);
    const body = JSON.stringify({
      passwordauth: { password: password.trim() },
    });

    const snap = await this.client.doRequest(
      "password",
      "POST",
      passwordUrl,
      body,
      "application/x-www-form-urlencoded;charset=UTF-8",
      { Accept: "application/json,text/plain,*/*" },
      false,
    );

    const result = parsePasswordResponse(snap.body, snap.location);

    if (snap.statusCode < 200 || snap.statusCode > 299) {
      throw new Error(`password request returned ${snap.statusCode}`);
    }
    if (!result.redirectUri && result.errorCode) {
      throw new Error(
        `password auth failed: ${result.localizedMessage} (${result.errorCode})`,
      );
    }
    return result;
  }

  private async completePostLogin(redirectUri: string): Promise<RequestSnapshot> {
    const finalTarget = redirectUri.trim() || this.serviceUrl;

    const snap = await this.client.doRequest(
      "post_login_navigation",
      "GET",
      finalTarget,
      null,
      "",
      { Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" },
      true,
    );

    return this.completePostLoginFlow(snap);
  }

  private async completePostLoginFlow(
    current: RequestSnapshot,
  ): Promise<RequestSnapshot> {
    let last = current;
    for (let step = 0; step < 6; step++) {
      const classification = classifyPage(last.url, last.body);
      if (classification === CLASS_SESSIONS) {
        last = await this.completeSessionTermination(last);
      } else if (classification === CLASS_DAILY_LIMIT) {
        last = await this.completeDailySigninWarning(last);
      } else {
        return last;
      }
    }
    throw new Error("post-login flow did not settle after multiple continuation steps");
  }

  private async completeSessionTermination(
    current: RequestSnapshot,
  ): Promise<RequestSnapshot> {
    let last = current;
    for (let step = 0; step < 4; step++) {
      const classification = classifyPage(last.url, last.body);
      if (classification !== CLASS_SESSIONS) return last;

      if (last.url.toLowerCase().includes("/preannouncement/block-sessions")) {
        last = await this.completePreannouncementSessionTermination(last);
        continue;
      }

      const actions = extractContinuationActions(last.body, last.url);
      if (actions.length === 0) {
        let actionUrl = extractSessionContinueUrl(last.body, last.url);
        if (!actionUrl) actionUrl = deriveSessionContinueUrl(last.url);
        if (actionUrl) {
          actions.push({
            name: "session_terminate_fallback",
            method: "GET",
            url: actionUrl,
          });
        }
      }
      if (actions.length === 0) {
        throw new Error("session reminder page did not expose a terminate action");
      }

      let progressed = false;
      for (const action of actions) {
        const snap = await this.client.doRequest(
          action.name,
          action.method,
          action.url,
          action.body ?? null,
          action.contentType ?? "",
          {
            Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            Referer: last.url,
          },
          true,
        );
        last = snap;
        progressed = true;
        const cls = classifyPage(last.url, last.body);
        if (cls !== CLASS_SESSIONS) return last;
      }

      if (!progressed) {
        throw new Error("session termination actions did not change page state");
      }
    }
    throw new Error("session reminder flow did not complete after multiple attempts");
  }

  private async completePreannouncementSessionTermination(
    current: RequestSnapshot,
  ): Promise<RequestSnapshot> {
    const deleteUrl = derivePreannouncementDeleteUrl(current.url);
    if (!deleteUrl) {
      throw new Error("preannouncement block-sessions page did not expose a terminate endpoint");
    }

    const deleteSnap = await this.client.doRequest(
      "session_terminate_delete",
      "DELETE",
      deleteUrl,
      null,
      "",
      {
        Accept: "application/json,text/plain,*/*",
        "X-Requested-With": "XMLHttpRequest",
        Referer: current.url,
      },
      false,
    );

    if (deleteSnap.statusCode < 200 || deleteSnap.statusCode > 299) {
      throw new Error(`preannouncement terminate returned ${deleteSnap.statusCode}`);
    }

    const actionUrl = deriveSessionContinueUrl(current.url);
    if (!actionUrl) {
      throw new Error("preannouncement block-sessions page did not expose continuation URL");
    }

    return await this.client.doRequest(
      "session_terminate_next",
      "GET",
      actionUrl,
      null,
      "",
      {
        Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        Referer: current.url,
      },
      true,
    );
  }

  private async completeDailySigninWarning(
    current: RequestSnapshot,
  ): Promise<RequestSnapshot> {
    const actions = extractContinuationActions(current.body, current.url);
    if (actions.length === 0) {
      let actionUrl = extractSessionContinueUrl(current.body, current.url);
      if (!actionUrl) actionUrl = deriveSessionContinueUrl(current.url);
      if (actionUrl) {
        actions.push({
          name: "daily_signin_continue_fallback",
          method: "GET",
          url: actionUrl,
        });
      }
    }
    if (actions.length === 0) {
      throw new Error("daily sign-in warning page did not expose an acknowledgement action");
    }

    for (const action of actions) {
      const snap = await this.client.doRequest(
        action.name,
        action.method,
        action.url,
        action.body ?? null,
        action.contentType ?? "",
        {
          Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          Referer: current.url,
        },
        true,
      );
      return snap;
    }

    throw new Error("daily sign-in acknowledgement failed");
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  /** Expose service URL for fragment URL construction. */
  getServiceUrl(): string {
    return this.serviceUrl;
  }

  /** Expose the HTTP client for direct requests (e.g. student photo). */
  getClient(): HttpClient {
    return this.client;
  }

  /**
   * Fetch a portal page fragment and decode the sanitized/zml/raw HTML.
   * Port of Go fetchDecodedFragment.
   */
  async fetchDecodedFragment(
    name: string,
    rawUrl: string,
    referer: string,
  ): Promise<{ html: string; debug: DecodedFragment }> {
    const debug: DecodedFragment = {
      html: "",
      statusCode: 0,
      contentType: "",
      payloadFound: false,
      payloadLength: 0,
    };

    const headers: Record<string, string> = {
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Referer": referer,
      "X-Requested-With": "XMLHttpRequest",
    };

    const snap = await this.client.doRequest(
      name,
      "GET",
      rawUrl,
      null,
      "",
      headers,
      false,
    );

    debug.statusCode = snap.statusCode;
    debug.contentType = snap.headers["content-type"] ?? "";

    if (snap.statusCode < 200 || snap.statusCode > 299) {
      throw new Error(`${name} request returned ${snap.statusCode}`);
    }

    if (looksLikeUnauthenticatedPage(snap.url, snap.body)) {
      throw new Error(`${name}: session expired (login page returned)`);
    }

    try {
      const { html, via } = decodeFragmentBody(snap.body);
      debug.html = html;
      debug.payloadFound = via !== "raw";
      debug.payloadLength = snap.body.length;
      return { html, debug };
    } catch (err) {
      const error = err as Error;
      throw new Error(`${name} decode failed: ${error.message}`);
    }
  }

  /**
   * Fetch student photo as base64 data URL.
   */
  async fetchStudentPhotoDataURL(photoSrc: string): Promise<string> {
    const snap = await this.client.doRequest(
      "student_photo",
      "GET",
      photoSrc,
      null,
      "",
      {
        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        "Referer": this.serviceUrl + "/#Report:Student_Profile_Report",
      },
      true,
    );

    if (snap.statusCode < 200 || snap.statusCode > 299) {
      throw new Error(`student photo request returned ${snap.statusCode}`);
    }
    if (!snap.body) throw new Error("student photo response was empty");

    let contentType = (snap.headers["content-type"] ?? "").trim();
    if (!contentType) {
      contentType = guessImageContentType(photoSrc);
    }
    if (contentType.toLowerCase().includes("application/octet-stream")) {
      contentType = guessImageContentType(photoSrc);
    }
    if (!contentType.toLowerCase().startsWith("image/")) {
      throw new Error(`student photo response was not an image (${contentType})`);
    }

    // Convert body string to base64
    const bytes = new TextEncoder().encode(snap.body);
    const b64 = btoa(String.fromCharCode(...bytes));
    return `data:${contentType};base64,${b64}`;
  }

  /**
   * Full login flow: signin page → locate → lookup → password → post-login navigation.
   * Returns classification and cookies on success.
   */
  async login(email: string, password: string): Promise<AcademiaLoginResult> {
    try {
      await this.fetchSigninPage();
      await this.runLocate();
      const lookup = await this.runLookup(email);
      const pwd = await this.runPassword(lookup.identifier, lookup.digest, password);
      const snap = await this.completePostLogin(pwd.redirectUri);

      if (!this.isAuthenticated()) {
        // Fall back to URL-based check — JSESSIONID may be set under a different
        // domain or the portal may use a different session cookie name.
        if (!this.looksAuthenticated(snap.url)) {
          return {
            success: false,
            classification: CLASS_UNKNOWN,
            cookies: this.serializedCookies(),
            hasJSessionId: false,
            finalUrl: snap.url,
            error: "login completed but JSESSIONID not established",
          };
        }
      }

      return {
        success: true,
        classification: CLASS_AUTHENTICATED,
        cookies: this.serializedCookies(),
        hasJSessionId: true,
        finalUrl: snap.url,
      };
    } catch (err) {
      const error = err as Error;
      const classification = classifyFromMessage(error.message, "");
      return {
        success: false,
        classification,
        cookies: this.serializedCookies(),
        hasJSessionId: this.isAuthenticated(),
        finalUrl: "",
        error: error.message,
      };
    }
  }

  /**
   * Check if seeded cookies are still valid by hitting the portal home page.
   */
  async verifySession(): Promise<boolean> {
    if (!this.isAuthenticated()) return false;
    try {
      await this.primePortalSession();
      return true;
    } catch {
      return false;
    }
  }
}
