/**
 * PlacementConnectBanner - Shows on Overview when placement is not connected.
 * Dismissible per session (localStorage). Reappears on next login.
 */
import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Briefcase, X, ArrowRight, Loader2 } from "lucide-react";
import { useAuth } from "../hooks/useAuth.jsx";
import { placementApi } from "../api/placementClient.js";
import PlacementConnectModal from "./PlacementConnectModal.jsx";

const DISMISS_KEY = "placement_banner_dismissed";

export default function PlacementConnectBanner() {
  const { user, placementUser, placementConnected } = useAuth();
  const [show, setShow] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    if (!user?.email || placementUser || placementConnected) {
      setChecking(false);
      return;
    }

    // Check if banner was dismissed this session
    const dismissed = sessionStorage.getItem(DISMISS_KEY) === "true";
    if (dismissed) {
      setChecking(false);
      return;
    }

    // Check if placement credentials exist in Supabase
    let cancelled = false;
    (async () => {
      try {
        const status = await placementApi.connectionStatus(user.email);
        if (cancelled) return;
        if (!status?.connected) {
          setShow(true);
        }
      } catch {
        // If we can't check, don't show banner (avoid false positives)
      } finally {
        if (!cancelled) setChecking(false);
      }
    })();
    return () => { cancelled = true; };
  }, [user?.email, placementUser, placementConnected]);

  const handleDismiss = () => {
    setShow(false);
    sessionStorage.setItem(DISMISS_KEY, "true");
  };

  const handleSuccess = () => {
    setShow(false);
    setShowModal(false);
  };

  if (checking || !show) return null;

  return (
    <>
      <AnimatePresence>
        {show && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.3 }}
            className="relative bg-gradient-to-r from-[#1A1A1A] to-[#2a2a2a] rounded-[24px] p-5 md:p-6 overflow-hidden"
          >
            {/* Decorative element */}
            <div className="absolute top-0 right-0 w-32 h-32 bg-terracotta/10 rounded-full blur-3xl pointer-events-none" />

            <button
              onClick={handleDismiss}
              className="absolute top-4 right-4 text-white/40 hover:text-white/80 transition-colors z-10"
              title="Dismiss"
            >
              <X size={18} />
            </button>

            <div className="relative z-10 flex flex-col sm:flex-row items-start sm:items-center gap-4">
              <div className="w-12 h-12 rounded-2xl bg-terracotta/20 flex items-center justify-center flex-shrink-0">
                <Briefcase size={22} className="text-terracotta" />
              </div>

              <div className="flex-1 min-w-0">
                <h3 className="font-display font-bold text-white text-lg mb-1">
                  Connect your Placement Account
                </h3>
                <p className="text-white/60 text-sm leading-relaxed">
                  Link your Haveloc credentials once to access jobs, companies, and tracker — auto-login on every visit.
                </p>
              </div>

              <button
                onClick={() => setShowModal(true)}
                className="flex items-center gap-2 bg-terracotta hover:bg-[#c26245] text-white rounded-full px-5 py-2.5 font-semibold text-sm transition-colors cursor-pointer flex-shrink-0 whitespace-nowrap"
              >
                Connect Now
                <ArrowRight size={15} />
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {showModal && (
        <PlacementConnectModal
          onClose={() => setShowModal(false)}
          onSuccess={handleSuccess}
        />
      )}
    </>
  );
}
