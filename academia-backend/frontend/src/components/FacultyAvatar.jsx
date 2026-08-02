import { useState } from "react";
import { User } from "lucide-react";
import { api } from "../api/client.js";
import ImagePreview from "./ImagePreview.jsx";

function cleanFacultyName(name = "") {
  return String(name)
    .replace(/\(.*?\)/g, "")
    .replace(/^(prof|mrs|ms|mr|dr)\.?\s*/i, "")
    .trim();
}

function initialsFromName(name = "") {
  const cleaned = cleanFacultyName(name);
  if (!cleaned) return "?";
  return cleaned
    .split(/\s+/)
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

/**
 * Renders a faculty photo via the academia /faculty-photo proxy.
 * Click an image to open an enlarged preview.
 */
export default function FacultyAvatar({
  name = "",
  photoUrl = "",
  size = 32,
  className = "",
  previewable = true,
}) {
  const [failed, setFailed] = useState(false);
  const [previewOpen, setPreviewOpen] = useState(false);
  const proxied = photoUrl ? api.facultyPhoto(photoUrl) : "";
  const showImage = Boolean(proxied) && !failed;
  const px = typeof size === "number" ? `${size}px` : size;
  const label = cleanFacultyName(name) || name || "Faculty";
  const canPreview = previewable && showImage;

  return (
    <>
      <button
        type="button"
        disabled={!canPreview}
        onClick={(e) => {
          e.stopPropagation();
          if (canPreview) setPreviewOpen(true);
        }}
        className={`relative flex-shrink-0 overflow-hidden rounded-full bg-slate-200 text-[#1A1A1A] flex items-center justify-center font-bold shadow-sm border border-white/70 ${
          canPreview ? "cursor-zoom-in hover:ring-2 hover:ring-[#1A1A1A]/20 transition-shadow" : "cursor-default"
        } ${className}`}
        style={{ width: px, height: px, fontSize: Math.max(10, Math.round(Number(size) * 0.32)) }}
        title={canPreview ? `View ${label}` : label}
        aria-label={canPreview ? `Enlarge photo of ${label}` : label}
      >
        {showImage ? (
          <img
            src={proxied}
            alt={label}
            className="w-full h-full object-cover pointer-events-none"
            loading="lazy"
            onError={() => setFailed(true)}
          />
        ) : cleanFacultyName(name) ? (
          <span>{initialsFromName(name)}</span>
        ) : (
          <User size={Math.max(12, Math.round(Number(size) * 0.45))} className="opacity-60" />
        )}
      </button>

      <ImagePreview
        open={previewOpen}
        src={proxied}
        alt={label}
        caption={label}
        onClose={() => setPreviewOpen(false)}
      />
    </>
  );
}
