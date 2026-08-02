# Privacy Policy for SRM One

**Last Updated:** August 2, 2026

## Introduction

Welcome to SRM One ("we," "our," or "us"). We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our SRM Academia and Placement dashboard application.

SRM One is an independent, student-built platform that aggregates data from SRM University's Academia portal and the Haveloc placement portal. SRM One is not affiliated with, endorsed by, or officially connected to SRM Institute of Science and Technology or Haveloc Technologies.

## Information We Collect

### 1. Credentials
- **SRMIST email**: Used to authenticate with the Academia portal and identify your session. Stored in browser `localStorage` for the duration of your login.
- **SRMIST password**: Used only during the login handshake with SRM's authentication servers. Never stored in the database, filesystem, or browser. Discarded from memory immediately after authentication succeeds.
- **Haveloc placement password**: Encrypted using AES-256-CBC and stored in our Supabase database to enable automatic placement login. You can disconnect and erase this at any time.
- **Session cookies**: Stored in server memory during your active session. Cleared when you log out or the session expires (30 minutes of inactivity).

### 2. Academic Data
- **Student profile**: Name, registration number, department, batch, semester, campus, photo.
- **Attendance records**: Course-wise attendance percentages, hours conducted, hours absent. Daily snapshots stored in Supabase for trend analysis.
- **Marks/Grades**: Semester-wise marks and grade information (in-memory only).
- **Timetable**: Class schedules, faculty information, room numbers (in-memory only).
- **Academic calendar**: Holiday dates, semester schedules, day-order information (in-memory only).

### 3. Placement Data
- **Job listings**: Company names, job titles, CTC ranges, eligibility status.
- **Application status**: Jobs applied to, offered positions, rejection status.
- **Job bookmarks**: Saved jobs with personal notes — stored in Supabase, accessible across devices.
- **Placement notices**: Notices and announcements from the placement cell.

### 4. Faculty Data (Public)
- Faculty names, designations, departments, email addresses, campus, profile photos, and detailed profiles (education, publications, awards, work experience) are sourced from SRM University's public-facing website (srmist.edu.in/faculty/).
- Cached in Supabase (1-hour TTL) and in browser `localStorage` (24-hour TTL) to avoid repeated scraping.

### 5. Notifications
- In-app notifications for: welcome messages, low attendance alerts, new job postings, upcoming holidays, and new placement notices.
- Stored in Supabase, linked to your email address. Retained for 90 days, then automatically purged.
- You can mark notifications as read or clear them at any time.

### 6. Usage Data (Minimal)
- The Service does not use analytics, tracking pixels, or advertising SDKs.
- Server logs may include anonymized error messages and request timestamps for debugging.
- Logs are rotated and do not contain personally identifiable information.

## How We Use Your Information

### 1. Core Functionality
- Authenticate you with SRM Academia and Haveloc portals.
- Display your academic and placement data in a unified dashboard.
- Cache frequently accessed data for faster load times.

### 2. Enhanced Features
- Track attendance trends over time with historical charts and predictions.
- Save and organize job bookmarks with personal notes.
- Deliver real-time notifications for important updates.
- Display faculty photos and detailed profiles alongside timetable and attendance.
- Enable automatic placement login with encrypted credentials.

### 3. What We Do NOT Do
- Advertising, marketing, or promotional purposes.
- Selling or sharing data with any third party.
- Training machine learning models.
- Building user profiles or behavioral analytics.

## Data Storage and Security

### 1. In-Memory (Session Data)
- Academic and placement data fetched during your session is stored in server RAM.
- Cleared when you log out or the session expires.
- Includes: timetable, marks, calendar, placement listings.

### 2. Supabase Database (Persisted)
- **Placement credentials** (encrypted AES-256-CBC) — retained until you disconnect.
- **Attendance snapshots** — daily snapshots for trend analysis. Deletable on request.
- **Job bookmarks** with notes — retained until you manually remove them.
- **Notifications** — retained for 90 days, then automatically purged.
- **Faculty profile cache** — public data, 1-hour TTL, auto-refreshed.
- **Notification settings** — your preferences for which alerts to receive.

### 3. Browser Storage (localStorage)
- `srm_user`: Your email address (to identify you across page refreshes).
- `placement_user`: Your Haveloc username (for the placement dashboard).
- Faculty profile cache (24-hour TTL for faster loading).
- UI preferences (theme, collapsed menus, dismissed banners).
- No passwords or session tokens are stored in the browser.

### 4. Security Measures
- **No password storage**: SRM passwords never written to disk, database, or logs.
- **Encrypted placement credentials**: AES-256-CBC encryption, key held server-side only.
- **Row-Level Security (RLS)**: Supabase database access restricted to backend service role.
- **Session isolation**: Each user's session is isolated. You can only access your own data.
- **HTTPS**: All communication encrypted using TLS.
- **No third-party sharing**: We do not share, sell, or transmit your data.
- **Rate limiting**: Login and API endpoints are rate-limited to prevent brute-force attacks.

## Data Retention

- **Session data**: Cleared after 30 minutes of inactivity or manual logout.
- **Placement credentials**: Retained until you disconnect your placement account.
- **Attendance snapshots**: Retained for trend analysis, deletable on request.
- **Job bookmarks**: Retained until you manually remove them.
- **Notifications**: Retained for 90 days, then automatically purged.
- **Faculty cache**: 1-hour TTL (Supabase), 24-hour TTL (localStorage).
- **Server logs**: Rotated regularly, no personally identifiable information.

## Third-Party Services

### 1. SRM Academia Portal (academia.srmist.edu.in)
- We access SRM's portal on your behalf using your credentials.
- Subject to SRM's own privacy policy and terms of service.
- We do not share your SRM credentials with any third party.

### 2. Haveloc Placement Portal (placements.haveloc.com)
- We store encrypted credentials to enable auto-login.
- Subject to Haveloc's privacy policy and terms of service.
- You can disconnect your placement account at any time.

### 3. SRM Public Website (srmist.edu.in)
- We scrape publicly available faculty profile pages.
- No authentication is required for this data.

### 4. Supabase (supabase.com)
- Hosts our database for encrypted credentials, attendance snapshots, bookmarks, notifications, and faculty cache.
- SOC 2 Type II compliant. Encrypts data at rest and in transit.
- Subject to Supabase's privacy policy and security standards.

### 5. Vercel (vercel.com)
- Hosts the frontend application.
- Subject to Vercel's privacy policy.

### 6. Render (render.com)
- Hosts the backend API services.
- Subject to Render's privacy policy.

## Your Rights

You have the right to:

1. **Access**: View all data the Service has about you by using the dashboard.
2. **Deletion**: Request deletion of your Supabase records (attendance snapshots, bookmarks, notifications) by contacting us. Logging out clears session data. Disconnecting placement erases encrypted credentials.
3. **Opt-out of notifications**: Disable specific notification types from the notification settings panel.
4. **Disconnect placement**: Remove your Haveloc placement account connection at any time, which immediately erases encrypted credentials.
5. **Data portability**: Export your academic data using the Service's export features or by directly accessing the source portals.

To exercise these rights, contact us through the project's GitHub repository.

## Cookies and Tracking

We use minimal tracking:
- **Session cookies**: Used internally by the server to maintain your authenticated session. Stored in server memory, not in your browser.
- **Local Storage**: For UI state (theme, email, faculty cache, dismissed banners).
- **No Analytics**: We do not use Google Analytics or similar tracking services.
- **No Advertising**: We do not serve ads or share data with advertisers.

## Children's Privacy

SRM One is intended for university students who are adults (18+). We do not knowingly collect data from anyone under 18. If you believe a minor has provided personal information, please contact us so we can take appropriate action.

## Changes to This Policy

We may update this privacy policy from time to time. We will notify you of significant changes by:
- Updating the "Last Updated" date
- Displaying a notice on the dashboard
- Sending an in-app notification (if enabled)

Continued use of SRM One after changes constitutes acceptance of the updated policy.

## Data Breach Notification

In the unlikely event of a data breach affecting your personal information, we will:
- Notify affected users within 72 hours of discovery
- Explain what data was compromised
- Describe steps we're taking to resolve the issue
- Provide guidance on protecting your account

## International Users

SRM One is operated from India and intended for SRM University students. By using our service, you consent to the transfer and processing of your data in India.

## Contact Us

If you have questions about this privacy policy or our data practices:
- **GitHub**: https://github.com/Harsx404/hacktrackr
- **Response Time**: We aim to respond within 48 hours

---

**Effective Date:** August 2, 2026

By using SRM One, you acknowledge that you have read and understood this Privacy Policy.
