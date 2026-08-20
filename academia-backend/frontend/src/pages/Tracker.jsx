import { useState, useMemo, useEffect, useRef } from "react";
import {
  RefreshCw, CheckCircle2, XCircle, Clock, AlertCircle, ChevronDown,
  Building2, MapPin, Calendar, Briefcase, TrendingUp, Search,
  QrCode, UserCheck, CalendarClock, Info, Loader2,
} from "lucide-react";
import { usePlacementData } from "../hooks/usePlacementData.js";
import { useAuth } from "../hooks/useAuth.jsx";
import { placementApi } from "../api/placementClient.js";
import Loading from "../components/Loading.jsx";

const ROUND_TYPE_ICONS = {
  SCREENING: AlertCircle,
  PRE_PLACEMENT_TALK: Building2,
  TEST: Clock,
  TECHNICAL_INTERVIEW: TrendingUp,
  GROUP_DISCUSSION: Briefcase,
  HR_INTERVIEW: CheckCircle2,
};

const JOB_STATUS_COLORS = {
  "In Progress": "bg-blue-100 text-blue-700",
  "Closed For Applications": "bg-slate-100 text-slate-600",
  "Completed With Hiring": "bg-green-100 text-green-700",
  "Completed Without Hiring": "bg-red-100 text-red-700",
  "Open For Applications": "bg-emerald-100 text-emerald-700",
  "Cancelled": "bg-red-100 text-red-700",
  "Hold": "bg-amber-100 text-amber-700",
  "Yet to Open": "bg-slate-100 text-slate-500",
};

const ROUND_STATUS_STYLES = {
  CLEARED: { icon: CheckCircle2, color: "text-green-600", bg: "bg-green-50", border: "border-green-200", label: "Cleared" },
  REJECTED: { icon: XCircle, color: "text-red-500", bg: "bg-red-50", border: "border-red-200", label: "Rejected" },
  ATTENDED: { icon: CheckCircle2, color: "text-blue-600", bg: "bg-blue-50", border: "border-blue-200", label: "Attended" },
  ABSENT: { icon: XCircle, color: "text-red-500", bg: "bg-red-50", border: "border-red-200", label: "Absent" },
  SKIPPED: { icon: AlertCircle, color: "text-slate-400", bg: "bg-slate-50", border: "border-slate-200", label: "Skipped" },
  UPCOMING: { icon: Clock, color: "text-slate-400", bg: "bg-slate-50", border: "border-slate-200", label: "Upcoming" },
  DEFAULT: { icon: Clock, color: "text-amber-500", bg: "bg-amber-50", border: "border-amber-200", label: "Pending" },
};

function getRoundDisplayStatus(round) {
  if (round.roundStatus === "CLEARED") return "CLEARED";
  if (round.roundStatus === "REJECTED") return "REJECTED";
  const att = round.attendance?.toUpperCase();
  if (att === "ATTENDED") return "ATTENDED";
  if (att === "ABSENT") return "ABSENT";
  if (att === "SKIPPED") return "SKIPPED";
  return "DEFAULT";
}

function formatDate(dateStr) {
  if (!dateStr || dateStr.startsWith("1970")) return "—";
  const d = new Date(dateStr);
  return d.toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
}

function groupByJob(entries) {
  const groups = {};
  for (const e of entries) {
    const key = e.jobUuid || e.jobId;
    if (!groups[key]) groups[key] = [];
    groups[key].push(e);
  }
  return Object.values(groups).map(rounds => {
    rounds.sort((a, b) => (a.jobRoundNum || 0) - (b.jobRoundNum || 0));
    const first = rounds[0];
    const lastRound = rounds[rounds.length - 1];
    const hasRejected = rounds.some(r => r.roundStatus === "REJECTED");
    const allCleared = rounds.every(r => r.roundStatus === "CLEARED");
    const hasPending = rounds.some(r => r.roundStatus === "DEFAULT");
    const overallStatus = hasRejected ? "rejected" : allCleared ? "cleared" : hasPending ? "in_progress" : "unknown";
    return { first, rounds, lastRound, overallStatus, numOfRounds: first.numOfRounds || rounds.length };
  }).sort((a, b) => new Date(b.first.appliedOn || 0) - new Date(a.first.appliedOn || 0));
}

function TrackerCard({ job, userEmail, logoMap = {} }) {
  const [expanded, setExpanded] = useState(false);
  const [workflowRounds, setWorkflowRounds] = useState(null);
  const [wfLoading, setWfLoading] = useState(false);
  const wfFetchedRef = useRef(false);
  const { first, rounds, overallStatus, numOfRounds } = job;
  const statusStyle = ROUND_STATUS_STYLES[overallStatus === "cleared" ? "CLEARED" : overallStatus === "rejected" ? "REJECTED" : "DEFAULT"];
  const StatusIcon = statusStyle.icon;
  const jobStatusColor = JOB_STATUS_COLORS[first.jobStatus] || "bg-slate-100 text-slate-600";
  const companyLogo = logoMap[first.companyId] || null;

  useEffect(() => {
    if (expanded && !wfFetchedRef.current && first.jobUuid) {
      wfFetchedRef.current = true;
      setWfLoading(true);
      fetch(`/placement-api/jobView/${encodeURIComponent(first.jobUuid)}`, { headers: { "x-user-email": userEmail } })
        .then(r => r.ok ? r.json() : null)
        .then(data => {
          const wfSet = data?.data?.hiringWorkflowSet || [];
          setWorkflowRounds(wfSet);
        })
        .catch(() => setWorkflowRounds([]))
        .finally(() => setWfLoading(false));
    }
  }, [expanded, first.jobUuid, userEmail]);

  // Merge workflow rounds with tracker rounds
  const allRounds = useMemo(() => {
    if (!workflowRounds || workflowRounds.length === 0) return rounds;
    // Build a map of tracker rounds by roundNum
    const trackerByNum = {};
    rounds.forEach(r => { trackerByNum[r.jobRoundNum] = r; });
    // For each workflow round, find matching tracker entry or create a placeholder
    return workflowRounds.map(wf => {
      const trackerRound = trackerByNum[wf.roundNum];
      if (trackerRound) return trackerRound;
      // Upcoming round - not yet in tracker
      return {
        ...first,
        jobRoundNum: wf.roundNum,
        roundTitle: wf.title,
        roundType: wf.roundType,
        roundStatus: null,
        attendance: null,
        attendanceType: null,
        isUpcoming: true,
      };
    }).sort((a, b) => (a.jobRoundNum || 0) - (b.jobRoundNum || 0));
  }, [workflowRounds, rounds, first]);

  const totalRounds = workflowRounds?.length || numOfRounds;

  return (
    <div className="bg-white rounded-[32px] border border-slate-100 shadow-[0_4px_20px_rgba(0,0,0,0.02)] overflow-hidden transition-shadow hover:shadow-md">
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full p-4 sm:p-6 md:p-8 flex items-center gap-3 sm:gap-4 md:gap-6 text-left hover:bg-slate-50/50 transition-colors cursor-pointer"
      >
        <div className="w-12 h-12 sm:w-14 sm:h-14 md:w-16 md:h-16 rounded-2xl bg-slate-50 flex items-center justify-center flex-shrink-0 overflow-hidden border border-slate-100">
          {companyLogo ? (
            <img src={companyLogo} alt={first.companyName} className="w-full h-full object-cover" />
          ) : (
            <Building2 size={24} className="text-slate-400" />
          )}
        </div>
        <div className="flex-1 min-w-0 pr-2 sm:pr-4">
          <div className="flex flex-wrap items-center gap-1.5 sm:gap-2 mb-1.5 sm:mb-2">
            <span className={`text-[10px] sm:text-[11px] font-bold px-2.5 py-1 rounded-full whitespace-nowrap ${jobStatusColor}`}>{first.jobStatus}</span>
            <span className="text-[10px] sm:text-[11px] font-bold text-slate-500 bg-slate-100 px-2.5 py-1 rounded-full whitespace-nowrap">
              {rounds.length}/{totalRounds} rounds
            </span>
          </div>
          <h3 className="font-display font-bold text-lg sm:text-xl md:text-2xl text-[#1A1A1A] truncate leading-tight">{first.companyName || "Unknown"}</h3>
          <p className="text-[12px] sm:text-[14px] text-slate-500 font-medium truncate mt-0.5 sm:mt-1">
            {first.jobTitle || "—"} <span className="mx-1 sm:mx-2 text-slate-300">•</span> Applied {formatDate(first.appliedOn)}
          </p>
        </div>
        <div className="flex items-center gap-2 sm:gap-3">
            <div className={`hidden md:flex items-center gap-2 px-4 py-2 rounded-full border ${statusStyle.bg} ${statusStyle.border}`}>
              <StatusIcon size={16} className={statusStyle.color} />
              <span className={`text-sm font-bold ${statusStyle.color}`}>{statusStyle.label}</span>
            </div>
            <div className={`w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-slate-50 flex items-center justify-center flex-shrink-0 transition-transform ${expanded ? "rotate-180" : ""}`}>
              <ChevronDown size={18} className="text-slate-400" />
            </div>
        </div>
      </button>

      {expanded && (
        <div className="px-6 md:px-8 pb-6 md:pb-8 pt-2">
          {/* Round Progression Timeline */}
          <div className="mt-4 space-y-0">
            {wfLoading && (
              <div className="flex items-center gap-2 text-[11px] text-slate-400 py-2">
                <Loader2 size={12} className="animate-spin" />
                Loading full hiring workflow…
              </div>
            )}
            {allRounds.map((round, idx) => {
              const isUpcoming = round.isUpcoming;
              const displayStatus = isUpcoming ? "UPCOMING" : getRoundDisplayStatus(round);
              const rs = ROUND_STATUS_STYLES[displayStatus] || ROUND_STATUS_STYLES.DEFAULT;
              const RoundIcon = ROUND_TYPE_ICONS[round.roundType] || AlertCircle;
              const isLast = idx === allRounds.length - 1;
              return (
                <div key={idx} className="flex gap-3">
                  <div className="flex flex-col items-center">
                    <div className={`w-8 h-8 rounded-full ${rs.bg} ${rs.border} border flex items-center justify-center flex-shrink-0`}>
                      <rs.icon size={14} className={rs.color} />
                    </div>
                    {!isLast && <div className="w-0.5 flex-1 bg-slate-200 my-1" style={{ minHeight: "24px" }} />}
                  </div>
                  <div className={`flex-1 ${isLast ? "" : "pb-4"}`}>
                    <div className="flex items-center gap-2">
                      <RoundIcon size={12} className="text-slate-400" />
                      <span className="text-[13px] font-semibold text-slate-700">{round.roundTitle || "Unknown Round"}</span>
                    </div>
                    <div className="flex items-center gap-3 mt-0.5">
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${rs.bg} ${rs.color}`}>{rs.label}</span>
                      <span className="text-[10px] text-slate-400">{round.roundType?.replace(/_/g, " ").toLowerCase()}</span>
                      {round.roundComments && (
                        <span className="text-[10px] text-slate-500 italic truncate">"{round.roundComments}"</span>
                      )}
                    </div>
                    {/* Attendance details */}
                    {round.attendanceType && (
                      <div className="mt-2 space-y-1.5">
                        <div className="flex items-center gap-2 flex-wrap">
                          <AttendanceBadge type={round.attendanceType} />
                          {round.attendance && round.attendance !== "Unmarked" && (
                            <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full ${
                              round.attendance === "Attended" ? "bg-blue-50 text-blue-600" :
                              round.attendance === "Absent" ? "bg-red-50 text-red-500" :
                              "bg-slate-50 text-slate-500"
                            }`}>
                              {round.attendance}
                            </span>
                          )}
                          {round.isStudentConfirmedToAttend === false && (
                            <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-amber-50 text-amber-600">
                              Not Confirmed
                            </span>
                          )}
                        </div>
                        {(round.attendanceStartDate || round.attendanceStartTime) && (
                          <div className="flex items-center gap-1.5 text-[10px] text-slate-400">
                            <CalendarClock size={11} className="flex-shrink-0" />
                            <span>
                              {formatDate(round.attendanceStartDate)}
                              {round.attendanceStartTime && round.attendanceStartTime !== "00:00:00" && ` · ${round.attendanceStartTime.slice(0, 5)}`}
                              {round.attendanceEndDate && round.attendanceEndDate !== round.attendanceStartDate && ` → ${formatDate(round.attendanceEndDate)}`}
                              {round.attendanceEndTime && round.attendanceEndTime !== "00:00:00" && ` · ${round.attendanceEndTime.slice(0, 5)}`}
                            </span>
                          </div>
                        )}
                        {round.attendanceType === "QRCode" && round.attendance === "Unmarked" && (
                          <div className="flex items-center gap-1.5 text-[10px] text-blue-500 bg-blue-50 px-2 py-1.5 rounded-lg mt-1">
                            <Info size={11} className="flex-shrink-0" />
                            <span>QR code attendance will be available at the venue during the scheduled time.</span>
                          </div>
                        )}
                        {round.attendanceType === "RFID" && round.attendance === "Unmarked" && (
                          <div className="flex items-center gap-1.5 text-[10px] text-slate-500 bg-slate-50 px-2 py-1.5 rounded-lg mt-1">
                            <Info size={11} className="flex-shrink-0" />
                            <span>RFID tap-in/tap-out at the venue.</span>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>

          {/* Job Details Grid */}
          <div className="mt-4 grid grid-cols-2 gap-3 pt-4 border-t border-slate-100">
            <DetailItem icon={Briefcase} label="Job Type" value={first.jobType?.replace(/_/g, " ").toLowerCase().replace(/\b\w/g, c => c.toUpperCase()) || "—"} />
            <DetailItem icon={Calendar} label="Date of Visit" value={formatDate(first.dateOfVisit)} />
            <DetailItem icon={MapPin} label="Mode" value={first.modeOfIntern || "—"} />
            <DetailItem icon={TrendingUp} label="Total Rounds" value={totalRounds} />
          </div>

          {first.companyWebsiteLink && (
            <a href={first.companyWebsiteLink} target="_blank" rel="noopener noreferrer" className="mt-3 inline-flex items-center gap-1 text-[12px] font-semibold text-blue-600 hover:text-blue-700">
              Company Website
            </a>
          )}
        </div>
      )}
    </div>
  );
}

function DetailItem({ icon: Icon, label, value }) {
  return (
    <div className="flex items-center gap-2">
      <Icon size={13} className="text-slate-400 flex-shrink-0" />
      <div className="min-w-0">
        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">{label}</p>
        <p className="text-[12px] font-semibold text-slate-700 truncate">{value}</p>
      </div>
    </div>
  );
}

const ATTENDANCE_TYPE_META = {
  QRCode: { icon: QrCode, label: "QR Code", color: "text-blue-600", bg: "bg-blue-50" },
  RFID: { icon: UserCheck, label: "RFID", color: "text-purple-600", bg: "bg-purple-50" },
  Manual_Marking: { icon: UserCheck, label: "Manual", color: "text-slate-600", bg: "bg-slate-100" },
};

function AttendanceBadge({ type }) {
  const meta = ATTENDANCE_TYPE_META[type] || { icon: AlertCircle, label: type?.replace(/_/g, " "), color: "text-slate-500", bg: "bg-slate-50" };
  const Icon = meta.icon;
  return (
    <span className={`inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full ${meta.bg} ${meta.color}`}>
      <Icon size={10} />
      {meta.label}
    </span>
  );
}

export default function Tracker() {
  const { data, loading, error, refetch } = usePlacementData("tracker");
  const { placementUser } = useAuth();
  const userEmail = placementUser?.username || "";
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [logoMap, setLogoMap] = useState({});
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const filterRef = useRef(null);

  useEffect(() => {
    function handleClickOutside(event) {
      if (filterRef.current && !filterRef.current.contains(event.target)) {
        setIsFilterOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  useEffect(() => {
    if (!userEmail) return;
    placementApi.companies(userEmail, 0, 20)
      .then((res) => {
        const list = res.data?._embedded?.entityModels || [];
        const map = {};
        for (const c of list) {
          if (c.id && c.imageUrl) map[c.id] = c.imageUrl;
        }
        setLogoMap(map);
      })
      .catch(() => {});
  }, [userEmail]);

  const applications = data?.data?._embedded?.entityModels || data?._embedded?.entityModels || [];
  const groupedJobs = useMemo(() => groupByJob(applications), [data]);

  const filteredJobs = useMemo(() => {
    return groupedJobs.filter(job => {
      const matchesSearch = !search ||
        job.first.companyName?.toLowerCase().includes(search.toLowerCase()) ||
        job.first.jobTitle?.toLowerCase().includes(search.toLowerCase());
      const matchesStatus = statusFilter === "all" || job.overallStatus === statusFilter;
      return matchesSearch && matchesStatus;
    });
  }, [groupedJobs, search, statusFilter]);

  if (loading) return <Loading label="Fetching application tracker…" />;
  if (error) return (
    <div className="pt-4 space-y-4">
      <div className="bg-red-50 rounded-2xl p-4 text-red-600 text-sm font-semibold">{error}</div>
      <button onClick={refetch} className="px-4 py-2 rounded-xl bg-white border border-slate-200 text-slate-600 text-sm font-semibold hover:bg-slate-50">Retry</button>
    </div>
  );

  const stats = {
    total: groupedJobs.length,
    inProgress: groupedJobs.filter(j => j.overallStatus === "in_progress").length,
    rejected: groupedJobs.filter(j => j.overallStatus === "rejected").length,
    cleared: groupedJobs.filter(j => j.overallStatus === "cleared").length,
  };

  return (
    <div className="space-y-5 pt-4">
      {/* Hero Header */}
      <div className="bg-[#1A1A1A] rounded-[32px] p-8 md:p-10 flex flex-col md:flex-row items-center justify-between overflow-hidden relative">
        <div className="absolute right-[-20px] bottom-[-20px] w-64 md:w-80 opacity-30 mix-blend-screen pointer-events-none">
          <img src="/assets/activity-tracker_3o6r.svg" alt="Tracker" className="w-full h-full object-contain object-right-bottom" />
        </div>
        
        <div className="relative z-10 text-white max-w-sm mb-6 md:mb-0">
          <h1 className="font-display text-4xl font-bold mb-2">Application Tracker</h1>
          <p className="text-white/70 text-sm">Monitor your placement journey, interview rounds, and application statuses in real-time.</p>
        </div>

        <button onClick={refetch} className="relative z-10 w-11 h-11 rounded-full bg-white/10 hover:bg-white/20 border border-white/10 flex items-center justify-center text-white cursor-pointer transition-colors backdrop-blur-sm self-start md:self-auto">
          <RefreshCw size={18} />
        </button>
      </div>

      {/* Quick Stats Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <StatCard label="Total Apps" value={stats.total} icon={<Briefcase size={18} />} />
        <StatCard label="In Progress" value={stats.inProgress} icon={<Clock size={18} />} />
        <StatCard label="Cleared" value={stats.cleared} icon={<CheckCircle2 size={18} />} />
        <StatCard label="Rejected" value={stats.rejected} icon={<XCircle size={18} />} />
      </div>

      {/* Search & Filter */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 sm:gap-4">
        <div className="flex-1 relative group">
          <Search size={18} className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-[#1A1A1A] transition-colors" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search company or role…"
            className="w-full pl-12 pr-6 py-3.5 rounded-full bg-white border border-slate-100 shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-sm font-medium text-slate-700 placeholder:text-slate-400 focus:outline-none focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50 transition-all"
          />
        </div>
        <div className="relative sm:min-w-[180px]" ref={filterRef}>
          <button
            onClick={() => setIsFilterOpen(!isFilterOpen)}
            className="w-full flex items-center justify-between pl-6 pr-5 py-3.5 rounded-full bg-white border border-slate-100 shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-sm font-bold text-slate-600 focus:outline-none focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50 transition-all cursor-pointer"
          >
            {statusFilter === "all" ? "All Applications" : statusFilter === "in_progress" ? "In Progress" : statusFilter === "cleared" ? "Cleared" : "Rejected"}
            <ChevronDown size={16} className={`text-slate-400 transition-transform duration-200 ${isFilterOpen ? "rotate-180" : ""}`} />
          </button>
          
          {isFilterOpen && (
            <div className="absolute top-full left-0 right-0 mt-2 bg-white rounded-2xl shadow-xl border border-slate-100/80 overflow-hidden z-20 py-1">
              {[
                { value: "all", label: "All Applications" },
                { value: "in_progress", label: "In Progress" },
                { value: "cleared", label: "Cleared" },
                { value: "rejected", label: "Rejected" },
              ].map(opt => (
                <button
                  key={opt.value}
                  onClick={() => {
                    setStatusFilter(opt.value);
                    setIsFilterOpen(false);
                  }}
                  className={`w-full text-left px-5 py-3 text-sm font-semibold transition-colors ${statusFilter === opt.value ? "bg-slate-50 text-[#1A1A1A]" : "text-slate-600 hover:bg-slate-50 hover:text-[#1A1A1A]"}`}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Job Cards */}
      {filteredJobs.length === 0 ? (
        <div className="text-center py-12 text-slate-400 text-sm font-medium">No applications found</div>
      ) : (
        <div className="space-y-3">
          {filteredJobs.map((job, i) => (
            <TrackerCard key={job.first.jobUuid || i} job={job} userEmail={userEmail} logoMap={logoMap} />
          ))}
        </div>
      )}
    </div>
  );
}

function StatCard({ label, value, icon }) {
  return (
    <div className="bg-white rounded-[24px] border border-slate-100 p-5 flex flex-col justify-center shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
      <div className="flex items-center gap-2 mb-2 text-slate-400">
        {icon}
        <p className="text-[11px] font-bold uppercase tracking-wider">{label}</p>
      </div>
      <p className="text-3xl font-display font-black text-[#1A1A1A]">{value}</p>
    </div>
  );
}
