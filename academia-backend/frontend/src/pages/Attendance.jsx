import { useEffect, useState } from "react";
import { CalendarCheck, TrendingUp, TrendingDown, LineChart as LineChartIcon } from "lucide-react";
import anime from "animejs";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/useAuth.jsx";
import { api } from "../api/client.js";
import Loading from "../components/Loading.jsx";
import FacultyAvatar from "../components/FacultyAvatar.jsx";
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from "recharts";

export default function Attendance() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [records, setRecords] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [history, setHistory] = useState([]);

  useEffect(() => {
    let cancelled = false;
    let pollTimer = null;

    const fetchData = async () => {
      try {
        const [attendanceData, historyResponse] = await Promise.all([
          api.attendance(user.email),
          api.getAttendanceHistory(user.email, 30).catch(() => ({ data: [] }))
        ]);
        if (cancelled) return;
        setRecords(attendanceData.attendance);
        setHistory(historyResponse.data || []);
        setLoading(false);

        // If photos aren't ready yet, poll again in 3s (silently)
        if (!attendanceData.photosReady) {
          pollTimer = setTimeout(fetchData, 3000);
        }
      } catch (err) {
        if (cancelled) return;
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

  if (loading) return <Loading label="Loading attendance…" />;
  if (error) return <ErrorBox message={error} />;

  const sorted = [...records].sort(
    (a, b) => parseFloat(b.attendancePct || 0) - parseFloat(a.attendancePct || 0)
  );

  const overall = records.length > 0
    ? (records.reduce((s, r) => s + parseFloat(r.attendancePct || 0), 0) / records.length).toFixed(1)
    : 0;

  const above75 = records.filter((r) => parseFloat(r.attendancePct) >= 75).length;
  const below75 = records.length - above75;

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
