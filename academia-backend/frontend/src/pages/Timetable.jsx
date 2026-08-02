import { useEffect, useState, useMemo } from "react";
import { Clock, MapPin, MoveHorizontal, Download, CalendarX, Sun, Sparkles, Info } from "lucide-react";
import anime from "animejs";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/useAuth.jsx";
import { api } from "../api/client.js";
import Loading from "../components/Loading.jsx";
import FacultyAvatar from "../components/FacultyAvatar.jsx";
import { generateTimetableImage } from "../utils/timetableExporter.js";
import {
  buildCalendarMap,
  getCurrentWeekDates,
  getDayStatus,
  getDefaultDayOrder,
  dateKey,
} from "../utils/calendarTimetableSync.js";

const DAYS = ["Day 1", "Day 2", "Day 3", "Day 4", "Day 5"];
const DAY_LABELS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
const SLOT_COLORS = [
  "bg-blue-50 text-blue-800",
  "bg-emerald-50 text-emerald-800",
  "bg-amber-50 text-amber-800",
  "bg-pink-50 text-pink-800",
  "bg-indigo-50 text-indigo-800",
  "bg-red-50 text-red-800",
  "bg-mint text-[#1A1A1A]",
  "bg-lavender text-[#1A1A1A]",
  "bg-beige text-[#1A1A1A]"
];

function cleanName(name = "") {
  return String(name).replace(/\(.*?\)/g, "").trim();
}

export default function Timetable() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [timetable, setTimetable] = useState(null);
  const [calendarMap, setCalendarMap] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [downloading, setDownloading] = useState(false);

  // Fetch timetable + calendar data
  useEffect(() => {
    let cancelled = false;
    let pollTimer = null;

    const fetchData = async () => {
      try {
        const data = await api.timetable(user.email);
        if (cancelled) return;
        setTimetable(data.timetable);
        setLoading(false);

        // Fetch calendar data in parallel (non-blocking, don't fail if it errors)
        const currentSem = new Date().getMonth() >= 6 && new Date().getMonth() <= 10 ? "odd" : "even";
        api.calendar(user.email, currentSem)
          .then((calData) => {
            if (cancelled) return;
            if (calData?.available !== false && calData?.calendar) {
              setCalendarMap(buildCalendarMap(calData.calendar));
            } else {
              // Try the other semester
              const otherSem = currentSem === "odd" ? "even" : "odd";
              api.calendar(user.email, otherSem)
                .then((fallback) => {
                  if (cancelled) return;
                  if (fallback?.available !== false && fallback?.calendar) {
                    setCalendarMap(buildCalendarMap(fallback.calendar));
                  }
                })
                .catch(() => {});
            }
          })
          .catch(() => {});

        // If photos aren't ready yet, poll again in 3s (silently)
        if (!data.photosReady) {
          pollTimer = setTimeout(fetchData, 3000);
        }
      } catch (err) {
        if (cancelled) return;
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
    if (!loading && timetable) {
      // Small delay to ensure DOM is painted
      const timer = setTimeout(() => {
        anime({
          targets: ".tt-cell",
          opacity: [0, 1],
          scale: [0.95, 1],
          delay: anime.stagger(30, { grid: [5, 10], from: "first" }),
          duration: 500,
          easing: "easeOutExpo",
        });
      }, 50);
      return () => clearTimeout(timer);
    }
  }, [loading, timetable, calendarMap]); // Re-run when calendarMap loads

  // Current week dates (Mon-Fri) - must be before any conditional returns
  const weekDates = useMemo(() => getCurrentWeekDates(), []);

  if (loading) return <Loading label="Loading timetable…" />;
  if (error) return <ErrorBox message={error} />;

  const courses = timetable?.courses || [];
  const advisors = timetable?.advisors || [];

  const colorMap = {};
  courses.forEach((c, i) => {
    colorMap[c.courseCode] = SLOT_COLORS[i % SLOT_COLORS.length];
  });

  // Build day schedule from timetable
  const daySchedule = {};
  DAYS.forEach(day => daySchedule[day] = []);

  courses.forEach((course) => {
    (course.schedule || []).forEach((s) => {
      if (daySchedule[s.day]) {
        daySchedule[s.day].push({ ...s, course });
      }
    });
  });

  DAYS.forEach(day => {
    daySchedule[day].sort((a, b) => a.hourIndex - b.hourIndex);
  });

  // Today's status from calendar
  const today = new Date();
  const todayStatus = calendarMap
    ? getDayStatus(calendarMap, today)
    : { status: "unknown", dayOrder: getDefaultDayOrder(today), event: "", label: "No calendar data" };

  // For each weekday, determine the effective day order
  const weekDayInfo = weekDates.map((date, i) => {
    const status = calendarMap ? getDayStatus(calendarMap, date) : null;
    const defaultOrder = i + 1; // Mon=1, Tue=2, ...
    const effectiveDayOrder = status?.dayOrder ?? defaultOrder;
    const isHoliday = status?.status === "holiday";
    const isWeekend = status?.status === "weekend";
    const event = status?.event || "";
    const hasDayOrderChange = status?.dayOrder != null && status.dayOrder !== defaultOrder;
    return {
      date,
      label: DAY_LABELS[i],
      defaultOrder,
      effectiveDayOrder,
      isHoliday,
      isWeekend,
      event,
      hasDayOrderChange,
      status: status?.status || "unknown",
    };
  });

  // Today's classes based on effective day order
  const todayDayOrder = todayStatus.dayOrder;
  const todayDayKey = todayDayOrder ? `Day ${todayDayOrder}` : null;
  const todayClasses = todayDayKey ? (daySchedule[todayDayKey] || []) : [];
  const isTodayHoliday = todayStatus.status === "holiday";
  const isTodayWeekend = todayStatus.status === "weekend" || today.getDay() === 0 || today.getDay() === 6;

  const handleDownload = async () => {
    setDownloading(true);
    try {
      let studentName = user?.email?.split('@')[0] || "Student";
      let photoUrl = api.studentPhoto(user.email);

      try {
        const studentData = await api.student(user.email);
        if (studentData && studentData.studentInfo) {
          if (studentData.studentInfo.Name) studentName = studentData.studentInfo.Name;
          if (studentData.studentInfo.PhotoUrl) photoUrl = studentData.studentInfo.PhotoUrl;
        }
      } catch (e) {
        console.warn("Failed to fetch student name for export:", e);
      }

      await generateTimetableImage(timetable, { name: studentName, email: user.email, photoUrl });
    } catch (err) {
      console.error('Failed to download timetable:', err);
      alert('Failed to download timetable. Please try again.');
    } finally {
      setDownloading(false);
    }
  };

  return (
    <div className="space-y-6 pt-4 pb-10">
      <div className="bg-[#1A1A1A] rounded-[24px] md:rounded-[32px] p-6 md:p-10 flex flex-col md:flex-row items-start md:items-center justify-between overflow-hidden relative min-h-[180px] md:min-h-[220px]">
        <div className="absolute inset-y-0 right-0 h-full w-[40%] sm:w-48 md:w-72 opacity-90 mix-blend-screen pointer-events-none py-4 pr-6">
          <img src="/assets/time-management_4ss6.svg" alt="Timetable" className="w-full h-full object-contain object-right" />
        </div>

        <div className="relative z-10 text-white w-[60%] sm:w-[65%] md:w-auto md:max-w-sm flex flex-col items-start">
          <h1 className="font-display text-2xl sm:text-3xl md:text-4xl font-bold mb-2 tracking-tight">Timetable</h1>
          <p className="text-white/70 text-xs sm:text-sm font-medium mb-6">Organize your week, plan your classes, and manage your schedule effectively.</p>
          
          <button
            onClick={handleDownload}
            disabled={downloading}
            className="bg-white hover:bg-white/90 text-[#1A1A1A] px-5 md:px-6 py-2.5 md:py-3 rounded-full font-bold text-sm shadow-lg hover:shadow-xl transition-all flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Download size={16} />
            {downloading ? 'Generating...' : 'Download'}
          </button>
        </div>
      </div>

      {/* Today's Status - Holiday/Weekend big card, or compact banner for working days */}
      <TodayBanner
        isHoliday={isTodayHoliday}
        isWeekend={isTodayWeekend}
        event={todayStatus.event}
        dayOrder={todayDayOrder}
        classesCount={todayClasses.length}
        calendarAvailable={!!calendarMap}
      />

      {advisors.length > 0 && (
        <div className="grid sm:grid-cols-2 gap-4">
          {advisors.map((advisor) => (
            <div
              key={`${advisor.role}-${advisor.name}`}
              className="bg-white rounded-[24px] p-5 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex items-center gap-4"
            >
              <FacultyAvatar name={advisor.name} photoUrl={advisor.photoUrl} size={56} />
              <div className="min-w-0">
                <p className="text-[10px] font-bold uppercase tracking-wider text-slate-400 mb-1">
                  {advisor.role || "Advisor"}
                </p>
                <p className="font-bold text-[#1A1A1A] text-[15px] truncate">{cleanName(advisor.name)}</p>
                {advisor.email && (
                  <p className="text-xs text-slate-500 truncate mt-0.5">{advisor.email}</p>
                )}
                {advisor.phone && (
                  <p className="text-xs text-slate-400 font-medium mt-0.5">{advisor.phone}</p>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Course Legend */}
      <div className="flex flex-nowrap sm:flex-wrap gap-2 pt-2 pb-2 -mx-6 px-6 sm:mx-0 sm:px-0 overflow-x-auto hide-scrollbar sm:overflow-visible">
        {courses.map((c) => (
          <div
            key={c.courseCode}
            className={`px-4 py-2.5 rounded-full text-[12px] font-bold shadow-[0_2px_10px_rgba(0,0,0,0.04)] flex-shrink-0 flex items-center border border-white/40 ${colorMap[c.courseCode]}`}
          >
            <span className="font-mono opacity-60 mr-2 text-[11px] uppercase tracking-wider">{c.slot.replace(/-+$/, '')}</span>
            <span className="truncate max-w-[180px] sm:max-w-[250px] leading-tight">{c.courseTitle}</span>
          </div>
        ))}
      </div>

      <div className="flex items-center justify-center gap-2 mt-6 lg:hidden text-slate-400">
        <MoveHorizontal size={14} className="opacity-60 animate-pulse" />
        <span className="text-[10px] font-bold uppercase tracking-wider opacity-80">Swipe left & right to view days</span>
      </div>

      {/* Weekly view with calendar-aware day orders */}
      <div className="flex overflow-x-auto hide-scrollbar snap-x snap-mandatory -mx-6 px-6 md:mx-0 md:px-0 lg:grid lg:grid-cols-5 gap-4 lg:gap-6 pt-3 pb-4">
        {weekDayInfo.map((dayInfo, i) => {
          const dayKey = `Day ${dayInfo.effectiveDayOrder}`;
          const classesToday = daySchedule[dayKey] || [];
          const isToday = dateKey(dayInfo.date) === dateKey(today);

          return (
            <div key={i} className="flex flex-col gap-4 w-[85vw] sm:w-[300px] lg:w-auto flex-shrink-0 snap-center">
              {/* Day header */}
              <div className={`rounded-t-[24px] md:rounded-t-[32px] rounded-b-[20px] md:rounded-b-[24px] p-4 md:p-5 border text-center relative overflow-hidden group ${
                dayInfo.isHoliday
                  ? "bg-red-50 border-red-200"
                  : isToday
                  ? "bg-[#1A1A1A] border-[#1A1A1A]"
                  : "bg-white border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]"
              }`}>
                <div className="absolute inset-0 opacity-10 bg-gradient-to-br from-slate-100 to-slate-200 pointer-events-none group-hover:opacity-20 transition-opacity" />

                {/* Date badge */}
                <div className={`relative z-10 text-[10px] font-bold mb-1 ${
                  dayInfo.isHoliday ? "text-red-400" : isToday ? "text-white/60" : "text-slate-400"
                }`}>
                  {dayInfo.date.toLocaleDateString("en-US", { day: "numeric", month: "short" })}
                </div>

                <h3 className={`relative z-10 font-display font-bold text-lg md:text-xl ${
                  dayInfo.isHoliday ? "text-red-600" : isToday ? "text-white" : "text-[#1A1A1A]"
                }`}>
                  {dayInfo.label}
                </h3>

                {/* Day order badge */}
                <div className="relative z-10 mt-1.5 flex items-center justify-center gap-1.5">
                  {dayInfo.isHoliday ? (
                    <span className="inline-flex items-center gap-1 text-[10px] font-bold text-red-500 bg-red-100 px-2.5 py-1 rounded-full">
                      <CalendarX size={10} /> Holiday
                    </span>
                  ) : (
                    <>
                      <span className={`text-[10px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-full ${
                        isToday ? "bg-white/15 text-white" : "bg-slate-100 text-slate-500"
                      }`}>
                        Day {dayInfo.effectiveDayOrder}
                      </span>
                      {isToday && (
                        <span className="text-[9px] font-bold text-green-300 bg-green-400/20 px-1.5 py-0.5 rounded-full uppercase tracking-wider">
                          Today
                        </span>
                      )}
                    </>
                  )}
                </div>

                {/* Holiday event text */}
                {dayInfo.isHoliday && dayInfo.event && (
                  <p className="relative z-10 text-[10px] text-red-500 font-medium mt-2 px-2 leading-tight line-clamp-2">
                    {dayInfo.event}
                  </p>
                )}
              </div>

              {/* Classes */}
              <div className="flex flex-col gap-3">
                {dayInfo.isHoliday ? (
                  <div className="p-6 text-center bg-red-50/50 rounded-[24px] border border-dashed border-red-200 relative overflow-hidden">
                    <img src="/assets/chilling_o2zv.svg" alt="Holiday" className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-24 h-24 opacity-5 pointer-events-none" />
                    <p className="text-sm font-bold text-red-400 relative z-10">No Classes</p>
                    <p className="text-[10px] text-red-300 font-medium mt-1 relative z-10">Enjoy your day off!</p>
                  </div>
                ) : classesToday.length === 0 ? (
                  <div className="p-6 text-center text-slate-400 bg-white/40 rounded-[24px] border border-dashed border-slate-200 relative overflow-hidden">
                    <img src="/assets/chilling_o2zv.svg" alt="Free Day" className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-24 h-24 opacity-5 pointer-events-none" />
                    <p className="text-sm font-bold relative z-10">Free Day!</p>
                  </div>
                ) : (
                  classesToday.map((cls, idx) => {
                    const colorClass = colorMap[cls.course.courseCode] || SLOT_COLORS[0];
                    return (
                      <div
                        key={`${dayKey}-${idx}`}
                        className={`tt-cell rounded-[20px] md:rounded-[24px] ${colorClass} p-3 md:p-4 shadow-sm border border-black/5 relative overflow-hidden group`}
                        style={{ opacity: 0 }}
                      >
                        <p className="text-[10px] font-bold opacity-70 mb-2 uppercase tracking-wider flex items-center gap-1">
                          <Clock size={10} /> {cls.timing}
                        </p>
                        <p className="text-[13px] font-bold leading-snug mb-2">
                          {cls.course.courseTitle}
                        </p>
                        <div className="flex items-center gap-2 mb-4 min-w-0">
                          <FacultyAvatar
                            name={cls.course.facultyName}
                            photoUrl={cls.course.facultyPhotoUrl}
                            size={24}
                          />
                          <p className="text-[11px] opacity-80 font-medium truncate">
                            {cleanName(cls.course.facultyName)}
                          </p>
                        </div>
                        <div className="flex items-center justify-between mt-auto pt-3 border-t border-black/5">
                          <span className="text-[9px] px-2 py-1 bg-black/5 rounded-full font-bold uppercase tracking-wider">
                            {cls.course.courseCode}
                          </span>
                          <p className="text-[10px] opacity-80 font-bold flex items-center gap-1">
                            <MapPin size={10} /> {cls.course.roomNo}
                          </p>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          );
        })}
      </div>

      <div className="bg-white rounded-[24px] md:rounded-[32px] p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)] mt-8">
        <h3 className="font-display font-bold text-xl md:text-2xl text-[#1A1A1A] mb-6">Course Details</h3>
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {courses.map((c) => (
            <div key={c.courseCode} className="p-5 rounded-[20px] md:rounded-[24px] bg-slate-50 border border-slate-100 hover:shadow-md transition-shadow">
              <div className="flex items-center justify-between mb-3">
                <span className="text-[10px] px-3 py-1 rounded-full bg-[#1A1A1A] text-white font-mono uppercase tracking-wider font-bold">
                  {c.courseCode}
                </span>
                <span className="text-[10px] px-3 py-1 rounded-full bg-slate-200 text-slate-700 font-bold uppercase tracking-wider">
                  Slot {c.slot}
                </span>
              </div>
              <p className="text-[14px] font-bold text-[#1A1A1A] mb-4">{c.courseTitle}</p>
              <div className="flex flex-col gap-3 text-xs font-medium text-slate-600">
                <span className="flex items-center gap-2 min-w-0">
                  <FacultyAvatar name={c.facultyName} photoUrl={c.facultyPhotoUrl} size={28} />
                  <span className="truncate">{cleanName(c.facultyName)}</span>
                </span>
                <span className="flex items-center gap-2">
                  <div className="w-6 h-6 rounded-full bg-white flex items-center justify-center shadow-sm"><MapPin size={12} /></div> {c.roomNo}
                </span>
                <span className="flex items-center gap-2">
                  <div className="w-6 h-6 rounded-full bg-white flex items-center justify-center shadow-sm"><Clock size={12} /></div> {c.courseType} · {c.credit} credits
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/**
 * Today's status - big card for holidays/weekends, compact banner for working days.
 */
function TodayBanner({ isHoliday, isWeekend, event, dayOrder, classesCount, calendarAvailable }) {
  if (!calendarAvailable) {
    return (
      <div className="bg-slate-50 rounded-[20px] md:rounded-[24px] p-4 md:p-5 border border-slate-200 flex items-center gap-3">
        <div className="w-10 h-10 rounded-full bg-slate-200 flex items-center justify-center flex-shrink-0">
          <Info size={18} className="text-slate-500" />
        </div>
        <div>
          <p className="text-sm font-bold text-slate-700">Calendar sync unavailable</p>
          <p className="text-xs text-slate-500">Day orders shown are defaults. Calendar data will appear once available.</p>
        </div>
      </div>
    );
  }

  if (isHoliday) {
    return (
      <div className="bg-gradient-to-br from-red-500 via-rose-500 to-pink-600 rounded-[24px] md:rounded-[32px] p-6 md:p-10 text-white shadow-xl relative overflow-hidden min-h-[200px] md:min-h-[240px] flex flex-col justify-center">
        {/* Decorative circles */}
        <div className="absolute -top-12 -right-12 w-48 h-48 rounded-full bg-white/10" />
        <div className="absolute -bottom-16 -left-16 w-56 h-56 rounded-full bg-white/5" />
        <div className="absolute top-1/2 right-12 w-24 h-24 rounded-full bg-white/5" />

        <div className="relative z-10 flex items-center gap-4 md:gap-6">
          <div className="w-16 h-16 md:w-20 md:h-20 rounded-full bg-white/20 backdrop-blur-sm flex items-center justify-center flex-shrink-0 border border-white/30">
            <CalendarX size={32} className="text-white md:hidden" />
            <CalendarX size={40} className="text-white hidden md:block" />
          </div>
          <div className="min-w-0">
            <p className="text-[10px] md:text-xs font-bold uppercase tracking-[0.2em] text-white/60 mb-1.5">Today is a Holiday</p>
            <h2 className="font-display text-2xl md:text-4xl font-bold mb-2 leading-tight">{event || "Holiday"}</h2>
            <p className="text-sm md:text-base text-white/80 font-medium">No classes today. Enjoy your day off!</p>
          </div>
        </div>

        <div className="relative z-10 mt-5 md:mt-6 flex items-center gap-2">
          <span className="inline-flex items-center gap-1.5 text-xs md:text-sm font-bold bg-white/20 backdrop-blur-sm px-4 py-2 rounded-full border border-white/20">
            <span className="w-1.5 h-1.5 rounded-full bg-white animate-pulse" />
            No Classes Scheduled
          </span>
        </div>
      </div>
    );
  }

  // Working day - intentionally removed per user request
  return null;
}

function ErrorBox({ message }) {
  return (
    <div className="bg-white rounded-[24px] md:rounded-[32px] p-6 md:p-8 text-center border border-red-100">
      <p className="text-red-500 text-sm font-bold">{message}</p>
    </div>
  );
}
