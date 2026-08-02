import { useEffect } from "react";
import { createPortal } from "react-dom";
import { motion, AnimatePresence } from "framer-motion";
import { X } from "lucide-react";

/**
 * Fullscreen lightbox for enlarged image previews.
 */
export default function ImagePreview({ open, src, alt = "", caption = "", onClose }) {
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => {
      if (e.key === "Escape") onClose?.();
    };
    document.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [open, onClose]);

  if (typeof document === "undefined") return null;

  return createPortal(
    <AnimatePresence>
      {open && src ? (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-8">
          <motion.button
            type="button"
            aria-label="Close preview"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 bg-slate-950/70 backdrop-blur-sm cursor-pointer border-0"
            onClick={onClose}
          />

          <motion.div
            role="dialog"
            aria-modal="true"
            aria-label={caption || alt || "Image preview"}
            initial={{ opacity: 0, scale: 0.92, y: 16 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.96, y: 8 }}
            transition={{ duration: 0.2, ease: "easeOut" }}
            className="relative z-10 w-full max-w-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="relative w-full rounded-[28px] overflow-hidden bg-white shadow-2xl border border-white/20">
              <div className="relative bg-slate-100">
                <img
                  src={src}
                  alt={alt || caption || "Preview"}
                  className="w-full max-h-[75vh] object-contain"
                />
                <button
                  type="button"
                  onClick={onClose}
                  className="absolute top-3 right-3 z-20 w-9 h-9 rounded-full bg-black/55 hover:bg-black/75 text-white flex items-center justify-center backdrop-blur-sm cursor-pointer transition-colors"
                  aria-label="Close"
                >
                  <X size={16} strokeWidth={2.5} />
                </button>
              </div>
              {(caption || alt) && (
                <div className="px-5 py-4 border-t border-slate-100 bg-white">
                  <p className="font-bold text-[#1A1A1A] text-sm truncate">{caption || alt}</p>
                  <p className="text-[11px] text-slate-400 font-medium mt-0.5">Click outside or press Esc to close</p>
                </div>
              )}
            </div>
          </motion.div>
        </div>
      ) : null}
    </AnimatePresence>,
    document.body
  );
}
