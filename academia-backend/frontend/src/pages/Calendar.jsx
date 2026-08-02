import { useEffect, useState, useRef } from "react";
import { CalendarDays, ChevronLeft, ChevronRight } from "lucide-react";
import anime from "animejs";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/useAuth.jsx";
import { api } from "../api/client.js";
import Loading from "../components/Loading.jsx";

const MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];
const WEEKDAYS = ["S", "M", "T", "W", "T", "F", "S"];
const WEEKDAYS_FULL = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export default function Calendar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [calendar, setCalendar] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [sem, setSem] = useState(() => {
    const month = new Date().getMonth();
    return month >= 6 && month <= 10 ? "odd" : "even";
  });
  const [currentMonthIdx, setCurrentMonthIdx] = useState(0);
  const [unavailableSem, setUnavailableSem] = useState(null);
  const isInitialLoad = useRef(true);

  // Today's date for highlighting (computed once)
  const today = new Date();
  const todayDate = today.getDate();
  const todayMonthShort = today.toLocaleString("en-US", { month: "short" }).toLowerCase();
  const todayYear = today.getFullYear();
  const todayYearShort = String(todayYear).slice(-2);

  // Find the index of the current month in a months array
  const findCurrentMonthIdx = (months) => {
    return months.findIndex((m) => {
      const name = (m.name || "").toLowerCase();
      return name.includes(todayMonthShort) && name.includes(todayYearShort);
    });
  };

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError("");
    setUnavailableSem(null);
    (async () => {
      try {
        const data = await api.calendar(user.email, sem);
        if (cancelled) return;

        if (data.available === false || !data.calendar) {
          if (isInitialLoad.current) {
            const otherSem = sem === "odd" ? "even" : "odd";
            try {
              const fallback = await api.calendar(user.email, otherSem);
              if (cancelled) return;
              if (fallback.available !== false && fallback.calendar) {
                const fbMonths = fallback.calendar?.months || [];
                const fbFocusIdx = findCurrentMonthIdx(fbMonths);
                setCalendar(fallback.calendar);
                setUnavailableSem(sem);
                setSem(otherSem);
                setCurrentMonthIdx(fbFocusIdx >= 0 ? fbFocusIdx : 0);
                setLoading(false);
                isInitialLoad.current = false;
                return;
              }
            } catch {
              // both failed
            }
          }
          setCalendar(null);
          setUnavailableSem(sem);
          setLoading(false);
          return;
        }

        const months = data.calendar?.months || [];
        const focusIdx = findCurrentMonthIdx(months);
        setCalendar(data.calendar);
        setCurrentMonthIdx(focusIdx >= 0 ? focusIdx : 0);
        setLoading(false);
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
    })();
    return () => { cancelled = true; };
  }, [user.email, sem, logout, navigate]);

  useEffect(() => {
    if (!loading && calendar) {
      const activePill = document.querySelector(".month-pill-active");
      if (activePill) activePill.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" });

      anime({
        targets: ".cal-cell",
        opacity: [0, 1],
        translateY: [8, 0],
        delay: anime.stagger(8, { from: "first" }),
        duration: 300,
        easing: "easeOutQuad",
      });
    }
  }, [loading, calendar, currentMonthIdx]);

  if (loading) return <Loading label="Loading calendar…" />;
  if (error) return <ErrorBox message={error} />;
  if (unavailableSem && unavailableSem !== "both" && !calendar)
    return (
      <div className="space-y-6 pt-4">
        <div className="bg-[#1A1A1A] rounded-[24px] md:rounded-[32px] p-6 md:p-10 text-center">
          <CalendarDays className="w-10 h-10 md:w-12 md:h-12 text-white/40 mx-auto mb-4" />
          <h2 className="text-white text-lg md:text-xl font-bold mb-2">
            {unavailableSem === "odd" ? "Odd" : "Even"} Semester Calendar Unavailable
          </h2>
          <p className="text-white/60 text-sm mb-6 px-4">
            The academic calendar for this semester hasn't been published yet.
          </p>
          <button
            onClick={() => {
              const other = unavailableSem === "odd" ? "even" : "odd";
              setUnavailableSem(null);
              setSem(other);
            }}
            className="px-6 py-2.5 rounded-full bg-white text-[#1A1A1A] text-sm font-bold hover:bg-white/90 transition-colors cursor-pointer"
          >
            View {unavailableSem === "odd" ? "Even" : "Odd"} Semester
          </button>
        </div>
      </div>
    );
  if (unavailableSem === "both" || (!calendar && !unavailableSem))
    return <ErrorBox message="Academic calendar is not available for either semester right now." />;

  const months = calendar?.months || [];
  const currentMonth = months[currentMonthIdx];

  if (!currentMonth) return <ErrorBox message="No calendar data available for this semester." />;

  const days = currentMonth.days || [];
  const firstDayWeekday = days.length > 0
    ? parseInt(days[0].day === "Sun" ? 0 : days[0].day === "Mon" ? 1 : days[0].day === "Tue" ? 2 : days[0].day === "Wed" ? 3 : days[0].day === "Thu" ? 4 : days[0].day === "Fri" ? 5 : 6)
    : 0;

  const isToday = (day) => {
    const monthName = (currentMonth.name || "").toLowerCase();
    return parseInt(day.date) === todayDate && monthName.includes(todayMonthShort) && monthName.includes(todayYearShort);
  };

  const events = days.filter((d) => d.event && d.event.trim());

  return (
    <div className="space-y-4 md:space-y-6 pt-4">
      {/* Banner / Header */}
      <div className="bg-[#1A1A1A] rounded-[24px] md:rounded-[32px] p-6 md:p-10 flex flex-col md:flex-row items-start md:items-center justify-between overflow-hidden relative min-h-[180px] md:min-h-[220px]">
        <div className="absolute inset-y-0 right-0 h-full w-[40%] sm:w-48 md:w-80 opacity-90 mix-blend-screen pointer-events-none py-4 pr-4 md:pr-6">
          <img src="/assets/events-calendar_sudy.svg" alt="Calendar" className="w-full h-full object-contain object-right" />
        </div>

        <div className="relative z-10 text-white w-[60%] sm:w-[65%] md:w-auto md:max-w-sm mb-4 md:mb-0">
          <h1 className="font-display text-2xl sm:text-3xl md:text-4xl font-bold mb-2 tracking-tight">Academic Calendar</h1>
          <p className="text-white/70 text-xs sm:text-sm font-medium">Stay up to date with semester events, holidays, and important deadlines.</p>
        </div>

        {/* Semester toggle */}
        <div className="relative z-10 flex gap-2 p-1.5 rounded-full bg-white/10 backdrop-blur-md border border-white/20 self-start md:self-auto">
          {["odd", "even"].map((s) => (
            <button
              key={s}
              onClick={() => setSem(s)}
              className={`px-4 md:px-5 py-2 rounded-full text-xs font-bold transition-all capitalize cursor-pointer ${
                sem === s
                  ? "bg-white text-[#1A1A1A] shadow-md"
                  : "text-white/70 hover:text-white hover:bg-white/10"
              }`}
            >
              {s} Sem
            </button>
          ))}
        </div>
      </div>

      {unavailableSem && unavailableSem !== "both" && calendar && (
        <div className="bg-amber-50 border border-amber-200 rounded-2xl px-4 md:px-5 py-3 text-xs md:text-sm text-amber-800 font-medium">
          {unavailableSem === "odd" ? "Odd" : "Even"} semester calendar is not available yet. Showing {sem} semester instead.
        </div>
      )}

      <div className="grid lg:grid-cols-3 gap-4 md:gap-6 items-start">
        {/* Calendar grid */}
        <div className="bg-white rounded-[24px] md:rounded-[32px] p-3 sm:p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)] lg:col-span-2 overflow-hidden">
          {/* Month navigation */}
          <div className="flex items-center justify-between mb-3 md:mb-4 px-1">
            <button
              onClick={() => setCurrentMonthIdx((prev) => (prev - 1 + months.length) % months.length)}
              className="p-2 md:p-3 rounded-full bg-slate-50 hover:bg-slate-100 text-[#1A1A1A] transition-all cursor-pointer active:scale-95 flex-shrink-0"
            >
              <ChevronLeft size={18} className="md:hidden" />
              <ChevronLeft size={20} className="hidden md:block" />
            </button>
            <h3 className="font-display font-bold text-[#1A1A1A] text-lg sm:text-xl md:text-2xl text-center flex-1 px-2">
              {currentMonth.name || MONTHS[currentMonthIdx] || "Month"}
            </h3>
            <button
              onClick={() => setCurrentMonthIdx((prev) => (prev + 1) % months.length)}
              className="p-2 md:p-3 rounded-full bg-slate-50 hover:bg-slate-100 text-[#1A1A1A] transition-all cursor-pointer active:scale-95 flex-shrink-0"
            >
              <ChevronRight size={18} className="md:hidden" />
              <ChevronRight size={20} className="hidden md:block" />
            </button>
          </div>

          {/* Month pills */}
          <div className="flex gap-1.5 md:gap-2 mb-4 md:mb-6 overflow-x-auto hide-scrollbar pb-1 -mx-3 px-3 sm:-mx-6 sm:px-6 md:mx-0 md:px-0">
            {months.map((m, i) => {
              const mName = (m.name || "").toLowerCase();
              const isCurrentMonth = mName.includes(todayMonthShort) && mName.includes(todayYearShort);
              return (
                <button
                  key={i}
                  onClick={() => setCurrentMonthIdx(i)}
                  className={`month-pill ${i === currentMonthIdx ? "month-pill-active" : ""} px-2.5 md:px-3 py-1.5 rounded-full text-[11px] md:text-xs font-bold whitespace-nowrap transition-colors cursor-pointer flex-shrink-0 ${
                    i === currentMonthIdx
                      ? "bg-[#1A1A1A] text-white"
                      : isCurrentMonth
                      ? "bg-terracotta/10 text-terracotta border border-terracotta/30"
                      : "bg-slate-100 text-slate-500 hover:bg-slate-200"
                  }`}
                >
                  {m.name}
                  {isCurrentMonth && i !== currentMonthIdx && <span className="ml-1 text-[9px]">●</span>}
                </button>
              );
            })}
          </div>

          {/* Weekday headers - single letter on mobile, full on desktop */}
          <div className="grid grid-cols-7 gap-0.5 sm:gap-2 md:gap-3 mb-2 md:mb-4 px-0.5">
            {WEEKDAYS.map((wd, i) => (
              <div key={i} className="text-center text-[10px] sm:text-xs font-bold text-slate-400 uppercase tracking-wider py-1.5 md:py-2">
                <span className="sm:hidden">{wd}</span>
                <span className="hidden sm:inline">{WEEKDAYS_FULL[i]}</span>
              </div>
            ))}
          </div>

          {/* Days grid - compact on mobile, full on desktop */}
          <div className="grid grid-cols-7 gap-0.5 sm:gap-2 md:gap-3 px-0.5">
            {Array.from({ length: firstDayWeekday }).map((_, i) => (
              <div key={`empty-${i}`} />
            ))}
            {days.map((day) => {
              const hasEvent = day.event && day.event.trim();
              const dayOrder = day.dayOrder && day.dayOrder !== "-" ? day.dayOrder : null;
              const todayHighlight = isToday(day);

              return (
                <div
                  key={day.date}
                  className={`cal-cell rounded-lg sm:rounded-2xl p-1 sm:p-2.5 md:p-3 flex flex-col justify-between ${
                    // Mobile: compact min-height; Desktop: full
                    "min-h-[46px] sm:min-h-[72px]"
                  } ${
                    todayHighlight
                      ? "bg-[#1A1A1A] border-2 border-[#1A1A1A] text-white shadow-lg ring-2 ring-[#1A1A1A]/20"
                      : hasEvent
                      ? "bg-mint border border-mint text-[#1A1A1A] shadow-sm"
                      : dayOrder
                      ? "bg-white border border-slate-200 shadow-[0_2px_8px_rgba(0,0,0,0.02)]"
                      : "bg-slate-50 border border-slate-100 text-slate-400"
                  }`}
                >
                  {/* Mobile: compact date only */}
                  <div className="sm:hidden flex flex-col items-center justify-center h-full gap-0.5">
                    <span className={`text-sm font-bold leading-none ${todayHighlight ? "text-white" : hasEvent ? "text-[#1A1A1A]" : "text-slate-700"}`}>
                      {day.date}
                    </span>
                    {hasEvent && <span className={`w-1 h-1 rounded-full ${todayHighlight ? "bg-white" : "bg-terracotta"}`} />}
                    {dayOrder && !hasEvent && <span className="text-[7px] font-bold text-slate-400 leading-none">D{dayOrder}</span>}
                  </div>

                  {/* Desktop: full layout */}
                  <div className="hidden sm:flex items-start justify-between">
                    <span className={`text-lg font-bold ${todayHighlight ? "text-white" : hasEvent ? "text-[#1A1A1A]" : "text-slate-800"}`}>
                      {day.date}
                      {todayHighlight && <span className="ml-1.5 text-[9px] uppercase tracking-wider bg-white/20 px-1.5 py-0.5 rounded-full">Today</span>}
                    </span>
                    {dayOrder && (
                      <span className={`text-[10px] px-2 py-1 rounded-full font-bold ${todayHighlight ? "bg-white/15 text-white" : "bg-slate-100 text-slate-500"}`}>
                        D{dayOrder}
                      </span>
                    )}
                  </div>
                  {hasEvent && (
                    <p className="hidden sm:block text-[11px] font-semibold mt-2 leading-tight truncate">
                      {day.event}
                    </p>
                  )}
                </div>
              );
            })}
          </div>

          {/* Mobile legend */}
          <div className="flex items-center gap-3 mt-3 sm:hidden text-[10px] text-slate-500 justify-center">
            <div className="flex items-center gap-1">
              <div className="w-2.5 h-2.5 rounded-full bg-mint border border-mint" />
              <span>Event</span>
            </div>
            <div className="flex items-center gap-1">
              <div className="w-2.5 h-2.5 rounded-full bg-[#1A1A1A]" />
              <span>Today</span>
            </div>
            <div className="flex items-center gap-1">
              <div className="w-2.5 h-2.5 rounded-full bg-white border border-slate-200" />
              <span>Class</span>
            </div>
          </div>
        </div>

        {/* Events list */}
        <div className="bg-white rounded-[24px] md:rounded-[32px] p-4 sm:p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex flex-col lg:max-h-[680px]">
          <h3 className="font-display font-bold text-xl md:text-2xl text-[#1A1A1A] mb-4 md:mb-6 flex items-center gap-2.5 md:gap-3 shrink-0">
            <div className="w-9 h-9 md:w-10 md:h-10 rounded-full bg-lavender flex items-center justify-center flex-shrink-0">
              <CalendarDays className="w-4 h-4 md:w-5 md:h-5 text-[#1A1A1A]" />
            </div>
            Events
            {events.length > 0 && (
              <span className="text-xs font-bold text-slate-400 bg-slate-100 px-2 py-1 rounded-full">{events.length}</span>
            )}
          </h3>

          {events.length === 0 ? (
            <div className="bg-slate-50 rounded-[16px] md:rounded-[24px] p-6 md:p-8 text-center border border-slate-100">
              <p className="text-slate-500 font-medium text-sm">No events this month.</p>
            </div>
          ) : (
            <div className="overflow-y-auto min-h-0 space-y-3 md:space-y-4 pr-1 md:pr-2 pb-2 -mr-1 md:-mr-2">
              {events.map((ev, i) => (
                <div
                  key={i}
                  className="p-3.5 md:p-5 rounded-[16px] md:rounded-[24px] bg-beige border border-slate-100 shadow-sm shrink-0"
                >
                  <div className="flex items-center gap-2.5 md:gap-3 mb-2">
                    <div className="bg-white px-2.5 md:px-3 py-1 rounded-full border border-slate-200 flex items-center gap-1.5">
                      <span className="text-base md:text-lg font-display font-bold text-[#1A1A1A]">
                        {ev.date}
                      </span>
                      <span className="text-[9px] md:text-[10px] text-slate-500 font-bold uppercase tracking-wider">{ev.day}</span>
                    </div>
                    {isToday(ev) && (
                      <span className="text-[9px] md:text-[10px] font-bold text-terracotta bg-terracotta/10 px-2 py-0.5 rounded-full uppercase tracking-wider">Today</span>
                    )}
                  </div>
                  <p className="text-[13px] md:text-[14px] font-bold text-[#1A1A1A] leading-snug">{ev.event}</p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function ErrorBox({ message }) {
  return (
    <div className="bg-white rounded-[24px] md:rounded-[32px] p-6 md:p-8 text-center border border-red-100">
      <p className="text-red-500 text-sm font-bold">{message}</p>
    </div>
  );
}
