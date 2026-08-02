/**
 * AttendancePrediction - Shows attendance predictions, bunk budgets, and risk analysis.
 */
import { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  TrendingUp, TrendingDown, AlertTriangle, CheckCircle2, Sparkles,
  ChevronDown, ChevronUp, Calendar, Target, Zap, Shield
} from "lucide-react";
import {
  predictSubject, predictOverall, getRiskStyle, getStatusStyle
} from "../utils/attendancePrediction.js";

export default function AttendancePrediction({ records }) {
  const [expanded, setExpanded] = useState(false);

  const overall = useMemo(() => predictOverall(records), [records]);
  const subjectPredictions = useMemo(
    () => records.map(predictSubject).sort((a, b) => parseFloat(a.pct) - parseFloat(b.pct)),
    [records]
  );

  const riskStyle = getRiskStyle(overall.riskLevel);

  const RiskIcon = overall.riskLevel === "high"
    ? AlertTriangle
    : overall.riskLevel === "medium"
    ? TrendingDown
    : CheckCircle2;

  return (
    <div className="attendance-row bg-white rounded-[32px] p-6 md:p-8 border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)]" style={{ opacity: 0 }}>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center">
            <Sparkles className="w-5 h-5 text-white" />
          </div>
          <div>
            <h3 className="font-display font-bold text-2xl text-[#1A1A1A]">Attendance Prediction</h3>
            <p className="text-xs text-slate-400 font-medium">AI-powered bunk budget & risk analysis</p>
          </div>
        </div>
        <div className={`px-3 py-1.5 rounded-full text-xs font-bold ${riskStyle.bgColor} ${riskStyle.color} border ${riskStyle.borderColor}`}>
          {riskStyle.label}
        </div>
      </div>

      {/* Risk Banner */}
      <div className={`rounded-2xl p-5 mb-6 ${riskStyle.bgColor} border ${riskStyle.borderColor} flex items-start gap-4`}>
        <div className={`w-10 h-10 rounded-full ${riskStyle.color} bg-white flex items-center justify-center flex-shrink-0`}>
          <RiskIcon size={20} />
        </div>
        <div className="flex-1">
          <p className={`font-bold text-sm ${riskStyle.color} mb-1`}>{overall.message}</p>
          <p className="text-xs text-slate-500">
            Overall: <span className="font-bold">{overall.overallPct}%</span> •
            Safe: <span className="font-bold text-emerald-600">{overall.safeSubjects}</span> •
            Borderline: <span className="font-bold text-amber-600">{overall.warningSubjects}</span> •
            Below 75%: <span className="font-bold text-red-600">{overall.criticalSubjects + overall.dangerSubjects}</span>
          </p>
        </div>
      </div>

      {/* Key Metrics Grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {/* Total Bunkable */}
        <div className="rounded-2xl bg-emerald-50 border border-emerald-100 p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-7 h-7 rounded-full bg-emerald-100 flex items-center justify-center">
              <CheckCircle2 size={14} className="text-emerald-600" />
            </div>
            <span className="text-[11px] font-bold text-emerald-700 uppercase tracking-wide">Bunk Budget</span>
          </div>
          <p className="text-3xl font-display font-bold text-emerald-700">
            {overall.totalBunkable}
          </p>
          <p className="text-[11px] text-emerald-600/70 font-medium mt-1">classes you can skip</p>
        </div>

        {/* Classes Needed */}
        <div className="rounded-2xl bg-red-50 border border-red-100 p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-7 h-7 rounded-full bg-red-100 flex items-center justify-center">
              <Target size={14} className="text-red-600" />
            </div>
            <span className="text-[11px] font-bold text-red-700 uppercase tracking-wide">Must Attend</span>
          </div>
          <p className="text-3xl font-display font-bold text-red-700">
            {overall.totalNeeded}
          </p>
          <p className="text-[11px] text-red-600/70 font-medium mt-1">classes to reach 75%</p>
        </div>

        {/* Current Rate */}
        <div className="rounded-2xl bg-violet-50 border border-violet-100 p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-7 h-7 rounded-full bg-violet-100 flex items-center justify-center">
              <Zap size={14} className="text-violet-600" />
            </div>
            <span className="text-[11px] font-bold text-violet-700 uppercase tracking-wide">Attend Rate</span>
          </div>
          <p className="text-3xl font-display font-bold text-violet-700">
            {overall.currentRate}%
          </p>
          <p className="text-[11px] text-violet-600/70 font-medium mt-1">current attendance rate</p>
        </div>

        {/* Projected */}
        <div className="rounded-2xl bg-blue-50 border border-blue-100 p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-7 h-7 rounded-full bg-blue-100 flex items-center justify-center">
              <TrendingUp size={14} className="text-blue-600" />
            </div>
            <span className="text-[11px] font-bold text-blue-700 uppercase tracking-wide">Projected</span>
          </div>
          <p className="text-3xl font-display font-bold text-blue-700">
            {overall.projectedPct}%
          </p>
          <p className="text-[11px] text-blue-600/70 font-medium mt-1">in 20 classes (current rate)</p>
        </div>
      </div>

      {/* Scenario Projections */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-6">
        <div className="rounded-2xl bg-slate-50 border border-slate-100 p-4 text-center">
          <div className="flex items-center justify-center gap-1.5 mb-2">
            <Shield size={14} className="text-emerald-600" />
            <span className="text-[11px] font-bold text-slate-600 uppercase tracking-wide">If You Attend All</span>
          </div>
          <p className="text-2xl font-display font-bold text-emerald-600">
            {overall.perfectProjectedPct}%
          </p>
          <p className="text-[11px] text-slate-400 font-medium mt-1">next 20 classes at 100%</p>
        </div>

        <div className="rounded-2xl bg-slate-50 border border-slate-100 p-4 text-center">
          <div className="flex items-center justify-center gap-1.5 mb-2">
            <TrendingUp size={14} className="text-blue-600" />
            <span className="text-[11px] font-bold text-slate-600 uppercase tracking-wide">If You Maintain</span>
          </div>
          <p className="text-2xl font-display font-bold text-blue-600">
            {overall.projectedPct}%
          </p>
          <p className="text-[11px] text-slate-400 font-medium mt-1">next 20 classes at current rate</p>
        </div>

        <div className="rounded-2xl bg-slate-50 border border-slate-100 p-4 text-center">
          <div className="flex items-center justify-center gap-1.5 mb-2">
            <TrendingDown size={14} className="text-red-600" />
            <span className="text-[11px] font-bold text-slate-600 uppercase tracking-wide">If You Bunk 5</span>
          </div>
          <p className="text-2xl font-display font-bold text-red-600">
            {overall.bunkProjectedPct}%
          </p>
          <p className="text-[11px] text-slate-400 font-medium mt-1">skip next 5 classes</p>
        </div>
      </div>

      {/* Expand/Collapse Subject Predictions */}
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full flex items-center justify-between px-4 py-3 rounded-2xl bg-slate-50 hover:bg-slate-100 transition-colors cursor-pointer"
      >
        <span className="font-bold text-sm text-slate-700">Subject-wise Predictions ({subjectPredictions.length})</span>
        {expanded ? <ChevronUp size={18} className="text-slate-400" /> : <ChevronDown size={18} className="text-slate-400" />}
      </button>

      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            className="overflow-hidden mt-3"
          >
            <div className="space-y-2">
              {subjectPredictions.map((pred) => {
                const style = getStatusStyle(pred.status);
                return (
                  <div
                    key={pred.courseCode}
                    className="flex items-center gap-3 p-3 rounded-2xl border border-slate-100 hover:bg-slate-50/50 transition-colors"
                  >
                    {/* Status badge */}
                    <span className={`text-[10px] font-bold px-2 py-1 rounded-md ${style.bgColor} ${style.color} flex-shrink-0`}>
                      {style.label}
                    </span>

                    {/* Course info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-0.5">
                        <span className="font-mono text-[11px] font-bold text-slate-500 uppercase">{pred.courseCode}</span>
                        <span className="text-sm font-bold text-slate-700">{pred.pct}%</span>
                      </div>
                      <p className="text-xs text-slate-400 truncate">{pred.courseTitle}</p>
                    </div>

                    {/* Prediction */}
                    <div className="text-right flex-shrink-0">
                      {pred.bunkable > 0 ? (
                        <p className="text-xs font-bold text-emerald-600">
                          Can bunk {pred.bunkable}
                        </p>
                      ) : pred.needed > 0 ? (
                        <p className="text-xs font-bold text-red-600">
                          Need {pred.needed} classes
                        </p>
                      ) : (
                        <p className="text-xs font-bold text-amber-600">
                          On track
                        </p>
                      )}
                      <p className="text-[10px] text-slate-400">
                        Bunk 1 → {pred.projectionIfBunk}% | Attend 1 → {pred.projectionIfAttend}%
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Disclaimer */}
      <div className="flex items-start gap-2 mt-4 px-1">
        <Calendar size={12} className="text-slate-300 mt-0.5 flex-shrink-0" />
        <p className="text-[10px] text-slate-400 font-medium leading-relaxed">
          Predictions are based on current attendance data and assume all subjects have equal weight. Actual results may vary based on subject-specific class schedules.
        </p>
      </div>
    </div>
  );
}
