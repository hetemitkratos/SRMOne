import { AlertCircle, RefreshCw } from "lucide-react";

export default function ErrorBox({ message, onRetry }) {
  return (
    <div className="bg-white rounded-[24px] border border-red-100 shadow-sm p-8 text-center">
      <AlertCircle size={32} className="text-red-400 mx-auto mb-3" />
      <p className="text-red-500 text-sm font-medium mb-4">{message}</p>
      {onRetry && (
        <button onClick={onRetry}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-slate-900 text-white text-sm font-semibold hover:bg-black cursor-pointer transition-colors">
          <RefreshCw size={14} /> Retry
        </button>
      )}
    </div>
  );
}
