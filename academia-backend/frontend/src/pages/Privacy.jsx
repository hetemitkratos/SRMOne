import { ArrowLeft } from "lucide-react";
import { useNavigate } from "react-router-dom";

const SECTIONS = [
  {
    title: "1. Introduction",
    body: (
      <>
        <p>
          This Privacy Policy describes how SRM One ("the Service", "we", "us") collects, uses, and
          protects your personal information when you use our platform. The Service is a
          student-built dashboard that aggregates academic and placement data from SRM University's
          Academia portal and the Haveloc placement portal.
        </p>
        <p>
          We are committed to protecting your privacy and being transparent about our data practices.
          By using the Service, you consent to the collection and use of information as described in
          this policy.
        </p>
      </>
    ),
  },
  {
    title: "2. Data We Collect",
    body: (
      <>
        <h3>2.1 Credentials</h3>
        <ul>
          <li>
            <strong>SRMIST email:</strong> Used to authenticate with the Academia portal and identify
            your session. Stored in browser <code>localStorage</code> for the duration of your login.
          </li>
          <li>
            <strong>SRMIST password:</strong> Used <strong>only</strong> during the login handshake
            with SRM's authentication servers. <strong>Never stored in the database, filesystem, or
            browser.</strong> Discarded from memory immediately after authentication succeeds.
          </li>
          <li>
            <strong>Haveloc placement password:</strong> Encrypted using AES-256-CBC and stored in
            our Supabase database to enable automatic placement login. You can disconnect and erase
            this at any time from the Placement settings.
          </li>
          <li>
            <strong>Session cookies:</strong> Stored in server memory during your active session.
            Cleared when you log out or the session expires (30 minutes of inactivity).
          </li>
        </ul>

        <h3>2.2 Academic Data (Cached & Snapshotted)</h3>
        <p>
          The following data is fetched from SRM Academia in real time and cached in server memory
          during your session. Some data is also persisted to our Supabase database for history and
          cross-device access:
        </p>
        <ul>
          <li>Student profile: name, registration number, department, batch, semester, campus, photo.</li>
          <li>Attendance records per course — <strong>daily snapshots</strong> stored in Supabase for trend analysis.</li>
          <li>Marks and grade history (in-memory only).</li>
          <li>Timetable and class schedule (in-memory only).</li>
          <li>Academic calendar (in-memory only).</li>
        </ul>

        <h3>2.3 Placement Data</h3>
        <ul>
          <li>Company listings, job postings, application tracker, placement cycles.</li>
          <li><strong>Job bookmarks</strong> with personal notes — stored in Supabase, accessible across devices.</li>
          <li>Placement notices and policies (cached in-memory).</li>
        </ul>

        <h3>2.4 Faculty Data (Public)</h3>
        <p>
          Faculty names, designations, departments, email addresses, campus, profile photos, and
          detailed profiles (education, publications, awards, work experience) are sourced from SRM
          University's <strong>public-facing website</strong> (srmist.edu.in/faculty/). This data is
          publicly accessible without authentication and is cached in our Supabase database (1-hour
          TTL) and in your browser's <code>localStorage</code> (24-hour TTL) to avoid repeated
          scraping.
        </p>

        <h3>2.5 Notifications</h3>
        <p>
          The Service generates in-app notifications for events such as welcome messages, low
          attendance alerts, new job postings, upcoming holidays, and new placement notices. These
          notifications are stored in Supabase and linked to your email address. You can mark
          notifications as read or clear them at any time.
        </p>

        <h3>2.6 Usage Data (Minimal)</h3>
        <p>
          The Service does not use analytics, tracking pixels, or advertising SDKs. Server logs may
          include anonymized error messages and request timestamps for debugging purposes. These
          logs are rotated and do not contain personally identifiable information.
        </p>
      </>
    ),
  },
  {
    title: "3. How We Use Your Data",
    body: (
      <>
        <p>Your data is used solely for the following purposes:</p>
        <ul>
          <li>
            <strong>Authentication:</strong> To log you into SRM Academia and Haveloc portals on your
            behalf.
          </li>
          <li>
            <strong>Data display:</strong> To present your academic and placement information in a
            unified dashboard.
          </li>
          <li>
            <strong>Performance:</strong> To cache frequently accessed data during your session so
            that repeated requests are faster.
          </li>
          <li>
            <strong>Attendance trends:</strong> To snapshot daily attendance and show historical
            trends and predictions.
          </li>
          <li>
            <strong>Job tracking:</strong> To save bookmarked jobs with personal notes, accessible
            across your devices.
          </li>
          <li>
            <strong>Notifications:</strong> To alert you about low attendance, new jobs, holidays,
            and placement notices.
          </li>
          <li>
            <strong>Faculty profiles:</strong> To display faculty photos and detailed profiles
            alongside your timetable and attendance.
          </li>
        </ul>
        <p>
          We do <strong>NOT</strong> use your data for:
        </p>
        <ul>
          <li>Advertising, marketing, or promotional purposes.</li>
          <li>Selling or sharing data with any third party.</li>
          <li>Training machine learning models.</li>
          <li>Building user profiles or behavioral analytics.</li>
        </ul>
      </>
    ),
  },
  {
    title: "4. Data Storage & Retention",
    body: (
      <>
        <h3>4.1 In-Memory (Session Data)</h3>
        <p>
          Academic and placement data fetched during your active session is stored in server memory
          (RAM). When you log out or the session expires, all cached data is garbage-collected.
          This includes timetable, marks, calendar, and placement listings.
        </p>

        <h3>4.2 Supabase Database (Persisted)</h3>
        <p>The following data is persisted in our Supabase database:</p>
        <ul>
          <li>
            <strong>Placement credentials</strong> (encrypted with AES-256-CBC) — retained until you
            disconnect your placement account.
          </li>
          <li>
            <strong>Attendance snapshots</strong> — daily snapshots retained for trend analysis.
            Deletable on request.
          </li>
          <li>
            <strong>Job bookmarks</strong> with notes — retained until you manually remove them.
          </li>
          <li>
            <strong>Notifications</strong> — retained for 90 days, then automatically purged.
          </li>
          <li>
            <strong>Faculty profile cache</strong> — public data, 1-hour TTL, auto-refreshed.
          </li>
          <li>
            <strong>Notification settings</strong> — your preferences for which alerts to receive.
          </li>
        </ul>

        <h3>4.3 Browser Storage</h3>
        <p>The following is stored in your browser's <code>localStorage</code>:</p>
        <ul>
          <li><code>srm_user</code>: Your email address (to identify you across page refreshes).</li>
          <li><code>placement_user</code>: Your Haveloc username (for the placement dashboard).</li>
          <li>Faculty profile cache (24-hour TTL for faster loading).</li>
          <li>UI preferences (theme, collapsed menus, dismissed banners).</li>
        </ul>
        <p>
          No passwords or session tokens are stored in the browser. You can clear this data at any
          time by logging out or clearing your browser storage.
        </p>
      </>
    ),
  },
  {
    title: "5. Data Security",
    body: (
      <>
        <p>We take the following measures to protect your data:</p>
        <ul>
          <li>
            <strong>No password storage:</strong> SRM passwords are never written to disk, database,
            or logs. They exist in memory only for the duration of the login request.
          </li>
          <li>
            <strong>Encrypted placement credentials:</strong> Haveloc passwords are encrypted using
            AES-256-CBC before being stored in Supabase. The encryption key is held server-side only.
          </li>
          <li>
            <strong>Row-Level Security (RLS):</strong> Supabase database access is restricted to the
            backend service role. The frontend uses anonymous keys with strict RLS policies that
            prevent cross-user data access.
          </li>
          <li>
            <strong>Session isolation:</strong> Each user's session is isolated. You can only access
            data associated with your own credentials.
          </li>
          <li>
            <strong>HTTPS:</strong> All communication between your browser and the server is
            encrypted using TLS.
          </li>
          <li>
            <strong>No third-party sharing:</strong> We do not share, sell, or transmit your data to
            any external service or advertising network.
          </li>
          <li>
            <strong>Rate limiting:</strong> Login and API endpoints are rate-limited to prevent
            brute-force attacks.
          </li>
        </ul>
        <p>
          Despite these measures, no system is 100% secure. You are responsible for protecting your
          SRMIST credentials and should not share them with anyone.
        </p>
      </>
    ),
  },
  {
    title: "6. Third-Party Services",
    body: (
      <>
        <p>
          The Service interacts with the following third-party systems on your behalf:
        </p>
        <ul>
          <li>
            <strong>SRM Academia portal (academia.srmist.edu.in):</strong> We authenticate using your
            credentials and retrieve your academic data. SRM's privacy policy applies to data stored
            on their servers.
          </li>
          <li>
            <strong>Haveloc placement portal (placements.haveloc.com):</strong> We authenticate using
            your credentials and retrieve your placement data. Haveloc's privacy policy applies to
            data stored on their servers.
          </li>
          <li>
            <strong>SRM public website (srmist.edu.in):</strong> We scrape publicly available faculty
            profile pages. No authentication is required for this data.
          </li>
          <li>
            <strong>Supabase (supabase.com):</strong> Hosts our database for encrypted placement
            credentials, attendance snapshots, job bookmarks, notifications, and faculty cache.
            Supabase is SOC 2 Type II compliant and encrypts data at rest and in transit.
          </li>
          <li>
            <strong>Vercel (vercel.com):</strong> Hosts the frontend application. Subject to Vercel's
            privacy policy.
          </li>
          <li>
            <strong>Render (render.com):</strong> Hosts the backend API services. Subject to Render's
            privacy policy.
          </li>
        </ul>
        <p>
          We are not responsible for the privacy practices or data handling of these third-party
          services. Your use of SRM Academia and Haveloc is subject to their respective terms and
          privacy policies.
        </p>
      </>
    ),
  },
  {
    title: "7. Your Rights",
    body: (
      <>
        <p>You have the following rights regarding your data:</p>
        <ul>
          <li>
            <strong>Access:</strong> You can view all data the Service has about you by using the
            dashboard — everything we retrieve is shown to you.
          </li>
          <li>
            <strong>Deletion:</strong> Logging out clears your session from server memory. You can
            disconnect your placement account to erase encrypted credentials. You can request full
            deletion of your Supabase records (attendance snapshots, bookmarks, notifications) by
            contacting us.
          </li>
          <li>
            <strong>Opt-out of notifications:</strong> You can disable specific notification types
            (low attendance, new jobs, holidays, notices) from the notification settings panel.
          </li>
          <li>
            <strong>Disconnect placement:</strong> You can disconnect your Haveloc placement account
            at any time, which immediately erases your encrypted credentials from Supabase.
          </li>
          <li>
            <strong>Data portability:</strong> You can export your academic data by using the
            Service's export features (if available) or by directly accessing the source portals.
          </li>
        </ul>
      </>
    ),
  },
  {
    title: "8. Cookies & Tracking",
    body: (
      <>
        <p>
          The Service does <strong>not</strong> use:
        </p>
        <ul>
          <li>Tracking cookies (Google Analytics, Facebook Pixel, etc.).</li>
          <li>Advertising cookies.</li>
          <li>Third-party tracking scripts.</li>
        </ul>
        <p>
          Session cookies (JWT tokens) are used internally by the server to maintain your
          authenticated session. These are stored in server memory, not in your browser.
        </p>
      </>
    ),
  },
  {
    title: "9. Children's Privacy",
    body: (
      <>
        <p>
          The Service is designed for university students who are adults (18+). We do not knowingly
          collect data from anyone under 18. If you believe a minor has provided personal
          information, please contact us so we can take appropriate action.
        </p>
      </>
    ),
  },
  {
    title: "10. Changes to This Policy",
    body: (
      <>
        <p>
          We may update this Privacy Policy from time to time. Changes will be posted on this page
          with an updated "Last updated" date. Continued use of the Service after changes are posted
          constitutes your acceptance of the updated policy.
        </p>
      </>
    ),
  },
  {
    title: "11. Contact",
    body: (
      <>
        <p>
          For questions, concerns, or requests regarding your privacy or this Privacy Policy, please
          contact the SRM One development team through the project's official communication channels.
        </p>
      </>
    ),
  },
];

export default function Privacy() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-[#F8F6F0] font-sans text-slate-900">
      {/* Header */}
      <header className="sticky top-0 z-20 bg-white/80 backdrop-blur-lg border-b border-slate-200/60">
        <div className="max-w-3xl mx-auto px-6 py-4 flex items-center gap-4">
          <button
            onClick={() => navigate(-1)}
            className="flex items-center gap-2 text-slate-600 hover:text-slate-900 transition-colors text-sm font-medium cursor-pointer"
          >
            <ArrowLeft size={18} />
            Back
          </button>
          <div className="flex items-center gap-2">
            <img src="/assets/logo.png" alt="SRM One" style={{ width: 28, height: 28, objectFit: "contain" }} />
            <span className="font-bold text-[18px] tracking-tight text-slate-800">SRM One</span>
          </div>
        </div>
      </header>

      {/* Content */}
      <main className="max-w-3xl mx-auto px-6 py-12">
        <h1 className="text-[2.5rem] font-serif font-bold tracking-tight text-slate-900 mb-3">
          Privacy Policy
        </h1>
        <p className="text-slate-500 text-[15px] mb-12">
          Last updated: {new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}
        </p>

        <div className="space-y-10">
          {SECTIONS.map((section, i) => (
            <section key={i}>
              <h2 className="text-[20px] font-bold text-slate-900 mb-3 tracking-tight">{section.title}</h2>
              <div className="text-[15px] text-slate-600 leading-relaxed space-y-3 [&_ul]:space-y-1.5 [&_ul]:list-disc [&_ul]:pl-6 [&_h3]:font-bold [&_h3]:text-slate-800 [&_h3]:text-[16px] [&_h3]:mt-5 [&_h3]:mb-1 [&_code]:bg-slate-100 [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:rounded [&_code]:text-[13px] [&_code]:font-mono [&_strong]:text-slate-800">
                {section.body}
              </div>
            </section>
          ))}
        </div>

        {/* Footer */}
        <div className="mt-16 pt-8 border-t border-slate-200/60 flex items-center justify-between text-[13px] text-slate-400 font-medium">
          <span>© {new Date().getFullYear()} SRM One</span>
          <button onClick={() => navigate("/terms")} className="text-slate-600 hover:text-slate-900 underline underline-offset-2 cursor-pointer">
            Terms of Service →
          </button>
        </div>
      </main>
    </div>
  );
}
