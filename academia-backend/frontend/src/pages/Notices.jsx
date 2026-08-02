import { Bell, RefreshCw } from "lucide-react";
import { usePlacementData } from "../hooks/usePlacementData.js";
import Loading from "../components/Loading.jsx";

export default function Notices() {
  const { data, loading, error, refetch } = usePlacementData("notices");

  if (loading) return <Loading label="Fetching notices…" />;
  if (error) return <ErrorBox message={error} onRetry={refetch} />;

  const notices = data?._embedded?.entityModels || [];

  return (
    <div className="space-y-5 pt-4">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-display font-bold text-[#1A1A1A]">Notices</h2>
        <button onClick={refetch} className="w-9 h-9 rounded-full bg-white border border-slate-200 flex items-center justify-center text-slate-500 hover:text-[#1A1A1A] cursor-pointer transition-colors">
          <RefreshCw size={15} />
        </button>
      </div>

      <p className="text-sm text-slate-500 font-medium">{notices.length} notices</p>

      <div className="space-y-3">
        {notices.map((n, i) => (
          <div key={n.id || i} className="bg-white rounded-[20px] p-5 border border-slate-200/60 shadow-sm">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-xl bg-lavender flex items-center justify-center flex-shrink-0">
                <Bell size={18} className="text-slate-700" />
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="font-bold text-[14px] text-slate-800">{n.title || n.subject || "Untitled Notice"}</h3>
                {n.message && <p className="text-[13px] text-slate-500 mt-1 line-clamp-3">{n.message}</p>}
                {n.createdDate && (
                  <p className="text-[11px] text-slate-400 mt-2 font-mono">
                    {new Date(n.createdDate).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" })}
                  </p>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
