import { useEffect, useState } from "react";
import { FileText, ChevronDown, ChevronRight, GraduationCap } from "lucide-react";
import anime from "animejs";
import { motion, AnimatePresence } from "framer-motion";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/useAuth.jsx";
import { api } from "../api/client.js";
import Loading from "../components/Loading.jsx";

export default function Marks() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [marks, setMarks] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [expanded, setExpanded] = useState({});
  const [spSource, setSpSource] = useState(false);
  const [spNeedsReconnect, setSpNeedsReconnect] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [marksRes, attRes] = await Promise.all([
          api.marks(user.email),
          api.attendance(user.email).catch(() => ({ attendance: [] })) // Fallback if attendance fails
        ]);
        
        if (!cancelled) {
          // Create a lookup dictionary for course titles
          const titleMap = {};
          if (attRes && attRes.attendance) {
            attRes.attendance.forEach(c => {
              if (c.courseCode && c.courseTitle) {
                titleMap[c.courseCode] = c.courseTitle;
              }
            });
          }

          // Inject course titles into marks
          const enrichedMarks = (marksRes.marks || []).map(m => ({
            ...m,
            courseTitle: titleMap[m.courseCode] || m.courseTitle
          }));

          // Academia no longer exposes marks for many students — fall back to
          // the Student Portal internal marks (course totals) when empty.
          if (enrichedMarks.length === 0) {
            try {
              const spRes = await api.spMarks(user.email);
              if (spRes.captchaRequired) {
                if (!cancelled) {
                  setSpNeedsReconnect(true);
                  setMarks([]);
                  setLoading(false);
                }
                return;
              }
              const spMarks = (spRes.marks || []).map((m) => {
                const obtained = parseFloat(m.obtained);
                const max = parseFloat(m.maxMark);
                const pct = max > 0 && !isNaN(obtained) ? ((obtained / max) * 100).toFixed(1) : null;
                return {
                  courseCode: m.courseCode,
                  courseTitle: titleMap[m.courseCode] || m.courseTitle || m.courseCode,
                  courseType: "Internal",
                  source: "student_portal",
                  tests: [
                    {
                      testName: "Total (Internal)",
                      marksObtained: m.obtained,
                      maxMarks: m.maxMark,
                      percentage: pct,
                    },
                  ],
                };
              });
              if (!cancelled) {
                setMarks(spMarks);
                setSpSource(spMarks.length > 0);
                setLoading(false);
              }
              return;
            } catch {
              /* fall through to showing academia's empty result */
            }
          }

          if (!cancelled) {
            setMarks(enrichedMarks);
            setLoading(false);
          }
        }
      } catch (err) {
        if (!cancelled) {
          // If server is down or auth failed, redirect to login
          const errorMsg = err.message || "";
          if (
            errorMsg.includes("backend running") ||
            errorMsg.includes("Empty response") ||
            errorMsg.includes("session") ||
            errorMsg.includes("unauthorized") ||
            errorMsg.includes("not logged in")
          ) {
            logout();
            navigate("/login", { replace: true });
            return;
          }
          setError(err.message);
          setLoading(false);
        }
      }
    })();
    return () => { cancelled = true; };
  }, [user.email, logout, navigate]);

  useEffect(() => {
    if (!loading && marks) {
      anime({
        targets: ".mark-row",
        opacity: [0, 1],
        translateY: [20, 0],
        delay: anime.stagger(60),
        duration: 500,
        easing: "easeOutExpo",
      });
    }
  }, [loading, marks]);

  if (loading) return <Loading label="Loading marks…" />;
  if (error) return <ErrorBox message={error} />;

  const toggle = (code) => setExpanded((p) => ({ ...p, [code]: !p[code] }));

  return (
    <div className="space-y-6 pt-4">
      {/* Banner / Header */}
      <div className="bg-[#1A1A1A] rounded-[32px] p-8 md:p-10 flex flex-col md:flex-row items-start md:items-center justify-between overflow-hidden relative min-h-[220px]">
        <div className="absolute inset-y-0 right-0 h-full w-[40%] sm:w-48 md:w-72 opacity-90 mix-blend-screen pointer-events-none py-4 pr-6">
          <img src="/assets/success_288d.svg" alt="Success" className="w-full h-full object-contain object-right" />
        </div>
        
        <div className="relative z-10 text-white w-[60%] sm:w-[65%] md:w-auto md:max-w-sm mb-6 md:mb-0">
          <h1 className="font-display text-3xl sm:text-4xl font-bold mb-2 tracking-tight">Marks & Grades</h1>
          <p className="text-white/70 text-sm font-medium">Review your test scores, track your performance, and celebrate your progress.</p>
        </div>
      </div>

      {spSource && marks.length > 0 && (
        <div className="flex items-center gap-2 text-xs font-semibold text-slate-500 -mt-2">
          <span className="w-2 h-2 rounded-full bg-mint" />
          Internal marks from Student Portal
        </div>
      )}

      {spNeedsReconnect ? (
        <div className="bg-white rounded-[32px] p-10 text-center border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
          <FileText className="w-12 h-12 text-slate-300 mx-auto mb-3" />
          <p className="text-slate-700 font-bold mb-1">Reconnect the Student Portal</p>
          <p className="text-slate-500 text-sm mb-4">
            Marks come from the SRM Student Portal. Open the Attendance tab and solve the
            captcha once to reconnect — marks will then load here automatically.
          </p>
          <button
            onClick={() => navigate("/dashboard/attendance")}
            className="inline-flex items-center gap-2 px-5 py-3 bg-[#1A1A1A] text-white text-sm font-bold rounded-full hover:bg-[#333] transition-colors"
          >
            Go to Attendance
          </button>
        </div>
      ) : marks.length === 0 ? (
        <div className="bg-white rounded-[32px] p-12 text-center border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
          <FileText className="w-12 h-12 text-slate-300 mx-auto mb-3" />
          <p className="text-slate-500 font-medium">No marks data available</p>
        </div>
      ) : (
        <div className="grid lg:grid-cols-2 gap-4 items-start">
          {marks.map((rec) => {
            const isOpen = expanded[rec.courseCode];
            const tests = rec.tests || [];
            return (
              <div
                key={rec.courseCode}
                className="mark-row bg-white rounded-[32px] border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)] overflow-hidden flex flex-col"
                style={{ opacity: 0 }}
              >
                <button
                  onClick={() => toggle(rec.courseCode)}
                  className="w-full p-6 md:p-8 flex items-center justify-between text-left hover:bg-slate-50/50 transition-colors cursor-pointer"
                >
                  <div className="flex-1 min-w-0 pr-4">
                    <div className="flex items-center gap-2 mb-2">
                      <span className="text-[11px] font-bold font-mono px-3 py-1 bg-[#1A1A1A] text-white rounded-full uppercase tracking-wider">{rec.courseCode}</span>
                      <span className="text-[11px] px-3 py-1 rounded-full bg-slate-100 text-slate-600 font-bold">
                        {rec.courseType}
                      </span>
                    </div>
                    <p className="text-lg font-bold text-[#1A1A1A] line-clamp-2 leading-tight">
                      {rec.courseTitle || rec.courseCode}
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs font-bold text-slate-400 bg-slate-100 px-3 py-1 rounded-full whitespace-nowrap">
                      {tests.length} test{tests.length !== 1 ? "s" : ""}
                    </span>
                    <div className={`w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center transition-transform ${isOpen ? 'rotate-180' : ''}`}>
                      <ChevronDown className="w-5 h-5 text-slate-600" />
                    </div>
                  </div>
                </button>

                <AnimatePresence>
                  {isOpen && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                      className="overflow-hidden"
                    >
                      <div className="px-6 md:px-8 pb-6 md:pb-8 pt-2">
                        {tests.length === 0 ? (
                          <div className="bg-slate-50 rounded-2xl p-6 text-center">
                            <p className="text-slate-500 font-medium text-sm">
                              No test scores published yet.
                            </p>
                          </div>
                        ) : (
                      <div className="grid gap-3">
                        {tests.map((test, i) => (
                          <div
                            key={i}
                            className="p-5 rounded-2xl bg-slate-50 border border-slate-100 flex flex-col gap-3"
                          >
                            <div className="flex items-center justify-between">
                              <p className="text-[13px] text-slate-500 font-bold uppercase tracking-wider">{test.testName || `Test ${i + 1}`}</p>
                              <div className="flex items-baseline gap-1">
                                <span className="text-2xl font-display font-bold text-[#1A1A1A]">
                                  {test.marksObtained ?? "—"}
                                </span>
                                <span className="text-sm font-bold text-slate-400">/ {test.maxMarks ?? "—"}</span>
                              </div>
                            </div>
                            
                            {test.percentage && (
                              <div className="h-2 rounded-full bg-slate-200 overflow-hidden relative">
                                <div
                                  className="h-full rounded-full bg-mint transition-all duration-1000 ease-out"
                                  style={{ width: `${Math.min(parseFloat(test.percentage), 100)}%` }}
                                />
                              </div>
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function ErrorBox({ message }) {
  return (
    <div className="bg-white rounded-[32px] p-8 text-center border border-red-100">
      <p className="text-red-500 text-sm font-bold">{message}</p>
    </div>
  );
}
