import { useEffect, useState, useMemo } from "react";
import { CalendarCheck, TrendingUp, TrendingDown, LineChart as LineChartIcon, RefreshCw, AlertCircle, Eye, EyeOff, Loader2 } from "lucide-react";
import anime from "animejs";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/useAuth.jsx";
import { api } from "../api/client.js";
import Loading from "../components/Loading.jsx";
import FacultyAvatar from "../components/FacultyAvatar.jsx";
import AttendancePlanner from "../components/AttendancePlanner.jsx";
import { buildCalendarMap } from "../utils/calendarTimetableSync.js";
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from "recharts";

export default function Attendance() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [records, setRecords] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [history, setHistory] = useState([]);
  const [timetable, setTimetable] = useState(null);
  const [calendarMap, setCalendarMap] = useState(null);
  const [spLoading, setSpLoading] = useState(false);
  const [spError, setSpError] = useState("");
  const [spSource, setSpSource] = useState(false);
  const [showSpLogin, setShowSpLogin] = useState(false);
  const [spPwd, setSpPwd] = useState("");
  const [spLoginLoading, setSpLoginLoading] = useState(false);
  const [spLoginError, setSpLoginError] = useState("");
  const [showSpPwd, setShowSpPwd] = useState(false);

  useEffect(() => {
    let cancelled = false;
    let pollTimer = null;

    const fetchData = async () => {
      try {
        const [attendanceData, historyResponse, initData] = await Promise.all([
          api.attendance(user.email),
          api.getAttendanceHistory(user.email, 30).catch(() => ({ data: [] })),
          api.init(user.email).catch(() => null),
        ]);
        if (cancelled) return;

        // If backend returned SP attendance as fallback, mark source
        if (attendanceData.source === "student_portal") {
          setSpSource(true);
        } else {
          setSpSource(false);
        }

        setRecords(attendanceData.attendance);
        setHistory(historyResponse.data || []);

        // If academia attendance is unavailable and no SP fallback yet,
        // automatically try fetching from Student Portal
        if (attendanceData.unavailable && (!attendanceData.attendance || attendanceData.attendance.length === 0)) {
          setSpError("Academia attendance is currently unavailable. Trying Student Portal…");
          // Attempt SP fetch automatically
          try {
            const spData = await api.spAttendance(user.email);
            if (!cancelled && spData.attendance && spData.attendance.length > 0) {
              setRecords(spData.attendance);
              setSpSource(true);
              setSpError("");
            } else if (!cancelled) {
              setSpError("Student Portal also returned no attendance data. Please try again later.");
            }
          } catch (spErr) {
            if (!cancelled) {
              setSpError(spErr.message || "Failed to fetch from Student Portal. Try logging in again.");
            }
          }
        } else if (attendanceData.unavailable) {
          setSpError("Academia attendance is currently unavailable. Showing Student Portal data.");
        } else {
          setSpError("");
        }

        if (initData) {
          setTimetable(initData.timetable || null);
          if (initData.calendar) {
            setCalendarMap(buildCalendarMap(initData.calendar));
          }
        }
        setLoading(false);

        // If photos aren't ready yet, poll again in 3s (silently)
        if (!attendanceData.photosReady) {
          pollTimer = setTimeout(fetchData, 3000);
        }
      } catch (err) {
        if (cancelled) return;
        const errorMsg = err.message || "";

        // If session expired but SP login may still be in progress, retry
        if (errorMsg.includes("No active session") || errorMsg.includes("session expired")) {
          setSpError("Connecting to Student Portal… This may take a moment.");
          setSpLoading(true);
          // Retry after 5s — SP background login takes ~30s for captcha solve
          pollTimer = setTimeout(async () => {
            if (cancelled) return;
            try {
              const spData = await api.spAttendance(user.email);
              if (!cancelled && spData.attendance && spData.attendance.length > 0) {
                setRecords(spData.attendance);
                setSpSource(true);
                setSpError("");
                setSpLoading(false);
                setLoading(false);
              } else if (!cancelled) {
                // Still no SP data — retry again (up to a few times)
                pollTimer = setTimeout(fetchData, 5000);
              }
            } catch (spErr) {
              if (!cancelled) {
                const spMsg = spErr.message || "";
                if (spMsg.includes("No student portal session") || spMsg.includes("Please login")) {
                  // SP login hasn't completed or failed — show login prompt
                  setShowSpLogin(true);
                  setSpLoading(false);
                  setLoading(false);
                  setSpError("Student Portal login required. Your SP password may be different from your academia password.");
                } else {
                  setSpLoading(false);
                  setLoading(false);
                  setSpError(spMsg || "Failed to fetch from Student Portal.");
                }
              }
            }
          }, 5000);
          return;
        }

        // If server is down or other auth error, redirect to login
        if (
          errorMsg.includes("backend running") ||
          errorMsg.includes("Empty response") ||
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
    };

    fetchData();
    return () => {
      cancelled = true;
      if (pollTimer) clearTimeout(pollTimer);
    };
  }, [user.email, logout, navigate]);

  useEffect(() => {
    if (!loading && records) {
      anime({
        targets: ".attendance-row",
        opacity: [0, 1],
        translateY: [20, 0],
        delay: anime.stagger(50),
        duration: 600,
        easing: "easeOutExpo",
      });
    }
  }, [loading, records]);

  const tryStudentPortal = async () => {
    setSpLoading(true);
    setSpError("");
    try {
      const data = await api.spAttendance(user.email);
      if (data.attendance && data.attendance.length > 0) {
        setRecords(data.attendance);
        setSpSource(true);
        setSpError("");
        setShowSpLogin(false);
      } else {
        setSpError("Student portal returned no attendance data.");
      }
    } catch (err) {
      const msg = err.message || "Failed to fetch from student portal";
      if (msg.includes("No student portal session") || msg.includes("Please login")) {
        setShowSpLogin(true);
        setSpError("Student Portal login required. Your SP password may be different from your academia password.");
      } else {
        setSpError(msg);
      }
    } finally {
      setSpLoading(false);
    }
  };

  const handleSpLogin = async () => {
    if (!spPwd) {
      setSpLoginError("Please enter your Student Portal password.");
      return;
    }
    setSpLoginLoading(true);
    setSpLoginError("");
    try {
      const result = await api.spLogin(user.email, spPwd);
      if (result.attendance && result.attendance.length > 0) {
        setRecords(result.attendance);
        setSpSource(true);
        setShowSpLogin(false);
        setSpError("");
        setSpPwd("");
      } else {
        setSpLoginError("Login successful but no attendance data found. Try refreshing.");
      }
    } catch (err) {
      setSpLoginError(err.message || "Student Portal login failed. Check your password.");
    } finally {
      setSpLoginLoading(false);
    }
  };

  if (loading) return <Loading label="Loading attendance…" />;
  if (error) return <ErrorBox message={error} />;

  const sorted = [...(records || [])].sort(
    (a, b) => parseFloat(b.attendancePct || 0) - parseFloat(a.attendancePct || 0)
  );

  const overall = (records || []).length > 0
    ? (records.reduce((s, r) => s + parseFloat(r.attendancePct || 0), 0) / records.length).toFixed(1)
    : 0;

  const above75 = (records || []).filter((r) => parseFloat(r.attendancePct) >= 75).length;
  const below75 = (records || []).length - above75;

  return (
    <div className="space-y-6 pt-4">
      {/* Banner / Header */}
      <div className="bg-[#1A1A1A] rounded-[32px] p-8 md:p-10 flex flex-col md:flex-row items-start md:items-center justify-between overflow-hidden relative min-h-[220px]">
        <div className="absolute inset-y-0 right-0 h-full w-[40%] sm:w-48 md:w-72 opacity-90 mix-blend-screen pointer-events-none py-4 pr-6">
          <img src="/assets/calendar_8r6s.svg" alt="Calendar" className="w-full h-full object-contain object-right" />
        </div>
        
        <div className="relative z-10 text-white w-[60%] sm:w-[65%] md:w-auto md:max-w-sm mb-6 md:mb-0">
          <h1 className="font-display text-3xl sm:text-4xl font-bold mb-2 tracking-tight">Attendance</h1>
          <p className="text-white/70 text-sm font-medium">Keep track of your classes, stay above 75%, and manage your absences.</p>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <SummaryCard 
          icon={CalendarCheck} 
          label="Overall Average" 
          value={`${overall}%`} 
          colorClass="bg-mint" 
          textColor="text-[#1A1A1A]" 
        />
        <SummaryCard 
          icon={TrendingUp} 
          label="Subjects Above 75%" 
          value={above75} 
          colorClass="bg-lavender" 
          textColor="text-[#1A1A1A]" 
        />
        <SummaryCard 
          icon={TrendingDown} 
          label="Subjects Below 75%" 
          value={below75} 
          colorClass="bg-terracotta text-white" 
          textColor="text-white"
          subColor="text-white/80"
        />
      </div>

      {/* Attendance History Chart */}
      <div className="attendance-row bg-white rounded-[32px] p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]" style={{ opacity: 0 }}>
        <div className="flex items-center justify-between mb-6">
          <h3 className="font-display font-bold text-2xl text-[#1A1A1A]">Attendance Trend</h3>
          <div className="w-10 h-10 rounded-full bg-mint/20 flex items-center justify-center">
            <LineChartIcon className="w-5 h-5 text-mint" />
          </div>
        </div>
        {history.length > 0 ? (
          <>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={history.map(h => ({
                date: new Date(h.snapshot_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                percentage: parseFloat(h.overall_percentage || 0)
              }))}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                <XAxis dataKey="date" stroke="#6B7280" style={{ fontSize: '12px' }} />
                <YAxis domain={[0, 100]} stroke="#6B7280" style={{ fontSize: '12px' }} />
                <Tooltip 
                  contentStyle={{ 
                    backgroundColor: '#1A1A1A', 
                    border: 'none', 
                    borderRadius: '12px',
                    color: '#fff',
                    fontSize: '14px',
                    padding: '12px'
                  }}
                  formatter={(value) => [`${value.toFixed(1)}%`, 'Attendance']}
                />
                <ReferenceLine y={75} stroke="#F97316" strokeDasharray="5 5" label={{ value: '75% Threshold', position: 'insideTopRight', fill: '#F97316', fontSize: 12 }} />
                <Line type="monotone" dataKey="percentage" stroke="#00D9A3" strokeWidth={3} dot={{ fill: '#00D9A3', r: 4 }} activeDot={{ r: 6 }} />
              </LineChart>
            </ResponsiveContainer>
            <p className="text-sm text-slate-600 mt-4 text-center">
              {history.length === 1 
                ? "First snapshot recorded — visit again to build your trend" 
                : `Last ${history.length} days attendance trend`}
            </p>
          </>
        ) : (
          <div className="flex flex-col items-center justify-center py-12 text-center">
            <div className="w-16 h-16 rounded-full bg-slate-100 flex items-center justify-center mb-4">
              <LineChartIcon className="w-8 h-8 text-slate-300" />
            </div>
            <p className="text-slate-500 font-medium text-sm mb-1">No attendance history yet</p>
            <p className="text-slate-400 text-xs">Your attendance trend will appear here after future visits. A snapshot is recorded each time you view this page.</p>
          </div>
        )}
      </div>

      {/* Attendance Planner */}
      <AttendancePlanner records={records} timetable={timetable} calendarMap={calendarMap} />

      {/* Student Portal fallback banner */}
      {spError && (
        <div className="bg-amber-50 border border-amber-200 rounded-[24px] p-5 flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <p className="text-amber-800 text-sm font-medium">{spError}</p>
          </div>
        </div>
      )}

      {spSource && (
        <div className="bg-mint/10 border border-mint/30 rounded-[24px] p-4 flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-mint/20 flex items-center justify-center">
            <RefreshCw className="w-4 h-4 text-mint" />
          </div>
          <p className="text-sm text-slate-700 font-medium">
            Showing attendance from <strong>Student Portal</strong> (sp.srmist.edu.in) — academia attendance was unavailable.
          </p>
        </div>
      )}

      {/* Student Portal fallback / refresh button */}
      {(!records || records.length === 0) && !spLoading && (
        <div className="bg-white rounded-[32px] p-8 text-center border border-slate-100">
          <div className="w-16 h-16 rounded-full bg-slate-100 flex items-center justify-center mx-auto mb-4">
            <CalendarCheck className="w-8 h-8 text-slate-300" />
          </div>
          <p className="text-slate-600 font-medium text-sm mb-1">No attendance data from Academia</p>
          <p className="text-slate-400 text-xs mb-4">Academia attendance may be closed. Try fetching from the Student Portal instead.</p>
          <button
            onClick={tryStudentPortal}
            disabled={spLoading}
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-[#1A1A1A] text-white text-sm font-bold rounded-full hover:bg-[#333] transition-colors disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${spLoading ? "animate-spin" : ""}`} />
            {spLoading ? "Fetching from Student Portal…" : "Fetch from Student Portal"}
          </button>
        </div>
      )}

      {/* Refresh from Student Portal when SP data is shown */}
      {spSource && records && records.length > 0 && (
        <div className="flex justify-end">
          <button
            onClick={tryStudentPortal}
            disabled={spLoading}
            className="inline-flex items-center gap-2 px-4 py-2 text-slate-500 text-xs font-bold rounded-full hover:bg-slate-100 transition-colors disabled:opacity-50"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${spLoading ? "animate-spin" : ""}`} />
            {spLoading ? "Refreshing…" : "Refresh from Student Portal"}
          </button>
        </div>
      )}

      {/* SP Login prompt — shown when SP credentials may differ */}
      {showSpLogin && (
        <div className="bg-white rounded-[32px] p-8 border border-slate-100">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-full bg-amber-50 flex items-center justify-center">
              <AlertCircle className="w-5 h-5 text-amber-500" />
            </div>
            <div>
              <p className="text-slate-800 font-bold text-sm">Student Portal Login Required</p>
              <p className="text-slate-400 text-xs">Your Student Portal password may be different from your academia password.</p>
            </div>
          </div>
          {spLoginError && (
            <p className="text-red-500 text-xs font-medium mb-3">{spLoginError}</p>
          )}
          <div className="flex gap-2">
            <div className="relative flex-1">
              <input
                type={showSpPwd ? "text" : "password"}
                value={spPwd}
                onChange={(e) => setSpPwd(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSpLogin()}
                placeholder="Student Portal password"
                className="w-full px-4 py-3 pr-11 rounded-full text-sm font-medium outline-none border border-slate-200 bg-white text-slate-900 placeholder:text-slate-400 focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50"
              />
              <button
                type="button"
                onClick={() => setShowSpPwd(!showSpPwd)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
              >
                {showSpPwd ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            <button
              onClick={handleSpLogin}
              disabled={spLoginLoading || !spPwd}
              className="inline-flex items-center gap-2 px-5 py-3 bg-[#1A1A1A] text-white text-sm font-bold rounded-full hover:bg-[#333] transition-colors disabled:opacity-50 whitespace-nowrap"
            >
              {spLoginLoading ? <Loader2 size={16} className="animate-spin" /> : <RefreshCw size={16} />}
              {spLoginLoading ? "Logging in…" : "Login & Fetch"}
            </button>
          </div>
          <button
            onClick={() => { setShowSpLogin(false); setSpError(""); setSpLoginError(""); }}
            className="text-slate-400 text-xs font-medium mt-3 hover:text-slate-600"
          >
            Cancel
          </button>
        </div>
      )}

      {/* Attendance list */}
      <div className="bg-white rounded-[32px] p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
        <h3 className="font-display font-bold text-2xl text-[#1A1A1A] mb-6">Course Breakdown</h3>
        <div className="grid gap-4 sm:grid-cols-2">
          {sorted.map((rec) => (
            <AttendanceRow key={rec.courseCode} rec={rec} />
          ))}
        </div>
      </div>
    </div>
  );
}

function SummaryCard({ icon: Icon, label, value, colorClass, textColor, subColor }) {
  return (
    <div className={`attendance-row ${colorClass} rounded-[24px] p-6 flex flex-col justify-between`} style={{ opacity: 0 }}>
      <div className="flex justify-between items-start mb-6">
        <span className={`${textColor} font-semibold text-lg`}>{label}</span>
        <div className="w-10 h-10 rounded-full bg-black/10 flex items-center justify-center">
          <Icon className={`w-5 h-5 ${textColor}`} />
        </div>
      </div>
      <div>
        <p className={`text-5xl font-display font-bold ${textColor}`}>{value}</p>
        <p className={`text-sm mt-1 ${subColor || 'text-[#1A1A1A]/70'}`}>Courses</p>
      </div>
    </div>
  );
}

function AttendanceRow({ rec }) {
  const pct = parseFloat(rec.attendancePct || 0);
  const conducted = parseInt(rec.hoursConducted || 0);
  const absent = parseInt(rec.hoursAbsent || 0);
  const present = conducted - absent;

  const isGood = pct >= 75;
  const isWarning = pct >= 50 && pct < 75;
  const barColor = isGood ? "bg-mint" : isWarning ? "bg-beige" : "bg-terracotta";
  
  let bunkText = "";
  let bunkColor = "";

  if (conducted === 0) {
    bunkText = "No classes yet";
    bunkColor = "text-slate-600 bg-slate-100";
  } else if (pct >= 75) {
    const bunkable = Math.floor((present - 0.75 * conducted) / 0.75);
    bunkText = bunkable > 0 ? `Can bunk ${bunkable} class${bunkable > 1 ? 'es' : ''}` : "On track (0 to bunk)";
    bunkColor = bunkable > 0 ? "text-emerald-700 bg-emerald-100" : "text-amber-700 bg-amber-100";
  } else {
    const req = Math.ceil((0.75 * conducted - present) / 0.25);
    bunkText = `Need ${req} class${req > 1 ? 'es' : ''} to reach 75%`;
    bunkColor = "text-red-700 bg-red-100";
  }
  
  return (
    <div className="attendance-row bg-white rounded-[24px] p-5 md:p-6 shadow-[0_4px_20px_rgba(0,0,0,0.03)] border border-slate-100 flex flex-col h-full" style={{ opacity: 0 }}>
      {/* Header: Code & Percentage */}
      <div className="flex justify-between items-center mb-3 gap-2">
        <span className="inline-block px-3 py-1 bg-[#1A1A1A] text-white text-[11px] font-bold rounded-full font-mono uppercase tracking-wider">
          {rec.courseCode}
        </span>
        <p className="text-2xl md:text-3xl font-display font-bold text-[#1A1A1A] leading-none">{pct}%</p>
      </div>

      {/* Course Title (Full width, no truncation) */}
      <p className="font-bold text-slate-800 text-[15px] md:text-lg leading-snug mb-4">
        {rec.courseTitle}
      </p>

      {/* Faculty and Bunk Status */}
      <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
        {rec.facultyName && (
          <div className="flex items-center gap-2 min-w-0">
            <FacultyAvatar name={rec.facultyName} photoUrl={rec.facultyPhotoUrl} size={28} />
            <p className="text-xs md:text-sm font-medium text-slate-500">
              {String(rec.facultyName).replace(/\(.*?\)/g, "").trim()}
            </p>
          </div>
        )}
        <span className={`text-[11px] font-bold px-2.5 py-1.5 rounded-md ${bunkColor}`}>
          {bunkText}
        </span>
      </div>

      <div className="mt-auto pt-4">
        <div className="h-3 rounded-full bg-slate-100 overflow-hidden mb-3">
          <div
            className={`h-full rounded-full ${barColor} transition-all duration-1000 ease-out`}
            style={{ width: `${Math.max(pct, 2)}%` }}
          />
        </div>

        <div className="flex items-center justify-between text-xs text-slate-500 font-medium">
          <span>Cond: {conducted}</span>
          <span className="text-emerald-600">Pres: {present}</span>
          <span className="text-red-500">Abs: {absent}</span>
        </div>
      </div>
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
