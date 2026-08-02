import {
  Briefcase, RefreshCw, Search, MapPin, IndianRupee, Clock, Building2,
  CheckCircle2, XCircle, AlertTriangle, Calendar, Users, FileText,
  ArrowLeft, GraduationCap, Layers, Globe, Sparkles, TrendingUp,
  Paperclip, Download, ExternalLink, HelpCircle, Milestone,
  Briefcase as BriefcaseIcon, Code2,
} from "lucide-react";
import { useState, useMemo, useEffect } from "react";
import { usePlacementData } from "../hooks/usePlacementData.js";
import { placementApi } from "../api/placementClient.js";
import { useAuth } from "../hooks/useAuth.jsx";
import Loading from "../components/Loading.jsx";
import ErrorBox from "../components/ErrorBox.jsx";

export default function Jobs() {
  const { data, loading, error, refetch } = usePlacementData("jobs");
  const { placementUser } = useAuth();
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("all");
  const [selectedJob, setSelectedJob] = useState(null);
  const [logoMap, setLogoMap] = useState({});

  useEffect(() => {
    if (!placementUser) return;
    placementApi.companies(placementUser.username, 0, 20)
      .then((res) => {
        const list = res.data?._embedded?.entityModels || [];
        const map = {};
        for (const c of list) {
          if (c.id && c.imageUrl) map[c.id] = c.imageUrl;
        }
        setLogoMap(map);
      })
      .catch(() => {});
  }, [placementUser]);

  const jobs = useMemo(() => {
    const list = data?._embedded?.entityModels || [];
    let filtered = list;
    if (filter === "eligible") filtered = list.filter((j) => j.isEligible);
    else if (filter === "applied") filtered = list.filter((j) => j.isApplied);
    else if (filter === "offered") filtered = list.filter((j) => j.isOffered);
    else if (filter === "notEligible") filtered = list.filter((j) => j.isNotEligible);
    if (!search) return filtered;
    return filtered.filter((j) =>
      j.jobTitle?.toLowerCase().includes(search.toLowerCase()) ||
      j.companyName?.toLowerCase().includes(search.toLowerCase()) ||
      j.jobTag?.toLowerCase().includes(search.toLowerCase())
    );
  }, [data, search, filter]);

  if (loading) return <Loading label="Fetching jobs…" />;
  if (error) return <ErrorBox message={error} onRetry={refetch} />;

  if (selectedJob) {
    return <JobDetailPage job={selectedJob} onBack={() => setSelectedJob(null)} logoMap={logoMap} />;
  }

  const allJobs = data?._embedded?.entityModels || [];
  const counts = {
    all: allJobs.length,
    eligible: allJobs.filter((j) => j.isEligible).length,
    applied: allJobs.filter((j) => j.isApplied).length,
    offered: allJobs.filter((j) => j.isOffered).length,
    notEligible: allJobs.filter((j) => j.isNotEligible).length,
  };

  return (
    <div className="space-y-5 pt-4">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <h2 className="text-2xl font-display font-bold text-[#1A1A1A]">Jobs</h2>
        <div className="flex gap-2 sm:gap-3 items-center w-full sm:w-auto">
          <div className="relative flex-1 sm:flex-none">
            <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
            <input type="text" value={search} onChange={(e) => setSearch(e.target.value)}
              placeholder="Search jobs…"
              className="w-full sm:w-64 pl-10 pr-4 py-2.5 sm:py-2 rounded-full text-sm border border-slate-200 bg-white text-slate-900 placeholder:text-slate-400 outline-none focus:border-[#1A1A1A] focus:ring-1 focus:ring-[#1A1A1A] transition-all" />
          </div>
          <button onClick={refetch} className="w-10 h-10 sm:w-9 sm:h-9 shrink-0 rounded-full bg-white border border-slate-200 flex items-center justify-center text-slate-500 hover:text-[#1A1A1A] hover:bg-slate-50 cursor-pointer transition-colors shadow-sm">
            <RefreshCw size={15} />
          </button>
        </div>
      </div>

      <div className="flex gap-2 overflow-x-auto hide-scrollbar pb-2 -mx-6 px-6 sm:mx-0 sm:px-0 sm:flex-wrap sm:pb-0">
        {[
          { key: "all", label: "All", count: counts.all },
          { key: "eligible", label: "Eligible", count: counts.eligible },
          { key: "applied", label: "Applied", count: counts.applied },
          { key: "offered", label: "Offered", count: counts.offered },
          { key: "notEligible", label: "Not Eligible", count: counts.notEligible },
        ].map((tab) => (
          <button key={tab.key} onClick={() => setFilter(tab.key)}
            className={`whitespace-nowrap px-4 py-2 rounded-full text-sm font-semibold transition-colors cursor-pointer ${
              filter === tab.key
                ? "bg-[#1A1A1A] text-white"
                : "bg-white text-slate-600 border border-slate-200 hover:bg-slate-50"
            }`}>
            {tab.label} <span className="opacity-60">({tab.count})</span>
          </button>
        ))}
      </div>

      <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-5">
        {jobs.map((job, i) => (
          <JobCard key={job.id || i} job={job} index={i} logoUrl={logoMap[job.companyId]} onClick={() => setSelectedJob(job)} />
        ))}
      </div>

      {jobs.length === 0 && (
        <div className="bg-white rounded-[20px] p-8 border border-slate-200/60 text-center">
          <Briefcase size={32} className="text-slate-300 mx-auto mb-3" />
          <p className="text-slate-500 text-sm font-medium">No jobs found matching your filters.</p>
        </div>
      )}
    </div>
  );
}

/* ─── Helpers ─── */

function formatCTC(min, max) {
  if (!min && !max) return "—";
  const fmt = (v) => {
    if (v >= 100000) return `₹${(v / 100000).toFixed(1)} LPA`;
    if (v >= 1000) return `₹${(v / 1000).toFixed(0)}K`;
    return `₹${v?.toLocaleString("en-IN") || "—"}`;
  };
  if (min && max && min !== max) return `${fmt(min)} – ${fmt(max)}`;
  return fmt(max || min);
}

function formatDate(dateStr) {
  if (!dateStr) return "—";
  const d = new Date(dateStr);
  if (isNaN(d)) return dateStr;
  return d.toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
}

function daysUntil(dateStr) {
  if (!dateStr) return null;
  const d = new Date(dateStr);
  if (isNaN(d)) return null;
  return Math.ceil((d - new Date()) / (1000 * 60 * 60 * 24));
}

function getStatusInfo(job) {
  if (job.isOffered) return { text: "Offered", cls: "bg-green-500 text-white", icon: <CheckCircle2 size={14} />, border: "border-green-500" };
  if (job.isRejected) return { text: "Rejected", cls: "bg-red-500 text-white", icon: <XCircle size={14} />, border: "border-red-500" };
  if (job.isApplied) return { text: "Applied", cls: "bg-blue-500 text-white", icon: <Clock size={14} />, border: "border-blue-500" };
  if (job.isEligible) return { text: "Eligible", cls: "bg-[#BDE3D5] text-green-800", icon: <CheckCircle2 size={14} />, border: "border-[#BDE3D5]" };
  if (job.isNotEligible) return { text: "Not Eligible", cls: "bg-red-50 text-red-600", icon: <XCircle size={14} />, border: "border-red-200" };
  return { text: "—", cls: "bg-slate-100 text-slate-500", icon: null, border: "border-slate-200" };
}

function parseEligibilityCriteria(reason) {
  if (!reason) return [];
  const criteria = [];
  if (/tenth|10th/i.test(reason)) criteria.push({ label: "10th Percentage", met: false, text: reason });
  if (/12th|twelfth|diploma/i.test(reason)) criteria.push({ label: "12th / Diploma", met: false, text: reason });
  if (/cgpa|percentage/i.test(reason)) criteria.push({ label: "CGPA", met: false, text: reason });
  if (/skill tag/i.test(reason)) criteria.push({ label: "Skill Tag", met: false, text: reason.replace(/.*Job Required Student Tags:\s*/, "Required: ") });
  if (criteria.length === 0 && reason) criteria.push({ label: "Other", met: false, text: reason });
  return criteria;
}

function getEligibilityTags(job) {
  const tags = [];
  if (job.cgpaRequired) tags.push({ label: `CGPA ≥ ${job.cgpaRequired}`, type: "requirement" });
  if (job.skillsRequired) {
    const skills = job.skillsRequired.split(":#*#:").map(s => s.trim()).filter(Boolean);
    skills.forEach(s => tags.push({ label: s, type: "skill" }));
  }
  return tags;
}

/* ─── Job Card (award-style selection UI) ─── */

const JOB_AVATARS = [
  "/assets/developer-avatar_f6ac.svg",
  "/assets/designer-avatar_n5q8.svg",
  "/assets/finance-guy-avatar_vhop.svg",
  "/assets/professional-woman-avatar_ivds.svg",
  "/assets/businesswoman-avatar_ktl2.svg",
  "/assets/indie-hacker-avatar_b3wy.svg",
  "/assets/professor-avatar_y9ai.svg",
  "/assets/young-man-avatar_wgbd.svg",
  "/assets/cool-guy-avatar_qjc4.svg",
  "/assets/deep-thinker-avatar_6xg6.svg",
  "/assets/friendly-guy-avatar_dqp5.svg",
  "/assets/stylish-girl-avatar_m8po.svg",
];

const CARD_THEMES = [
  {
    key: "mint",
    iconBg: "#BDE3D5",
    accent: "#5B9E8B",
    accentSoft: "rgba(189, 227, 213, 0.35)",
  },
  {
    key: "lavender",
    iconBg: "#C7C9E0",
    accent: "#6E7196",
    accentSoft: "rgba(199, 201, 224, 0.4)",
  },
  {
    key: "terracotta",
    iconBg: "#D97757",
    accent: "#D97757",
    accentSoft: "rgba(217, 119, 87, 0.35)",
  },
  {
    key: "beige",
    iconBg: "#E6D5C3",
    accent: "#A38565",
    accentSoft: "rgba(230, 213, 195, 0.45)",
  },
];

function hashSeed(value = "") {
  let hash = 0;
  const str = String(value);
  for (let i = 0; i < str.length; i += 1) {
    hash = (hash * 31 + str.charCodeAt(i)) >>> 0;
  }
  return hash;
}

function getCardStyle(job, index = 0) {
  const seed = hashSeed(`${job.companyName || ""}|${job.jobTitle || ""}|${job.id || index}`);
  return {
    avatar: JOB_AVATARS[seed % JOB_AVATARS.length],
    theme: CARD_THEMES[seed % CARD_THEMES.length],
    motif: seed % 6,
  };
}

function CardMotif({ motif, color }) {
  const common = {
    className: "absolute -bottom-6 -right-4 w-[82%] h-[95%] pointer-events-none",
    "aria-hidden": true,
    preserveAspectRatio: "xMaxYMax meet",
  };
  switch (motif) {
    case 0:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          <path d="M10 180C45 140 70 120 105 100C140 80 165 45 200 15" stroke={color} strokeWidth="5" opacity="0.55" />
          <path d="M0 195C40 155 75 128 115 108C155 88 175 55 205 35" stroke={color} strokeWidth="4" opacity="0.38" />
          <path d="M25 200C55 165 90 142 130 122C170 102 185 70 210 55" stroke={color} strokeWidth="3.5" opacity="0.28" />
          <path d="M40 205C70 175 105 155 145 138C185 120 198 88 215 75" stroke={color} strokeWidth="3" opacity="0.2" />
        </svg>
      );
    case 1:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          {Array.from({ length: 10 }).map((_, row) =>
            Array.from({ length: 8 }).map((_, col) => {
              const x = 40 + col * 22 + (row % 2) * 10;
              const y = 20 + row * 18;
              return <circle key={`${row}-${col}`} cx={x} cy={y} r={3 + ((row + col) % 4)} fill={color} opacity={0.28 + ((row + col) % 4) * 0.12} />;
            })
          )}
        </svg>
      );
    case 2:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          <path d="M40 200L200 20V200H40Z" fill={color} opacity="0.2" />
          <path d="M75 200L200 55V200H75Z" fill={color} opacity="0.28" />
          <path d="M110 200L200 95V200H110Z" fill={color} opacity="0.4" />
          <path d="M55 190L190 40" stroke={color} strokeWidth="14" opacity="0.35" />
          <path d="M85 198L198 75" stroke={color} strokeWidth="14" opacity="0.45" />
          <path d="M120 200L200 115" stroke={color} strokeWidth="14" opacity="0.55" />
        </svg>
      );
    case 3:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          {[
            [95, 55, 28], [145, 40, 16], [70, 95, 18], [130, 95, 36],
            [175, 80, 14], [85, 145, 22], [155, 145, 30], [185, 160, 12],
            [55, 160, 14], [115, 175, 20], [170, 50, 10],
          ].map(([cx, cy, r], i) => (
            <circle key={i} cx={cx} cy={cy} r={r} fill={color} opacity={0.22 + (i % 4) * 0.12} />
          ))}
        </svg>
      );
    case 4:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          <circle cx="155" cy="135" r="95" fill={color} opacity="0.18" />
          <circle cx="155" cy="135" r="95" stroke={color} strokeWidth="14" opacity="0.28" strokeDasharray="24 14" />
          <path d="M70 185L195 55" stroke={color} strokeWidth="14" opacity="0.45" />
          <path d="M95 198L205 85" stroke={color} strokeWidth="14" opacity="0.35" />
          <path d="M50 170L175 40" stroke={color} strokeWidth="14" opacity="0.28" />
        </svg>
      );
    default:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          {Array.from({ length: 40 }).map((_, i) => {
            const x = 45 + (i % 8) * 18;
            const y = 25 + Math.floor(i / 8) * 32 + (i % 2) * 8;
            const rot = (i * 37) % 360;
            return (
              <rect
                key={i}
                x={x}
                y={y}
                width="14"
                height="4.5"
                rx="2"
                fill={color}
                opacity={0.3 + (i % 5) * 0.1}
                transform={`rotate(${rot} ${x + 7} ${y + 2})`}
              />
            );
          })}
        </svg>
      );
  }
}

function JobCard({ job, index = 0, logoUrl, onClick }) {
  const status = getStatusInfo(job);
  const ctc = formatCTC(job.minCtc, job.maxCtc);
  const applyBy = formatDate(job.jobApplyBy);
  const days = daysUntil(job.jobApplyByTimestamp);
  const isUrgent = days !== null && days >= 0 && days <= 3;
  const { avatar, theme, motif } = getCardStyle(job, index);
  const category =
    status.text !== "—"
      ? status.text
      : (job.jobType || "Opportunity").replace(/_/g, " ");

  return (
    <button
      type="button"
      onClick={onClick}
      className="group relative text-left w-full min-h-[230px] rounded-[28px] bg-[#1A1A1A] text-white p-6 overflow-hidden cursor-pointer transition-transform duration-200 hover:scale-[1.015] active:scale-[0.99] shadow-[0_10px_30px_rgba(26,26,26,0.18)]"
    >
      <CardMotif motif={motif} color={theme.accent} />

      <div className="relative z-10 flex items-start justify-between gap-3">
        <div
          className="w-12 h-12 rounded-2xl flex items-center justify-center overflow-hidden flex-shrink-0 border border-white/10"
          style={{ backgroundColor: theme.iconBg }}
        >
          {logoUrl ? (
            <img src={logoUrl} alt={job.companyName || ""} className="w-full h-full object-cover" />
          ) : (
            <img src={avatar} alt="" className="w-10 h-10 object-contain" />
          )}
        </div>
        <span className={`text-[12px] font-semibold ${isUrgent ? "text-[#D97757]" : "text-white/45"}`}>
          {isUrgent ? `${days}d left` : applyBy}
        </span>
      </div>

      <div className="relative z-10 mt-8 pr-16">
        <p className="text-[12px] font-semibold tracking-wide mb-2" style={{ color: theme.accent }}>
          {category}
        </p>
        <h3 className="font-display font-bold text-[22px] leading-tight text-white line-clamp-2">
          {job.companyName || "Company"}
        </h3>
        <p className="mt-2 text-[14px] font-medium text-white/80 line-clamp-1">
          {job.jobTitle || "Untitled role"}
        </p>
        <p className="mt-1 text-[13px] font-semibold text-white/55">
          {ctc}
        </p>
      </div>

      <div className="relative z-10 mt-8 flex items-end justify-between gap-3">
        <p className="text-[12px] font-medium text-white/45 truncate max-w-[60%]">
          {job.location || "Location TBA"}
        </p>
        <span
          className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider"
          style={{ backgroundColor: theme.accentSoft, color: theme.accent === "#D97757" ? "#F4F0EB" : "#1A1A1A" }}
        >
          {job.jobType ? job.jobType.replace(/_/g, " ") : "Job"}
        </span>
      </div>
    </button>
  );
}

function Pill({ text, icon }) {
  return (
    <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold text-slate-600 bg-slate-100">
      {icon}{text}
    </span>
  );
}

/* ─── Job Detail Page (full page) ─── */

function JobDetailPage({ job, onBack, logoMap = {} }) {
  const status = getStatusInfo(job);
  const ctc = formatCTC(job.minCtc, job.maxCtc);
  const internCtc = job.internshipMaxCtc ? formatCTC(job.internshipMinCtc, job.internshipMaxCtc) : null;
  const days = daysUntil(job.jobApplyByTimestamp);
  const isUrgent = days !== null && days >= 0 && days <= 3;
  const eligibilityCriteria = parseEligibilityCriteria(job.notEligibleReason);
  const eligibilityTags = getEligibilityTags(job);
  const jdLink = job._links?.jobFormLink?.href;
  const [jdError, setJdError] = useState(false);
  const [jdDownloading, setJdDownloading] = useState(false);
  const [jobView, setJobView] = useState(null);
  const [jobViewLoading, setJobViewLoading] = useState(true);
  const [attachments, setAttachments] = useState([]);
  const [attDownloading, setAttDownloading] = useState({});

  const detail = jobView || {};
  const hiringRounds = detail.hiringWorkflowSet || [];
  const questions = detail.questionBeanSet || [];
  const jobDesc = detail.jobDesc || "";
  const appliedCount = detail.appliedCount ?? job.appliedCount;
  const webSiteLink = detail.webSiteLink || "";
  const genders = typeof detail.genders === "string" ? detail.genders : "";
  const policyCategoryName = detail.policyCategoryName || "";
  const dateOfVisitStatus = detail.dateOfVisitStatus || "";
  const createdBy = detail.createdBy || job.createdBy || "";
  const createdDate = detail.createdDate || job.createdDate || "";
  const lastModifiedBy = detail.lastModifiedBy || job.lastModifiedBy || "";
  const lastModifiedDate = detail.lastModifiedDate || job.lastModifiedDate || "";
  const internshipSeason = detail.internshipSeason || "";
  const expectedOffers = detail.expectedOffers || "";
  const minHires = detail.minHires || "";
  const jobStartDate = detail.jobStartDate || job.jobStartDate;
  const bondDetails = detail.bondDetails || "";
  const bonusIncentives = detail.bonusIncentives || "";
  const facilitiesProvided = detail.facilitiesProvided || "";
  const tenthPercentRequired = detail.tenthPercentRequired;
  const twelfthPercentRequired = detail.twelfthPercentRequired;
  const diplomaPercentRequired = detail.diplomaPercentRequired;
  const ugPercentRequired = detail.ugPercentRequired;
  const ugCgpaRequired = detail.ugCgpaRequired;
  const ugCgpaMax = detail.ugCgpaMax;
  const tenthCgpaRequired = detail.tenthCgpaRequired;
  const twelfthCgpaRequired = detail.twelfthCgpaRequired;
  const diplomaCgpaRequired = detail.diplomaCgpaRequired;
  const interDiplomaValidationType = detail.interDiplomaValidationType || "";
  const jobCriteriaSet = detail.jobCriteriaSet || [];
  const criteriaCgpa = jobCriteriaSet.find(c => c.cgpaRequired)?.cgpaRequired;
  const criteriaCgpaMax = jobCriteriaSet.find(c => c.cgpaMax)?.cgpaMax;
  const criteriaPercentRequired = jobCriteriaSet.find(c => c.percentageRequired)?.percentageRequired;
  const cgpaRequired = criteriaCgpa || ugCgpaRequired || detail.cgpaRequired || job.cgpaRequired;
  const cgpaMax = criteriaCgpaMax || ugCgpaMax;

  useEffect(() => {
    const userEmail = localStorage.getItem("placement_user") ? JSON.parse(localStorage.getItem("placement_user")).username : "";
    setJobViewLoading(true);
    fetch(`/placement-api/jobView/${encodeURIComponent(job.uuid)}`, {
      headers: { "x-user-email": userEmail },
    })
      .then((r) => r.ok ? r.json() : null)
      .then((data) => setJobView(data?.data || null))
      .catch(() => setJobView(null))
      .finally(() => setJobViewLoading(false));

    fetch(`/placement-api/jobAttachments/${encodeURIComponent(job.uuid)}`, {
      headers: { "x-user-email": userEmail },
    })
      .then((r) => r.ok ? r.json() : null)
      .then((data) => {
        const list = Array.isArray(data?.data) ? data.data : data?.data?._embedded?.entityModels || [];
        setAttachments(list);
      })
      .catch(() => setAttachments([]));
  }, [job.uuid]);

  async function downloadFile() {
    if (!job.uuid) return;
    setJdDownloading(true);
    setJdError(false);
    try {
      const userEmail = localStorage.getItem("placement_user") ? JSON.parse(localStorage.getItem("placement_user")).username : "";
      const res = await fetch(`/placement-api/jd?jobUuid=${encodeURIComponent(job.uuid)}`, {
        headers: { "x-user-email": userEmail },
      });
      if (!res.ok) {
        setJdError(true);
        return;
      }
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `JD_${job.companyName}_${job.jobTitle}.pdf`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch {
      setJdError(true);
    } finally {
      setJdDownloading(false);
    }
  }

  async function downloadAttachment(att, idx) {
    if (!att.attachmentUrl) return;
    setAttDownloading(prev => ({ ...prev, [idx]: true }));
    try {
      const userEmail = localStorage.getItem("placement_user") ? JSON.parse(localStorage.getItem("placement_user")).username : "";
      const res = await fetch(`/placement-api/jd?fileUrl=${encodeURIComponent(att.attachmentUrl)}`, {
        headers: { "x-user-email": userEmail },
      });
      if (!res.ok) return;
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = att.name || `attachment_${idx}.pdf`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch {
      // silent
    } finally {
      setAttDownloading(prev => ({ ...prev, [idx]: false }));
    }
  }

  const jobTypeLabels = {
    INTERN_LEADS_TO_FULL_TIME: "Intern Leads to Full Time",
    FULL_TIME: "Full Time",
    REGULAR_INTERN: "Regular Intern",
    INTERN_PLUS_FULL_TIME: "Intern + Full Time",
    SUMMER_INTERN: "Summer Intern",
    CONTRACT_TO_HIRE: "Contract to Hire",
    APPRENTICESHIP: "Apprenticeship",
    COMPETITION: "Competition",
    HACKATHON: "Hackathon",
  };

  const roundStatusMap = (round, idx) => {
    if (round.hiringRoundStatus) return round.hiringRoundStatus.replace(/_/g, " ");
    if (idx === 0) return "Pending";
    return "Upcoming";
  };

  const roundStatusColor = (status) => {
    const s = status.toLowerCase();
    if (s.includes("completed") || s.includes("done")) return "text-green-600 bg-green-50";
    if (s.includes("in progress") || s.includes("ongoing")) return "text-blue-600 bg-blue-50";
    if (s.includes("pending")) return "text-amber-600 bg-amber-50";
    return "text-slate-500 bg-slate-50";
  };

  return (
    <div className="pt-4 pb-12">
      <button onClick={onBack}
        className="inline-flex items-center gap-2 text-slate-500 hover:text-[#1A1A1A] font-semibold text-sm mb-6 cursor-pointer transition-colors">
        <ArrowLeft size={18} /> Back to Jobs
      </button>

      {/* Hero Header */}
      <div className="bg-[#1A1A1A] rounded-[32px] p-8 md:p-10 text-white relative overflow-hidden mb-6">
        <div className="absolute right-0 top-0 w-[40%] h-full opacity-5 pointer-events-none">
          <Building2 size={400} className="object-contain" />
        </div>
        <div className="relative z-10">
          <div className="flex items-start gap-4 mb-4 flex-wrap">
            <div className="w-16 h-16 rounded-2xl bg-white/10 flex items-center justify-center flex-shrink-0 backdrop-blur-sm overflow-hidden">
              {logoMap[job.companyId] ? (
                <img src={logoMap[job.companyId]} alt={job.companyName || ""} className="w-full h-full object-cover" />
              ) : (
                <Building2 size={32} className="text-white/80" />
              )}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <h1 className="text-2xl md:text-3xl font-display font-bold leading-tight">{job.jobTitle || "Untitled"}</h1>
              </div>
              <button className="text-white/60 text-base hover:text-white transition-colors inline-flex items-center gap-1 cursor-pointer">
                {job.companyName || "—"}
                <ExternalLink size={14} className="opacity-60" />
              </button>
            </div>
            <span className={`inline-flex items-center gap-1.5 px-4 py-2 rounded-full text-[13px] font-bold whitespace-nowrap ${status.cls}`}>
              {status.icon}{job.jobStatus || status.text}
            </span>
          </div>

          {/* Job type tags */}
          <div className="flex flex-wrap gap-2 mb-6">
            {policyCategoryName && <TagPill text={policyCategoryName} />}
            <TagPill text={jobTypeLabels[job.jobType] || job.jobType?.replace(/_/g, " ") || ""} />
            {job.source && <TagPill text={job.source} />}
            {genders && genders.split(" ").filter(Boolean).map((g) => <TagPill key={g} text={g.charAt(0) + g.slice(1).toLowerCase()} />)}
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <HeroStat icon={<IndianRupee size={16} />} label="CTC" value={ctc} sub={job.payType?.replace(/_/g, " ")} />
            <HeroStat icon={<MapPin size={16} />} label="Location" value={job.location || "—"} />
            {internCtc && <HeroStat icon={<IndianRupee size={16} />} label="Internship Stipend" value={internCtc} sub={job.stipendType?.replace(/_/g, " ")} />}
            <HeroStat icon={<Calendar size={16} />} label="Apply By" value={isUrgent ? `${days} days left!` : formatDate(job.jobApplyBy)} sub={job.jobApplyByTime || ""} urgent={isUrgent} />
          </div>
        </div>
      </div>

      {/* Not Eligible Warning */}
      {job.isNotEligible && (
        <div className="mb-6">
          <div className="flex items-start gap-3 px-5 py-4 rounded-2xl bg-red-50 border-2 border-red-100">
            <AlertTriangle size={20} className="text-red-500 flex-shrink-0 mt-0.5" />
            <div className="flex-1">
              <p className="text-[14px] font-bold text-red-700 mb-2">Not Eligible</p>
              {eligibilityCriteria.length > 0 ? (
                <div className="space-y-2">
                  {eligibilityCriteria.map((c, i) => (
                    <div key={i} className="flex items-start gap-2">
                      <XCircle size={14} className="text-red-400 flex-shrink-0 mt-0.5" />
                      <div>
                        <span className="text-[13px] font-bold text-red-600">{c.label}: </span>
                        <span className="text-[13px] text-red-600">{c.text}</span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-[13px] text-red-600">{job.notEligibleReason || "You do not meet the eligibility criteria."}</p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Quick Stats Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <QuickStat icon={<Users size={18} />} label="Applicants" value={appliedCount?.toLocaleString("en-IN") || "—"} />
        <QuickStat icon={<Milestone size={18} />} label="Date of Visit" value={formatDate(job.dateOfVisit)} sub={dateOfVisitStatus} />
        <QuickStat icon={<BriefcaseIcon size={18} />} label="Openings" value={job.numOfOpenings?.toString() || "—"} />
        <QuickStat icon={<Layers size={18} />} label="Rounds" value={job.numOfRounds?.toString() || "—"} />
      </div>

      {/* Hiring Process */}
      {hiringRounds.length > 0 && (
        <div className="mb-6 bg-white rounded-[24px] p-6 border border-slate-200/60 shadow-sm">
          <div className="flex items-center gap-2 mb-4">
            <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-slate-500">
              <Milestone size={18} />
            </div>
            <h3 className="font-display font-bold text-lg text-[#1A1A1A]">Hiring Process</h3>
          </div>
          <div className="space-y-0">
            {hiringRounds.map((round, i) => {
              const roundStatus = roundStatusMap(round, i);
              const isLast = i === hiringRounds.length - 1;
              return (
                <div key={round.id || i} className="flex gap-4">
                  <div className="flex flex-col items-center">
                    <div className="w-9 h-9 rounded-full bg-slate-100 flex items-center justify-center text-[13px] font-bold text-slate-600 flex-shrink-0">
                      {round.roundNum || i + 1}
                    </div>
                    {!isLast && <div className="w-0.5 flex-1 bg-slate-200 my-1" style={{ minHeight: "20px" }} />}
                  </div>
                  <div className={`flex-1 ${isLast ? "pb-0" : "pb-4"}`}>
                    <div className="flex items-center justify-between">
                      <p className="text-[14px] font-bold text-slate-800">{round.title}</p>
                      <span className={`px-2.5 py-1 rounded-full text-[11px] font-bold ${roundStatusColor(roundStatus)}`}>
                        {roundStatus}
                      </span>
                    </div>
                    <p className="text-[12px] text-slate-400 mt-0.5">Yet to Start</p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* About the Job (description) */}
      {jobDesc && (
        <div className="mb-6 bg-white rounded-[24px] p-6 border border-slate-200/60 shadow-sm">
          <div className="flex items-center gap-2 mb-4">
            <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-slate-500">
              <FileText size={18} />
            </div>
            <h3 className="font-display font-bold text-lg text-[#1A1A1A]">About the Job</h3>
          </div>
          <div className="prose prose-sm max-w-none text-[14px] text-slate-600 leading-relaxed [&_strong]:text-slate-800 [&_p]:mb-2" dangerouslySetInnerHTML={{ __html: jobDesc }} />
        </div>
      )}

      {/* Two column layout */}
      <div className="grid lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          {/* Compensation */}
          <Card title="Compensation" icon={<IndianRupee size={18} />}>
            <div className="grid grid-cols-2 gap-4">
              <StatBox label="Full-time CTC" value={ctc} highlight={ctc !== "—"} sub={job.payType?.replace(/_/g, " ")} />
              <StatBox label="CTC Type" value={job.ctcType?.replace(/_/g, " ") || "—"} />
              {internCtc && <StatBox label="Internship Stipend" value={internCtc} highlight sub={job.stipendType?.replace(/_/g, " ")} />}
              {job.grossSalary != null && <StatBox label="Gross Salary" value={formatCTC(job.grossSalary, job.grossSalary)} />}
              {job.takeHomeSalary != null && <StatBox label="Take Home" value={formatCTC(job.takeHomeSalary, job.takeHomeSalary)} />}
              {bondDetails && <StatBox label="Bond Details" value={bondDetails} />}
            </div>
          </Card>

          {/* Job & Internship Details */}
          <Card title="Job & Internship Details" icon={<Briefcase size={18} />}>
            <div className="grid grid-cols-2 gap-6">
              <div>
                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wide mb-3">Job</p>
                <div className="space-y-2">
                  <KVRow label="Start Date" value={formatDate(jobStartDate) || "—"} />
                  <KVRow label="Min Hires" value={minHires?.toString() || "—"} />
                  <KVRow label="Expected Offers" value={expectedOffers?.toString() || "—"} />
                  <KVRow label="Work Type" value={job.workType?.replace(/_/g, " ") || "—"} />
                </div>
              </div>
              <div>
                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wide mb-3">Internship</p>
                <div className="space-y-2">
                  <KVRow label="Mode" value={job.modeOfIntern || "—"} />
                  <KVRow label="Start Date" value="—" />
                  <KVRow label="Duration" value={job.duration ? `${job.duration} months` : "—"} />
                  <KVRow label="Season" value={internshipSeason || "—"} />
                </div>
              </div>
            </div>
          </Card>

          {/* Questions */}
          {questions.length > 0 && (
            <Card title="Questions" icon={<HelpCircle size={18} />}>
              <div className="space-y-4">
                {questions.map((q, i) => (
                  <div key={q.id || i} className="rounded-2xl bg-slate-50 p-4">
                    <div className="flex items-start gap-2 mb-2">
                      <span className="text-[11px] font-bold text-slate-400 mt-0.5">Q{q.orderNum || i + 1}</span>
                      <p className="text-[14px] font-semibold text-slate-800 flex-1">{q.title}</p>
                      {q.isMandatory && <span className="text-[10px] font-bold text-red-500">Required</span>}
                    </div>
                    {q.options?.length > 0 && (
                      <div className="flex flex-wrap gap-2 mt-2">
                        {q.options.map((opt, j) => (
                          <span key={j} className="px-3 py-1 rounded-full text-[12px] font-semibold bg-white text-slate-600 border border-slate-200">
                            {opt}
                          </span>
                        ))}
                      </div>
                    )}
                    <p className="text-[11px] text-slate-400 mt-2">{q.questionType?.replace(/_/g, " ").toLowerCase()}</p>
                  </div>
                ))}
              </div>
            </Card>
          )}

          {/* Skills Required */}
          {job.skillsRequired && (
            <Card title="Skills Required" icon={<Code2 size={18} />}>
              <div className="flex flex-wrap gap-2">
                {job.skillsRequired.split(":#*#:").filter(Boolean).map((skill, i) => (
                  <span key={i} className="px-3 py-1.5 rounded-full text-[12px] font-semibold bg-lavender text-slate-700">
                    {skill.trim()}
                  </span>
                ))}
              </div>
            </Card>
          )}

          {/* Incentives & Perks */}
          {(job.incentives || bonusIncentives || facilitiesProvided) && (
            <Card title="Incentives & Perks" icon={<Sparkles size={18} />}>
              <div className="space-y-2">
                {job.incentives && <p className="text-[14px] text-slate-600 leading-relaxed">{job.incentives}</p>}
                {bonusIncentives && <p className="text-[14px] text-slate-600 leading-relaxed">{bonusIncentives}</p>}
                {facilitiesProvided && <p className="text-[14px] text-slate-600 leading-relaxed">{facilitiesProvided}</p>}
              </div>
            </Card>
          )}

          {/* Timeline */}
          <Card title="Timeline" icon={<Calendar size={18} />}>
            <div className="space-y-3">
              <TimelineItem label="Posted" value={formatDate(job.jobPostedDate)} />
              <TimelineItem label="Apply By" value={formatDate(job.jobApplyBy)} urgent={isUrgent} />
              <TimelineItem label="Date of Visit" value={formatDate(job.dateOfVisit)} />
              {job.jobClosedOn && <TimelineItem label="Closed On" value={formatDate(job.jobClosedOn)} />}
              <TimelineItem label="Hiring Start Date" value={formatDate(job.hiringStartDate)} />
              <TimelineItem label="Job Start Date" value={formatDate(jobStartDate)} />
            </div>
          </Card>
        </div>

        <div className="space-y-6">
          {/* Attachments */}
          {(attachments.length > 0 || jdLink) && (
            <div className="bg-white rounded-[24px] p-5 border border-slate-200/60 shadow-sm">
              <h3 className="text-[13px] font-bold text-slate-400 uppercase tracking-wide mb-3">Attachments</h3>
              <div className="space-y-2">
                {attachments.map((att, idx) => (
                  <button
                    key={att.id || idx}
                    onClick={() => downloadAttachment(att, idx)}
                    disabled={attDownloading[idx]}
                    className="flex items-center gap-3 px-4 py-3 rounded-2xl bg-slate-50 hover:bg-slate-100 transition-colors group w-full text-left cursor-pointer disabled:opacity-50"
                  >
                    <Paperclip size={18} className="text-slate-400 flex-shrink-0" />
                    <span className="flex-1 text-sm font-semibold text-slate-700 truncate">{att.name || `Attachment ${idx + 1}`}</span>
                    <span className="inline-flex items-center gap-1 text-xs font-bold text-slate-500 group-hover:text-slate-700">
                      {attDownloading[idx] ? "Downloading…" : "Download"} {!attDownloading[idx] && <Download size={14} />}
                    </span>
                  </button>
                ))}
                {attachments.length === 0 && jdLink && (
                  <>
                    {jdError ? (
                      <div className="flex items-center gap-3 px-4 py-3 rounded-2xl bg-red-50 text-red-500">
                        <FileText size={18} className="flex-shrink-0" />
                        <span className="text-sm font-semibold">File not available for this job</span>
                      </div>
                    ) : (
                      <button
                        onClick={downloadFile}
                        disabled={jdDownloading}
                        className="flex items-center gap-3 px-4 py-3 rounded-2xl bg-slate-50 hover:bg-slate-100 transition-colors group w-full text-left cursor-pointer disabled:opacity-50"
                      >
                        <Paperclip size={18} className="text-slate-400 flex-shrink-0" />
                        <span className="flex-1 text-sm font-semibold text-slate-700 truncate">Job Description</span>
                        <span className="inline-flex items-center gap-1 text-xs font-bold text-slate-500 group-hover:text-slate-700">
                          {jdDownloading ? "Downloading…" : "Download"} {!jdDownloading && <Download size={14} />}
                        </span>
                      </button>
                    )}
                  </>
                )}
              </div>
            </div>
          )}

          {/* About Company */}
          <Card title={`About ${job.companyName || "Company"}`} icon={<Building2 size={18} />}>
            <div className="space-y-3">
              {logoMap[job.companyId] && (
                <div className="flex items-center gap-3 pb-3 border-b border-slate-100">
                  <div className="w-12 h-12 rounded-xl bg-slate-100 flex items-center justify-center overflow-hidden flex-shrink-0">
                    <img src={logoMap[job.companyId]} alt={job.companyName || ""} className="w-full h-full object-cover" />
                  </div>
                  <span className="font-bold text-[15px] text-slate-800">{job.companyName}</span>
                </div>
              )}
              {webSiteLink && (
                <a href={webSiteLink} target="_blank" rel="noopener noreferrer"
                  className="flex items-center gap-2 text-[14px] font-semibold text-blue-600 hover:text-blue-700 cursor-pointer">
                  <Globe size={16} className="flex-shrink-0" />
                  {webSiteLink.replace(/^https?:\/\//, "").replace(/\/$/, "")}
                  <ExternalLink size={12} className="opacity-60" />
                </a>
              )}
              <KVRow label="Source" value={job.source || "—"} />
              <KVRow label="Mode of Visit" value={job.modeOfVisit?.replace(/_/g, " ") || "—"} />
              <KVRow label="College Approval" value={job.collegeApprovalFlag ? "Approved" : "Pending"} />
            </div>
          </Card>

          {/* Application Status */}
          <Card title="Application Status" icon={<TrendingUp size={18} />}>
            <div className="space-y-3">
              <StatusRow label="Applied" value={job.isApplied} />
              <StatusRow label="Eligible" value={job.isEligible} />
              <StatusRow label="Offered" value={job.isOffered} />
              <StatusRow label="Rejected" value={job.isRejected} />
              {job.currentRound && (
                <div className="pt-3 border-t border-slate-100">
                  <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wide mb-1">Current Round</p>
                  <p className="text-[14px] font-semibold text-slate-700">{job.currentRound}</p>
                  {job.currentRoundStatus && (
                    <p className="text-[12px] text-slate-500 mt-0.5">{job.currentRoundStatus.replace(/_/g, " ")}</p>
                  )}
                </div>
              )}
            </div>
          </Card>

          {/* Eligibility Criteria */}
          <Card title="Eligibility Criteria" icon={<GraduationCap size={18} />}>
            <div className="space-y-3">
              {cgpaRequired && <KVRow label="CGPA Required" value={cgpaMax ? `${cgpaRequired} – ${cgpaMax}` : `${cgpaRequired} CGPA`} />}
              {criteriaPercentRequired && <KVRow label="Percentage Required" value={`${criteriaPercentRequired}%`} />}
              {interDiplomaValidationType && (tenthPercentRequired || twelfthPercentRequired) && (
                <KVRow label="10th / 12th" value={`${tenthPercentRequired || "—"}% / ${twelfthPercentRequired || "—"}% (${interDiplomaValidationType.toLowerCase()})`} />
              )}
              {tenthCgpaRequired && <KVRow label="10th CGPA" value={tenthCgpaRequired.toString()} />}
              {twelfthCgpaRequired && <KVRow label="12th CGPA" value={twelfthCgpaRequired.toString()} />}
              {diplomaPercentRequired && <KVRow label="Diploma %" value={`${diplomaPercentRequired}%`} />}
              {diplomaCgpaRequired && <KVRow label="Diploma CGPA" value={diplomaCgpaRequired.toString()} />}
              {ugPercentRequired && <KVRow label="UG %" value={`${ugPercentRequired}%`} />}
              {ugCgpaRequired && <KVRow label="UG CGPA" value={ugCgpaMax ? `${ugCgpaRequired} – ${ugCgpaMax}` : ugCgpaRequired.toString()} />}
              {!cgpaRequired && !criteriaPercentRequired && !ugCgpaRequired && !ugPercentRequired && <KVRow label="CGPA / %" value="Not specified" />}
              <KVRow label="Genders" value={genders ? genders.split(" ").filter(Boolean).map(g => g.charAt(0) + g.slice(1).toLowerCase()).join(" & ") : "All"} />
              <KVRow label="Arrears Allowed" value={detail.arrears?.toString() || "Not specified"} />
            </div>
            {eligibilityTags.length > 0 && (
              <div className="flex flex-wrap gap-2 mt-4">
                {eligibilityTags.map((tag, i) => (
                  <span key={i} className={`px-3 py-1.5 rounded-full text-[12px] font-semibold ${
                    tag.type === "requirement" ? "bg-amber-100 text-amber-800" : "bg-lavender text-slate-700"
                  }`}>
                    {tag.label}
                  </span>
                ))}
              </div>
            )}
          </Card>

          {/* Created / Modified */}
          {(createdBy || lastModifiedBy) && (
            <Card title="Activity" icon={<Clock size={18} />}>
              <div className="space-y-3">
                {createdBy && <KVRow label="Created By" value={createdBy} />}
                {createdDate && <KVRow label="Created On" value={formatDate(createdDate)} />}
                {lastModifiedBy && <KVRow label="Modified By" value={lastModifiedBy} />}
                {lastModifiedDate && <KVRow label="Modified On" value={formatDate(lastModifiedDate)} />}
              </div>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

/* ─── UI Primitives ─── */

function HeroStat({ icon, label, value, sub, urgent }) {
  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center gap-1.5 text-white/50">
        {icon}
        <span className="text-[11px] font-bold uppercase tracking-wide">{label}</span>
      </div>
      <span className={`text-[15px] font-bold ${urgent ? "text-red-400" : "text-white"}`}>{value}</span>
      {sub && <span className="text-[10px] text-white/40 font-medium capitalize">{sub}</span>}
    </div>
  );
}

function TagPill({ text }) {
  return (
    <span className="px-3 py-1 rounded-full text-[11px] font-bold text-white/80 bg-white/10 backdrop-blur-sm">
      {text}
    </span>
  );
}

function QuickStat({ icon, label, value, sub }) {
  return (
    <div className="bg-white rounded-[20px] p-4 border border-slate-200/60 shadow-sm">
      <div className="flex items-center gap-2 text-slate-400 mb-2">
        {icon}
        <span className="text-[11px] font-bold uppercase tracking-wide">{label}</span>
      </div>
      <p className="text-[18px] font-bold text-slate-800">{value}</p>
      {sub && <p className="text-[10px] text-slate-400 font-medium capitalize mt-0.5">{sub}</p>}
    </div>
  );
}

function Card({ title, icon, children }) {
  return (
    <div className="bg-white rounded-[24px] p-6 border border-slate-200/60 shadow-sm">
      <div className="flex items-center gap-2 mb-4">
        <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-slate-500">
          {icon}
        </div>
        <h3 className="font-display font-bold text-lg text-[#1A1A1A]">{title}</h3>
      </div>
      {children}
    </div>
  );
}

function StatBox({ label, value, highlight, sub }) {
  return (
    <div className={`rounded-2xl p-4 ${highlight ? "bg-mint" : "bg-slate-50"}`}>
      <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wide mb-1">{label}</p>
      <p className={`text-[16px] font-bold ${highlight ? "text-green-800" : "text-slate-700"}`}>{value}</p>
      {sub && <p className="text-[10px] text-slate-400 font-medium capitalize mt-0.5">{sub}</p>}
    </div>
  );
}

function TimelineItem({ label, value, urgent }) {
  return (
    <div className="flex items-center justify-between py-1">
      <span className="text-[13px] text-slate-500 font-medium">{label}</span>
      <span className={`text-[13px] font-bold ${urgent ? "text-red-500" : "text-slate-700"}`}>{value}</span>
    </div>
  );
}

function KVRow({ label, value }) {
  return (
    <div className="flex items-center justify-between py-1">
      <span className="text-[12px] text-slate-500 font-medium">{label}</span>
      <span className="text-[13px] font-semibold text-slate-700 text-right">{value}</span>
    </div>
  );
}

function StatusRow({ label, value }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-[13px] text-slate-500 font-medium">{label}</span>
      {value ? (
        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold bg-green-100 text-green-700">
          <CheckCircle2 size={11} /> Yes
        </span>
      ) : (
        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-400">
          <XCircle size={11} /> No
        </span>
      )}
    </div>
  );
}
