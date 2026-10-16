# SCRAPER_SPEC.md — Exact Protocol, Regex, Decoder & Parser Specification

This document contains the verified, source-grounded HTTP sequences, headers, cookie rules, regexes, byte-scanners, and CSS selectors extracted from:
- `academia-backend/academia-scraper/cmd/loginprobe/` (`client.go`, `login.go`, `parsers.go`)
- `academia-backend/academia-scraper/cmd/studentportal/` (`client.go`, `login.go`, `captcha.go`, `parsers.go`, `marks.go`)
- `academia-backend/faculty-scraper/` (`scraper/scraper.go`, `models/faculty.go`)

The Flutter coding agent must implement these rules verbatim inside `srmone_mobile/lib/core/network/` and `srmone_mobile/lib/scrapers/`.

---

## 1. Shared Networking Primitives (`lib/core/network/`)

### 1.1 `SimpleCookieJar` (Port of Go Custom CookieJar)
Do **not** use a strict RFC-6265 browser cookie jar that drops cookies on path/domain attribute mismatches. Both Go scrapers use a simplified hostname-scoped (or service-scoped) key-value map:
1. Store cookies as `Map<String, Map<String, String>>` keyed by `[host][cookieName] = cookieValue`.
2. On every HTTP response, inspect all `Set-Cookie` headers:
   - Take only the first `name=value` pair before the first `;`.
   - Trim whitespace around `name` and `value`.
   - **Deletion Rule:** If `value` is empty `""`, `"delete"` (case-insensitive), or `"null"` (case-insensitive), remove `name` from the host's map.
   - Otherwise, set `cookies[host][name] = value`.
3. On every outgoing HTTP request to `host`, serialize all entries in `cookies[host]` as `name1=val1; name2=val2` in the `Cookie` request header.
4. Provide `toJson()` and `fromJson()` methods to persist/restore the map in `flutter_secure_storage`.

### 1.2 `ManualRedirectClient` (10-Hop Redirect Follower)
Configure `Dio` with `followRedirects: false` and `validateStatus: (status) => status != null && status < 500`.
Implement a wrapper that loops up to **`maxRedirects = 10`**:
1. Execute the request and update `SimpleCookieJar` from `response.headers['set-cookie']`.
2. If status is `301`, `302`, `303`, `307`, or `308`:
   - Read the `Location` header. If absent, stop and return current response.
   - Resolve relative `Location` URLs against the current request's URI (`currentUri.resolve(location)`).
   - For `301`, `302`, and `303`, if the current method is not `GET` or `HEAD`, switch method to `GET` and clear the request body and `Content-Type` header.
   - Repeat loop with the resolved URI.

---

## 2. SRM Academia Scraper (`lib/scrapers/academia/`)

### 2.1 Constants & Default Headers
```dart
const String defaultBaseURL = 'https://academia.srmist.edu.in';
const String defaultPortalID = '40-10002227248';
const String defaultStudentPhotoReportID = '2727643000298055031';
const String defaultSigninPath = '/accounts/p/$defaultPortalID/signin';
const String defaultAttendanceURL = '$defaultBaseURL/srm_university/academia-academic-services/page/My_Time_Table_2023_24';
const String defaultPersonalTTURL = '$defaultBaseURL/srm_university/academia-academic-services/page/My_Time_Table_2023_24';
const String defaultUnifiedTTB1 = '$defaultBaseURL/srm_university/academia-academic-services/page/Unified_Time_Table_2025_Batch_1';
const String defaultUnifiedTTB2 = '$defaultBaseURL/srm_university/academia-academic-services/page/Unified_Time_Table_2025_batch_2';
const String defaultAcademicReportsURL = '$defaultBaseURL/srm_university/academia-academic-services/page/Academic_Reports';

const String defaultUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
```
- **Session Initialization (`LoginSession`):**
  - `uriPrefix = '/accounts/p/$defaultPortalID'`
  - `csrfParam = 'iamcsrcoo'`
  - `csrfCookie = 'iamcsr'`
  - `serviceURL = defaultBaseURL`
  - `cliTime = DateTime.now().toUtc().millisecondsSinceEpoch.toString()` (Generated once per login session and reused across steps 1–4).
- **CSRF Header Construction (`X-ZCSRF-TOKEN`):**
  - Whenever `csrfParam` is non-empty AND `cookieJar.get(host, csrfCookie)` is non-empty, attach header:
    `X-ZCSRF-TOKEN: $csrfParam=${cookieJar.get(host, csrfCookie)}`

### 2.2 The 6-Step Zoho Authentication Sequence (`academia_client.dart`)

#### Account Normalization
```dart
String fullEmail = email.trim();
if (!fullEmail.contains('@')) {
  fullEmail = '$fullEmail@srmist.edu.in';
}
final String encodedEmail = Uri.encodeComponent(fullEmail);
```

#### Step 1: Load Sign-In Page (`GET`)
- **URL:** `$defaultBaseURL$defaultSigninPath?serviceurl=${Uri.encodeQueryComponent(serviceURL)}`
- **Headers:** `Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8`
- **Response Parsing (`parseSigninPage`):**
  Extract JavaScript variables from the HTML response using both double-quote and single-quote regexes:
  - `RegExp(r'var\s+' + name + r'\s*=\s*"([^"]*)"')`
  - `RegExp(r"var\s+" + name + r"\s*=\s*'([^']*)'")`
  - For `name` in `['csrfParam', 'csrfCookieName', 'uriPrefix']`: unescape `\/` → `/`, `\'` → `'`, `\"` → `"`, and update session properties if found.
  - For `emailOnlySignin`: `RegExp(r'var\s+emailOnlySignin\s*=\s*Boolean\("([^"]*)"\)')`
  - For `serviceUrl`: `RegExp(r"serviceUrl\s*=\s*'([^']+)'")` (fallback to `serviceurl` query param from final URL).
  - Also collect `input[type="hidden"]` (`name`, `value`) into `SigninPageInfo.hiddenFields`.

#### Step 2: Locate Service (`POST`)
- **URL:** `$serviceURL$uriPrefix/accounts/public/api/locate?cli_time=${Uri.encodeQueryComponent(cliTime)}&serviceurl=${Uri.encodeQueryComponent(serviceURL)}`
- **Headers:** `Accept: application/json,text/plain,*/*`, `X-ZCSRF-TOKEN` (if cookie available), `Referer: $signinURL`
- **Body:** Empty.

#### Step 3: Account Lookup (`POST`)
- **URL:** `$serviceURL$uriPrefix/signin/v2/lookup/$encodedEmail`
- **Headers:**
  - `Accept: application/json,text/plain,*/*`
  - `Content-Type: application/x-www-form-urlencoded;charset=UTF-8`
  - `X-ZCSRF-TOKEN: $csrfParam=$csrfCookieVal`
  - `Referer: $signinURL`
- **Body:**
  `"mode=primary&cli_time=${Uri.encodeQueryComponent(cliTime)}&serviceurl=${Uri.encodeQueryComponent(serviceURL)}"`
- **Response JSON Extraction:**
  - Read top-level `code`, `resource_name`, `localized_message`, `errors`.
  - Inspect nested object `json[json['resource_name'] ?? 'lookup'] ?? json['lookup']`.
  - Extract runtime **`identifier`** (`String`) and **`digest`** (`String`). Never hardcode these.

#### Step 4: Password Authentication (`POST`)
- **URL:**
  `$serviceURL$uriPrefix/signin/v2/primary/${Uri.encodeComponent(identifier)}/password?digest=${Uri.encodeQueryComponent(digest)}&cli_time=${Uri.encodeQueryComponent(cliTime)}&serviceurl=${Uri.encodeQueryComponent(serviceURL)}`
- **CRITICAL HEADER QUIRK:**
  Even though the body is JSON-formatted, `Content-Type` **MUST** be set to:
  `Content-Type: application/x-www-form-urlencoded;charset=UTF-8`
- **Other Headers:** `Accept: application/json,text/plain,*/*`, `X-ZCSRF-TOKEN`, `Referer: $signinURL`
- **Body:**
  `'{"passwordauth":{"password":${jsonEncode(password.trim())}}}'`
- **Response JSON Extraction:**
  - Read nested object `json[json['resource_name'] ?? 'passwordauth'] ?? json['passwordauth']`.
  - Extract `redirect_uri` (fallback to HTTP `Location` header, or `serviceURL` if both are empty).

#### Step 5: Follow Post-Password Redirect (`GET`)
- **URL:** `redirectUri` (from Step 4).

#### Step 6: Settle Portal Session & Continuation Unblocker (`completePostLoginFlow`)
Allow up to **6 outer continuation iterations** if the post-login response lands on a Zoho session-reminder or daily sign-in-limit warning page:
- **Classification checks:**
  - **Session-Reminder URL fragments:** `sessions-reminder`, `block-sessions`, `preannouncement/block-sessions`, `preannouncement/continue`, `announcement/sessions-reminder`, `announcement/continue`.
  - **Daily-Limit conditions:** Body (lowercased) contains `'daily sign-in limit'`, OR contains both `'signed in'` and `'times today'`, OR contains `'you are nearing your daily sign-in limit'`, OR (URL contains `'signin-block'` AND body contains `'i understand'`).
- **Special Preannouncement Block-Sessions Sequence:**
  If the URL contains `/preannouncement/block-sessions`:
  1. Truncate URL path at `/preannouncement/` and append `/webclient/v1/announcement/pre/blocksessions`.
  2. Send `DELETE` request with headers `Accept: application/json,text/plain,*/*`, `X-Requested-With: XMLHttpRequest`, `X-ZCSRF-TOKEN`, and `Referer: <current_page_url>`.
  3. Derive continuation URL by replacing `/preannouncement/block-sessions` with `/preannouncement/block-sessions/next` (query string cleared) and issue `GET`.
- **General Continuation Action Extraction:**
  1. Inspect `a[href], button[href], [data-href]` where target contains `block-sessions`, `sessions-reminder`, `signin-block`, `terminate`, `status=2`, `continue`, or `understand`.
  2. Scan inline scripts / `[onclick]` with regexes:
     - `RegExp(r'''location\.href\s*=\s*['"]([^'"]+)['"]''')`
     - `RegExp(r'''window\.location\s*=\s*['"]([^'"]+)['"]''')`
     - `RegExp(r'''window\.open\(\s*['"]([^'"]+)['"]''')`
     - `RegExp(r'''['"]([^'"]*(?:block-sessions|sessions-reminder|status=2|terminate|continue)[^'"]*)['"]''')`
  3. Inspect `form` elements (`action`, `method`, and named `input:not([type=submit]):not([type=button])`, `select`, `textarea`).
  4. Fallback selectors: `#continue_button[href]`, `.continue_button[href]`, `a[href*="/next?status=2"]`, `a[href*="status=2"]`, `button[href*="status=2"]`, or regex `RegExp(r'href="([^"]*\/next\?status=2[^"]*)"')`.
  5. Final fallback (`deriveSessionContinueURL`): append `/next?status=2` to current path.
- Finish by issuing `GET $serviceURL/` to prime the portal session.

---

### 2.3 Decoding Zoho Report Fragments (`academia_decoder.dart`)
When requesting data fragments (Attendance, Timetable, Marks, Profile, Calendar), send:
- `Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8`
- `X-Requested-With: XMLHttpRequest`
- `Referer: https://academia.srmist.edu.in/`
- `Cache-Control: no-cache, no-store, must-revalidate`
- Query suffix: `?_t=${DateTime.now().millisecondsSinceEpoch}`
*(If a 403 occurs, retry once with `Referer: https://academia.srmist.edu.in/`).*

Run these 3 decoders in strict order on the response text:

1. **Decoder 1: `decodeSanitizedHTML(String raw)` (Byte-by-Byte Scanner)**
   - Locate literal marker: `const marker = "pageSanitizer.sanitize('";`
   - Start immediately after `marker`. Scan character-by-character:
     - If current char is `\`, append both `\` and the next char to buffer and advance index by 2 (so `\'` does not terminate the string).
     - If current char is unescaped `'`, stop scanning.
   - Pass buffer to `decodeJSString(String input)`:
     - `\xHH` → parse 2 hex digits (invalid hex nibble falls back to `0`) → `String.fromCharCode(byte)`.
     - `\uHHHH` → parse 4 hex digits → `String.fromCharCode(rune)`.
     - `\n` → `\n`, `\r` → `\r`, `\t` → `\t`, `\b` → `\b`, `\f` → `\f`.
     - `\\` → `\`, `\'` → `'`, `\"` → `"`, `\/` → `/`.
     - Any other `\X` → `X` (drop backslash).
2. **Decoder 2: `decodeZMLValueHTML(String raw)`**
   - Parse DOM with `package:html`. Find first element matching `[zmlvalue]` with a non-empty `zmlvalue` attribute.
   - HTML-unescape the attribute value (`HtmlUnescape().convert(val)`).
   - Verify the unescaped string contains `<table` (case-insensitive).
3. **Decoder 3: Raw HTML Fallback**
   - If `raw` contains `<table` or `<html` (case-insensitive), return `raw`.

---

### 2.4 Academia HTML Parsers (`academia_parsers.dart`)

#### A. Attendance Parser (`My_Time_Table_2023_24`)
- Find the **first `table`** whose header row cells (`th` or first-row `td`) contain the exact text `Attn %`.
- Iterate subsequent `tr` rows and map cells by header name:
  - `Course Code` → `courseCode` (trim; if it contains `\n`, keep **only** text before the first `\n`).
  - `Course Title` → `courseTitle`
  - `Category` → `category`
  - `Faculty Name` → `facultyName`
  - `Slot` → `slot`
  - `Room No` → `roomNo`
  - `Hours Conducted` → `hoursConducted`
  - `Hours Absent` → `hoursAbsent`
  - `Attn %` → `attendancePct`

#### B. Student Profile & Photo Parser (`My_Time_Table_2023_24`)
- **Profile Table:** Find the first `table` containing header/cell `Registration Number:`. Walk rows and pair adjacent cells `(cell[i], cell[i+1])` as `label: value` pairs (stripping trailing `:` from labels).
- **Photo Extraction:**
  - Try selectors in order: `img[src*="Photo_Upload_Student_Report"]`, `img[src*="Your_Photo/image/"]`, or `img` inside a cell mentioning `photo-id` or Zoho preview/download patterns.
  - Fetch the image bytes with `Referer` set to the profile report URL and convert to Base64 data URI (`data:image/jpeg;base64,...`) for offline SQLite storage.

#### C. Marks Parser (`My_Time_Table_2023_24` / Academic Report)
- Find the first `table` whose extracted headers contain `Test Performance`.
- For each direct row:
  - Cell 0: `courseCode`
  - Cell 1: `courseType`
  - Cell 2: Nested cells for individual tests. Split each test cell by lines: Line 0 is `testName` (often formatted as `FT-I/5.00`, from which `testName` and `maxMarks` are separated on `/`), and remaining lines form `marksObtained` (`score`). Compute `percentage = (obtained / max) * 100`.

#### D. Personal + Unified Timetable Parser
1. **Personal Timetable (`My_Time_Table_2023_24`):**
   - **Advisor Table:** Table whose headers contain `Counselor` → extract `name`, `role`, `email`, `phone`.
   - **Course Table:** Table whose headers contain both `Course Code` and `Slot` → extract `courseCode`, `courseTitle`, `credit`, `category`, `courseType`, `facultyName`, `slot`, `roomNo`.
2. **Unified Timetable (`Unified_Time_Table_2025_Batch_1` or `Batch_2` based on `studentInfo.Batch`):**
   - Find table whose first cell is exactly `FROM`.
   - Row 0 provides `timing` strings per column index (`hourIndex`).
   - Subsequent rows starting with `Day` (e.g., `Day 1` .. `Day 5`) contain slot tokens (split cell text by `/`, `-`, `,`, or whitespace).
   - Map every slot token → `{day, hourIndex, timing, slotToken}`.
   - Split each personal course's `Slot` string into tokens, join with the unified slot map, and sort each course's resulting `schedule` list by day number and `hourIndex`.

#### E. Heuristic Academic Calendar Parser (`Academic_Reports` + Legacy Planner Fallbacks)
- Scan all `table` elements, inspecting the first 5 rows of each table.
- Match cells against month regex:
  `RegExp(r'^(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)\b', caseSensitive: false)`
- Pick the row with the highest number of month-matching cells as the header row.
- **Column Offset Detection:**
  - Where a month header cell appears at column index `i >= 2`, assign:
    - `dtCol = i - 2` (Date of month)
    - `dayCol = i - 1` (Weekday: Mon, Tue, etc.)
    - `eventCol = i` (Holiday/Event description)
    - `doCol = i + 1` (Day Order: `1`..`5` or `-`)
  - **Fallback (if no month group at `i >= 2` but row has `>= 4` cells):** Group columns in blocks of 5 (`dtCol = i`, `dayCol = i+1`, `eventCol = i+2`, `doCol = i+3`).
- Walk rows below the header row, skip empty `date` cells, and emit `CalendarMonth(name, days: [CalendarDay(date, day, event, dayOrder)])`.

---

## 3. SRM Student Portal Scraper (`lib/scrapers/student_portal/`)

### 3.1 Endpoints & Constants
```dart
const String spBaseURL = 'https://sp.srmist.edu.in';
const String spLoginURL = '$spBaseURL/srmiststudentportal/students/loginManager/youLogin.jsp';
const String spLoginPostURL = '$spBaseURL/srmiststudentportal/LoginServlet';
const String spDashboardURL = '$spBaseURL/srmiststudentportal/students/template/HRDSystem.jsp';
const String spAttendanceURL = '$spBaseURL/srmiststudentportal/students/report/studentAttendanceDetails.jsp';
const String spMarksURL = '$spBaseURL/srmiststudentportal/students/report/studentInternalMarkDetails.jsp';
```

### 3.2 `SECURE_CONFIG` Extraction & CAPTCHA Fetch (`sp_client.dart`)
1. `GET $spLoginURL`.
2. Extract dynamic security configuration using exact regexes:
   - `captchaText`: `RegExp(r"SECURE_CONFIG\.captchaText\s*=\s*'([^']+)'")` *(Note: decoy text; do not submit as answer)*
   - `captchaFieldName`: `RegExp(r"SECURE_CONFIG\.captchaFieldName\s*=\s*'([^']+)'")`
   - `domainFieldName`: `RegExp(r"SECURE_CONFIG\.domainFieldName\s*=\s*'([^']+)'")`
   - `randomDelimiter`: `RegExp(r"SECURE_CONFIG\.randomDelimiter\s*=\s*'([^']+)'")`
   - `challengeId`: `RegExp(r'id="challengeId"\s+value="([^"]+)"')`
   - `fpNonce`: `RegExp(r'id="fpNonce"\s+value="([^"]+)"')`
   - `nonce`: `RegExp(r"nonce\s*:\s*'([^']+)'")`
3. Collect all honeypot field names via CSS selector `input[name^=ph_]` (preserve DOM order).
4. Extract CAPTCHA image URL from `img#secure_captcha` attribute `data-src` (prefix with `spBaseURL` if it starts with `/`).
5. Compute `X-Domain-Proof` header:
   ```dart
   final String domainProof = base64Encode(utf8.encode('${config.nonce}:sp.srmist.edu.in'));
   ```
6. Fetch CAPTCHA image (`GET $captchaUrl`) with headers:
   - `Referer: $spLoginURL`
   - `Accept: image/png,image/jpeg,image/svg+xml,image/*`
   - `X-Domain-Proof: $domainProof`
7. Pass image bytes to `SpCaptchaSolver` (ONNX `ddddocr_common.onnx` model).

### 3.3 Exact DOM-Ordered Login Form Construction (`POST /srmiststudentportal/LoginServlet`)
Strip `@srmist.edu.in` from `email` to get `netID`. Assemble form fields in this **exact order**:
1. `username=${Uri.encodeQueryComponent(netID)}`
2. `password=${Uri.encodeQueryComponent(password)}`
3. For each `phName` in `honeypotNames`: `${Uri.encodeQueryComponent(phName)}=` (empty value)
4. `captcha=${Uri.encodeQueryComponent(solvedCaptcha)}`
5. `fpPayload=`
6. `fpToken=`
7. `telemetryPayload=${Uri.encodeQueryComponent(base64TelemetryJson)}`
   Where `telemetryJson` is:
   ```json
   {
     "startTime": "<nowMs - 5000>",
     "currentDomain": "sp.srmist.edu.in",
     "timezoneOffset": -330,
     "screenWidth": 1920,
     "screenHeight": 1080,
     "colorDepth": 24,
     "devicePixelRatio": 1,
     "platform": "Win32",
     "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
     "language": "en-US",
     "hardwareConcurrency": 8,
     "deviceMemory": 8,
     "touchSupport": false,
     "webdriver": false,
     "mouseClicks": 1,
     "mouseMovements": 5,
     "keystrokeCount": 10,
     "typingSpeedMs": 5000,
     "canvasHash": "a1b2c3d4e5f6",
     "submitTime": "<nowMs>",
     "timeOnPageMs": 5000
   }
   ```
8. If `domainFieldName` is non-empty:
   ```dart
   final String reversedHost = 'sp.srmist.edu.in'.split('').reversed.join(); // 'ni.ude.tsimrs.ps'
   final String encodedHost = base64Encode(utf8.encode(reversedHost));
   ```
   Append `${Uri.encodeQueryComponent(domainFieldName)}=${Uri.encodeQueryComponent(encodedHost)}`.
9. If `captchaFieldName` is non-empty:
   ```dart
   int timeElapsed = DateTime.now().difference(pageLoadTime).inSeconds;
   if (timeElapsed < 3) {
     timeElapsed = 3 + (config.randomDelimiter.codeUnitAt(0) % 10);
   }
   final int interactCount = 5 + (timeElapsed % 10);
   final String trapPayload = '$timeElapsed${config.randomDelimiter}$interactCount';
   final String encodedTrap = base64Encode(utf8.encode(trapPayload));
   ```
   Append `${Uri.encodeQueryComponent(captchaFieldName)}=${Uri.encodeQueryComponent(encodedTrap)}`.
10. If `domainFieldName` is non-empty, append `${Uri.encodeQueryComponent(domainFieldName)}=${Uri.encodeQueryComponent(encodedHost)}` **a second time**.

Join all parts with `&` and `POST` to `spLoginPostURL` with headers:
- `Referer: $spLoginURL`
- `Origin: https://sp.srmist.edu.in`
- `Content-Type: application/x-www-form-urlencoded`
- `Upgrade-Insecure-Requests: 1`
- `Sec-Fetch-Dest: document`, `Sec-Fetch-Mode: navigate`, `Sec-Fetch-Site: same-origin`, `Sec-Fetch-User: ?1`

Check response: if `div.alert-danger` is present or final URL is still `youLogin.jsp`, treat as CAPTCHA/auth failure.

### 3.4 Student Portal Data Requests & Parsers (`sp_parsers.dart`)
Before fetching Attendance or Marks, issue `GET $spDashboardURL` to establish dashboard context.
1. **Attendance & Profile (`POST $spAttendanceURL`):**
   - Headers: `Referer: $spDashboardURL`, `X-Requested-With: XMLHttpRequest`, `Content-Type: application/x-www-form-urlencoded`.
   - Body: `iden=9&filter=&hdnFormDetails=1&csrfPreventionSalt=`
   - **Table Selection:** First table whose headers contain `Attn`, `Attendance`, both `%` and `Course`, or both `Percentage` and `Code` (fallback: first table with `>= 5` header cells).
   - **Permissive Header Mapping:**
     - `courseCode`: `['Course Code', 'courseCode', 'Subject Code', 'Code']`
     - `courseTitle`: `['Course Title', 'courseTitle', 'Subject', 'Course', 'Subject Name', 'Description']`
     - `category`: `['Category', 'category', 'Type']`
     - `facultyName`: `['Faculty Name', 'facultyName', 'Faculty', 'Teacher']`
     - `slot`: `['Slot', 'slot']`
     - `roomNo`: `['Room No', 'roomNo', 'Room', 'Room Number']`
     - `hoursConducted`: `['Hours Conducted', 'hoursConducted', 'Conducted', 'Total Hours', 'Max. hours']`
     - `hoursAbsent`: `['Hours Absent', 'hoursAbsent', 'Absent', 'Absent hours']`
     - `attendancePct`: `['Attn %', 'Attendance %', 'attendancePct', 'Percentage', '%', 'Attn', 'Total Percentage']`
2. **Internal Marks (`POST $spMarksURL`):**
   - Headers: `Referer: $spDashboardURL`, `X-Requested-With: XMLHttpRequest`, `Content-Type: application/x-www-form-urlencoded`.
   - Body: `iden=13&filter=&hdnFormDetails=1&csrfPreventionSalt=`
   - **Table Selection:** First table whose headers contain both `Code` and `Mark`.
   - **Row Parsing:** Cell 0 = `courseCode`, Cell 1 = `courseDescription`, Cell 2 = `obtained/maxMark` (split on `/` into `obtained` and `maxMark`).

---

## 4. Faculty Directory Scraper (`lib/scrapers/faculty/`)

### 4.1 Search & Profile URLs
- **Base URL:** `https://www.srmist.edu.in`
- **Search URL:** `https://www.srmist.edu.in/?s=${Uri.encodeQueryComponent(name)}&post_type=faculty`
  - Select `article a[href]`, keep URLs containing `/faculty/`, trim trailing `/`, extract last path segment as `slug`, and deduplicate.
- **Direct Slug Fallback:** Lowercase `name`, replace `RegExp(r'[^a-z0-9]+')` with `'-'`, trim leading/trailing `'-'`.
- **Profile URL:** `https://www.srmist.edu.in/faculty/$slug/`

### 4.2 Exact Profile Selectors (`faculty_parser.dart`)
- `name`: `meta[property='og:title']` `content` attribute (strip trailing `SRMIST` and separators).
- `photo_url`: Scan all `script` tags with `RegExp(r'"featuredImage"\s*:\s*"(https:[^"]+\.(?:jpg|jpeg|png|webp))"', caseSensitive: false)` and unescape `\/` → `/`.
- `designation`, `email`, `department`: Select `div.hide_empty_list_item .elementor-icon-list-items .elementor-icon-list-item .elementor-icon-list-text`:
  - Item 0 → `designation`
  - First item containing `'@'` → `email`
  - Item 1 (if it does not contain `'@'`) → `department`
- `campus`: Select `.faculty-cdc`, strip `CAMPUS:` prefix, collapse whitespace.
- `experience`, `research_interest`, `courses`: Select `div[data-widget_type='text-editor.default'] .elementor-widget-container`, match text prefix `EXPERIENCE`, `RESEARCH INTEREST`, or `COURSES` (strip prefix + optional space + `:`).
- **Accordion Tabs (`.elementor-tab-title` & `.elementor-tab-content` matched by `data-tab` attribute):**
  - Title contains `'education'` → `education`
  - Title contains `'publication'` → `publications`
  - Title contains `'award'` → `awards`
  - Title contains `'workshop'`, `'seminar'`, or `'conference'` → `workshops`
  - Title contains `'work experience'` → `work_experience`
  - Title contains `'membership'` → `memberships`
  - Title contains `'responsibilit'` → `responsibilities`