/**
 * AttendancePlanner - Interactive attendance prediction tool.
 *
 * Two modes:
 * 1. Reach Target — Set a target %, see how many classes you must attend per subject
 * 2. Plan Holiday — Pick a date range, see impact based on actual timetable + calendar
 *
 * UI follows the app's design system: dark hero banners, rounded-[32px] cards,
 * mint/terracotta/lavender accent colors, unDraw SVG illustrations.
 */
import { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Target, TrendingUp, TrendingDown, Sparkles,
  AlertTriangle, Plane, Info, Calendar, CheckCircle2,
  ChevronDown, ChevronUp
} from "lucide-react";
import { dateKey, getDayStatus } from "../utils/calendarTimetableSync.js";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatDateShort(dateStr) {
  if (!dateStr) return "";
  return new Date(dateStr).toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function calculateMissedClasses(fromDate, toDate, calendarMap, timetable) {
  if (!fromDate || !toDate) return { perSubject: {}, totalMissed: 0, dayBreakdown: [] };

  const start = new Date(fromDate);
  const end = new Date(toDate);
  if (start > end) return { perSubject: {}, totalMissed: 0, dayBreakdown: [] };

  const courses = timetable?.courses || [];
  const perSubject = {};
  const dayBreakdown = [];

  const dayOrderClasses = {};
  for (const course of courses) {
    for (const slot of (course.schedule || [])) {
      if (!dayOrderClasses[slot.day]) dayOrderClasses[slot.day] = [];
      dayOrderClasses[slot.day].push({
        courseCode: course.courseCode,
        courseTitle: course.courseTitle,
        hourIndex: slot.hourIndex,
        timing: slot.timing,
      });
    }
  }

  const cur = new Date(start);
  while (cur <= end) {
    const key = dateKey(cur);
    let dayOrder = null;
    let dayLabel = "";
    let isWorkingDay = false;

    if (calendarMap) {
      const status = getDayStatus(calendarMap, cur);
      if (status.status === "working") {
        dayOrder = status.dayOrder;
        dayLabel = `Day ${dayOrder}`;
        isWorkingDay = true;
      } else {
        dayLabel = status.label;
      }
    } else {
      const dow = cur.getDay();
      if (dow >= 1 && dow <= 5) {
        dayOrder = dow;
        dayLabel = `Day ${dayOrder}`;
        isWorkingDay = true;
      } else {
        dayLabel = dow === 0 ? "Sunday" : "Saturday";
      }
    }

    let classesToday = [];
    if (isWorkingDay && dayOrderClasses[dayLabel]) {
      classesToday = dayOrderClasses[dayLabel];
      for (const cls of classesToday) {
        perSubject[cls.courseCode] = (perSubject[cls.courseCode] || 0) + 1;
      }
    }

    dayBreakdown.push({
      date: new Date(cur),
      key,
      dayOrder,
      dayLabel,
      isWorkingDay,
      classesCount: classesToday.length,
      classes: classesToday,
    });

    cur.setDate(cur.getDate() + 1);
  }

  const totalMissed = Object.values(perSubject).reduce((s, v) => s + v, 0);
  return { perSubject, totalMissed, dayBreakdown };
}

// ─── Reach Target Mode ────────────────────────────────────────────────────────

function MarginCalculator({ records }) {
  const [target, setTarget] = useState(75);

  const results = useMemo(() => {
    return records.map((rec) => {
      const conducted = parseInt(rec.hoursConducted || 0);
      const absent = parseInt(rec.hoursAbsent || 0);
      const present = conducted - absent;
      const pct = conducted > 0 ? (present / conducted) * 100 : 0;
      const T = target;

      let needed = 0;
      if (conducted > 0 && pct < T) {
        needed = Math.ceil((T * conducted - 100 * present) / (100 - T));
        if (needed < 0) needed = 0;
      }

      let bunkable = 0;
      if (conducted > 0 && pct >= T) {
        bunkable = Math.floor((100 * present) / T - conducted);
        if (bunkable < 0) bunkable = 0;
      }

      const newPct = (needed > 0) ? ((present + needed) / (conducted + needed)) * 100 : pct;

      return {
        courseCode: rec.courseCode,
        courseTitle: rec.courseTitle,
        conducted, present, absent,
        pct: pct.toFixed(1),
        needed, bunkable,
        newPct: newPct.toFixed(1),
        alreadyAbove: pct >= T,
      };
    }).sort((a, b) => b.needed - a.needed || parseFloat(b.pct) - parseFloat(a.pct));
  }, [records, target]);

  const totalNeeded = results.reduce((s, r) => s + r.needed, 0);
  const totalBunkable = results.reduce((s, r) => s + r.bunkable, 0);
  const belowTarget = results.filter((r) => !r.alreadyAbove).length;

  return (
    <div className="space-y-6">
      {/* Target selector — dark hero card matching app style */}
      <div className="bg-[#1A1A1A] rounded-[32px] p-6 md:p-8 relative overflow-hidden">
        <div className="absolute inset-y-0 right-0 h-full w-[40%] opacity-80 mix-blend-screen pointer-events-none p-4 hidden sm:flex items-center justify-end">
          <img src="/assets/target-achieved_o5y5.svg" alt="Target" className="h-full w-full object-contain object-right" />
        </div>
        <div className="relative z-10 w-full md:w-auto">
          <div className="flex items-center gap-2 mb-4">
            <Target size={18} className="text-mint" />
            <span className="font-bold text-sm text-white/80 uppercase tracking-wide">Target Attendance</span>
          </div>
          <div className="flex items-center gap-4 mb-2">
            <input
              type="range"
              min="50"
              max="100"
              step="1"
              value={target}
              onChange={(e) => setTarget(parseInt(e.target.value))}
              className="flex-1 max-w-xs accent-[#BDE3D5] cursor-pointer"
            />
            <div className="flex items-baseline gap-1">
              <span className="text-5xl font-display font-bold text-white">{target}</span>
              <span className="text-xl font-bold text-white/40">%</span>
            </div>
          </div>
          <p className="text-white/50 text-xs font-medium">Slide to set your desired attendance goal</p>
        </div>
      </div>

      {/* Summary cards — matching the 3-card grid style */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-[24px] p-6 bg-terracotta text-white flex flex-col justify-between min-h-[140px]">
          <div className="flex justify-between items-start mb-4">
            <span className="font-semibold text-lg">Classes to Attend</span>
            <div className="w-10 h-10 rounded-full bg-black/10 flex items-center justify-center">
              <Target className="w-5 h-5 text-white" />
            </div>
          </div>
          <div>
            <p className="text-5xl font-display font-bold">{totalNeeded}</p>
            <p className="text-sm mt-1 text-white/80">to reach {target}%</p>
          </div>
        </div>

        <div className="rounded-[24px] p-6 bg-mint text-[#1A1A1A] flex flex-col justify-between min-h-[140px]">
          <div className="flex justify-between items-start mb-4">
            <span className="font-semibold text-lg">Can Bunk</span>
            <div className="w-10 h-10 rounded-full bg-black/10 flex items-center justify-center">
              <CheckCircle2 className="w-5 h-5 text-[#1A1A1A]" />
            </div>
          </div>
          <div>
            <p className="text-5xl font-display font-bold">{totalBunkable}</p>
            <p className="text-sm mt-1 text-[#1A1A1A]/70">classes to skip</p>
          </div>
        </div>

        <div className="rounded-[24px] p-6 bg-lavender text-[#1A1A1A] flex flex-col justify-between min-h-[140px]">
          <div className="flex justify-between items-start mb-4">
            <span className="font-semibold text-lg">Below Target</span>
            <div className="w-10 h-10 rounded-full bg-black/10 flex items-center justify-center">
              <TrendingDown className="w-5 h-5 text-[#1A1A1A]" />
            </div>
          </div>
          <div>
            <p className="text-5xl font-display font-bold">{belowTarget}</p>
            <p className="text-sm mt-1 text-[#1A1A1A]/70">subjects need work</p>
          </div>
        </div>
      </div>

      {/* Per-subject breakdown — white card */}
      <div className="bg-white rounded-[32px] p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
        <h3 className="font-display font-bold text-xl text-[#1A1A1A] mb-4">Subject Breakdown</h3>
        <div className="space-y-3">
          {results.map((r) => (
            <div
              key={r.courseCode}
              className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 p-4 rounded-2xl border border-slate-100 bg-slate-50/30 hover:bg-slate-50/80 transition-colors"
            >
              <div className="min-w-0 w-full sm:w-auto">
                <div className="flex justify-between items-start mb-2">
                   <span className="inline-block px-2.5 py-1 bg-[#1A1A1A] text-white text-[10px] font-bold rounded-full font-mono uppercase tracking-wider flex-shrink-0">
                     {r.courseCode}
                   </span>
                   {/* Pill moved to top right on mobile */}
                   <div className="sm:hidden flex-shrink-0">
                     {r.needed > 0 ? (
                       <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-red-700 bg-red-100">
                         Attend {r.needed} {r.needed > 1 ? "classes" : "class"}
                       </span>
                     ) : r.bunkable > 0 ? (
                       <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-emerald-700 bg-emerald-100">
                         Can bunk {r.bunkable}
                       </span>
                     ) : (
                       <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-amber-700 bg-amber-100">
                         On track
                       </span>
                     )}
                   </div>
                </div>
                <p className="text-[14px] font-bold text-slate-800 truncate mb-1">{r.courseTitle}</p>
                <div className="flex items-center gap-2">
                   <span className="text-sm font-bold text-slate-600">Current: {r.pct}%</span>
                   {r.needed > 0 && (
                     <>
                       <span className="text-slate-300 text-xs">→</span>
                       <span className="text-sm font-bold text-mint">Target: {r.newPct}%</span>
                     </>
                   )}
                </div>
              </div>
              
              {/* Desktop pill */}
              <div className="hidden sm:block flex-shrink-0">
                {r.needed > 0 ? (
                  <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-red-700 bg-red-100">
                    Attend {r.needed} {r.needed > 1 ? "classes" : "class"}
                  </span>
                ) : r.bunkable > 0 ? (
                  <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-emerald-700 bg-emerald-100">
                    Can bunk {r.bunkable}
                  </span>
                ) : (
                  <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-amber-700 bg-amber-100">
                    On track
                  </span>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── Holiday Planner Mode ────────────────────────────────────────────────────

function HolidayPlanner({ records, calendarMap, timetable }) {
  const today = new Date().toISOString().slice(0, 10);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");

  const { perSubject, totalMissed, dayBreakdown } = useMemo(
    () => calculateMissedClasses(fromDate, toDate, calendarMap, timetable),
    [fromDate, toDate, calendarMap, timetable]
  );

  const projections = useMemo(() => {
    if (totalMissed === 0) return [];
    return records.map((rec) => {
      const conducted = parseInt(rec.hoursConducted || 0);
      const absent = parseInt(rec.hoursAbsent || 0);
      const present = conducted - absent;
      const pct = conducted > 0 ? (present / conducted) * 100 : 0;
      const missedForThis = perSubject[rec.courseCode] || 0;
      const newConducted = conducted + missedForThis;
      const newPct = newConducted > 0 ? (present / newConducted) * 100 : 0;
      let recoveryNeeded = 0;
      if (newPct < 75 && newConducted > 0) {
        recoveryNeeded = Math.ceil((75 * newConducted - 100 * present) / 25);
        if (recoveryNeeded < 0) recoveryNeeded = 0;
      }
      return {
        courseCode: rec.courseCode, courseTitle: rec.courseTitle,
        conducted, present, pct: pct.toFixed(1), missedForThis,
        newConducted, newPct: newPct.toFixed(1), drop: (pct - newPct).toFixed(1),
        recoveryNeeded, willDropBelow: newPct < 75 && pct >= 75, alreadyBelow: pct < 75,
      };
    }).filter((p) => p.missedForThis > 0).sort((a, b) => parseFloat(b.drop) - parseFloat(a.drop));
  }, [records, perSubject, totalMissed]);

  const overallPct = records.length > 0
    ? (records.reduce((s, r) => s + parseFloat(r.attendancePct || 0), 0) / records.length).toFixed(1) : 0;
  const totalConductedAll = records.reduce((s, r) => s + parseInt(r.hoursConducted || 0), 0);
  const totalPresentAll = totalConductedAll - records.reduce((s, r) => s + parseInt(r.hoursAbsent || 0), 0);
  const projectedOverall = (totalConductedAll + totalMissed) > 0
    ? ((totalPresentAll / (totalConductedAll + totalMissed)) * 100).toFixed(1) : 0;
  const workingDaysMissed = dayBreakdown.filter((d) => d.isWorkingDay).length;
  const subjectsDropping = projections.filter((p) => p.willDropBelow).length;
  const hasValidRange = fromDate && toDate && totalMissed > 0;
  const hasTimetable = timetable?.courses?.length > 0;
  const [showDayBreakdown, setShowDayBreakdown] = useState(false);

  return (
    <div className="space-y-6">
      {/* Date range — dark hero card with illustration */}
      <div className="bg-[#1A1A1A] rounded-[32px] p-6 md:p-8 relative overflow-hidden">
        <div className="absolute inset-y-0 right-0 h-full w-[35%] opacity-80 mix-blend-screen pointer-events-none p-4 hidden sm:flex items-center justify-end">
          <img src="/assets/travel-plans_l0fo.svg" alt="Travel plans" className="h-full w-full object-contain object-right" />
        </div>
        <div className="relative z-10 w-full">
          <div className="flex items-center gap-2 mb-5">
            <Plane size={18} className="text-mint" />
            <span className="font-bold text-sm text-white/80 uppercase tracking-wide">Plan Your Holiday</span>
          </div>
          <div className="grid grid-cols-2 gap-4 w-full md:max-w-md">
            <div>
              <label className="block text-[11px] font-bold text-white/50 uppercase tracking-wide mb-2">From</label>
              <input
                type="date" value={fromDate} min={today}
                onChange={(e) => setFromDate(e.target.value)}
                className="w-full px-4 py-3 rounded-full text-sm font-medium bg-white/10 border border-white/20 text-white [color-scheme:dark] focus:border-mint focus:ring-2 focus:ring-mint/20 outline-none cursor-pointer min-h-[48px]"
              />
            </div>
            <div>
              <label className="block text-[11px] font-bold text-white/50 uppercase tracking-wide mb-2">To</label>
              <input
                type="date" value={toDate} min={fromDate || today}
                onChange={(e) => setToDate(e.target.value)}
                className="w-full px-4 py-3 rounded-full text-sm font-medium bg-white/10 border border-white/20 text-white [color-scheme:dark] focus:border-mint focus:ring-2 focus:ring-mint/20 outline-none cursor-pointer min-h-[48px]"
              />
            </div>
          </div>
          {!hasTimetable && (
            <div className="flex items-start gap-2 mt-4 max-w-md">
              <Info size={14} className="text-amber-400 mt-0.5 flex-shrink-0" />
              <p className="text-[11px] text-amber-400/80 font-medium leading-relaxed">
                Timetable not loaded — using default day-order mapping (Mon=Day 1, etc.)
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Empty states */}
      {!fromDate || !toDate ? (
        <div className="bg-white rounded-[32px] p-8 md:p-12 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex flex-col items-center justify-center text-center min-h-[280px]">
          <div className="w-32 h-32 mb-4 opacity-90">
            <img src="/assets/a-day-off_uk4x.svg" alt="Day off" className="w-full h-full object-contain mix-blend-multiply" />
          </div>
          <p className="font-display font-bold text-lg text-[#1A1A1A] mb-1">Plan your holiday</p>
          <p className="text-slate-400 text-xs max-w-xs">
            Select a date range above. We'll check your actual timetable and calendar day orders to calculate missed classes per subject.
          </p>
        </div>
      ) : new Date(fromDate) > new Date(toDate) ? (
        <div className="bg-white rounded-[32px] p-8 md:p-12 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex flex-col items-center justify-center text-center min-h-[280px]">
          <div className="w-16 h-16 rounded-full bg-red-50 flex items-center justify-center mb-4">
            <AlertTriangle size={28} className="text-red-400" />
          </div>
          <p className="font-display font-bold text-lg text-red-600 mb-1">Invalid date range</p>
          <p className="text-slate-400 text-xs">The "from" date must be before the "to" date.</p>
        </div>
      ) : !hasValidRange ? (
        <div className="bg-white rounded-[32px] p-8 md:p-12 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex flex-col items-center justify-center text-center min-h-[280px]">
          <div className="w-32 h-32 mb-4 opacity-90">
            <img src="/assets/vacation-selfie_q5bs.svg" alt="Vacation" className="w-full h-full object-contain mix-blend-multiply" />
          </div>
          <p className="font-display font-bold text-lg text-mint mb-1">No classes missed!</p>
          <p className="text-slate-400 text-xs max-w-xs">
            The selected range ({formatDateShort(fromDate)} – {formatDateShort(toDate)}) doesn't include any working days with classes. You're clear to take this time off!
          </p>
        </div>
      ) : (
        <>
          {/* Summary cards */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="rounded-[24px] p-5 bg-mint text-[#1A1A1A] flex flex-col justify-between min-h-[120px]">
              <div className="flex justify-between items-start mb-3">
                <span className="font-semibold text-sm">Days Off</span>
                <div className="w-8 h-8 rounded-full bg-black/10 flex items-center justify-center">
                  <Calendar className="w-4 h-4 text-[#1A1A1A]" />
                </div>
              </div>
              <p className="text-4xl font-display font-bold">{workingDaysMissed}</p>
            </div>
            <div className="rounded-[24px] p-5 bg-lavender text-[#1A1A1A] flex flex-col justify-between min-h-[120px]">
              <div className="flex justify-between items-start mb-3">
                <span className="font-semibold text-sm">Classes Missed</span>
                <div className="w-8 h-8 rounded-full bg-black/10 flex items-center justify-center">
                  <TrendingDown className="w-4 h-4 text-[#1A1A1A]" />
                </div>
              </div>
              <p className="text-4xl font-display font-bold">{totalMissed}</p>
            </div>
            <div className="rounded-[24px] p-5 bg-beige text-[#1A1A1A] flex flex-col justify-between min-h-[120px]">
              <div className="flex justify-between items-start mb-3">
                <span className="font-semibold text-sm">Overall</span>
                <div className="w-8 h-8 rounded-full bg-black/10 flex items-center justify-center">
                  <TrendingUp className="w-4 h-4 text-[#1A1A1A]" />
                </div>
              </div>
              <div>
                <p className="text-2xl font-display font-bold">{overallPct}%</p>
                <p className="text-xs text-[#1A1A1A]/60 font-medium">→ {projectedOverall}%</p>
              </div>
            </div>
            <div className="rounded-[24px] p-5 bg-terracotta text-white flex flex-col justify-between min-h-[120px]">
              <div className="flex justify-between items-start mb-3">
                <span className="font-semibold text-sm">At Risk</span>
                <div className="w-8 h-8 rounded-full bg-black/10 flex items-center justify-center">
                  <AlertTriangle className="w-4 h-4 text-white" />
                </div>
              </div>
              <p className="text-4xl font-display font-bold">{subjectsDropping}</p>
            </div>
          </div>

          {/* Warning */}
          {subjectsDropping > 0 && (
            <div className="rounded-[24px] bg-terracotta/10 border border-terracotta/30 p-5 flex items-start gap-3">
              <AlertTriangle size={20} className="text-terracotta mt-0.5 flex-shrink-0" />
              <p className="text-sm text-terracotta font-medium leading-relaxed">
                <span className="font-bold">{subjectsDropping} subject{subjectsDropping > 1 ? "s" : ""}</span> will drop below 75% if you take this holiday. Check the recovery column below.
              </p>
            </div>
          )}

          {/* Day-by-day breakdown — collapsible */}
          <div className="bg-white rounded-[32px] p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
            <button
              onClick={() => setShowDayBreakdown(!showDayBreakdown)}
              className="w-full flex items-center justify-between cursor-pointer"
            >
              <div className="flex items-center gap-2">
                <Calendar size={18} className="text-slate-400" />
                <h3 className="font-display font-bold text-lg text-[#1A1A1A]">Day-by-day Breakdown</h3>
              </div>
              {showDayBreakdown ? <ChevronUp size={18} className="text-slate-400" /> : <ChevronDown size={18} className="text-slate-400" />}
            </button>
            <AnimatePresence>
              {showDayBreakdown && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  className="overflow-hidden mt-4"
                >
                  <div className="flex flex-wrap gap-2">
                    {dayBreakdown.map((d) => (
                      <div
                        key={d.key}
                        className={`px-3 py-2.5 rounded-2xl text-center border min-w-[85px] ${
                          d.isWorkingDay ? "bg-terracotta/10 border-terracotta/20" : "bg-slate-50 border-slate-100"
                        }`}
                        title={d.classes.map((c) => `${c.courseCode} (${c.timing})`).join(", ") || "No classes"}
                      >
                        <p className="text-[10px] font-bold text-slate-400">
                          {d.date.toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                        </p>
                        <p className={`text-xs font-bold mt-0.5 ${d.isWorkingDay ? "text-terracotta" : "text-slate-400"}`}>
                          {d.dayLabel}
                        </p>
                        {d.isWorkingDay && (
                          <p className="text-[10px] text-terracotta/80 font-medium mt-0.5">
                            {d.classesCount} {d.classesCount === 1 ? "class" : "classes"}
                          </p>
                        )}
                      </div>
                    ))}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          {/* Per-subject projection — white card */}
          <div className="bg-white rounded-[32px] p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
            <h3 className="font-display font-bold text-xl text-[#1A1A1A] mb-4">Subject Impact</h3>
            <div className="space-y-3 mt-4">
              {projections.map((p) => (
                <div
                  key={p.courseCode}
                  className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 p-4 rounded-2xl border border-slate-100 bg-slate-50/30 hover:bg-slate-50/80 transition-colors"
                >
                  <div className="min-w-0 w-full sm:w-1/2">
                    <div className="flex justify-between items-start mb-2">
                       <span className="inline-block px-2.5 py-1 bg-[#1A1A1A] text-white text-[10px] font-bold rounded-full font-mono uppercase tracking-wider flex-shrink-0">
                         {p.courseCode}
                       </span>
                       <div className="sm:hidden flex-shrink-0">
                         {p.recoveryNeeded > 0 ? (
                           <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-red-700 bg-red-100">
                             Need {p.recoveryNeeded}
                           </span>
                         ) : (
                           <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-emerald-700 bg-emerald-100">
                             Still safe
                           </span>
                         )}
                       </div>
                    </div>
                    <p className="text-[14px] font-bold text-slate-800 truncate mb-1">{p.courseTitle}</p>
                    <p className="text-xs font-medium text-slate-500 mb-2">Missing <span className="font-bold text-violet-600">{p.missedForThis} classes</span></p>
                  </div>
                  
                  <div className="flex items-center justify-between w-full sm:w-auto gap-4 bg-white p-3 sm:p-0 rounded-xl sm:rounded-none sm:bg-transparent">
                    <div className="flex items-center gap-2">
                       <div className="text-center">
                         <p className="text-[10px] uppercase font-bold text-slate-400 mb-0.5">Now</p>
                         <span className={`text-sm font-bold ${p.alreadyBelow ? "text-red-600" : "text-slate-700"}`}>{p.pct}%</span>
                       </div>
                       <span className="text-slate-300 text-xs mt-3">→</span>
                       <div className="text-center">
                         <p className="text-[10px] uppercase font-bold text-slate-400 mb-0.5">After</p>
                         <span className={`text-sm font-bold ${parseFloat(p.newPct) < 75 ? "text-red-600" : "text-slate-700"}`}>{p.newPct}%</span>
                       </div>
                    </div>
                    <div className="text-center">
                       <p className="text-[10px] uppercase font-bold text-slate-400 mb-0.5">Drop</p>
                       <span className="text-sm font-bold text-terracotta">-{p.drop}%</span>
                    </div>
                  </div>

                  <div className="hidden sm:block flex-shrink-0 text-right">
                    {p.recoveryNeeded > 0 ? (
                      <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-red-700 bg-red-100">
                        Need {p.recoveryNeeded}
                      </span>
                    ) : (
                      <span className="text-xs font-bold px-2.5 py-1.5 rounded-md text-emerald-700 bg-emerald-100">
                        Still safe
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>
            <div className="flex items-start gap-2 mt-4 px-1">
              <Info size={12} className="text-slate-300 mt-0.5 flex-shrink-0" />
              <p className="text-[10px] text-slate-400 font-medium leading-relaxed">
                Missed classes are calculated from your actual timetable and academic calendar day orders. Holidays and weekends in the range are automatically excluded.
              </p>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

// ─── Main Component ───────────────────────────────────────────────────────────

export default function AttendancePlanner({ records, timetable, calendarMap }) {
  const [mode, setMode] = useState("margin");

  return (
    <div className="space-y-6">
      {/* Section header — dark hero banner matching app style */}
      <div className="bg-[#1A1A1A] rounded-[32px] p-8 md:p-10 flex flex-col md:flex-row items-start md:items-center justify-between overflow-hidden relative min-h-[200px]">
        <div className="absolute inset-y-0 right-0 h-full w-[40%] sm:w-48 md:w-72 opacity-90 mix-blend-screen pointer-events-none py-4 pr-6">
          <img src="/assets/time-management_4ss6.svg" alt="Time management" className="w-full h-full object-contain object-right" />
        </div>
        <div className="relative z-10 text-white w-[60%] sm:w-[65%] md:w-auto md:max-w-sm mb-4 md:mb-0">
          <div className="flex items-center gap-2 mb-2">
            <Sparkles size={18} className="text-mint" />
            <span className="text-mint text-xs font-bold uppercase tracking-wide">Planner</span>
          </div>
          <h1 className="font-display text-3xl sm:text-4xl font-bold mb-2 tracking-tight">Attendance Planner</h1>
          <p className="text-white/70 text-sm font-medium">Set a target or plan a holiday — see exactly what it takes to stay above 75%.</p>
        </div>
      </div>

      {/* Mode toggle */}
      <div className="flex gap-2 p-1.5 bg-[#1A1A1A] rounded-full max-w-md mx-auto">
        <button
          onClick={() => setMode("margin")}
          className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-full text-sm font-bold transition-all cursor-pointer ${
            mode === "margin" ? "bg-mint text-[#1A1A1A]" : "text-white/50 hover:text-white/80"
          }`}
        >
          <Target size={16} />
          Reach Target
        </button>
        <button
          onClick={() => setMode("holiday")}
          className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-full text-sm font-bold transition-all cursor-pointer ${
            mode === "holiday" ? "bg-mint text-[#1A1A1A]" : "text-white/50 hover:text-white/80"
          }`}
        >
          <Plane size={16} />
          Plan Holiday
        </button>
      </div>

      {/* Content */}
      <AnimatePresence mode="wait">
        <motion.div
          key={mode}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -10 }}
          transition={{ duration: 0.2 }}
        >
          {mode === "margin" ? (
            <MarginCalculator records={records} />
          ) : (
            <HolidayPlanner records={records} calendarMap={calendarMap} timetable={timetable} />
          )}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
