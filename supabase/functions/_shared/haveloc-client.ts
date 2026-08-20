/**
 * Haveloc API client — TypeScript port of Go client.go + api.go
 * Handles all HTTP communication with the Haveloc placement portal.
 *
 * Auth is stateless: Cookie header (ihaveloc + phaveloc) + API-KEY header.
 * No cookie jar needed — auth is injected per-request.
 */

import { encryptToken, generateAPIKey, extractSubFromJWT, extractTSFromJWT, extractUUIDFromJWT } from "./haveloc-crypto.ts";

const BASE_API_URL = "https://app.haveloc.com/app";
const CHAT_BASE_URL = "https://chat.haveloc.com/communication";
const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";

// ─── Types ───────────────────────────────────────────────────────────────────

export interface HavelocAuth {
  encryptedToken: string;
  phaveloc: number;
  sub: string;
}

export interface LoginResult {
  token: string;
  encryptedToken: string;
  sub: string;
  uuid: string;
  phaveloc: number;
  publicUrl: string;
  requiresMfa?: boolean;
  mfaToken?: string;
}

export interface FetchOptions {
  uuid?: string;
  page?: number;
  size?: number;
  sort?: string;
  filters?: unknown[];
  startDate?: string;
  endDate?: string;
  jobUuid?: string;
}

export interface ApplyAnswer {
  questionId: number;
  responseOptions: string[];
}

// ─── Async header building ───────────────────────────────────────────────────

async function buildHeadersAsync(auth: HavelocAuth | null, userAgent: string): Promise<Record<string, string>> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Accept": "application/json, text/plain, */*",
    "User-Agent": userAgent,
    "Origin": "https://placements.haveloc.com",
    "Referer": "https://placements.haveloc.com/",
  };

  if (auth) {
    headers["Cookie"] = `ihaveloc=${auth.encryptedToken}; phaveloc=${auth.phaveloc}`;
    const apiKey = await generateAPIKey(auth.sub, auth.phaveloc);
    headers["API-KEY"] = apiKey;
  }

  return headers;
}

// ─── Re-export the client with async headers ─────────────────────────────────

export class HavelocClientAsync {
  private auth: HavelocAuth | null = null;
  private userAgent = USER_AGENT;

  async setAuth(token: string, phaveloc: number): Promise<void> {
    const sub = extractSubFromJWT(token);
    const encryptedToken = await encryptToken(token);
    this.auth = {
      encryptedToken,
      phaveloc,
      sub,
    };
  }

  get hasAuth(): boolean {
    return this.auth !== null;
  }

  async doRequest(method: string, url: string, body?: unknown): Promise<{ data: unknown; status: number }> {
    const maxRetries = 3;
    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        const headers = await buildHeadersAsync(this.auth, this.userAgent);
        const init: RequestInit = { method, headers };

        if (body !== undefined && body !== null) {
          init.body = JSON.stringify(body);
        }

        const resp = await fetch(url, init);
        const status = resp.status;
        const text = await resp.text();

        if ((status === 429 || status === 502 || status === 503 || status === 504) && attempt < maxRetries) {
          await sleep(500 * (attempt + 1));
          continue;
        }

        if (status === 401) {
          throw new Error("authentication expired");
        }

        // 409 is handled by the caller (e.g. session limit in login)
        if (status === 409) {
          try {
            return { data: JSON.parse(text), status };
          } catch {
            return { data: text, status };
          }
        }

        if (status >= 400) {
          const isHTML = text.trimStart().startsWith("<!doctype") || text.trimStart().startsWith("<html");
          const msg = isHTML ? `Haveloc portal is temporarily unavailable (HTTP ${status})` : text;
          const err = new Error(`API error ${status}: ${msg}`) as Error & { status?: number; rawData?: unknown };
          err.status = status;
          try { err.rawData = JSON.parse(text); } catch { err.rawData = text; }
          throw err;
        }

        if (!text) {
          return { data: null, status };
        }

        try {
          return { data: JSON.parse(text), status };
        } catch {
          return { data: text, status };
        }
      } catch (err) {
        if (err instanceof Error && err.message === "authentication expired") {
          throw err;
        }
        lastError = err as Error;
        if (attempt < maxRetries) {
          await sleep(500 * (attempt + 1));
          continue;
        }
      }
    }

    throw lastError || new Error("max retries exceeded");
  }

  async fetchDirect(fileUrl: string): Promise<{ data: Uint8Array; contentType: string }> {
    const headers = await buildHeadersAsync(this.auth, this.userAgent);
    headers["Accept"] = "*/*";

    const resp = await fetch(fileUrl, { headers });
    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`JD download failed: status ${resp.status}, body: ${text.substring(0, 500)}`);
    }

    const buf = new Uint8Array(await resp.arrayBuffer());
    const contentType = resp.headers.get("Content-Type") || "application/octet-stream";
    return { data: buf, contentType };
  }
}

// ─── Login / MFA / Session ───────────────────────────────────────────────────

export async function login(client: HavelocClientAsync, username: string, password: string): Promise<LoginResult> {
  const { data, status } = await client.doRequest("POST", `${BASE_API_URL}/sign-in`, { username, password });

  // Handle 409 session limit
  if (status === 409 && data && typeof data === "object") {
    const conflict = data as { sessionLimitReached?: boolean; activeSessions?: { sessionUuid: string; revocationSecret: string }[] };
    if (conflict.sessionLimitReached && conflict.activeSessions) {
      for (const s of conflict.activeSessions) {
        await client.doRequest("POST", `${BASE_API_URL}/sign-in/revoke-session`, {
          sessionUuid: s.sessionUuid,
          revocationSecret: s.revocationSecret,
        });
      }
      // Retry login
      const retry = await client.doRequest("POST", `${BASE_API_URL}/sign-in`, { username, password });
      return await parseLoginResponse(retry.data);
    }
    throw new Error("session limit reached");
  }

  return await parseLoginResponse(data);
}

async function parseLoginResponse(data: unknown): Promise<LoginResult> {
  const resp = data as { token?: string; publicUrl?: string; requiresTotp?: boolean; mfaToken?: string };

  if (resp.requiresTotp && resp.mfaToken) {
    return {
      token: "",
      encryptedToken: "",
      sub: "",
      uuid: "",
      phaveloc: 0,
      publicUrl: resp.publicUrl || "",
      requiresMfa: true,
      mfaToken: resp.mfaToken,
    };
  }

  if (!resp.token) {
    throw new Error("login succeeded but no token returned");
  }

  const sub = extractSubFromJWT(resp.token);
  const ts = extractTSFromJWT(resp.token);
  const phaveloc = Math.floor(Date.now() / 1000) - ts;
  const encryptedToken = await encryptToken(resp.token);
  let uuid = "";
  try { uuid = extractUUIDFromJWT(resp.token); } catch { /* uuid may not be present */ }

  return {
    token: resp.token,
    encryptedToken,
    sub,
    uuid,
    phaveloc,
    publicUrl: resp.publicUrl || "",
  };
}

export async function verifyTOTP(client: HavelocClientAsync, mfaToken: string, totpCode: string, emailOtp: string): Promise<LoginResult> {
  const body: Record<string, string> = { mfaToken };
  if (emailOtp) {
    body.emailOtp = emailOtp.trim();
  } else {
    body.totpCode = totpCode;
  }

  const { data } = await client.doRequest("POST", `${BASE_API_URL}/sign-in/totp`, body);
  return await parseLoginResponse(data);
}

export async function sendMFAPrompt(client: HavelocClientAsync, mfaToken: string): Promise<void> {
  await client.doRequest("POST", `${BASE_API_URL}/sign-in/mfa-email`, { mfaToken });
}

export async function signOut(client: HavelocClientAsync): Promise<void> {
  await client.doRequest("GET", `${BASE_API_URL}/sign-out`);
}

// ─── Section fetchers ────────────────────────────────────────────────────────

export async function fetchCompanies(client: HavelocClientAsync, page: number, size: number, sort: string): Promise<unknown> {
  if (!sort) sort = "name,asc";
  if (size === 0) size = 20;
  if (page > 0) {
    const url = `${BASE_API_URL}/companyViews?respectConfigProp=false&sort=${sort}&size=${size}&page=${page}`;
    const { data } = await client.doRequest("POST", url, []);
    return data;
  }
  return fetchAllPages(client, `${BASE_API_URL}/companyViews?respectConfigProp=false&sort=${sort}&size=${size}`, []);
}

export async function fetchJobs(client: HavelocClientAsync, page: number, size: number, sort: string, filters: unknown[]): Promise<unknown> {
  if (!sort) sort = "jobApplyBy,desc";
  if (size === 0) size = 20;
  const body = filters || [];
  if (page > 0) {
    const url = `${BASE_API_URL}/studentJobSubViews?sort=${sort}&size=${size}&page=${page}`;
    const { data } = await client.doRequest("POST", url, body);
    return data;
  }
  return fetchAllPages(client, `${BASE_API_URL}/studentJobSubViews?sort=${sort}&size=${size}`, body);
}

// ─── Paginated fetch (all pages) ─────────────────────────────────────────────

async function fetchAllPages(client: HavelocClientAsync, baseURL: string, body: unknown): Promise<unknown> {
  const firstURL = `${baseURL}&page=0`;
  const { data: firstData } = await client.doRequest("POST", firstURL, body);

  const first = firstData as {
    _embedded?: { entityModels?: unknown[] };
    page?: { totalPages?: number };
  };

  const totalPages = first.page?.totalPages ?? 1;
  if (totalPages <= 1) {
    return firstData;
  }

  const allModels = [...(first._embedded?.entityModels || [])];

  // Fetch remaining pages in parallel
  const pagePromises: Promise<unknown[]>[] = [];
  for (let p = 1; p < totalPages; p++) {
    pagePromises.push(
      client.doRequest("POST", `${baseURL}&page=${p}`, body)
        .then(({ data }) => {
          const pageData = data as { _embedded?: { entityModels?: unknown[] } };
          return pageData._embedded?.entityModels || [];
        })
        .catch(() => [])
    );
  }

  const results = await Promise.all(pagePromises);
  for (const models of results) {
    allModels.push(...models);
  }

  // Build merged response preserving original structure
  const merged = firstData as Record<string, unknown>;
  if (merged._embedded && typeof merged._embedded === "object") {
    (merged._embedded as Record<string, unknown>).entityModels = allModels;
  }
  if (merged.page && typeof merged.page === "object") {
    const page = merged.page as Record<string, unknown>;
    page.totalElements = allModels.length;
    page.totalPages = 1;
    page.number = 0;
  }

  return merged;
}

// ─── More section fetchers ───────────────────────────────────────────────────

export async function fetchJobTracker(client: HavelocClientAsync, uuid: string, page: number, size: number): Promise<unknown> {
  if (size === 0) size = 50;
  if (page > 0) {
    const url = `${BASE_API_URL}/jobTrackerViews/studentUuid/${uuid}?respectConfigProp=false&sort=lastModifiedDate,desc&page=${page}&size=${size}`;
    const { data } = await client.doRequest("POST", url, []);
    return data;
  }
  return fetchAllPages(client, `${BASE_API_URL}/jobTrackerViews/studentUuid/${uuid}?respectConfigProp=false&sort=lastModifiedDate,desc&size=${size}`, []);
}

export async function fetchStudentProfile(client: HavelocClientAsync, uuid: string): Promise<unknown> {
  const { data } = await client.doRequest("GET", `${BASE_API_URL}/studentViews/u/${uuid}`);
  return data;
}

export async function fetchPlacementCycles(client: HavelocClientAsync, cycleId: number = 136): Promise<unknown> {
  const { data } = await client.doRequest("POST", `${BASE_API_URL}/placementCycles/basic/${cycleId}`, {});
  return data;
}

export async function fetchStudentStats(client: HavelocClientAsync, uuid: string): Promise<unknown> {
  const { data } = await client.doRequest("POST", `${BASE_API_URL}/studentStatsByStudentUuid?studentUuid=${uuid}&respectConfigProp=false`, []);
  return data;
}

export async function fetchNotices(client: HavelocClientAsync, page: number, size: number): Promise<unknown> {
  if (size === 0) size = 20;
  const url = `${BASE_API_URL}/notification?page=${page}&size=${size}&sort=createdDate,desc`;
  const { data } = await client.doRequest("POST", url, []);
  return data;
}

export async function fetchGlobalPolicy(client: HavelocClientAsync): Promise<unknown> {
  const { data } = await client.doRequest("POST", `${BASE_API_URL}/globalPolicy`, {});
  return data;
}

export async function fetchPolicies(client: HavelocClientAsync): Promise<unknown> {
  const { data } = await client.doRequest("POST", `${BASE_API_URL}/policies?sort=startRange,asc`, []);
  return data;
}

export async function fetchCalendar(client: HavelocClientAsync, startDate: string, endDate: string): Promise<unknown> {
  const url = `${BASE_API_URL}/placementCalendar/dateRange?startDate=${startDate}&endDate=${endDate}`;
  const { data } = await client.doRequest("POST", url, {});
  return data;
}

export async function fetchInsights(client: HavelocClientAsync): Promise<unknown> {
  const { data } = await client.doRequest("POST", `${BASE_API_URL}/haveloc-insights?requestAPI=overall/get_college_course_branch_list`, {});
  return data;
}

export async function fetchChatInbox(client: HavelocClientAsync): Promise<unknown> {
  const { data } = await client.doRequest("GET", `${CHAT_BASE_URL}/v1/comm/inbox?archived=false`);
  return data;
}

export async function fetchChatUnread(client: HavelocClientAsync): Promise<unknown> {
  const { data } = await client.doRequest("GET", `${CHAT_BASE_URL}/v1/comm/inbox/unread-summary`);
  return data;
}

export async function fetchStudentSocialMedia(client: HavelocClientAsync, uuid: string): Promise<unknown> {
  const { data } = await client.doRequest("POST", `${BASE_API_URL}/studentSocialMedia/studentUuid/${uuid}`, []);
  return data;
}

export async function fetchJobView(client: HavelocClientAsync, jobUuid: string): Promise<unknown> {
  const { data } = await client.doRequest("POST", `${BASE_API_URL}/jobViews/u/${jobUuid}`, {});
  return data;
}

export async function fetchJobAttachments(client: HavelocClientAsync, jobUuid: string): Promise<unknown> {
  const { data } = await client.doRequest("POST", `${BASE_API_URL}/jobAttachments/jobUuid/${jobUuid}`, {});
  return data;
}

export async function fetchStudentDocuments(client: HavelocClientAsync, studentUuid: string): Promise<unknown> {
  const { data } = await client.doRequest("POST", `${BASE_API_URL}/studentDocumentService/studentUuid/${studentUuid}`, {});
  return data;
}

export async function applyForJob(
  client: HavelocClientAsync,
  jobUuid: string,
  jobId: number | string,
  answers: ApplyAnswer[],
  resumeName: string,
): Promise<unknown> {
  const answerBeans = answers.map((a) => ({
    questionId: a.questionId,
    responseOptions: a.responseOptions,
  }));

  const body = {
    jobUuid,
    jobId,
    jobAppliedAnswerBeans: answerBeans,
    resumeName,
  };

  const { data, status } = await client.doRequest("PUT", `${BASE_API_URL}/jobTrackerApply`, body);
  return data;
}

// ─── JD (job description) download ───────────────────────────────────────────

export async function fetchJD(
  client: HavelocClientAsync,
  fileUrl: string,
  jobUuid: string,
): Promise<{ data: Uint8Array; contentType: string; fileName: string }> {
  if (fileUrl.includes("hlc-secure-url")) {
    const { data, contentType } = await client.fetchDirect(fileUrl);
    const fileName = extractFileName(fileUrl, contentType);
    return { data, contentType, fileName };
  }

  if (jobUuid) {
    const attachments = await fetchJobAttachments(client, jobUuid);
    const attList = extractAttachmentList(attachments);

    for (const att of attList) {
      const attachmentUrl = (att as Record<string, unknown>)?.attachmentUrl;
      if (typeof attachmentUrl === "string" && attachmentUrl) {
        const { data, contentType } = await client.fetchDirect(attachmentUrl);
        const fileName = extractFileName(attachmentUrl, contentType);
        return { data, contentType, fileName };
      }
    }

    throw new Error("no attachment URL found in job attachments");
  }

  throw new Error("JD download failed: no job UUID and not a secure URL");
}

function extractAttachmentList(attachments: unknown): Record<string, unknown>[] {
  if (Array.isArray(attachments)) return attachments;
  const wrapper = attachments as { _embedded?: { entityModels?: Record<string, unknown>[] } };
  if (wrapper?._embedded?.entityModels) return wrapper._embedded.entityModels;
  return [];
}

function extractFileName(url: string, contentType: string): string {
  const parts = url.split("/");
  let fileName = parts[parts.length - 1] || "attachment";
  if (contentType.includes("pdf") && !fileName.endsWith(".pdf")) {
    fileName += ".pdf";
  }
  return fileName;
}

// ─── Section dispatcher ──────────────────────────────────────────────────────

export async function fetchSection(
  client: HavelocClientAsync,
  section: string,
  opts: FetchOptions = {},
): Promise<unknown> {
  const page = opts.page || 0;
  const size = opts.size || 0;
  const sort = opts.sort || "";
  const uuid = opts.uuid || "";
  const filters = opts.filters || [];
  const jobUuid = opts.jobUuid || "";

  switch (section) {
    case "companies":
      return fetchCompanies(client, page, size, sort);
    case "jobs":
      return fetchJobs(client, page, size, sort, filters);
    case "tracker":
      return fetchJobTracker(client, uuid, page, size);
    case "profile":
      return fetchStudentProfile(client, uuid);
    case "placementCycles":
      return fetchPlacementCycles(client, 136);
    case "studentStats":
      return fetchStudentStats(client, uuid);
    case "notices":
      return fetchNotices(client, page, size);
    case "globalPolicy":
      return fetchGlobalPolicy(client);
    case "policies":
      return fetchPolicies(client);
    case "calendar": {
      let startDate = opts.startDate || "";
      let endDate = opts.endDate || "";
      if (!startDate) {
        const now = new Date();
        const past = new Date(now);
        past.setMonth(past.getMonth() - 1);
        const future = new Date(now);
        future.setMonth(future.getMonth() + 1);
        startDate = past.toISOString();
        endDate = future.toISOString();
      }
      return fetchCalendar(client, startDate, endDate);
    }
    case "insights":
      return fetchInsights(client);
    case "chatInbox":
      return fetchChatInbox(client);
    case "chatUnread":
      return fetchChatUnread(client);
    case "socialMedia":
      return fetchStudentSocialMedia(client, uuid);
    case "jobView":
      return fetchJobView(client, jobUuid);
    case "jobAttachments":
      return fetchJobAttachments(client, jobUuid);
    case "studentDocuments":
      return fetchStudentDocuments(client, uuid);
    default:
      throw new Error(`unknown section: ${section}`);
  }
}

// ─── Utility ─────────────────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
