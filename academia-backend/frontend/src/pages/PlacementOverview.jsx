import { useEffect, useState } from "react";
import { Briefcase, Building2, TrendingUp, FileText, ArrowUpRight, RefreshCw } from "lucide-react";
import anime from "animejs";
import { usePlacementData } from "../hooks/usePlacementData.js";
import Loading from "../components/Loading.jsx";

export default function PlacementOverview() {
  const [stats, setStats] = useState(null);

  const profile = usePlacementData("profile");
  const studentStats = usePlacementData("studentStats");

  useEffect(() => {
    if (studentStats.data) {
      const s = studentStats.data;
      const embedded = s?._embedded?.entityModels?.[0];
      if (embedded) {
        setStats({
          applied: embedded.appliedCount || 0,
          eligible: embedded.eligibleJobCount || 0,
          notEligible: embedded.notEligibleJobCount || 0,
          offered: embedded.offerCount || 0,
          notApplied: embedded.eligibleNotAppliedCount || 0,
        });
      }
    }
  }, [studentStats.data]);

  useEffect(() => {
    const isLoading = studentStats.loading || profile.loading;
    if (!isLoading) {
      anime({
        targets: ".placement-anim",
        opacity: [0, 1],
        translateY: [20, 0],
        delay: anime.stagger(100),
        duration: 700,
        easing: "easeOutExpo",
      });
    }
  }, [studentStats.loading, profile.loading]);

  const loading = studentStats.loading || profile.loading;
  if (loading) return <Loading label="Fetching placement dashboard…" />;

  const profileData = profile.data?._embedded?.entityModels?.[0] || profile.data;
  const studentName = profileData?.name || profileData?.firstName || "Student";

  return (
    <div className="space-y-6 pt-4">
      <div className="placement-anim bg-[#1A1A1A] rounded-[32px] p-6 sm:p-8 md:p-10 text-white min-h-[260px] flex flex-col justify-between relative overflow-hidden" style={{ opacity: 0 }}>
        <div className="absolute right-0 bottom-0 h-full w-[45%] sm:w-[50%] md:w-auto md:h-[120%] opacity-30 md:opacity-40 mix-blend-screen pointer-events-none flex items-end justify-end">
          <img src="/assets/job-hunt_5umi.svg" alt="Placement" className="w-full h-full object-contain object-right-bottom" />
        </div>
        <div className="relative z-10 w-[55%] sm:w-[60%] md:w-auto md:max-w-md mb-6">
          <p className="text-white/70 text-sm sm:text-lg mb-1 font-medium">Placement Dashboard</p>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-display font-bold leading-tight mb-3 tracking-tight break-words">
            {studentName?.split(" ")[0] || "Student"}
          </h1>
          <p className="text-white/60 text-xs sm:text-sm md:text-base line-clamp-3">
            {profileData?.branch || "—"} • {profileData?.college || "—"}
          </p>
        </div>
        <div className="relative z-10 flex gap-3">
          <button
            onClick={() => studentStats.refetch()}
            className="bg-white/10 hover:bg-white/20 text-white rounded-full px-4 py-2 font-medium flex items-center gap-2 text-sm transition-colors cursor-pointer"
          >
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard label="Applied" value={stats?.applied ?? "—"} icon={<Briefcase size={18} />} color="bg-mint" animClass="placement-anim" />
        <StatCard label="Eligible Jobs" value={stats?.eligible ?? "—"} icon={<TrendingUp size={18} />} color="bg-lavender" animClass="placement-anim" />
        <StatCard label="Not Applied" value={stats?.notApplied ?? "—"} icon={<FileText size={18} />} color="bg-beige" animClass="placement-anim" />
        <StatCard label="Offers" value={stats?.offered ?? "—"} icon={<ArrowUpRight size={18} />} color="bg-terracotta text-white" animClass="placement-anim" />
      </div>

      {profileData && (
        <div className="placement-anim bg-white rounded-[24px] p-6 border border-slate-200/60 shadow-sm" style={{ opacity: 0 }}>
          <h3 className="font-display font-bold text-xl text-[#1A1A1A] mb-4">Profile Summary</h3>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-y-5 gap-x-4">
            <InfoItem label="Roll Number" value={profileData?.rollNumber || "—"} />
            <InfoItem label="Course" value={profileData?.course || "—"} />
            <InfoItem label="Section" value={profileData?.section || "—"} />
            <InfoItem label="Semester" value={profileData?.semester || "—"} />
            <InfoItem label="Passed Out Year" value={profileData?.passedOutYear || "—"} />
            <InfoItem label="Status" value={profileData?.studentStatus || "—"} className="col-span-2 sm:col-span-1" />
            <InfoItem label="Mentor" value={profileData?.mentor || "—"} className="col-span-2 sm:col-span-1" />
            <InfoItem label="Advisor" value={profileData?.advisor || "—"} className="col-span-2 sm:col-span-1" />
          </div>
        </div>
      )}
    </div>
  );
}

function StatCard({ label, value, icon, color, animClass }) {
  return (
    <div className={`${animClass} ${color} rounded-[24px] p-5 flex flex-col justify-between min-h-[120px]`} style={{ opacity: 0 }}>
      <div className="flex justify-between items-start gap-2">
        <span className="text-[#1A1A1A] font-bold text-[13px] sm:text-sm leading-tight tracking-tight max-w-[60%] sm:max-w-none">{label}</span>
        <div className="w-8 h-8 rounded-full bg-white/40 flex items-center justify-center text-[#1A1A1A] shrink-0">{icon}</div>
      </div>
      <span className="text-4xl font-display font-bold text-[#1A1A1A] mt-2">{value}</span>
    </div>
  );
}

function InfoItem({ label, value, className = "" }) {
  return (
    <div className={`flex flex-col min-w-0 ${className}`}>
      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">{label}</span>
      <span className="text-[13px] font-semibold text-slate-700 break-words">{value}</span>
    </div>
  );
}
