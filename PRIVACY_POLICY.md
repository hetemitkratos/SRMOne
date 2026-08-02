# Privacy Policy for HackTrackr

**Last Updated:** February 2, 2026

## Introduction

Welcome to HackTrackr ("we," "our," or "us"). We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our SRM Academia and Placement dashboard application.

## Information We Collect

### 1. Account Information
- **SRM Academia Credentials**: Email and password for SRM portal access (stored in-memory only, never persisted)
- **Haveloc Placement Credentials**: Username and encrypted password (stored securely in Supabase)
- **Student Profile Data**: Name, registration number, photo, CGPA, branch, section, semester, contact details

### 2. Academic Data
- **Attendance Records**: Course-wise attendance percentages, hours conducted, hours absent
- **Marks/Grades**: Semester-wise marks and grade information
- **Timetable**: Class schedules, faculty information, room numbers
- **Academic Calendar**: Holiday dates, semester schedules, day-order information

### 3. Placement Data
- **Job Listings**: Company names, job titles, CTC ranges, eligibility status
- **Application Status**: Jobs applied to, offered positions, rejection status
- **Job Bookmarks**: Saved jobs with personal notes and application tracking

### 4. Usage Data
- **Attendance History**: Daily snapshots of attendance percentages for trend tracking
- **Settings & Preferences**: Theme, default view, dashboard customization
- **Notifications**: In-app notification records and read/unread status
- **Device Information**: Browser type, IP address, session timestamps

## How We Use Your Information

### 1. Core Functionality
- Authenticate you with SRM Academia and Haveloc portals
- Display your academic and placement data in a unified dashboard
- Cache frequently accessed data for faster load times
- Sync settings across multiple devices

### 2. Enhanced Features
- Track attendance trends over time with historical charts
- Save and organize job bookmarks with personal notes
- Deliver real-time notifications for important updates
- Provide personalized dashboard experience

### 3. Service Improvement
- Analyze usage patterns to improve user experience
- Debug technical issues and optimize performance
- Develop new features based on user needs

## Data Storage and Security

### 1. Storage Locations
- **In-Memory Sessions**: SRM credentials stored temporarily in server memory (30-minute timeout)
- **Supabase Database**: Encrypted placement credentials, cached profiles, attendance history, bookmarks, settings, notifications
- **No Local Storage**: Sensitive data is not stored in browser localStorage

### 2. Security Measures
- **Encryption**: Placement passwords encrypted using AES-256-CBC
- **HTTPS**: All data transmitted over secure SSL/TLS connections
- **Row-Level Security (RLS)**: Database access restricted to service role only
- **Session Management**: Automatic session expiry after 30 minutes of inactivity
- **No Password Storage**: SRM passwords never stored, only used for authentication

### 3. Access Control
- Your data is accessible only to you when logged in
- Backend uses service role keys (never exposed to frontend)
- Frontend uses anonymous keys with strict RLS policies
- No third-party access to your personal data

## Data Retention

- **Session Data**: Cleared after 30 minutes of inactivity or manual logout
- **Cached Profiles**: Retained until you delete your account or request removal
- **Attendance History**: Retained for trend analysis, can be deleted on request
- **Job Bookmarks**: Retained until you manually remove them
- **Settings**: Retained for multi-device sync, can be reset to defaults
- **Notifications**: Retained for 90 days, then automatically purged

## Third-Party Services

### 1. SRM Academia Portal
- We access SRM's portal on your behalf using your credentials
- Subject to SRM's own privacy policy and terms of service
- We do not share your SRM credentials with any third party

### 2. Haveloc Placement Portal
- We store encrypted credentials to enable auto-login
- Subject to Haveloc's privacy policy and terms of service
- You can disconnect your placement account at any time

### 3. Supabase (Database Provider)
- Hosts our database and real-time infrastructure
- Subject to Supabase's privacy policy and security standards
- Data stored in secure, encrypted databases

## Your Rights

You have the right to:

1. **Access**: Request a copy of all data we store about you
2. **Correction**: Update or correct inaccurate information
3. **Deletion**: Request deletion of your account and all associated data
4. **Portability**: Export your data in a machine-readable format
5. **Opt-Out**: Disable specific features like notifications or bookmarks
6. **Disconnect**: Remove placement account connection at any time

To exercise these rights, contact us at: [your-email@example.com]

## Cookies and Tracking

We use minimal tracking:
- **Session Cookies**: To maintain your login state
- **Local Storage**: For temporary UI state (theme, collapsed menus)
- **No Analytics**: We do not use Google Analytics or similar tracking services
- **No Advertising**: We do not serve ads or share data with advertisers

## Children's Privacy

HackTrackr is intended for college students (18+ years). We do not knowingly collect data from individuals under 18. If you are under 18, please do not use this service.

## Changes to This Policy

We may update this privacy policy from time to time. We will notify you of significant changes by:
- Updating the "Last Updated" date
- Displaying a notice on the dashboard
- Sending an in-app notification (if enabled)

Continued use of HackTrackr after changes constitutes acceptance of the updated policy.

## Data Breach Notification

In the unlikely event of a data breach affecting your personal information, we will:
- Notify you within 72 hours of discovery
- Explain what data was compromised
- Describe steps we're taking to resolve the issue
- Provide guidance on protecting your account

## International Users

HackTrackr is operated from India and intended for SRM University students. By using our service, you consent to the transfer and processing of your data in India.

## Contact Us

If you have questions about this privacy policy or our data practices:

- **Email**: [your-email@example.com]
- **GitHub**: https://github.com/Harsx404/hacktrackr
- **Response Time**: We aim to respond within 48 hours

## Legal Basis for Processing (GDPR)

For users in the EU/EEA, we process your data based on:
- **Consent**: You provide explicit consent when creating an account
- **Contractual Necessity**: To provide the services you requested
- **Legitimate Interests**: To improve and secure our service

## Your California Privacy Rights (CCPA)

California residents have additional rights:
- Right to know what personal information is collected
- Right to know if personal information is sold or disclosed
- Right to opt-out of sale of personal information (we do not sell data)
- Right to deletion of personal information
- Right to non-discrimination for exercising privacy rights

---

**Effective Date:** February 2, 2026

By using HackTrackr, you acknowledge that you have read and understood this Privacy Policy.
