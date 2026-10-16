# AGENTS.md — Autonomous Coding Agent Operating Manual (`SRMOne` → Flutter Mobile Migration)

## 1. Mission & Architectural Mandate
You are migrating the forked **`SRMOne`** web/Go/Node/Supabase repository into a **100% Local-First, Zero-Server Native Mobile Application (iOS & Android)** built in **Flutter (Dart)** inside a new root directory named `srmone_mobile/`.

### Core Non-Negotiable Constraints
1. **ZERO Hosted Server Dependency:** Do NOT call `academia-backend/backend/api/server.js`, Supabase cloud tables, or the Cloudflare Worker relay by default. Every student's mobile device executes its own HTTP scraping, HTML parsing, CAPTCHA OCR solving, schedule computation, and SQLite persistence locally on-device using the student's residential/cellular IP.
2. **Preserve Existing Forked Reference Code:** Keep `academia-backend/`, `supabase/`, and `relay/` untouched in the repository root as reference implementations and fixture sources while building `srmone_mobile/`.
3. **Never Bundle PII or All 3,447 SVGs:**
   - Do NOT copy the entire `assests-downloaded/` or `academia-backend/frontend/public/assets/` folders into `srmone_mobile/assets/`. Copy **only** the 13 actively referenced SVGs and `logo.png` listed in `plan.md`.
   - Before copying `student_resp.json`, `marks_resp.json`, `timetable_resp.json`, or `sp_*_response.html` into `srmone_mobile/test/fixtures/`, sanitize all real student names, registration numbers, phone numbers, advisor emails, and Base64 photo strings.
4. **Zero-Logout Live Attendance Refresh:** Implement the 4-layer Stale-While-Revalidate + Zoho cache-busting (`?_t=<epoch_ms>` + `Cache-Control: no-cache`) + Silent Background Cookie Rotation + Dual-Source (Academia vs. Student Portal `hoursConducted`) sync engine specified in `architecture.md`.

---

## 2. Document Map (Read Order Before Coding)
Always consult these files in the repository root before writing or modifying code:
1. **`AGENTS.md`** (This file): Operational guardrails, verification rules, and phase gates.
2. **`architecture.md`**: Target Flutter system design, folder structure, `Drift` SQLite schema, `flutter_secure_storage` vault contract, Riverpod state graph, and the Zero-Logout Auto-Refresh engine.
3. **`SCRAPER_SPEC.md`**: Exact byte-for-byte HTTP endpoints, headers, custom `SimpleCookieJar` behavior, regexes, Zoho `pageSanitizer.sanitize('...')` byte-scanner, Student Portal `SECURE_CONFIG` trap math, and HTML CSS selectors ported from the Go scrapers.
4. **`plan.md`**: File-by-file reusability matrix, exact math formulas (including the 5 required bug fixes from the web version), component transformation specs, and the 7-phase implementation roadmap.
5. **`IOS_BUILD_GUIDE.md`**: GitHub Actions macOS CI/CD workflow and Xcode/Unsigned/TestFlight configuration for building the iPhone `.ipa` from a Windows development environment.

---

## 3. Mandatory Bug Fixes Over the Legacy Web/Server Implementation
When translating logic from `academia-backend/` to `srmone_mobile/`, you MUST enforce these 6 verified fixes:
1. **Attendance Auto-Refresh Without Logout:** Never lock attendance behind an in-memory 30-minute session cache. Always serve cached SQLite data immediately (`0ms`), trigger a background scrape with cache-busting headers, and if the Zoho session returns stale/403/redirect, silently re-authenticate using credentials in `flutter_secure_storage` and swap the cookie jar without logging the user out.
2. **100% Target Division-by-Zero Guard (`AttendancePlanner`):** In Reach Target mode, the formula `ceil((T * C - 100 * P) / (100 - T))` divides by zero when `T == 100`. Explicitly guard `T == 100`: if `absent > 0`, mark as unreachable (`needed = -1`, UI displays `"Cannot reach 100% (missed $absent hr)"`); if `absent == 0`, `needed = 0`.
3. **Overall Attendance Consistency:** Standardize on **both** values clearly labeled in the domain model:
   - `unweightedMeanPct`: arithmetic mean of each subject's `attendancePct` (matches legacy `Attendance.jsx` header and snapshot).
   - `weightedOverallPct`: `(totalPresent / totalConducted) * 100` (used for mathematically consistent holiday projection comparisons).
4. **Unified Calendar & Holiday Day-Order Resolver:** Merge the conflicting holiday logic between `backend/utils/schedule_utils.js` and `frontend/src/utils/calendarTimetableSync.js` into a single `CalendarDayResolver` Dart class.
5. **Notification Unread Count Integrity:** Never manually increment/decrement `unreadCount` in memory on `UPDATE` events (which caused negative drift in `useNotifications.js`). Compute `unreadCount` via a reactive Drift SQLite stream: `SELECT COUNT(*) FROM notifications WHERE read = 0`.
6. **Strict Separate Models for Academia vs. Student Portal Marks:** Keep parser logic separate (`AcademiaMarksParser` parses test-level rows; `SpMarksParser` parses course-total `obtained/maxMark` rows and wraps them into a single synthetic test named `"Total (Internal)"` with `source: "student_portal"`). Never invent letter grades or sum test scores unless explicitly present.

---

## 4. Execution & Verification Protocol (Phase Gates)
Execute the migration strictly in the order defined in `plan.md` (Phase 0 through Phase 6). **Do not advance to the next phase until all verification commands for the current phase pass with zero errors.**

### Required Verification Commands Per Phase
```bash
cd srmone_mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze --no-fatal-infos
flutter test
```