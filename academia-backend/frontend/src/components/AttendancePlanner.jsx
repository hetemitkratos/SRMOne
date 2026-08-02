/**
 * AttendancePlanner - Interactive attendance prediction tool.
 *
 * Two modes:
 * 1. Margin Calculator — Set a target %, see how many classes you must attend per subject
 * 2. Holiday Planner   — Pick a date range, see how your attendance drops if you skip
 */
import { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Target, CalendarDays, TrendingUp, TrendingDown, Sparkles,
  CheckCircle2, AlertTriangle, Plane, Calculator, Info
} from "lucide-react";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function countWeekdays(startDate, endDate) {
  if (!startDate || !endDate) return 0;
  const start = new Date(startDate);
  const end = new Date(endDate);
  if (start > end) return 0;
  let count = 0;
  const cur = new Date(start);
  while (cur <= end) {
    const day = cur.getDay();
    if (day !== 0 && day !== 6) count++;
    cur.setDate(cur.getDate() + 1);
  }
  return count;
}

function formatDateShort(dateStr) {
  if (!dateStr) return "";
  return new Date(dateStr).toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

// ─── Margin Calculator ────────────────────────────────────────────────────────

function MarginCalculator({ records }) {
  const [target, setTarget] = useState(75);

  const results = useMemo(() => {
    return records.map((rec) => {
      const conducted = parseInt(rec.hoursConducted || 0);
      const absent = parseInt(rec.hoursAbsent || 0);
      const present = conducted - absent;
      const pct = conducted > 0 ? (present / conducted) * 100 : 0;
      const T = target;

      // Classes needed: (P + Y) / (C + Y) >= T/100
      // Y >= (T*C - 100*P) / (100 - T)
      let needed = 0;
      if (conducted > 0 && pct < T) {
        needed = Math.ceil((T * conducted - 100 * present) / (100 - T));
        if (needed < 0) needed = 0;
      }

      // Classes you can bunk while staying above T%
      // P / (C + X) >= T/100 → X <= (100*P/T) - C
      let bunkable = 0;
      if (conducted > 0 && pct >= T) {
        bunkable = Math.floor((100 * present) / T - conducted);
        if (bunkable < 0) bunkable = 0;
      }

      // New percentage if you attend exactly `needed` classes
      const newPct = (needed > 0)
        ? ((present + needed) / (conducted + needed)) * 100
        : pct;

      return {
        courseCode: rec.courseCode,
        courseTitle: rec.courseTitle,
        conducted,
        present,
        absent,
        pct: pct.toFixed(1),
        needed,
        bunkable,
        newPct: newPct.toFixed(1),
        alreadyAbove: pct >= T,
      };
    }).sort((a, b) => b.needed - a.needed || parseFloat(b.pct) - parseFloat(a.pct));
  }, [records, target]);

  const totalNeeded = results.reduce((s, r) => s + r.needed, 0);
  const totalBunkable = results.reduce((s, r) => s + r.bunkable, 0);
  const belowTarget = results.filter((r) => !r.alreadyAbove).length;

  return (
    <div>
      {/* Target selector */}
      <div className="flex flex-col sm:flex-row sm:items-center gap-4 mb-6 p-5 rounded-2xl bg-slate-50 border border-slate-100">
        <div className="flex items-center gap-2 flex-shrink-0">
          <Target size={18} className="text-violet-600" />
          <span className="font-bold text-sm text-slate-700">Target Attendance</span>
        </div>
        <div className="flex items-center gap-3 flex-1">
          <input
            type="range"
            min="50"
            max="100"
            step="1"
            value={target}
            onChange={(e) => setTarget(parseInt(e.target.value))}
            className="flex-1 accent-violet-600 cursor-pointer"
          />
          <div className="flex items-center gap-1 bg-white rounded-full px-4 py-2 border border-slate-200 shadow-sm">
            <span className="text-2xl font-display font-bold text-violet-600">{target}</span>
            <span className="text-sm font-bold text-slate-400">%</span>
          </div>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-6">
        <div className="rounded-2xl bg-red-50 border border-red-100 p-4 text-center">
          <p className="text-3xl font-display font-bold text-red-600">{totalNeeded}</p>
          <p className="text-xs text-red-500/70 font-medium mt-1">total classes to attend</p>
        </div>
        <div className="rounded-2xl bg-emerald-50 border border-emerald-100 p-4 text-center">
          <p className="text-3xl font-display font-bold text-emerald-600">{totalBunkable}</p>
          <p className="text-xs text-emerald-500/70 font-medium mt-1">total classes you can bunk</p>
        </div>
        <div className="rounded-2xl bg-amber-50 border border-amber-100 p-4 text-center">
          <p className="text-3xl font-display font-bold text-amber-600">{belowTarget}</p>
          <p className="text-xs text-amber-500/70 font-medium mt-1">subjects below {target}%</p>
        </div>
      </div>

      {/* Per-subject breakdown */}
      <div className="space-y-2">
        {results.map((r) => (
          <div
            key={r.courseCode}
            className="flex items-center gap-3 p-3 rounded-2xl border border-slate-100 hover:bg-slate-50/50 transition-colors"
          >
            <span className="font-mono text-[10px] font-bold text-slate-500 uppercase flex-shrink-0 w-20 truncate">
              {r.courseCode}
            </span>
            <div className="flex-1 min-w-0">
              <p className="text-xs text-slate-400 truncate">{r.courseTitle}</p>
              <div className="flex items-center gap-2 mt-0.5">
                <span className="text-sm font-bold text-slate-700">{r.pct}%</span>
                {r.needed > 0 ? (
                  <>
                    <span className="text-slate-300 text-xs">→</span>
                    <span className="text-sm font-bold text-emerald-600">{r.newPct}%</span>
                  </>
                ) : null}
              </div>
            </div>
            <div className="text-right flex-shrink-0">
              {r.needed > 0 ? (
                <p className="text-xs font-bold text-red-600">
                  Attend {r.needed} {r.needed > 1 ? "classes" : "class"}
                </p>
              ) : r.bunkable > 0 ? (
                <p className="text-xs font-bold text-emerald-600">
                  Can bunk {r.bunkable}
                </p>
              ) : (
                <p className="text-xs font-bold text-amber-600">On track</p>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Holiday Planner ──────────────────────────────────────────────────────────

function HolidayPlanner({ records }) {
  const today = new Date().toISOString().slice(0, 10);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [classesPerDay, setClassesPerDay] = useState(4);

  const weekdays = useMemo(() => countWeekdays(fromDate, toDate), [fromDate, toDate]);
  const totalMissed = weekdays * classesPerDay;

  // Distribute missed classes across subjects
  // Simple approach: distribute proportionally based on each subject's share of total classes
  const projections = useMemo(() => {
    if (!fromDate || !toDate || weekdays === 0) return [];

    const totalConducted = records.reduce((s, r) => s + parseInt(r.hoursConducted || 0), 0);
    if (totalConducted === 0) return [];

    return records.map((rec) => {
      const conducted = parseInt(rec.hoursConducted || 0);
      const absent = parseInt(rec.hoursAbsent || 0);
      const present = conducted - absent;
      const pct = conducted > 0 ? (present / conducted) * 100 : 0;

      // Distribute missed classes proportionally
      const share = conducted / totalConducted;
      const missedForThis = Math.round(totalMissed * share);

      // New attendance after missing these classes
      const newConducted = conducted + missedForThis;
      const newPresent = present; // they didn't attend these
      const newPct = newConducted > 0 ? (newPresent / newConducted) * 100 : 0;

      // How many classes they'd need to attend after the holiday to get back to 75%
      let recoveryNeeded = 0;
      if (newPct < 75) {
        recoveryNeeded = Math.ceil((75 * newConducted - 100 * newPresent) / 25);
        if (recoveryNeeded < 0) recoveryNeeded = 0;
      }

      return {
        courseCode: rec.courseCode,
        courseTitle: rec.courseTitle,
        conducted,
        present,
        pct: pct.toFixed(1),
        missedForThis,
        newConducted,
        newPct: newPct.toFixed(1),
        drop: (pct - newPct).toFixed(1),
        recoveryNeeded,
        willDropBelow: newPct < 75 && pct >= 75,
      };
    }).sort((a, b) => parseFloat(b.drop) - parseFloat(a.drop));
  }, [records, fromDate, toDate, weekdays, classesPerDay, totalMissed]);

  const overallPct = records.length > 0
    ? (records.reduce((s, r) => s + parseFloat(r.attendancePct || 0), 0) / records.length).toFixed(1)
    : 0;

  const projectedOverall = projections.length > 0
    ? (projections.reduce((s, p) => s + parseFloat(p.newPct), 0) / projections.length).toFixed(1)
    : 0;

  const subjectsDropping = projections.filter((p) => p.willDropBelow).length;
  const hasValidRange = fromDate && toDate && weekdays > 0;

  return (
    <div>
      {/* Date range selector */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-4 p-5 rounded-2xl bg-slate-50 border border-slate-100">
        <div>
          <label className="block text-[11px] font-bold text-slate-500 uppercase tracking-wide mb-2">
            <Plane size={12} className="inline mr-1" /> Holiday From
          </label>
          <input
            type="date"
            value={fromDate}
            min={today}
            onChange={(e) => setFromDate(e.target.value)}
            className="w-full px-4 py-3 rounded-xl text-sm font-medium border border-slate-200 bg-white text-slate-900 focus:border-violet-400 focus:ring-2 focus:ring-violet-100 outline-none cursor-pointer"
          />
        </div>
        <div>
          <label className="block text-[11px] font-bold text-slate-500 uppercase tracking-wide mb-2">
            <CalendarDays size={12} className="inline mr-1" /> Holiday To
          </label>
          <input
            type="date"
            value={toDate}
            min={fromDate || today}
            onChange={(e) => setToDate(e.target.value)}
            className="w-full px-4 py-3 rounded-xl text-sm font-medium border border-slate-200 bg-white text-slate-900 focus:border-violet-400 focus:ring-2 focus:ring-violet-100 outline-none cursor-pointer"
          />
        </div>
      </div>

      {/* Classes per day slider */}
      <div className="flex items-center gap-4 mb-6 p-5 rounded-2xl bg-slate-50 border border-slate-100">
        <div className="flex items-center gap-2 flex-shrink-0">
          <Calculator size={18} className="text-violet-600" />
          <span className="font-bold text-sm text-slate-700">Classes per day</span>
        </div>
        <div className="flex items-center gap-3 flex-1">
          <input
            type="range"
            min="1"
            max="8"
            step="1"
            value={classesPerDay}
            onChange={(e) => setClassesPerDay(parseInt(e.target.value))}
            className="flex-1 accent-violet-600 cursor-pointer"
          />
          <div className="flex items-center gap-1 bg-white rounded-full px-4 py-2 border border-slate-200 shadow-sm">
            <span className="text-2xl font-display font-bold text-violet-600">{classesPerDay}</span>
          </div>
        </div>
      </div>

      {!hasValidRange ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <div className="w-16 h-16 rounded-full bg-slate-100 flex items-center justify-center mb-4">
            <Plane size={28} className="text-slate-300" />
          </div>
          <p className="text-slate-500 font-medium text-sm mb-1">Plan your holiday</p>
          <p className="text-slate-400 text-xs max-w-xs">
            Select a date range above to see how your attendance would be affected if you skip classes during that period.
          </p>
        </div>
      ) : (
        <>
          {/* Summary */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
            <div className="rounded-2xl bg-blue-50 border border-blue-100 p-4 text-center">
              <p className="text-2xl font-display font-bold text-blue-600">{weekdays}</p>
              <p className="text-[11px] text-blue-500/70 font-medium mt-1">weekdays off</p>
            </div>
            <div className="rounded-2xl bg-violet-50 border border-violet-100 p-4 text-center">
              <p className="text-2xl font-display font-bold text-violet-600">{totalMissed}</p>
              <p className="text-[11px] text-violet-500/70 font-medium mt-1">total classes missed</p>
            </div>
            <div className="rounded-2xl bg-amber-50 border border-amber-100 p-4 text-center">
              <p className="text-2xl font-display font-bold text-amber-600">
                {overallPct}% <span className="text-sm text-slate-400">→</span> {projectedOverall}%
              </p>
              <p className="text-[11px] text-amber-500/70 font-medium mt-1">overall attendance</p>
            </div>
            <div className="rounded-2xl bg-red-50 border border-red-100 p-4 text-center">
              <p className="text-2xl font-display font-bold text-red-600">{subjectsDropping}</p>
              <p className="text-[11px] text-red-500/70 font-medium mt-1">subjects dropping below 75%</p>
            </div>
          </div>

          {/* Warning if subjects drop below 75% */}
          {subjectsDropping > 0 && (
            <div className="rounded-2xl bg-red-50 border border-red-200 p-4 mb-6 flex items-start gap-3">
              <AlertTriangle size={18} className="text-red-600 mt-0.5 flex-shrink-0" />
              <p className="text-xs text-red-700 font-medium leading-relaxed">
                <span className="font-bold">{subjectsDropping} subject{subjectsDropping > 1 ? "s" : ""}</span> will drop below 75% if you take this holiday.
                Check the recovery column to see how many classes you'd need to attend afterward to get back on track.
              </p>
            </div>
          )}

          {/* Per-subject projection */}
          <div className="space-y-2">
            <div className="grid grid-cols-12 gap-2 px-3 pb-2 border-b border-slate-100">
              <span className="col-span-3 text-[10px] font-bold text-slate-400 uppercase">Subject</span>
              <span className="col-span-2 text-[10px] font-bold text-slate-400 uppercase text-right">Now</span>
              <span className="col-span-2 text-[10px] font-bold text-slate-400 uppercase text-right">After</span>
              <span className="col-span-2 text-[10px] font-bold text-slate-400 uppercase text-right">Drop</span>
              <span className="col-span-3 text-[10px] font-bold text-slate-400 uppercase text-right">Recovery</span>
            </div>
            {projections.map((p) => (
              <div
                key={p.courseCode}
                className="grid grid-cols-12 gap-2 items-center p-3 rounded-2xl border border-slate-100 hover:bg-slate-50/50 transition-colors"
              >
                <div className="col-span-3 min-w-0">
                  <p className="font-mono text-[10px] font-bold text-slate-500 uppercase truncate">{p.courseCode}</p>
                  <p className="text-xs text-slate-400 truncate">{p.courseTitle}</p>
                </div>
                <div className="col-span-2 text-right">
                  <span className="text-sm font-bold text-slate-700">{p.pct}%</span>
                </div>
                <div className="col-span-2 text-right">
                  <span className={`text-sm font-bold ${parseFloat(p.newPct) < 75 ? "text-red-600" : "text-slate-700"}`}>
                    {p.newPct}%
                  </span>
                </div>
                <div className="col-span-2 text-right">
                  <span className="text-sm font-bold text-red-500">-{p.drop}%</span>
                </div>
                <div className="col-span-3 text-right">
                  {p.recoveryNeeded > 0 ? (
                    <span className="text-xs font-bold text-red-600">
                      Need {p.recoveryNeeded} classes
                    </span>
                  ) : (
                    <span className="text-xs font-bold text-emerald-600">
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
              Missed classes are distributed proportionally based on each subject's current class count. Actual impact may vary depending on your timetable and which subjects have classes during the holiday period.
            </p>
          </div>
        </>
      )}
    </div>
  );
}

// ─── Main Component ───────────────────────────────────────────────────────────

export default function AttendancePlanner({ records }) {
  const [mode, setMode] = useState("margin"); // "margin" | "holiday"

  return (
    <div className="attendance-row bg-white rounded-[32px] p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]" style={{ opacity: 0 }}>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center">
            <Sparkles className="w-5 h-5 text-white" />
          </div>
          <div>
            <h3 className="font-display font-bold text-2xl text-[#1A1A1A]">Attendance Planner</h3>
            <p className="text-xs text-slate-400 font-medium">Plan your attendance — reach your target or plan a holiday</p>
          </div>
        </div>
      </div>

      {/* Mode toggle */}
      <div className="flex gap-2 mb-6 p-1.5 bg-slate-100 rounded-2xl">
        <button
          onClick={() => setMode("margin")}
          className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold transition-all cursor-pointer ${
            mode === "margin"
              ? "bg-white text-violet-600 shadow-sm"
              : "text-slate-500 hover:text-slate-700"
          }`}
        >
          <Target size={16} />
          Reach Target
        </button>
        <button
          onClick={() => setMode("holiday")}
          className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold transition-all cursor-pointer ${
            mode === "holiday"
              ? "bg-white text-violet-600 shadow-sm"
              : "text-slate-500 hover:text-slate-700"
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
            <HolidayPlanner records={records} />
          )}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
