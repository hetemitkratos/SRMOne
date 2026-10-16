# plan.md — Complete Module Reusability Matrix, Component Specs & 7-Phase Migration Plan

## 1. Complete Repository Reusability & Transformation Matrix

Every file and directory in the forked `SRMOne` repository is mapped below so the coding agent knows what to copy, what to port to Dart, and what to retire.

### 1.1 Backend, Scrapers & Infrastructure (`academia-backend/`, `supabase/`, `relay/`)

| Existing File / Module | Action | Target in `srmone_mobile/` | Exact Changes Required |
|---|---|---|---|
| `academia-scraper/cmd/loginprobe/client.go` | **Port Logic to Dart** | `lib/core/network/simple_cookie_jar.dart` & `manual_redirect_client.dart` | Replicate hostname-keyed `SimpleCookieJar` (deleting on `""`/`"delete"`/`"null"`) and 10-hop manual redirect loop (`301`/`302`/`303` POST → GET). |
| `academia-scraper/cmd/loginprobe/login.go` | **Port Logic to Dart** | `lib/scrapers/academia/academia_client.dart` | Implement 6-step Zoho login (`signin` → `locate` → `lookup` → `password` with `application/x-www-form-urlencoded` JSON body → redirect → 6-step continuation unblocker). |
| `academia-scraper/cmd/loginprobe/parsers.go` | **Port Logic to Dart** | `lib/scrapers/academia/academia_decoder.dart` & `academia_parsers.dart` | Implement `pageSanitizer.sanitize('...')` byte-scanner, `[zmlvalue]` unescaper, and CSS table parsers for Attendance, Profile, Photo, Marks, Personal+Unified Timetable, and Heuristic Calendar. |
| `academia-scraper/cmd/studentportal/login.go` | **Port Logic to Dart** | `lib/scrapers/student_portal/sp_client.dart` | Implement `SECURE_CONFIG` regex parser, `input[name^=ph_]` honeypot collector, `X-Domain-Proof` header, `telemetryPayload`, reversed hostname `dtoken_*` (x2), and `cptoken_*` trap payload. |
| `academia-scraper/solve_captcha.py` & `captcha.go` | **Replace with ONNX + UI** | `lib/scrapers/student_portal/sp_captcha_solver.dart` & `sp_captcha_bottom_sheet.dart` | Bundle `ddddocr_common.onnx` (`assets/ml/`) for offline inference via `onnxruntime`, plus manual bottom sheet fallback if `div.alert-danger` appears. Drop 2Captcha network API. |
| `academia-scraper/cmd/studentportal/parsers.go` & `marks.go` | **Port Logic to Dart** | `lib/scrapers/student_portal/sp_parsers.dart` | Implement `iden=9` attendance/profile parser (permissive header variants) and `iden=13` internal marks parser (`obtained/maxMark` split on `/`). |
| `faculty-scraper/scraper/scraper.go` & `models/faculty.go` | **Port Logic to Dart** | `lib/scrapers/faculty/faculty_client.dart` & `faculty_parser.dart` | Query `https://www.srmist.edu.in/?s=...&post_type=faculty`, parse `/faculty/{slug}/` using Elementor selectors and `featuredImage` regex, cache in SQLite `FacultyCache`. |
| `backend/api/server.js` | **Replace with On-Device Orchestrator** | `lib/domain/services/session_sync_orchestrator.dart` | Eliminate 30-min in-memory session cache and `MAX_USERS = 8` limit. Implement 4-layer Zero-Logout Attendance Refresh (SWR + Cache-Busting + Silent Re-Auth + Dual-Source Sync). |
| `backend/utils/crypto.js` | **Replace with Hardware Vault** | `lib/core/security/secure_vault_service.dart` | Replace unauthenticated `aes-256-cbc` DB strings with hardware-backed `flutter_secure_storage` (iOS Keychain / Android Keystore). |
| `backend/utils/schedule_utils.js` | **Unify & Port to Dart** | `lib/domain/services/calendar_day_resolver.dart` | Combine with `calendarTimetableSync.js` into a single deterministic day-order and daily schedule builder. |
| `backend/utils/supabaseClient.js` & `supabase/migrations/*.sql` | **Port Schema to SQLite (`Drift`)** | `lib/core/database/app_database.dart` & `notification_rule_engine.dart` | Create 10 local SQLite tables in `Drift`. Port `maybeNotifyLowAttendance`, `welcome`, and `holiday_alert` rules with exact 18h/6h fingerprint deduplication. |
| `relay/cf-worker/src/index.js` | **Retire as Default (Optional Hook)** | `lib/core/network/sp_transport.dart` | Default to direct HTTPS requests from the student's phone IP. Allow optional custom relay URL in Advanced Settings without shipping any server secret. |
| `student_resp.json`, `marks_resp.json`, `timetable_resp.json`, `sp_*.html` | **Sanitize & Reuse for Tests** | `srmone_mobile/test/fixtures/` | Strip all real student PII and Base64 photos, then use as automated unit-test fixtures for Dart parsers. |

---

### 1.2 Frontend Hooks, Utilities & Assets (`academia-backend/frontend/src/`)

| Existing Frontend File | Action | Target in `srmone_mobile/` | Exact Changes Required |
|---|---|---|---|
| `src/api/client.js` | **Replace with Local Repository Calls** | `lib/domain/services/session_sync_orchestrator.dart` | Replace all 28 HTTP `/api/*` wrapper functions with direct calls to local `Drift` DAOs and background scraper isolates. |
| `src/hooks/useAuth.jsx` | **Port to Riverpod Notifier** | `lib/features/auth/auth_controller.dart` | Replace insecure `localStorage['srm_user']` with `SecureVaultService` check + optional `BiometricAuthService` (`local_auth`) gate on launch. |
| `src/hooks/useNotifications.js` | **Port to Drift Reactive Stream** | `lib/features/notifications/notifications_controller.dart` | Replace Supabase Realtime channel with `appDatabase.watchNotifications()`. **Bug Fix:** Derive `unreadCount` from `SELECT COUNT(*) WHERE read = 0` stream to eliminate decrement drift. |
| `src/hooks/useSettings.js` | **Port to Drift + Riverpod** | `lib/features/settings/settings_controller.dart` | Persist `theme`, `defaultView`, `attendanceThreshold`, `calendarView`, `timetableView`, `showWeekends`, `biometricLockEnabled` directly in SQLite `UserSettingsTable`. |
| `src/utils/calendarTimetableSync.js` | **Unify & Port to Dart** | `lib/domain/services/calendar_day_resolver.dart` | Preserve `parseMonthName` (`Aug '26` / `August 2026`), local `YYYY-MM-DD` date keys (never UTC), `getDayStatus`, and unify holiday detection with `schedule_utils.js`. |
| `src/utils/timetableExporter.js` | **Rewrite for Native Mobile** | `lib/domain/services/timetable_image_exporter.dart` | Replace browser `html2canvas` with Flutter `ScreenshotController` + `RepaintBoundary` rendering `ExportableTimetablePoster` (same 9-color course palette, `cleanName()`, `getInitials()`) + `share_plus` / `gal`. |
| `public/assets/*` (3,447 SVGs) | **Prune & Copy ONLY 14 Files** | `srmone_mobile/assets/` | Copy ONLY `logo.png` and the 13 referenced SVGs: `a-day-off_uk4x.svg`, `calendar_8r6s.svg`, `chilling_o2zv.svg`, `coffee-time_98vi.svg`, `events-calendar_sudy.svg`, `learning_qt7d.svg`, `online-learning.svg`, `studying.svg`, `success_288d.svg`, `target_d6hf.svg`, `time-management_4ss6.svg`, `travel-plans_l0fo.svg`, `vacation-selfie_q5bs.svg`. |

---

### 1.3 Frontend Pages & UI Components (`academia-backend/frontend/src/pages/` & `components/`)

| Existing JSX Component / Page | Target Flutter Widget / Screen | Required UI & Logic Adjustments |
|---|---|---|
| `pages/Login.jsx` | `features/auth/login_screen.dart` | Native `Form` with `@srmist.edu.in` auto-append, password visibility toggles, optional Student Portal password expandable field, Terms checkbox, rotating placeholder hint, and inline `SpCaptchaBottomSheet` trigger. |
| `pages/Dashboard.jsx` | `features/shell/dashboard_shell_screen.dart` | `Scaffold` with bottom `NavigationBar` (Overview, Attendance, Timetable, Marks, Calendar), top `AppBar` with `NotificationBell`, student avatar trigger for profile/settings drawer, and active sync status pill. |
| `pages/Overview.jsx` | `features/overview/overview_screen.dart` | Pull-to-refresh (`RefreshIndicator`), current week strip (`Mon`–`Fri`) with Day Order pills, selected day classes sorted by `hourIndex`, and **new Clock-Based Current/Upcoming Class highlight badge**. |
| `pages/Attendance.jsx` | `features/attendance/attendance_screen.dart` | Summary header (`overallPct`, `above75`, `below75`), subject cards sorted by descending `attendancePct` with fixed 75% status badges (`>=75` Good, `50..74.9` Warning, `<50` Danger), `fl_chart` 30-day trend chart, Student Portal reconnect banner, and embedded `AttendancePlannerCard`. |
| `components/AttendancePlanner.jsx` | `features/attendance/widgets/attendance_planner_card.dart` | Two-tab segmented control (`Reach Target` with slider `50..100%` and `Plan Holiday` with native date range picker). Includes **`T=100` division-by-zero fix** and displays both unweighted and weighted overall percentages. |
| `pages/Marks.jsx` | `features/marks/marks_screen.dart` | Enriches course codes with `courseTitle` from cached timetable. Renders expandable cards (`ExpansionTile` / animated accordion) for Academia test rows (`testName`, `marksObtained`, `maxMarks`, progress bar capped at `100%`) or Student Portal fallback (`"Total (Internal)"`). |
| `pages/Timetable.jsx` | `features/timetable/timetable_screen.dart` | Horizontal swipeable `TabBarView` / `PageView` across `Day 1` – `Day 5` (auto-focused on today's effective day order), advisor contact cards, and 1-tap "Export PNG / Share" button. |
| `pages/Calendar.jsx` | `features/calendar/calendar_screen.dart` | Semester toggle (`Odd` / `Even`), month selector (`PageView` or dropdown), daily list with Holiday / Working Day / Day Order badges, and `HolidayGif` card. |
| `pages/Privacy.jsx` & `Terms.jsx` | `features/settings/legal_markdown_screen.dart` | Native scrollable legal viewer accessible from both `LoginScreen` and `SettingsScreen` (mandatory for Apple App Store review). |
| `components/FacultyAvatar.jsx` & `FacultyProfileModal.jsx` | `features/faculty/faculty_avatar.dart` & `faculty_profile_sheet.dart` | Cached network avatar (`cached_network_image`) + draggable modal bottom sheet (`showModalBottomSheet`) that scrapes & caches faculty profile on-demand from `www.srmist.edu.in`. |
| `components/HolidayGif.jsx` | `features/calendar/widgets/holiday_illustration.dart` | Renders `assets/illustrations/chilling_o2zv.svg` offline by default (optional Giphy API key support if configured). |
| `components/ImagePreview.jsx` | `features/shell/widgets/fullscreen_image_viewer.dart` | Native `InteractiveViewer` hero dialog with pinch-to-zoom for student/faculty photos. |
| `components/NotificationBell.jsx` | `features/notifications/notification_bell_sheet.dart` | Badge icon in `AppBar` watching reactive SQLite unread count stream; opens modal sheet displaying latest notifications with "Mark all as read". |
| `components/InstallPrompt.jsx` | **Drop / Delete** | Not applicable to native iOS/Android apps. |
| `components/BackgroundOrbs.jsx` | `core/theme/ambient_background.dart` | Lightweight GPU shader / `RadialGradient` container (avoids heavy DOM blur battery drain). |

---

## 2. Exact Domain Math & Business Logic Specifications

### 2.1 Main Attendance Screen Card Math (`attendance_screen.dart`)
- **Sorting:** Sort subjects by `attendancePct` descending: `b.attendancePct.compareTo(a.attendancePct)`.
- **Summary Header Metrics:**
  - `unweightedOverallPct`: `(records.fold(0.0, (s, r) => s + r.attendancePct) / records.length)` formatted to 1 decimal place.
  - `weightedOverallPct`: `(totalPresent / totalConducted) * 100`.
  - `above75 = records.where((r) => r.attendancePct >= 75.0).length`
  - `below75 = records.length - above75`
- **Per-Subject Card Status (Fixed 75% Threshold):**
  - `present = conducted - absent`
  - `isGood = pct >= 75.0`
  - `isWarning = pct >= 50.0 && pct < 75.0`
  - `isDanger = pct < 50.0`
  - If `pct >= 75.0`: `bunkable75 = ((present - 0.75 * conducted) / 0.75).floor().clamp(0, 9999)`
  - If `pct < 75.0`: `needed75 = ((0.75 * conducted - present) / 0.25).ceil().clamp(0, 9999)`

### 2.2 Attendance Planner Math (`attendance_planner_math.dart`)

#### Mode A: Reach Target (`T` from `50` to `100`, default `75`)
For each subject with `C = hoursConducted`, `A = hoursAbsent`, `P = C - A`, `pct = C > 0 ? (P / C) * 100 : 0.0`:
1. **Guard for `T == 100` (Fixes Web Division-by-Zero Bug):**
   - If `T == 100`:
     - If `A > 0`: `needed = -1` (flag `isUnreachable100 = true`), `bunkable = 0`, `newPct = pct`.
     - If `A == 0`: `needed = 0`, `bunkable = 0`, `newPct = C > 0 ? 100.0 : 0.0`.
2. **Standard Case (`50 <= T < 100`):**
   - If `C > 0 && pct < T`:
     $$\text{needed} = \max\left(0, \left\lceil \frac{T \cdot C - 100 \cdot P}{100 - T} \right\rceil\right)$$
     $$\text{newPct} = \text{needed} > 0 ? \frac{100 \cdot (P + \text{needed})}{C + \text{needed}} : \text{pct}$$
   - If `C > 0 && pct >= T`:
     $$\text{bunkable} = \max\left(0, \left\lfloor \frac{100 \cdot P}{T} - C \right\rfloor\right)$$
     $$\text{needed} = 0, \quad \text{newPct} = \text{pct}$$
- **Sorting:** Sort by descending `needed` (treating unreachable `-1` at the top when `T == 100`), then descending `pct`.

#### Mode B: Plan Holiday (`fromDate` to `toDate` inclusive)
1. Walk every local calendar date `cur` from `fromDate` to `toDate` inclusive:
   - Resolve status via `CalendarDayResolver.getDayStatus(calendarMap, cur)`.
   - If `calendarMap` is non-empty: count `cur` as a working day **only** when `status.type == DayStatusType.working` with `dayLabel = 'Day ${status.dayOrderNum}'`.
   - If `calendarMap` is empty: fallback to weekday `Mon = Day 1` .. `Fri = Day 5` (exclude `Sat`/`Sun`).
2. Index timetable slots by `slot.day` (`'Day 1'` .. `'Day 5'`). Each matching slot on `dayLabel` increments `missedForSubject[courseCode]` by `1`.
3. For each subject with `M = missedForSubject[courseCode]`:
   - `newConducted = C + M`
   - `newPct = newConducted > 0 ? (P / newConducted) * 100.0 : 0.0`
   - `drop = pct - newPct`
   - `willDropBelow75 = (pct >= 75.0) && (newPct < 75.0)`
   - If `newPct < 75.0`:
     $$\text{recoveryNeeded} = \max\left(0, \left\lceil \frac{75 \cdot \text{newConducted} - 100 \cdot P}{25} \right\rceil\right)$$

### 2.3 Unified Calendar & Day-Order Resolver (`calendar_day_resolver.dart`)
Fixes the discrepancy between `schedule_utils.js` and `calendarTimetableSync.js`:
- **Local Date Keys Only:** Format `DateTime` as `YYYY-MM-DD` using local `.year`, `.month`, `.day` (never `.toUtc()`).
- **Month Name Parser (`parseMonthName`):** Accepts both `Aug '26` and `August 2026` (2-digit years `YY` mapped to `2000 + YY`).
- **Unified Holiday & Working Day Rule:**
  - `dayOrderNum`: parsed integer if `dayOrder` is `'1'`..`'5'`; `null` if `'-'`, `''`, or non-numeric.
  - `isWeekend`: `day == 'Sat' || day == 'Sun'` (or `date.weekday == DateTime.saturday || date.weekday == DateTime.sunday`).
  - `isHoliday`: `event.toLowerCase().contains('holiday')` **OR** (`!isWeekend && dayOrderNum == null && event.trim().isNotEmpty`).
  - `isWorkingDay`: `dayOrderNum != null && !isHoliday`.

### 2.4 Current & Upcoming Class Clock Detector (`current_class_detector.dart`)
New explicit mobile enhancement for `OverviewScreen` and `TimetableScreen`:
- Parse `slot.timing` (e.g., `"08:00 - 08:50"` or `"13:25 - 14:15"`, handling 12-hour PM rollover for afternoon hours `01:xx`–`05:xx` by adding 12 hours when hour `< 7`) into `startMinutes` and `endMinutes` since local midnight.
- Compare against `nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute`:
  - **`ClassTimeState.ongoing`**: `nowMinutes >= startMinutes && nowMinutes < endMinutes` (renders pulsing green `"LIVE NOW"` pill + progress bar).
  - **`ClassTimeState.upcomingNext`**: First slot where `startMinutes > nowMinutes` (renders `"UP NEXT · in X min"` pill).
  - **`ClassTimeState.completed`**: `endMinutes <= nowMinutes`.

### 2.5 On-Device Notification Rule Engine (`notification_rule_engine.dart`)
Executed automatically after every foreground or `WorkManager` background sync:
1. **Daily Snapshot Upsert:** Before checking notification preferences, compute `unweightedOverallPct` and `weightedOverallPct` and upsert today's row (`YYYY-MM-DD`) in `AttendanceSnapshots`.
2. **`low_attendance` Rule:**
   - Check `notificationSettings.attendanceAlertEnabled`.
   - Effective threshold `T = (notificationSettings.attendanceThreshold > 0) ? notificationSettings.attendanceThreshold : 75.0`.
   - Filter subjects with `attendancePct < T`. If empty, return.
   - Build deterministic fingerprint: sort below-threshold subjects by `courseCode` ascending, join as `'${code}:${pct.round()}'` separated by `','`.
   - Query latest `low_attendance` row in SQLite `NotificationsTable`:
     - Suppress if latest row is `< 6 hours` old.
     - Suppress if latest row has the **same `fingerprint`** and is `< 18 hours` old.
   - Otherwise, insert into `NotificationsTable` (`title: 'Low Attendance Alert'`, `body: '${below.length} subject(s) below ${T.toStringAsFixed(0)}%: ...Check the attendance page for details.'`) and trigger a native OS notification via `flutter_local_notifications`.
3. **`welcome` Rule:** On first successful Academia login where `NotificationsTable` has zero rows with `type == 'welcome'`, insert `'Welcome to SRM One! 🎉'`.
4. **`holiday_alert` Rule:** After calendar sync, scan `today` through `today + 7 days` for `isHoliday == true`. If found and no unread `holiday_alert` exists in SQLite, insert `'📅 Upcoming Holiday'`.

---

## 3. Phased Execution Plan for the Coding Agent

### Phase 0: Workspace Bootstrap, Asset Pruning & Fixture Sanitization
1. Run `flutter create --org in.srmone --project-name srmone_mobile srmone_mobile` at the root of the forked repository.
2. Configure `pubspec.yaml` with `flutter_riverpod`, `go_router`, `dio`, `html`, `drift`, `sqlite3_flutter_libs`, `path_provider`, `flutter_secure_storage`, `local_auth`, `fl_chart`, `flutter_svg`, `lucide_icons_flutter`, `flutter_animate`, `cached_network_image`, `screenshot`, `share_plus`, `gal`, `workmanager`, `flutter_local_notifications`, `onnxruntime`, `image`, `home_widget`, `device_calendar`, `freezed_annotation`, `json_annotation`.
3. Copy **only** `logo.png` and the 13 active SVGs from `academia-backend/frontend/public/assets/` into `srmone_mobile/assets/`.
4. Create sanitized copies of `student_resp.json`, `marks_resp.json`, `timetable_resp.json`, `sp_attendance_response.html`, `sp_dashboard_response.html`, and `sp_login_response.html` inside `srmone_mobile/test/fixtures/` with all personal student data replaced by synthetic values.
- **Verification Gate:** `flutter pub get && flutter analyze` passes with 0 errors.

### Phase 1: Local SQLite (`Drift`), Hardware Vault & Domain Math Layer
1. Implement `SecureVaultService` (`flutter_secure_storage`) and `BiometricAuthService` (`local_auth`).
2. Implement `AppDatabase` (`Drift`) with all 10 tables and reactive stream DAOs (including reactive `watchUnreadNotificationCount()`).
3. Implement `CalendarDayResolver`, `AttendancePlannerMath` (with `T=100` guard), `CurrentClassDetector`, and `NotificationRuleEngine`.
4. Write comprehensive unit tests in `test/domain/` covering Reach Target (`T=75`, `T=100` with `absent > 0` and `absent == 0`), Plan Holiday, and Calendar Day Order resolution.
- **Verification Gate:** `flutter test test/domain/` passes 100%.

### Phase 2: Pure Dart Scrapers (Academia, Student Portal, Faculty) & ONNX CAPTCHA
1. Implement `SimpleCookieJar` and `ManualRedirectClient` (`lib/core/network/`).
2. Implement `AcademiaDecoder` (`pageSanitizer.sanitize` byte-scanner + `[zmlvalue]` unescaper) and `AcademiaParsers` (`lib/scrapers/academia/`).
3. Implement `AcademiaClient` (6-step Zoho login + continuation unblocker + cache-busting headers).
4. Implement `SpCaptchaSolver` (`ddddocr_common.onnx` inference) + `SpClient` (`SECURE_CONFIG`, `X-Domain-Proof`, DOM-order login POST) + `SpParsers` (`iden=9`, `iden=13`).
5. Implement `FacultyClient` & `FacultyParser` (`www.srmist.edu.in`).
6. Write unit tests in `test/scrapers/` validating all parsers against the sanitized HTML/JSON fixtures.
- **Verification Gate:** `flutter test test/scrapers/` passes 100%.

### Phase 3: The 4-Layer "Zero-Logout" `SessionSyncOrchestrator` & Background Worker
1. Build `SessionSyncOrchestrator` coordinating Stale-While-Revalidate reads from `Drift`, live background scraping in Dart Isolates, silent credential re-authentication on expired Zoho sessions, and Academia vs. Student Portal `hoursConducted` reconciliation.
2. Configure `WorkManager` (`background_sync_worker.dart`) + `flutter_local_notifications` to run periodic 6-hour background attendance checks and fire native lock-screen alerts.
- **Verification Gate:** Orchestrator integration test with mocked expired Zoho session verifies automatic silent re-login and SQLite update without throwing auth logout.

### Phase 4: Core Mobile UI Screens & Navigation Shell
1. Build `LoginScreen`, `SpCaptchaBottomSheet`, and `BiometricLockScreen`.
2. Build `DashboardShellScreen` (`go_router` bottom tabs + `NotificationBellSheet` + Profile/Settings drawer).
3. Build `OverviewScreen` (with week day-order strip & live/upcoming class badge).
4. Build `AttendanceScreen` (subject cards, `fl_chart` 30-day trend chart, `AttendancePlannerCard`, and "Force Deep Sync" pull-to-refresh).
5. Build `MarksScreen` (Academia test accordions + Student Portal fallback).
6. Build `TimetableScreen` (swipeable Day 1–5 pages + `ExportableTimetablePoster` PNG share).
7. Build `CalendarScreen` (semester switcher, month view, holiday illustrations).
8. Build `FacultyAvatar` & `FacultyProfileSheet`, `SettingsScreen` (including Biometric Lock toggle & JSON Backup Export/Import), and `LegalMarkdownScreen` (Privacy Policy & Terms).
- **Verification Gate:** `flutter analyze` and widget smoke tests pass with 0 errors.

### Phase 5: Post-Core Native Enhancements (Home Screen Widgets & Calendar Sync)
1. Implement `HomeWidgetSync` (`home_widget`) pushing Today's Day Order, Next Class, and Overall Attendance % to iOS `WidgetKit` and Android `AppWidgetProvider`.
2. Implement `NativeCalendarExporter` (`device_calendar`) allowing 1-tap sync of the semester's Day-Order-resolved classes and holidays into Apple Calendar / Google Calendar.

### Phase 6: Release Packaging & iOS Cloud CI Verification
1. Configure Android release signing, ProGuard/R8 rules for `onnxruntime`, and `AndroidManifest.xml` permissions.
2. Configure `ios/Runner/Info.plist` keys (`NSFaceIDUsageDescription`, `NSCalendarsUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `BGTaskSchedulerPermittedIdentifiers`).
3. Add `.github/workflows/mobile_build.yml` from `IOS_BUILD_GUIDE.md` to build both Android `.apk`/`.aab` and iOS `.ipa` automatically on GitHub Actions.