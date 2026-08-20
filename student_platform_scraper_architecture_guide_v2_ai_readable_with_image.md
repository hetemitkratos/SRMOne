# Student Information Platform

## Scraper Architecture, Scheduling & 5-Day Data Cleanup Guide

This Markdown document is an AI-readable companion to the PDF. It
contains the extracted document text plus the architecture diagram as a
local image reference.

## Architecture Diagram

![Student Information Platform scraper architecture
flow](student_platform_architecture_flow.png)

**Image description:** The diagram shows students accessing the website,
which reads from Supabase PostgreSQL. Academia attendance and Haveloc
placement scrapers feed the database. Academia runs four scheduled times
per day. Haveloc runs frequently for job tracking. A cleanup process
removes eligible temporary user data after five days of inactivity while
preserving the user's authentication identity and core profile.

### Text-only representation of the visual flow

``` text
Students
   |
   v
Website / API
   |
   v
Supabase PostgreSQL
   ^
   |
   +----------------------+----------------------+
   |                      |                      |
   |                      |                      |
Academia                Haveloc              Cleanup
4x daily                every 5 min           daily
   |                      |                      |
   v                      v                      v
Edge Function          Edge Function          SQL / Function
   |                      |                      |
   +----------------------+----------------------+
                          |
                          v
                    Supabase Database
```

------------------------------------------------------------------------

## Extracted PDF Page 1

Student Information Platform  Scraper & Data Lifecycle Guide Page 1
Student Information Platform Scraper Architecture, Scheduling & 5-Day
Data Cleanup Guide Recommended starting architecture: Supabase Cron →
Edge Functions → Supabase PostgreSQL → Website/API. Academia refreshes
four times daily, Haveloc checks frequently, and a separate cleanup job
removes selected user-specific temporary data after 5 days of
inactivity. Important: Keep the user's Supabase Auth account and core
profile. Delete only data that is safe to recreate. If Haveloc requires
browser automation or a long-running Go process, move only that scraper
to a free VM while keeping Supabase as the database.

------------------------------------------------------------------------

## Extracted PDF Page 2

Student Information Platform  Scraper & Data Lifecycle Guide Page 2 1.
Final System Architecture The platform has three background jobs:
Academia attendance synchronization, Haveloc placement tracking, and
inactive-user cleanup. Students do not trigger scrapers. They read the
latest stored data from the database/API. SUPABASE ■
■■■■■■■■■■■■■■■■■■■■■■ ■ ■ ■ Academia Haveloc Cleanup 4×/day every 5m
daily ■ ■ ■ ■■■■■■■■■■■■■■■■■■■■■■ ↓ PostgreSQL DB ↓ API / Website ↓
Students The cleanup job is deliberately separate from the scraper jobs.
It should never delete global placement data just because an individual
student is inactive. Recommended data ownership: Data Lifecycle Reason
Haveloc jobs Keep globally Shared platform data Academia attendance
Refresh 4× daily Current student data User profile/Auth Keep Preserve
account identity Temporary/cache data Delete after 5 inactive days
Recoverable and space-heavy Notifications/history Delete if
non-essential Reduce storage

------------------------------------------------------------------------

## Extracted PDF Page 3

Student Information Platform  Scraper & Data Lifecycle Guide Page 3 2.
Scraper Schedules Academia attendance is scheduled at the four times you
specified. Haveloc is scheduled frequently so new placement postings can
be detected without keeping a process alive 24/7, provided the scraper
fits the Edge Function execution model. Job Schedule Action Academia
08:00 IST Sync attendance Academia 12:30 IST Sync attendance Academia
17:00 IST Sync attendance Academia 20:00 IST Sync attendance Haveloc
Every 5 minutes Check and store new jobs Cleanup Once daily, e.g. 03:00
IST Delete eligible user-specific temporary data If the scheduler uses
UTC, the four Academia times correspond to 02:30, 07:00, 11:30 and 14:30
UTC. Always verify the timezone configured for the scheduler before
production.

------------------------------------------------------------------------

## Extracted PDF Page 4

Student Information Platform  Scraper & Data Lifecycle Guide Page 4 3.
Inactive User Cleanup The safest design is not to delete the Supabase
Auth account after five days. Instead, keep the account and core profile
while deleting selected application data that can be recreated. User
lifecycle: User logs in ↓ last_seen_at = NOW() ↓ User data remains
available No login for 5+ days ↓ Daily cleanup Cron ↓ Delete selected
temporary/cache data ↓ Keep auth.users + core profile User returns later
↓ Login works normally ↓ Recreate missing application/cache data Why
keep Auth? Repeatedly deleting and recreating Auth accounts can break
stable user IDs, foreign keys, preferences, OAuth identities, and saved
relationships. Supabase documents a public profile-table pattern linked
to auth.users, which is the better place for your application's user
metadata. Suggested profile fields: profiles -------- id UUID -- same
identity as auth user created_at TIMESTAMPTZ last_seen_at TIMESTAMPTZ
display_name TEXT course TEXT year INT

------------------------------------------------------------------------

## Extracted PDF Page 5

Student Information Platform  Scraper & Data Lifecycle Guide Page 5 4.
What Gets Deleted? Separate permanent identity data from
temporary/recreatable data. This is the most important design decision
for the cleanup job. Table / data After 5 inactive days Notes auth.users
KEEP Preserve login identity profiles KEEP Keep essential profile fields
attendance cache DELETE Re-fetch on next relevant sync/login temporary
preferences DELETE if safe Only if recreatable notification history
DELETE if non-essential Useful storage target saved jobs OPTIONAL Delete
only if product policy allows it Haveloc jobs KEEP Global platform
dataset If attendance records are considered part of the student's
durable academic history, do not delete the canonical attendance table.
Instead, delete only a derived cache or old temporary session data. The
five-day policy should apply to data you explicitly decide is
disposable.

------------------------------------------------------------------------

## Extracted PDF Page 6

Student Information Platform  Scraper & Data Lifecycle Guide Page 6 5.
Cleanup Cron Implementation A simple SQL cleanup is usually better than
starting another Edge Function if all you need is deletion. Supabase
Cron can schedule SQL statements. Use a transaction or tightly scoped
statements so the job is predictable. Example for temporary data: select
cron.schedule( 'cleanup-inactive-users', '30 21 \* \* \*', -- 03:00 IST
if scheduler is UTC $$
    delete from public.user_temporary_data t
    where t.user_id in (
      select p.id
      from public.profiles p
      where p.last_seen_at < now() - interval '5 days'
    );
  $$ ); For a real project, prefer a foreign key with ON DELETE CASCADE
where appropriate, or explicitly delete child rows first. Do not use a
broad DELETE against all user-related tables without checking
dependencies. Make the cleanup observable. Insert a row into a cleanup
log with the run timestamp and number of deleted records, or use
Supabase's job monitoring to verify the scheduled task is succeeding.
Also consider adding a short grace period and excluding recently active
users to avoid deleting data while a user is actively returning to the
platform.

------------------------------------------------------------------------

## Extracted PDF Page 7

Student Information Platform  Scraper & Data Lifecycle Guide Page 7 6.
Login and Data Recreation When a student returns, the application should
treat missing disposable data as normal rather than as an error. Login ↓
Find auth user / profile ↓ Update last_seen_at ↓ Check required
application data ■■■ Exists → use it ■■■ Missing → recreate / fetch it ↓
Show dashboard Example pseudo-logic: onLogin(userId): update profiles
set last_seen_at = now() if temporary_data_missing(userId):
recreate_temporary_data(userId) return dashboard This makes cleanup
transparent to users. They keep their account, while disposable data is
rebuilt when needed.

------------------------------------------------------------------------

## Extracted PDF Page 8

Student Information Platform  Scraper & Data Lifecycle Guide Page 8 7.
Storage Strategy for the Free Tier The cleanup system helps, but it
should not be your only storage strategy. Supabase's Free plan has a
database size quota, so the best savings come from keeping large
datasets centralized and removing only genuinely temporary user data.
Use these principles: 1. Keep one canonical Haveloc jobs table. Do not
copy every job into every user's row. 2. Keep shared Academia data
centralized where possible. Avoid duplicating the same attendance data
per student if one normalized record can serve multiple views. 3. Delete
temporary caches after inactivity. 4. Add indexes only where they help
actual queries, because indexes also consume storage. 5. Avoid storing
large raw HTML responses or screenshots unless they are genuinely
required. 6. Store only the fields your website needs from scraped
sources. 7. Track table sizes periodically so you know what is actually
consuming the quota. 8. Keep a last-success timestamp for every scraper
so the frontend can report data freshness. A useful dashboard metric is:
Academia: Last successful sync → 20:00 IST Haveloc: Last successful
check → 10:35:00 IST Cleanup: Last successful run → 03:00 IST Inactive
users cleaned → 184 records

------------------------------------------------------------------------

## Extracted PDF Page 9

Student Information Platform  Scraper & Data Lifecycle Guide Page 9 8.
Complete Production Flow ■■■■■■■■■■■■■■■■■■■■■■■ ■ SUPABASE CRON ■
■■■■■■■■■■■■■■■■■■■■■■■ ■ ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
■ ■ ■ ▼ ▼ ▼ ACADEMIA HAVELOC CLEANUP 4× daily every 5m daily ■ ■ ■ ▼ ▼ ▼
Edge Function Edge Function SQL / Function ■ ■ ■
■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ ▼ ■■■■■■■■■■■■■■■■■■■■■■■
■ SUPABASE POSTGRESQL ■ ■■■■■■■■■■■■■■■■■■■■■■■ ■
■■■■■■■■■■■■■■■■■■■■■■■■■ ■ ■ ▼ ▼ Supabase API Website / App ■ ▼ MANY
STUDENTS Result: the scrapers are independent of user traffic, scheduled
jobs run automatically, inactive users do not consume unnecessary
temporary storage, and returning users can have disposable data
recreated.

------------------------------------------------------------------------

## Extracted PDF Page 10

Student Information Platform  Scraper & Data Lifecycle Guide Page 10 9.
Deployment Checklist \# Action 1 Create/confirm Supabase tables and
relationships. 2 Add profiles.last_seen_at and update it on
login/activity. 3 Create Academia Edge Function and test it manually. 4
Schedule Academia at 08:00, 12:30, 17:00 and 20:00 IST. 5 Create Haveloc
Edge Function and test one run. 6 Schedule Haveloc every 5 minutes
initially. 7 Add unique constraints to prevent duplicate jobs. 8 Create
cleanup SQL/function for only disposable user data. 9 Schedule cleanup
once daily after your chosen inactivity window. 10 Keep auth.users and
essential profile data. 11 Test a user becoming inactive and then
logging back in. 12 Monitor storage, function runtime, failures and
target-site rate limits. 13 If Haveloc requires heavy browser
automation, move only Haveloc to a free VM. Final recommendation: Start
with Supabase Cron + Edge Functions + PostgreSQL. Use four Academia runs
per day, Haveloc every five minutes, and one daily cleanup job for
disposable data belonging to users inactive for five days. Keep Auth
accounts and durable data. Use a free VM only if the Haveloc scraper's
runtime requirements make Edge Functions unsuitable. Official
documentation to consult: Supabase Cron:
https://supabase.com/docs/guides/cron Supabase scheduled Edge Functions:
https://supabase.com/docs/guides/functions/schedule-functions Supabase
user management:
https://supabase.com/docs/guides/auth/managing-user-data Supabase Edge
Function limits: https://supabase.com/docs/guides/functions/limits
Cloudflare Cron Triggers:
https://developers.cloudflare.com/workers/configuration/cron-triggers/
