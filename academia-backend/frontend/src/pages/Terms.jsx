import { ArrowLeft } from "lucide-react";
import { useNavigate } from "react-router-dom";

const SECTIONS = [
  {
    title: "1. Acceptance of Terms",
    body: (
      <>
        <p>
          By accessing or using SRM One ("the Service"), you agree to be bound by these Terms of
          Service ("Terms"). If you do not agree to any part of these Terms, you must not use the
          Service.
        </p>
        <p>
          The Service is an independent, student-built platform that aggregates data from SRM
          University's Academia portal and Haveloc placement portal. SRM One is not affiliated with,
          endorsed by, or officially connected to SRM Institute of Science and Technology or Haveloc
          Technologies.
        </p>
      </>
    ),
  },
  {
    title: "2. Eligibility",
    body: (
      <>
        <p>
          The Service is intended exclusively for current SRM University students who possess valid
          SRMIST credentials. By using the Service, you represent and warrant that:
        </p>
        <ul>
          <li>You are a current student of SRM Institute of Science and Technology.</li>
          <li>You are at least 18 years of age or have parental consent to use the Service.</li>
          <li>Your use of the Service complies with all applicable laws and university policies.</li>
        </ul>
      </>
    ),
  },
  {
    title: "3. User Credentials & Authentication",
    body: (
      <>
        <p>
          You are solely responsible for maintaining the confidentiality of your SRMIST username and
          password. The Service uses your credentials solely to authenticate with SRM's Academia and
          Haveloc placement portals on your behalf, to retrieve your own academic and placement data.
        </p>
        <ul>
          <li>
            <strong>Credentials are never stored in plaintext.</strong> Passwords are used only for
            the duration of an active session and are not persisted to disk.
          </li>
          <li>
            Session tokens (cookies) are stored in memory and cleared when you log out or the session
            expires.
          </li>
          <li>
            You must not share your credentials with any third party or allow unauthorized access to
            your account.
          </li>
        </ul>
      </>
    ),
  },
  {
    title: "4. Permitted Use",
    body: (
      <>
        <p>The Service is provided for personal, non-commercial use to:</p>
        <ul>
          <li>View your attendance, marks, timetable, and academic calendar.</li>
          <li>Track placement opportunities, job applications, and interview schedules.</li>
          <li>View faculty information and contact details.</li>
        </ul>
        <p>You agree NOT to:</p>
        <ul>
          <li>Use the Service for any commercial purpose without written consent.</li>
          <li>Attempt to access data belonging to other students.</li>
          <li>Reverse engineer, decompile, or disassemble any part of the Service.</li>
          <li>Use automated scripts, bots, or crawlers to overload or disrupt the Service.</li>
          <li>Resell, redistribute, or republish data obtained through the Service.</li>
        </ul>
      </>
    ),
  },
  {
    title: "5. Data Accuracy & Availability",
    body: (
      <>
        <p>
          The Service retrieves data from third-party portals (SRM Academia, Haveloc) in real time.
          We do not guarantee that:
        </p>
        <ul>
          <li>The data displayed is always accurate, complete, or up to date.</li>
          <li>The Service will be available without interruption or downtime.</li>
          <li>All features (e.g., academic calendar, specific faculty pages) will function at all
            times, as they depend on the availability of upstream portals.</li>
        </ul>
        <p>
          You should always verify critical information (attendance requirements, exam dates,
          placement deadlines) directly with official university sources.
        </p>
      </>
    ),
  },
  {
    title: "6. Intellectual Property",
    body: (
      <>
        <p>
          The Service's design, code, branding, and original content are the intellectual property of
          the SRM One development team. Faculty profile data and photos are sourced from SRM
          University's public website and are attributed to the university.
        </p>
        <p>
          All trademarks, logos, and service marks displayed on the Service are the property of their
          respective owners. Their use does not imply endorsement or affiliation.
        </p>
      </>
    ),
  },
  {
    title: "7. Disclaimer of Warranties",
    body: (
      <>
        <p>
          The Service is provided "AS IS" and "AS AVAILABLE" without warranties of any kind, either
          express or implied, including but not limited to:
        </p>
        <ul>
          <li>Warranties of merchantability or fitness for a particular purpose.</li>
          <li>That the Service will be error-free, secure, or uninterrupted.</li>
          <li>That data retrieved from third-party portals will be accurate or reliable.</li>
        </ul>
        <p>
          Your use of the Service is entirely at your own risk. The development team shall not be
          liable for any direct, indirect, incidental, consequential, or punitive damages arising
          from your use of (or inability to use) the Service.
        </p>
      </>
    ),
  },
  {
    title: "8. Limitation of Liability",
    body: (
      <>
        <p>
          To the maximum extent permitted by law, the SRM One development team shall not be liable
          for:
        </p>
        <ul>
          <li>Any loss of data, grades, or academic standing resulting from reliance on the Service.</li>
          <li>Any missed deadlines, interviews, or opportunities due to Service unavailability.</li>
          <li>Any unauthorized access to your account due to your failure to protect your credentials.</li>
          <li>Any actions taken by the university or third parties in response to your use of the Service.</li>
        </ul>
      </>
    ),
  },
  {
    title: "9. Changes to the Service & Terms",
    body: (
      <>
        <p>
          We reserve the right to modify, suspend, or discontinue the Service (or any part of it) at
          any time, with or without notice. We may also update these Terms periodically. Continued use
          of the Service after changes are posted constitutes your acceptance of the updated Terms.
        </p>
      </>
    ),
  },
  {
    title: "10. Termination",
    body: (
      <>
        <p>
          You may stop using the Service at any time by logging out. We may terminate or restrict
          access to the Service for any user who violates these Terms or engages in conduct that we
          deem harmful to the Service, other users, or the university.
        </p>
      </>
    ),
  },
  {
    title: "11. Governing Law",
    body: (
      <>
        <p>
          These Terms shall be governed by and construed in accordance with the laws of India. Any
          disputes arising from these Terms or your use of the Service shall be subject to the
          exclusive jurisdiction of the courts in Chennai, Tamil Nadu.
        </p>
      </>
    ),
  },
  {
    title: "12. Contact",
    body: (
      <>
        <p>
          For questions or concerns about these Terms, please contact the SRM One development team
          through the project's official communication channels.
        </p>
      </>
    ),
  },
];

export default function Terms() {
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
          Terms of Service
        </h1>
        <p className="text-slate-500 text-[15px] mb-12">
          Last updated: {new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}
        </p>

        <div className="space-y-10">
          {SECTIONS.map((section, i) => (
            <section key={i}>
              <h2 className="text-[20px] font-bold text-slate-900 mb-3 tracking-tight">{section.title}</h2>
              <div className="text-[15px] text-slate-600 leading-relaxed space-y-3 [&_ul]:space-y-1.5 [&_ul]:list-disc [&_ul]:pl-6 [&_li]:text-slate-600 [&_strong]:text-slate-800">
                {section.body}
              </div>
            </section>
          ))}
        </div>

        {/* Footer */}
        <div className="mt-16 pt-8 border-t border-slate-200/60 flex items-center justify-between text-[13px] text-slate-400 font-medium">
          <span>© {new Date().getFullYear()} SRM One</span>
          <button onClick={() => navigate("/privacy")} className="text-slate-600 hover:text-slate-900 underline underline-offset-2 cursor-pointer">
            Privacy Policy →
          </button>
        </div>
      </main>
    </div>
  );
}
