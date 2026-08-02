/**
 * Attendance Prediction Utility
 * Calculates bunk budgets, classes needed, and risk projections.
 */

const THRESHOLD = 75;
const SAFE_THRESHOLD = 80;
const DANGER_THRESHOLD = 65;

/**
 * Calculate prediction for a single subject.
 * @param {Object} rec - Attendance record with hoursConducted, hoursAbsent, attendancePct
 * @returns {Object} Prediction data
 */
export function predictSubject(rec) {
  const conducted = parseInt(rec.hoursConducted || 0);
  const absent = parseInt(rec.hoursAbsent || 0);
  const present = conducted - absent;
  const pct = parseFloat(rec.attendancePct || 0);

  if (conducted === 0) {
    return {
      courseCode: rec.courseCode,
      courseTitle: rec.courseTitle,
      conducted: 0,
      present: 0,
      absent: 0,
      pct: 0,
      status: "no-data",
      bunkable: 0,
      needed: 0,
      projectionIfBunk: 0,
      projectionIfAttend: 0,
      daysTo75: 0,
    };
  }

  // How many classes can you bunk while staying at exactly 75%?
  // P / (C + X) >= 0.75  →  X <= (P/0.75) - C
  const bunkableRaw = (present / 0.75) - conducted;
  const bunkable = bunkableRaw > 0 ? Math.floor(bunkableRaw) : 0;

  // How many consecutive classes must you attend to reach 75%?
  // (P + Y) / (C + Y) >= 0.75  →  Y >= (0.75*C - P) / 0.25 = 3C - 4P
  const neededRaw = (0.75 * conducted - present) / 0.25;
  const needed = neededRaw > 0 ? Math.ceil(neededRaw) : 0;

  // If you bunk 1 more class, what's your new percentage?
  const projectionIfBunk = conducted + 1 > 0
    ? ((present / (conducted + 1)) * 100).toFixed(1)
    : 0;

  // If you attend 1 more class, what's your new percentage?
  const projectionIfAttend = conducted + 1 > 0
    ? (((present + 1) / (conducted + 1)) * 100).toFixed(1)
    : 0;

  // Days to reach 75% if attending all classes (needed > 0 only)
  const daysTo75 = needed;

  // Determine status
  let status = "safe";
  if (pct < DANGER_THRESHOLD) status = "danger";
  else if (pct < THRESHOLD) status = "critical";
  else if (pct < SAFE_THRESHOLD) status = "warning";

  return {
    courseCode: rec.courseCode,
    courseTitle: rec.courseTitle,
    conducted,
    present,
    absent,
    pct: pct.toFixed(1),
    status,
    bunkable,
    needed,
    projectionIfBunk: parseFloat(projectionIfBunk),
    projectionIfAttend: parseFloat(projectionIfAttend),
    daysTo75,
  };
}

/**
 * Calculate overall prediction across all subjects.
 * @param {Array} records - All attendance records
 * @returns {Object} Overall prediction summary
 */
export function predictOverall(records) {
  if (!records || records.length === 0) {
    return {
      totalSubjects: 0,
      safeSubjects: 0,
      warningSubjects: 0,
      criticalSubjects: 0,
      dangerSubjects: 0,
      totalBunkable: 0,
      totalNeeded: 0,
      overallPct: 0,
      riskLevel: "unknown",
      message: "No data available",
    };
  }

  const predictions = records.map(predictSubject);
  const totalConducted = records.reduce((s, r) => s + parseInt(r.hoursConducted || 0), 0);
  const totalAbsent = records.reduce((s, r) => s + parseInt(r.hoursAbsent || 0), 0);
  const totalPresent = totalConducted - totalAbsent;
  const overallPct = totalConducted > 0
    ? ((totalPresent / totalConducted) * 100).toFixed(1)
    : 0;

  const safe = predictions.filter(p => p.status === "safe").length;
  const warning = predictions.filter(p => p.status === "warning").length;
  const critical = predictions.filter(p => p.status === "critical").length;
  const danger = predictions.filter(p => p.status === "danger").length;

  const totalBunkable = predictions.reduce((s, p) => s + p.bunkable, 0);
  const totalNeeded = predictions.reduce((s, p) => s + p.needed, 0);

  // Determine risk level
  let riskLevel = "low";
  let message = "You're in a safe zone. Keep it up!";

  if (danger > 0 || critical > records.length / 2) {
    riskLevel = "high";
    message = "Multiple subjects at risk. Attend classes regularly.";
  } else if (critical > 0 || warning > records.length / 2) {
    riskLevel = "medium";
    message = "Some subjects need attention. Don't bunk upcoming classes.";
  } else if (warning > 0) {
    riskLevel = "low";
    message = "You're doing well, but keep an eye on borderline subjects.";
  }

  // Projection: if you maintain current attendance rate for next 20 classes
  const currentRate = totalConducted > 0 ? totalPresent / totalConducted : 0;
  const projectedConducted = totalConducted + 20;
  const projectedPresent = totalPresent + Math.round(20 * currentRate);
  const projectedPct = projectedConducted > 0
    ? ((projectedPresent / projectedConducted) * 100).toFixed(1)
    : 0;

  // Projection: if you attend ALL next 20 classes
  const perfectProjectedPct = projectedConducted > 0
    ? (((totalPresent + 20) / projectedConducted) * 100).toFixed(1)
    : 0;

  // Projection: if you bunk ALL next 5 classes
  const bunkProjectedConducted = totalConducted + 5;
  const bunkProjectedPct = bunkProjectedConducted > 0
    ? ((totalPresent / bunkProjectedConducted) * 100).toFixed(1)
    : 0;

  return {
    totalSubjects: records.length,
    safeSubjects: safe,
    warningSubjects: warning,
    criticalSubjects: critical,
    dangerSubjects: danger,
    totalBunkable,
    totalNeeded,
    overallPct,
    riskLevel,
    message,
    projectedPct: parseFloat(projectedPct),
    perfectProjectedPct: parseFloat(perfectProjectedPct),
    bunkProjectedPct: parseFloat(bunkProjectedPct),
    currentRate: (currentRate * 100).toFixed(1),
  };
}

/**
 * Get risk level styling.
 */
export function getRiskStyle(riskLevel) {
  switch (riskLevel) {
    case "high":
      return {
        color: "text-red-600",
        bgColor: "bg-red-50",
        borderColor: "border-red-200",
        label: "High Risk",
        icon: "alert",
      };
    case "medium":
      return {
        color: "text-amber-600",
        bgColor: "bg-amber-50",
        borderColor: "border-amber-200",
        label: "Medium Risk",
        icon: "warning",
      };
    case "low":
      return {
        color: "text-emerald-600",
        bgColor: "bg-emerald-50",
        borderColor: "border-emerald-200",
        label: "Low Risk",
        icon: "check",
      };
    default:
      return {
        color: "text-slate-600",
        bgColor: "bg-slate-50",
        borderColor: "border-slate-200",
        label: "Unknown",
        icon: "info",
      };
  }
}

/**
 * Get status styling for a subject.
 */
export function getStatusStyle(status) {
  switch (status) {
    case "safe":
      return { color: "text-emerald-700", bgColor: "bg-emerald-100", label: "Safe" };
    case "warning":
      return { color: "text-amber-700", bgColor: "bg-amber-100", label: "Borderline" };
    case "critical":
      return { color: "text-red-700", bgColor: "bg-red-100", label: "Below 75%" };
    case "danger":
      return { color: "text-red-800", bgColor: "bg-red-200", label: "Critical" };
    default:
      return { color: "text-slate-600", bgColor: "bg-slate-100", label: "No Data" };
  }
}
