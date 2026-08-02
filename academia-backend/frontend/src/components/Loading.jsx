import { Loader2 } from "lucide-react";

export default function Loading({ label = "Loading…" }) {
  return (
    <div className="flex flex-col items-center justify-center py-20 gap-3">
      <Loader2 className="w-8 h-8 animate-spin text-accent" />
      <p className="text-white/40 text-sm">{label}</p>
    </div>
  );
}
