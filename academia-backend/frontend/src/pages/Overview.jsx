import { useEffect, useState, useMemo } from "react";
import { ArrowUpRight, MapPin, CalendarDays, CalendarX, Sun, Coffee } from "lucide-react";
import anime from "animejs";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/useAuth.jsx";
import { api } from "../api/client.js";
import Loading from "../components/Loading.jsx";
import FacultyAvatar from "../components/FacultyAvatar.jsx";
import { buildCalendarMap, getDayStatus, getCurrentWeekDates, dateKey } from "../utils/calendarTimetableSync.js";
import HolidayGif from "../components/HolidayGif.jsx";
import PlacementConnectBanner from "../components/PlacementConnectBanner.jsx";

function cleanName(name = "") {
  return String(name).replace(/\(.*?\)/g, "").trim();
}

const DAYS = ["Day 1", "Day 2", "Day 3", "Day 4", "Day 5"];

export default function Overview() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [calendarMap, setCalendarMap] = useState(null);
  const [selectedDay, setSelectedDay] = useState(() => {
    const dayMap = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const dayOrderMap = { Mon: "Day 1", Tue: "Day 2", Wed: "Day 3", Thu: "Day 4", Fri: "Day 5" };
    // Default to today's day order; on weekends default to Day 1 (Monday)
    const today = new Date().getDay();
    if (today === 0) return "Day 1"; // Sunday → show Monday's schedule
    if (today === 6) return "Day 5"; // Saturday → show Friday's schedule
    return dayOrderMap[dayMap[today]] || "Day 1";
  });

  // Build calendar map from init data (must be before conditional returns)
  const weekDates = useMemo(() => getCurrentWeekDates(), []);

  useEffect(() => {
    let cancelled = false;
    let pollTimer = null;

    const fetchData = async () => {
      try {
        const [init, attendance] = await Promise.all([
          api.init(user.email),
          api.attendance(user.email),
        ]);
        if (cancelled) return;
        setData({
          studentInfo: init.studentInfo,
          timetable: init.timetable,
          calendar: init.calendar,
          attendance: attendance.attendance,
        });
        // Build calendar map for holiday/day-order detection
        if (init.calendar) {
          const calMap = buildCalendarMap(init.calendar);
          setCalendarMap(calMap);
          
          // Set active tab to today's real day order
          const todayStatus = getDayStatus(calMap, new Date());
          if (todayStatus?.dayOrder) {
            setSelectedDay(`Day ${todayStatus.dayOrder}`);
          }
        }
        setLoading(false);

        // If photos aren't ready yet, poll again in 3s (silently, no loading state)
        const photosReady = init.photosReady && attendance.photosReady;
        if (!photosReady) {
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
    if (!loading) {
      anime({
        targets: ".anim-item",
        opacity: [0, 1],
        translateY: [20, 0],
        delay: anime.stagger(100),
        duration: 800,
        easing: "easeOutExpo",
      });
    }
  }, [loading]);

  if (loading) return <Loading label="Fetching your academic dashboard…" />;
  if (error) return <ErrorBox message={error} />;

  const { studentInfo, attendance, timetable } = data;
  const courses = timetable?.courses || [];
  const advisors = timetable?.advisors || [];
  const attendanceRecords = attendance || [];

  const overallPct =
    attendanceRecords.length > 0
      ? (
          attendanceRecords.reduce((sum, r) => sum + parseFloat(r.attendancePct || 0), 0) /
          attendanceRecords.length
        ).toFixed(1)
      : "—";

  // Calculate classes today using calendar-aware day order
  const today = new Date();
  const todayStatus = calendarMap
    ? getDayStatus(calendarMap, today)
    : null;
  const isTodayHoliday = todayStatus?.status === "holiday";
  const isWeekend = todayStatus
    ? todayStatus.status === "weekend"
    : today.getDay() === 0 || today.getDay() === 6;
  const todayDayOrder = todayStatus?.dayOrder || (!isWeekend && !isTodayHoliday ? ({ Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5 }[["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][today.getDay()]] || null) : null);
  const todayDay = todayDayOrder ? `Day ${todayDayOrder}` : null;
  const todayHolidayEvent = todayStatus?.event || "";
  const dayName = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"][today.getDay()];
  const todayLabel = isTodayHoliday ? "Holiday" : isWeekend ? `${dayName} (Weekend)` : todayDay;

  const dayClasses = courses
    .flatMap((c) =>
      (c.schedule || [])
        .filter((s) => s.day === selectedDay)
        .map((s) => ({ ...s, course: c }))
    )
    .sort((a, b) => a.hourIndex - b.hourIndex);

  // Classes scheduled for today (independent of selectedDay) — used by the today banner
  const todayClasses = todayDay
    ? courses
        .flatMap((c) =>
          (c.schedule || [])
            .filter((s) => s.day === todayDay)
            .map((s) => ({ ...s, course: c }))
        )
        .sort((a, b) => a.hourIndex - b.hourIndex)
    : [];

  return (
    <div className="space-y-6 pt-4">
      {/* Placement Connect Banner (shows if not connected) */}
      <PlacementConnectBanner />

      {/* 1. Top Section Grid */}
      <div className="grid lg:grid-cols-3 gap-6">
        
        {/* Dark Hero Banner (takes 2 columns) */}
        <div className="anim-item lg:col-span-2 relative bg-[#1A1A1A] rounded-[32px] p-8 md:p-10 overflow-hidden text-white min-h-[300px] flex flex-col justify-between" style={{ opacity: 0 }}>
          {/* Decorative Assets */}
          <div className="absolute right-0 bottom-0 h-full w-[45%] sm:w-[60%] md:w-auto md:h-[130%] max-h-[400px] opacity-80 md:opacity-90 pointer-events-none mix-blend-screen flex items-end justify-end">
             <img src="/assets/learning_qt7d.svg" alt="Education illustration" className="object-contain object-right-bottom h-full w-full" />
          </div>
          <div className="absolute top-6 right-8 opacity-20 hidden md:block">
             <div className="w-12 h-12 rounded-full border border-white/50 mb-2"></div>
             <div className="w-12 h-12 rounded-full border border-white/50 mb-2"></div>
             <div className="w-12 h-12 rounded-full border border-white/50"></div>
          </div>

          <div className="relative z-10 w-[55%] sm:max-w-sm">
            <h2 className="text-white/70 text-lg md:text-xl mb-1 font-medium">Welcome back,</h2>
            <h1 className="text-3xl sm:text-4xl md:text-5xl font-display font-bold leading-tight mb-4 tracking-tight">
              {studentInfo?.Name?.split(" ")[0] || "Student"}
            </h1>
            <p className="text-white/60 text-sm md:text-base leading-relaxed mb-8">
              {studentInfo?.Department} • Batch {studentInfo?.Batch || "—"}
            </p>
          </div>
          
          <div className="relative z-10">
            <Link to="/dashboard/timetable" className="bg-terracotta text-white hover:bg-[#c26245] transition-colors rounded-full px-6 py-3 font-semibold flex items-center gap-2 w-max cursor-pointer">
              View Timetable
              <div className="bg-white/20 rounded-full p-1.5"><CalendarDays size={16} /></div>
            </Link>
          </div>
        </div>

        {/* Stats Column (1 column) */}
        <div className="anim-item flex flex-col gap-4" style={{ opacity: 0 }}>
          {/* Stat 1: Mint */}
          <div className="bg-mint flex-1 rounded-[24px] p-6 flex flex-col justify-between relative overflow-hidden">
             <div className="flex justify-between items-start">
               <span className="text-[#1A1A1A] font-semibold text-lg">Total Courses</span>
               <div className="w-8 h-8 rounded-full bg-white/40 flex items-center justify-center"><ArrowUpRight size={16} className="text-[#1A1A1A]" /></div>
             </div>
             <div className="mt-4">
               <span className="text-5xl font-display font-bold text-[#1A1A1A]">{courses.length}</span>
               <span className="text-slate-700 ml-2 font-medium">Enrolled</span>
             </div>
          </div>
          
          {/* Stat 2: Lavender */}
          <div className="bg-lavender flex-1 rounded-[24px] p-6 flex flex-col justify-between relative overflow-hidden">
             <div className="flex justify-between items-start">
               <span className="text-[#1A1A1A] font-semibold text-lg">Attendance</span>
             </div>
             <div className="mt-4 flex items-end justify-between">
               <div>
                 <span className="text-5xl font-display font-bold text-[#1A1A1A]">{overallPct}</span>
                 <span className="text-slate-700 ml-1 font-bold text-xl">%</span>
               </div>
               
               {/* Decorative little pills */}
               <div className="flex items-end gap-1.5 opacity-60">
                 <div className="w-3 h-8 bg-black/20 rounded-full"></div>
                 <div className="w-3 h-12 bg-black/30 rounded-full"></div>
                 <div className="w-3 h-16 bg-black/40 rounded-full"></div>
                 <div className="w-3 h-10 bg-black/30 rounded-full"></div>
               </div>
             </div>
          </div>
        </div>

      </div>

      {advisors.length > 0 && (
        <div className="anim-item grid sm:grid-cols-2 gap-4" style={{ opacity: 0 }}>
          {advisors.map((advisor) => (
            <div
              key={`${advisor.role}-${advisor.name}`}
              className="bg-white rounded-[24px] p-5 border border-slate-200/50 shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex items-center gap-4"
            >
              <FacultyAvatar name={advisor.name} photoUrl={advisor.photoUrl} size={52} />
              <div className="min-w-0">
                <p className="text-[10px] font-bold uppercase tracking-wider text-slate-400 mb-1">
                  {advisor.role || "Advisor"}
                </p>
                <p className="font-bold text-[#1A1A1A] text-[15px] truncate">{cleanName(advisor.name)}</p>
                {advisor.email && <p className="text-xs text-slate-500 truncate mt-0.5">{advisor.email}</p>}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* 2. Main Content Row */}
      <div className="grid lg:grid-cols-3 gap-6 pt-4">
        {/* Left: Today's Timeline (2/3) */}
        <div className="anim-item lg:col-span-2 min-w-0" style={{ opacity: 0 }}>
          <div className="bg-beige/40 rounded-[32px] p-6 md:p-8 h-full">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-4 gap-3">
              <h3 className="font-display font-bold text-2xl text-[#1A1A1A]">
                {selectedDay === todayDay ? "Today's Schedule" : "Schedule"}
              </h3>
              <div className="flex flex-wrap items-center gap-2">
                <span className="px-3 py-1.5 rounded-full bg-terracotta/10 text-terracotta font-bold text-xs border border-terracotta/30">
                  Today: {todayLabel}
                </span>
                {selectedDay && (
                  <span className="px-4 py-1.5 rounded-full bg-white text-[#1A1A1A] font-bold text-sm shadow-sm">
                    {selectedDay}
                  </span>
                )}
              </div>
            </div>

            {/* Day selector */}
            <div className="flex flex-nowrap sm:flex-wrap gap-2 mb-4 overflow-x-auto hide-scrollbar -mx-6 px-6 md:mx-0 md:px-0">
              {DAYS.map((day, i) => {
                const isActive = day === selectedDay;
                const isToday = day === todayDay;
                return (
                  <button
                    key={day}
                    onClick={() => setSelectedDay(day)}
                    className={`whitespace-nowrap flex-shrink-0 px-4 py-2 rounded-full text-sm font-bold transition-all ${
                      isActive
                        ? "bg-[#1A1A1A] text-white shadow-md"
                        : isToday
                          ? "bg-white text-[#1A1A1A] hover:bg-slate-50 border-2 border-terracotta"
                          : "bg-white text-slate-600 hover:bg-slate-50 border border-slate-200"
                    }`}
                  >
                    {day}
                    {isToday && (
                      <span className="ml-1.5 inline-block w-1.5 h-1.5 rounded-full bg-terracotta" />
                    )}
                  </button>
                );
              })}
            </div>

            <div className="">
              {/* Holiday/Weekend banner (shown above schedule if today is a holiday or weekend) */}
              {isTodayHoliday ? (
                <div className="text-center py-8 mb-4 bg-white/50 rounded-[24px] border border-white/50">
                  <HolidayGif eventName={todayHolidayEvent} />
                  <p className="text-slate-800 font-bold text-xl">{todayHolidayEvent || "It's a Holiday!"}</p>
                  <p className="text-slate-500 mt-2 font-medium">No classes today. Here's a preview of {selectedDay}.</p>
                </div>
              ) : isWeekend ? (
                <div className="text-center py-8 mb-4 bg-white/50 rounded-[24px] border border-white/50">
                  <HolidayGif eventName={`happy ${dayName} weekend`} />
                  <p className="text-slate-800 font-bold text-xl">It's {dayName} — Weekend!</p>
                  <p className="text-slate-500 mt-2 font-medium">Here's a preview of {selectedDay}.</p>
                </div>
              ) : null}

              {/* Schedule for selected day */}
              {dayClasses.length === 0 ? (
                <div className="text-center py-16 bg-white/50 rounded-[24px] border border-white/50">
                  <img src="/assets/coffee-time_98vi.svg" alt="Free time" className="w-40 h-40 mx-auto mb-6 opacity-90 drop-shadow-sm" />
                  <p className="text-slate-800 font-bold text-xl">No classes scheduled for {selectedDay} 🎉</p>
                  <p className="text-slate-500 mt-2 font-medium">Enjoy your free time!</p>
                </div>
              ) : (
                <div className="grid gap-4 sm:grid-cols-2">
                  {dayClasses.map((c, i) => (
                    <div key={i} className="bg-white rounded-[24px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] border border-white">
                      <div className="flex justify-between items-start mb-3">
                         <span className="inline-block px-3 py-1 bg-[#1A1A1A] text-white text-[11px] font-bold rounded-full font-mono uppercase tracking-wider">
                            {c.course.courseCode}
                         </span>
                         <span className="text-[#1A1A1A] font-bold text-sm">{c.timing}</span>
                      </div>
                      <p className="font-bold text-slate-800 text-[15px] leading-snug mb-4 line-clamp-2">{c.course.courseTitle}</p>
                      <div className="flex items-center gap-3 text-xs text-slate-500 font-medium min-w-0">
                         <span className="flex items-center gap-1.5 min-w-0">
                           <FacultyAvatar name={c.course.facultyName} photoUrl={c.course.facultyPhotoUrl} size={22} />
                           <span className="truncate">{cleanName(c.course.facultyName)}</span>
                         </span>
                         <span className="flex items-center gap-1 flex-shrink-0"><MapPin size={14} /> {c.course.roomNo}</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Right: Quick Attendance Widget (1/3) */}
        <div className="anim-item lg:col-span-1 min-w-0" style={{ opacity: 0 }}>
          <div className="bg-white rounded-[32px] p-6 md:p-8 border border-slate-200/50 shadow-[0_4px_20px_rgba(0,0,0,0.02)] h-full flex flex-col min-w-0">
            <div className="flex items-center justify-between mb-6">
              <h3 className="font-display font-bold text-2xl text-[#1A1A1A]">Attendance</h3>
              <Link to="/dashboard/attendance" className="w-8 h-8 rounded-full bg-slate-100 hover:bg-slate-200 transition-colors flex items-center justify-center cursor-pointer">
                 <ArrowUpRight size={16} className="text-slate-600" />
              </Link>
            </div>
            
            <div className="flex-1 overflow-y-auto space-y-4 pr-2">
              {attendanceRecords.length === 0 ? (
                <p className="text-slate-500 text-sm text-center mt-10">No attendance data.</p>
              ) : (
                attendanceRecords.slice(0, 5).map((rec) => (
                  <AttendanceCompact key={rec.courseCode} rec={rec} />
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function AttendanceCompact({ rec }) {
  const pct = parseFloat(rec.attendancePct || 0);
  const isGood = pct >= 75;
  const isWarning = pct >= 50 && pct < 75;
  const barColor = isGood ? "bg-mint" : isWarning ? "bg-beige" : "bg-terracotta";

  return (
    <div className="group min-w-0">
      <div className="flex items-center justify-between mb-2 gap-2 min-w-0">
        <div className="flex items-center gap-2 flex-1 min-w-0 pr-2">
          <FacultyAvatar name={rec.facultyName} photoUrl={rec.facultyPhotoUrl} size={24} />
          <p className="text-[13px] font-bold text-slate-800 truncate">
            {rec.courseTitle}
          </p>
        </div>
        <div className="text-[13px] font-bold text-[#1A1A1A] flex-shrink-0">
          {pct}%
        </div>
      </div>
      <div className="h-3 rounded-full bg-slate-100 overflow-hidden relative">
        <div
          className={`h-full rounded-full ${barColor} transition-all duration-1000 ease-out`}
          style={{ width: `${Math.max(pct, 2)}%` }}
        />
      </div>
    </div>
  );
}

function ErrorBox({ message }) {
  return (
    <div className="bg-white rounded-[24px] border border-red-100 shadow-sm p-8 text-center">
      <p className="text-red-500 text-sm font-medium">{message}</p>
    </div>
  );
}
