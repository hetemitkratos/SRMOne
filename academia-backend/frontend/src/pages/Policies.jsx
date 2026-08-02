import { FileText, RefreshCw } from "lucide-react";
import { usePlacementData } from "../hooks/usePlacementData.js";
import Loading from "../components/Loading.jsx";

export default function Policies() {
  const { data, loading, error, refetch } = usePlacementData("policies");

  if (loading) return <Loading label="Fetching policies…" />;
  if (error) return <ErrorBox message={error} onRetry={refetch} />;

  const policies = Array.isArray(data) ? data : data?._embedded?.entityModels || [];

  return (
    <div className="space-y-5 pt-4">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-display font-bold text-[#1A1A1A]">Placement Policies</h2>
        <button onClick={refetch} className="w-9 h-9 rounded-full bg-white border border-slate-200 flex items-center justify-center text-slate-500 hover:text-[#1A1A1A] cursor-pointer transition-colors">
          <RefreshCw size={15} />
        </button>
      </div>

      <div className="space-y-3">
        {policies.length === 0 ? (
          <div className="bg-white rounded-[20px] p-8 border border-slate-200/60 text-center">
            <FileText size={32} className="text-slate-300 mx-auto mb-3" />
            <p className="text-slate-500 text-sm font-medium">No policies found.</p>
          </div>
        ) : (
          policies.map((p, i) => (
            <div key={p.id || i} className="bg-white rounded-[20px] p-5 border border-slate-200/60 shadow-sm">
              <h3 className="font-bold text-[15px] text-slate-800 mb-2">{p.title || p.name || "Untitled Policy"}</h3>
              {p.description && <p className="text-[13px] text-slate-500 leading-relaxed">{p.description}</p>}
              {p.content && <p className="text-[13px] text-slate-500 leading-relaxed whitespace-pre-wrap">{p.content}</p>}
            </div>
          ))
        )}
      </div>
    </div>
  );
}
