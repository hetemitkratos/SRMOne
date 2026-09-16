import {
  Briefcase, RefreshCw, Search, MapPin, IndianRupee, Clock, Building2,
  CheckCircle2, XCircle, AlertTriangle, Calendar, Users, FileText,
  ArrowLeft, GraduationCap, Layers, Globe, Sparkles, TrendingUp,
  Paperclip, Download, ExternalLink, HelpCircle, Milestone,
  Briefcase as BriefcaseIcon, Code2, Bookmark, BookmarkCheck, StickyNote,
  Send, Loader2, X,
} from "lucide-react";
import { useState, useMemo, useEffect } from "react";
import { createPortal } from "react-dom";
import { usePlacementData } from "../hooks/usePlacementData.js";
import { placementApi } from "../api/placementClient.js";
import { useAuth } from "../hooks/useAuth.jsx";
import { api } from "../api/client.js";
import Loading from "../components/Loading.jsx";
import ErrorBox from "../components/ErrorBox.jsx";

export default function Jobs() {
  const { data, loading, error, refetch } = usePlacementData("jobs");
  const { placementUser, user } = useAuth();
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("all");
  const [selectedJob, setSelectedJob] = useState(null);
  const [logoMap, setLogoMap] = useState({});
  const [bookmarks, setBookmarks] = useState([]);

  /** Normalize job identifiers so uuid/id and string/number always compare equal. */
  const jobIds = (job) => {
    if (!job) return [];
    const ids = [];
    if (job.uuid != null && String(job.uuid).trim() !== "") ids.push(String(job.uuid));
    if (job.id != null && String(job.id).trim() !== "") ids.push(String(job.id));
    return [...new Set(ids)];
  };

  const primaryJobId = (job) => jobIds(job)[0] || "";

  const isJobBookmarked = (job) => {
    const ids = jobIds(job);
    if (!ids.length) return false;
    return bookmarks.some((b) => ids.includes(String(b.job_uuid)));
  };

  const bookmarksForJob = (job) => {
    const ids = new Set(jobIds(job));
    return bookmarks.filter((b) => {
      if (ids.has(String(b.job_uuid))) return true;
      // Fallback: match against snapshot stored at bookmark time
      const snapIds = jobIds(b.job_data);
      return snapIds.some((id) => ids.has(id));
    });
  };

  const syncBookmarksFromApi = (list) => {
    setBookmarks(Array.isArray(list) ? list : []);
  };

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

  useEffect(() => {
    if (!user?.email) return;
    api.getBookmarks(user.email)
      .then((res) => syncBookmarksFromApi(res.data))
      .catch(() => {});
  }, [user?.email]);

  const toggleBookmark = async (job) => {
    if (!user?.email) return;
    const jobUuid = primaryJobId(job);
    if (!jobUuid) {
      console.error("Job has no UUID:", job);
      return;
    }

    const existing = bookmarksForJob(job);
    const currentlyBookmarked = existing.length > 0;

    try {
      if (currentlyBookmarked) {
        for (const row of existing) {
          await api.removeBookmark(user.email, String(row.job_uuid));
        }
        const removeKeys = new Set(existing.map((b) => String(b.job_uuid)));
        setBookmarks((prev) => prev.filter((b) => !removeKeys.has(String(b.job_uuid))));
      } else {
        await api.addBookmark(user.email, {
          jobUuid,
          jobTitle: job.jobTitle,
          companyName: job.companyName,
          jobData: job,
          notes: "",
        });
        setBookmarks((prev) => [...prev, { job_uuid: jobUuid, job_data: job, notes: "" }]);
      }
    } catch (err) {
      console.error("Bookmark toggle failed:", err);
      api.getBookmarks(user.email)
        .then((res) => syncBookmarksFromApi(res.data))
        .catch(() => {});
    }
  };

  const saveBookmarkNotes = async (job, notes) => {
    if (!user?.email) return;
    const rows = bookmarksForJob(job);
    const key = rows[0] ? String(rows[0].job_uuid) : primaryJobId(job);
    try {
      await api.updateBookmark(user.email, key, { notes });
      setBookmarks((prev) =>
        prev.map((b) => (String(b.job_uuid) === key ? { ...b, notes } : b))
      );
    } catch (err) {
      console.error("Save notes failed:", err);
      throw err;
    }
  };

  const jobs = useMemo(() => {
    const list = data?._embedded?.entityModels || [];
    let filtered = list;
    if (filter === "eligible") filtered = list.filter((j) => j.isEligible);
    else if (filter === "applied") filtered = list.filter((j) => j.isApplied);
    else if (filter === "offered") filtered = list.filter((j) => j.isOffered);
    else if (filter === "notEligible") filtered = list.filter((j) => j.isNotEligible);
    else if (filter === "bookmarked") {
      // Only jobs that actually have a bookmark row (by uuid/id or snapshot)
      filtered = list.filter((j) => {
        const ids = jobIds(j);
        return bookmarks.some((b) => {
          if (ids.includes(String(b.job_uuid))) return true;
          return jobIds(b.job_data).some((id) => ids.includes(id));
        });
      });
    }

    if (search) {
      filtered = filtered.filter((j) =>
        j.jobTitle?.toLowerCase().includes(search.toLowerCase()) ||
        j.companyName?.toLowerCase().includes(search.toLowerCase()) ||
        j.jobTag?.toLowerCase().includes(search.toLowerCase())
      );
    }

    return filtered.sort((a, b) => {
      const getDate = (job) => {
        const candidates = [
          job.jobPostedDate,
          job.createdDate,
          job.lastModifiedDate,
          job.jobApplyBy,
        ];
        for (const d of candidates) {
          if (d) {
            const parsed = new Date(d);
            if (!isNaN(parsed.getTime())) return parsed;
          }
        }
        return new Date(0);
      };

      return getDate(b) - getDate(a);
    });
  }, [data, search, filter, bookmarks]);

  if (loading) return <Loading label="Fetching jobs…" />;
  if (error) return <ErrorBox message={error} onRetry={refetch} />;

  if (selectedJob) {
    return (
      <JobDetailPage
        job={selectedJob}
        onBack={() => setSelectedJob(null)}
        logoMap={logoMap}
        isBookmarked={isJobBookmarked(selectedJob)}
        bookmarkNotes={bookmarksForJob(selectedJob)[0]?.notes || ""}
        onSaveNotes={(notes) => saveBookmarkNotes(selectedJob, notes)}
        onToggleBookmark={() => toggleBookmark(selectedJob)}
      />
    );
  }

  const allJobs = data?._embedded?.entityModels || [];
  const counts = {
    all: allJobs.length,
    eligible: allJobs.filter((j) => j.isEligible).length,
    applied: allJobs.filter((j) => j.isApplied).length,
    offered: allJobs.filter((j) => j.isOffered).length,
    notEligible: allJobs.filter((j) => j.isNotEligible).length,
    bookmarked: bookmarks.length,
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
          { key: "bookmarked", label: "Bookmarked", count: counts.bookmarked },
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
          <JobCard 
            key={job.id || i} 
            job={job} 
            index={i} 
            logoUrl={logoMap[job.companyId]} 
            onClick={() => setSelectedJob(job)}
            isBookmarked={filter === "bookmarked" || isJobBookmarked(job)}
            onToggleBookmark={(e) => {
              e.stopPropagation();
              toggleBookmark(job);
            }}
          />
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

function JobCard({ job, index = 0, logoUrl, onClick, isBookmarked, onToggleBookmark }) {
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
    <div
      role="button"
      tabIndex={0}
      onClick={onClick}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onClick?.(e);
        }
      }}
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
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onToggleBookmark?.(e);
            }}
            className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition-colors"
            title={isBookmarked ? "Remove bookmark" : "Bookmark job"}
            aria-label={isBookmarked ? "Remove bookmark" : "Bookmark job"}
          >
            {isBookmarked ? (
              <BookmarkCheck size={16} className="text-mint" />
            ) : (
              <Bookmark size={16} className="text-white/60" />
            )}
          </button>
          <span className={`text-[12px] font-semibold ${isUrgent ? "text-[#D97757]" : "text-white/45"}`}>
            {isUrgent ? `${days}d left` : applyBy}
          </span>
        </div>
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
    </div>
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

function JobDetailPage({ job, onBack, logoMap = {}, isBookmarked = false, bookmarkNotes = "", onSaveNotes, onToggleBookmark }) {
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
  const [showApplyModal, setShowApplyModal] = useState(false);

  const detail = jobView || {};
  const hiringRounds = detail.hiringWorkflowSet || [];
  const questions = detail.questionBeanSet || [];
  const jobDesc = detail.jobDesc || "";
  const displayApplyButton = detail.displayApplyButton || false;
  const externalLink = detail.externalLink || "";
  const isStudentResumeUpload = detail.isStudentResumeUpload || false;
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
          <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4 mb-4">
            <div className="flex items-start gap-3 sm:gap-4">
              <div className="w-14 h-14 sm:w-16 sm:h-16 rounded-2xl bg-white/10 flex items-center justify-center flex-shrink-0 backdrop-blur-sm overflow-hidden">
                {logoMap[job.companyId] ? (
                  <img src={logoMap[job.companyId]} alt={job.companyName || ""} className="w-full h-full object-cover" />
                ) : (
                  <Building2 size={32} className="text-white/80" />
                )}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <h1 className="text-xl sm:text-2xl md:text-3xl font-display font-bold leading-tight break-words">{job.jobTitle || "Untitled"}</h1>
                </div>
                <button className="text-white/60 text-sm sm:text-base hover:text-white transition-colors flex items-center gap-1 cursor-pointer text-left break-words">
                  {job.companyName || "—"}
                  <ExternalLink size={14} className="opacity-60 flex-shrink-0" />
                </button>
              </div>
            </div>
            <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 sm:px-4 sm:py-2 rounded-full text-[12px] sm:text-[13px] font-bold whitespace-nowrap w-fit ${status.cls}`}>
              {status.icon}{job.jobStatus || status.text}
            </span>
          </div>
          <div className="flex flex-wrap items-center gap-2 mb-2">
            {onToggleBookmark && (
              <button
                type="button"
                onClick={onToggleBookmark}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12px] font-bold bg-white/10 hover:bg-white/20 border border-white/10 transition-colors cursor-pointer"
              >
                {isBookmarked ? (
                  <>
                    <BookmarkCheck size={14} className="text-mint" />
                    Bookmarked — tap to remove
                  </>
                ) : (
                  <>
                    <Bookmark size={14} className="text-white/70" />
                    Bookmark
                  </>
                )}
              </button>
            )}
            {displayApplyButton && !job.isApplied && !jobViewLoading && (
              externalLink ? (
                <a
                  href={externalLink}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full text-[12px] font-bold bg-green-500 hover:bg-green-600 text-white transition-colors cursor-pointer"
                >
                  <ExternalLink size={14} />
                  Apply on External Portal
                </a>
              ) : (
                <button
                  type="button"
                  onClick={() => setShowApplyModal(true)}
                  className="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full text-[12px] font-bold bg-green-500 hover:bg-green-600 text-white transition-colors cursor-pointer"
                >
                  <Send size={14} />
                  Apply Now
                </button>
              )
            )}
            {job.isApplied && (
              <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12px] font-bold bg-blue-500/20 text-blue-300 border border-blue-500/30">
                <CheckCircle2 size={14} />
                Applied
              </span>
            )}
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
          <div className="w-full overflow-x-auto">
            <div
              className="prose prose-sm md:prose-base max-w-none break-words text-[14px] md:text-[15px] text-slate-700 leading-relaxed
                [&_a]:text-blue-600 [&_a]:underline [&_a]:decoration-blue-300 [&_a]:underline-offset-2 [&_a]:font-medium [&_a]:break-all hover:[&_a]:text-blue-800 hover:[&_a]:decoration-blue-600 transition-colors
                [&_p]:mb-5 [&_p]:leading-[1.7]
                [&_h1]:text-2xl [&_h1]:font-display [&_h1]:font-bold [&_h1]:text-slate-900 [&_h1]:mt-8 [&_h1]:mb-4 [&_h1]:tracking-tight
                [&_h2]:text-xl [&_h2]:font-display [&_h2]:font-bold [&_h2]:text-slate-900 [&_h2]:mt-8 [&_h2]:mb-4 [&_h2]:tracking-tight
                [&_h3]:text-lg [&_h3]:font-display [&_h3]:font-bold [&_h3]:text-slate-800 [&_h3]:mt-6 [&_h3]:mb-3
                [&_h4]:text-base [&_h4]:font-bold [&_h4]:text-slate-800 [&_h4]:mt-5 [&_h4]:mb-2
                [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:mb-5 [&_ul]:space-y-2
                [&_ol]:list-decimal [&_ol]:pl-5 [&_ol]:mb-5 [&_ol]:space-y-2
                [&_li]:text-slate-700 [&_li]:leading-[1.7] [&_li]:pl-1
                [&_strong]:text-slate-900 [&_strong]:font-semibold
                [&_em]:italic [&_em]:text-slate-600
                [&_blockquote]:border-l-[3px] [&_blockquote]:border-slate-300 [&_blockquote]:bg-slate-50 [&_blockquote]:px-5 [&_blockquote]:py-3 [&_blockquote]:rounded-r-xl [&_blockquote]:italic [&_blockquote]:text-slate-600 [&_blockquote]:my-6
                [&_code]:bg-slate-100 [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:rounded-md [&_code]:text-[13px] [&_code]:font-mono [&_code]:text-pink-600 [&_code]:border [&_code]:border-slate-200
                [&_pre]:bg-[#1A1A1A] [&_pre]:text-slate-100 [&_pre]:p-5 [&_pre]:rounded-2xl [&_pre]:overflow-x-auto [&_pre]:my-6 [&_pre]:shadow-lg
                [&_img]:rounded-2xl [&_img]:shadow-md [&_img]:max-w-full [&_img]:h-auto [&_img]:my-6 [&_img]:border [&_img]:border-slate-200/60
                [&_hr]:border-slate-100 [&_hr]:my-8"
              dangerouslySetInnerHTML={{ __html: jobDesc }}
            />
          </div>
        </div>
      )}

      {/* Two column layout */}
      <div className="grid lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          {/* Compensation */}
          <Card title="Compensation" icon={<IndianRupee size={18} />}>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
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
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
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
                      <span className="text-[11px] font-bold text-slate-400 mt-0.5 flex-shrink-0">Q{q.orderNum || i + 1}</span>
                      <p className="text-[14px] font-semibold text-slate-800 flex-1 min-w-0 break-words">{q.title}</p>
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
                    className="flex items-center gap-3 px-4 py-3 rounded-2xl bg-slate-50 hover:bg-slate-100 transition-colors group w-full text-left cursor-pointer disabled:opacity-50 min-w-0"
                  >
                    <Paperclip size={18} className="text-slate-400 flex-shrink-0" />
                    <span className="flex-1 min-w-0 text-sm font-semibold text-slate-700 break-words">{att.name || `Attachment ${idx + 1}`}</span>
                    <span className="inline-flex items-center gap-1 text-xs font-bold text-slate-500 group-hover:text-slate-700 flex-shrink-0">
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
                        className="flex items-center gap-3 px-4 py-3 rounded-2xl bg-slate-50 hover:bg-slate-100 transition-colors group w-full text-left cursor-pointer disabled:opacity-50 min-w-0"
                      >
                        <Paperclip size={18} className="text-slate-400 flex-shrink-0" />
                        <span className="flex-1 min-w-0 text-sm font-semibold text-slate-700 break-words">Job Description</span>
                        <span className="inline-flex items-center gap-1 text-xs font-bold text-slate-500 group-hover:text-slate-700 flex-shrink-0">
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

          {/* My Notes (only for bookmarked jobs) */}
          {isBookmarked && (
            <NotesCard
              initialNotes={bookmarkNotes}
              onSave={onSaveNotes}
            />
          )}

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

      {showApplyModal && (
        <ApplyModal
          job={job}
          questions={questions}
          isStudentResumeUpload={isStudentResumeUpload}
          onClose={() => setShowApplyModal(false)}
          onApplied={() => {
            setShowApplyModal(false);
            setJobView(prev => prev ? { ...prev, displayApplyButton: false } : prev);
          }}
        />
      )}
    </div>
  );
}

/* ─── UI Primitives ─── */

function ApplyModal({ job, questions, isStudentResumeUpload, onClose, onApplied }) {
  const [resumes, setResumes] = useState([]);
  const [resumesLoading, setResumesLoading] = useState(true);
  const [resumesError, setResumesError] = useState(null);
  const [selectedResume, setSelectedResume] = useState("");
  const [answers, setAnswers] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState(null);
  const [success, setSuccess] = useState(false);

  const placementUser = JSON.parse(localStorage.getItem("placement_user") || "{}");
  const username = placementUser.username || "";

  // Lock background scroll while the modal is open
  useEffect(() => {
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = ""; };
  }, []);

  useEffect(() => {
    if (!isStudentResumeUpload) {
      setResumesLoading(false);
      return;
    }
    placementApi.getResumes(username)
      .then((res) => {
        const list = Array.isArray(res.data) ? res.data : res.data?._embedded?.entityModels || [];
        setResumes(list);
        if (list.length > 0) setSelectedResume(list[0].documentLink || list[0].uuid || "");
      })
      .catch((err) => setResumesError(err.message))
      .finally(() => setResumesLoading(false));
  }, [username, isStudentResumeUpload]);

  const mandatoryQuestions = questions.filter(q => q.isMandatory);
  const allMandatoryAnswered = mandatoryQuestions.every(q => answers[q.id]);

  function handleAnswer(qId, option) {
    setAnswers(prev => ({ ...prev, [qId]: option }));
  }

  async function handleSubmit() {
    if (!allMandatoryAnswered) return;
    if (isStudentResumeUpload && !selectedResume) return;

    setSubmitting(true);
    setSubmitError(null);

    try {
      const answerBeans = questions.map(q => ({
        questionId: q.id,
        responseOptions: answers[q.id] ? [answers[q.id]] : [],
      }));

      await placementApi.applyForJob(
        username,
        job.uuid,
        job.id,
        answerBeans,
        isStudentResumeUpload ? selectedResume : "",
      );

      setSuccess(true);
      setTimeout(() => onApplied(), 1500);
    } catch (err) {
      setSubmitError(err.message || "Application failed. Please try again.");
    } finally {
      setSubmitting(false);
    }
  }

  if (success) {
    return createPortal(
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
        <div className="bg-white rounded-[28px] p-8 max-w-md w-full text-center shadow-2xl">
          <div className="w-16 h-16 rounded-full bg-mint flex items-center justify-center mx-auto mb-4">
            <CheckCircle2 size={32} className="text-green-800" />
          </div>
          <h3 className="font-display font-bold text-xl text-[#1A1A1A] mb-2">Application Submitted!</h3>
          <p className="text-sm text-slate-500">Your application for {job.jobTitle} at {job.companyName} has been submitted successfully.</p>
        </div>
      </div>,
      document.body
    );
  }

  return createPortal(
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4" onClick={onClose}>
      <div
        className="bg-white rounded-[28px] max-w-lg w-full max-h-[85vh] overflow-y-auto shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="sticky top-0 bg-white border-b border-slate-100 px-6 py-4 flex items-center justify-between rounded-t-[28px]">
          <div>
            <h3 className="font-display font-bold text-lg text-[#1A1A1A]">Apply for Job</h3>
            <p className="text-[13px] text-slate-500 mt-0.5">{job.jobTitle} — {job.companyName}</p>
          </div>
          <button onClick={onClose} className="w-9 h-9 rounded-full bg-slate-100 hover:bg-slate-200 flex items-center justify-center text-slate-500 cursor-pointer transition-colors">
            <X size={18} />
          </button>
        </div>

        {/* Body */}
        <div className="px-6 py-5 space-y-5">
          {/* Resume Selection */}
          {isStudentResumeUpload && (
            <div>
              <label className="text-[13px] font-bold text-slate-700 mb-2 block">Select Resume</label>
              {resumesLoading ? (
                <div className="flex items-center gap-2 text-sm text-slate-400">
                  <Loader2 size={16} className="animate-spin" /> Loading resumes…
                </div>
              ) : resumesError ? (
                <p className="text-sm text-red-500">{resumesError}</p>
              ) : resumes.length === 0 ? (
                <p className="text-sm text-slate-400">No resumes found. Please upload a resume on the Haveloc portal first.</p>
              ) : (
                <div className="space-y-2">
                  {resumes.map((r, i) => {
                    const value = r.documentLink || r.uuid || "";
                    const label = r.title || r.documentName || `Resume ${i + 1}`;
                    return (
                      <label
                        key={r.uuid || i}
                        className={`flex items-center gap-3 px-4 py-3 rounded-2xl border-2 cursor-pointer transition-colors ${
                          selectedResume === value
                            ? "border-green-500 bg-green-50"
                            : "border-slate-200 hover:border-slate-300"
                        }`}
                      >
                        <input
                          type="radio"
                          name="resume"
                          value={value}
                          checked={selectedResume === value}
                          onChange={(e) => setSelectedResume(e.target.value)}
                          className="accent-green-600"
                        />
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-semibold text-slate-700 truncate">{label}</p>
                          {r.lastModifiedDate && (
                            <p className="text-[11px] text-slate-400">Updated {formatDate(r.lastModifiedDate)}</p>
                          )}
                        </div>
                      </label>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* Questions */}
          {questions.length > 0 && (
            <div>
              <label className="text-[13px] font-bold text-slate-700 mb-2 block">Application Questions</label>
              <div className="space-y-4">
                {questions.map((q, i) => (
                  <div key={q.id || i} className="rounded-2xl bg-slate-50 p-4">
                    <div className="flex items-start gap-2 mb-3">
                      <span className="text-[11px] font-bold text-slate-400 mt-0.5 flex-shrink-0">Q{i + 1}</span>
                      <p className="text-[14px] font-semibold text-slate-800 flex-1 min-w-0 break-words">{q.title}</p>
                      {q.isMandatory && <span className="text-[10px] font-bold text-red-500 flex-shrink-0">Required</span>}
                    </div>
                    {q.options?.length > 0 && (
                      <div className="flex flex-wrap gap-2">
                        {q.options.map((opt, j) => (
                          <button
                            key={j}
                            type="button"
                            onClick={() => handleAnswer(q.id, opt)}
                            className={`px-3 py-1.5 rounded-full text-[12px] font-semibold capitalize border-2 cursor-pointer transition-colors ${
                              answers[q.id] === opt
                                ? "border-green-500 bg-green-500 text-white"
                                : "border-slate-200 bg-white text-slate-600 hover:border-slate-300"
                            }`}
                          >
                            {opt}
                          </button>
                        ))}
                      </div>
                    )}
                    {(!q.options || q.options.length === 0) && (
                      <input
                        type="text"
                        value={answers[q.id] || ""}
                        onChange={(e) => handleAnswer(q.id, e.target.value)}
                        placeholder="Enter your answer…"
                        className="w-full px-3 py-2 rounded-xl text-sm border border-slate-200 bg-white outline-none focus:border-[#1A1A1A] focus:ring-1 focus:ring-[#1A1A1A] transition-all"
                      />
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Error */}
          {submitError && (
            <div className="flex items-start gap-2 px-4 py-3 rounded-2xl bg-red-50 border border-red-100">
              <AlertTriangle size={18} className="text-red-500 flex-shrink-0 mt-0.5" />
              <p className="text-sm text-red-600 font-medium">{submitError}</p>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="sticky bottom-0 bg-white border-t border-slate-100 px-6 py-4 flex items-center justify-between rounded-b-[28px]">
          <button
            onClick={onClose}
            disabled={submitting}
            className="px-4 py-2 rounded-full text-[13px] font-bold text-slate-600 hover:text-[#1A1A1A] cursor-pointer transition-colors disabled:opacity-40"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={submitting || !allMandatoryAnswered || (isStudentResumeUpload && !selectedResume)}
            className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full text-[13px] font-bold text-white bg-green-500 hover:bg-green-600 cursor-pointer transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {submitting ? (
              <>
                <Loader2 size={15} className="animate-spin" />
                Submitting…
              </>
            ) : (
              <>
                <Send size={15} />
                Submit Application
              </>
            )}
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
}

function NotesCard({ initialNotes = "", onSave }) {
  const [notes, setNotes] = useState(initialNotes);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(false);
  const [savedFlash, setSavedFlash] = useState(false);

  // Sync if the prop changes externally (e.g. after refetch)
  useEffect(() => {
    if (!editing) setNotes(initialNotes);
  }, [initialNotes, editing]);

  const dirty = notes !== initialNotes;

  const handleSave = async () => {
    setSaving(true);
    setError(false);
    try {
      await onSave(notes);
      setEditing(false);
      setSavedFlash(true);
      setTimeout(() => setSavedFlash(false), 2000);
    } catch {
      setError(true);
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    setNotes(initialNotes);
    setEditing(false);
    setError(false);
  };

  return (
    <div className="bg-white rounded-[24px] p-5 border border-slate-200/60 shadow-sm">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-amber-50 flex items-center justify-center text-amber-500">
            <StickyNote size={18} />
          </div>
          <h3 className="font-display font-bold text-lg text-[#1A1A1A]">My Notes</h3>
        </div>
        {savedFlash && (
          <span className="inline-flex items-center gap-1 text-[11px] font-bold text-green-600 animate-pulse">
            <CheckCircle2 size={13} /> Saved
          </span>
        )}
      </div>

      {!editing ? (
        <div>
          {notes ? (
            <p className="text-[14px] text-slate-600 leading-relaxed whitespace-pre-wrap min-h-[60px]">
              {notes}
            </p>
          ) : (
            <p className="text-[13px] text-slate-400 italic min-h-[60px] flex items-center">
              No notes yet. Click "Add notes" to jot down reminders about this job.
            </p>
          )}
          <button
            onClick={() => setEditing(true)}
            className="mt-3 inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-[#1A1A1A] cursor-pointer transition-colors"
          >
            {notes ? "Edit notes" : "Add notes"}
          </button>
        </div>
      ) : (
        <div>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            autoFocus
            rows={5}
            placeholder="e.g. Strong in DSA, prepare system design. Referral from senior. Apply before deadline…"
            className="w-full px-4 py-3 rounded-xl text-[14px] text-slate-700 bg-slate-50 border border-slate-200 outline-none focus:border-[#1A1A1A] focus:ring-1 focus:ring-[#1A1A1A] transition-all resize-y min-h-[100px] placeholder:text-slate-400"
          />
          {error && (
            <p className="text-[12px] text-red-500 font-semibold mt-2">
              Failed to save. Please try again.
            </p>
          )}
          <div className="flex items-center gap-2 mt-3">
            <button
              onClick={handleSave}
              disabled={saving || !dirty}
              className="px-4 py-2 rounded-full text-[12px] font-bold text-white bg-[#1A1A1A] hover:bg-black cursor-pointer transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {saving ? "Saving…" : "Save"}
            </button>
            <button
              onClick={handleCancel}
              disabled={saving}
              className="px-4 py-2 rounded-full text-[12px] font-bold text-slate-600 hover:text-[#1A1A1A] cursor-pointer transition-colors disabled:opacity-40"
            >
              Cancel
            </button>
            {dirty && !saving && (
              <span className="text-[11px] text-slate-400 font-medium ml-1">Unsaved changes</span>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function HeroStat({ icon, label, value, sub, urgent }) {
  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center gap-1.5 text-white/50">
        {icon}
        <span className="text-[10px] sm:text-[11px] font-bold uppercase tracking-wide">{label}</span>
      </div>
      <span className={`text-[13px] sm:text-[15px] font-bold ${urgent ? "text-red-400" : "text-white"} break-words`}>{value}</span>
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
    <div className="flex flex-col sm:flex-row sm:items-center justify-between py-1.5 sm:py-1 gap-0.5 sm:gap-2">
      <span className="text-[12px] text-slate-500 font-medium">{label}</span>
      <span className="text-[13px] font-semibold text-slate-700 sm:text-right break-words">{value}</span>
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
