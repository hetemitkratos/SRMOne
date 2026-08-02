import { useEffect, useState, useRef } from "react";
import { Routes, Route, NavLink, Navigate, useNavigate, useLocation } from "react-router-dom";
import { ArrowLeft, Briefcase, LogOut, Menu, X, Loader2 } from "lucide-react";
import anime from "animejs";
import { motion, AnimatePresence } from "framer-motion";
import { useAuth } from "../hooks/useAuth.jsx";
import { placementApi } from "../api/placementClient.js";
import PlacementOverview from "./PlacementOverview.jsx";
import Companies from "./Companies.jsx";
import Jobs from "./Jobs.jsx";
import Tracker from "./Tracker.jsx";
import Notices from "./Notices.jsx";
import Policies from "./Policies.jsx";
import PlacementLoginModal from "../components/PlacementLoginModal.jsx";

const PLACEMENT_NAV = [
  { to: "/placement", label: "Overview", end: true },
  { to: "/placement/companies", label: "Companies" },
  { to: "/placement/jobs", label: "Jobs" },
  { to: "/placement/tracker", label: "Tracker" },
  { to: "/placement/notices", label: "Notices" },
  { to: "/placement/policies", label: "Policies" },
];

export default function PlacementDashboard() {
  const { user, placementUser, logoutPlacement, setPlacementConnected } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [showLogin, setShowLogin] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState(null);
  const [autoLoggingIn, setAutoLoggingIn] = useState(false);
  const navRefs = useRef([]);
  const [indicatorStyle, setIndicatorStyle] = useState({ width: 0, left: 0, opacity: 0 });

  useEffect(() => {
    const t = setTimeout(() => {
      const activeIdx = PLACEMENT_NAV.findIndex((item) =>
        item.end
          ? location.pathname === item.to || location.pathname === `${item.to}/`
          : location.pathname.startsWith(item.to)
      );
      if (activeIdx >= 0 && navRefs.current[activeIdx]) {
        const el = navRefs.current[activeIdx];
        setIndicatorStyle({
          width: el.offsetWidth,
          left: el.offsetLeft,
          opacity: 1,
        });
      }
    }, 50);
    return () => clearTimeout(t);
  }, [location.pathname, placementUser]);

  useEffect(() => {
    const el = document.getElementById("placement-content-area");
    if (!el) return;
    anime({
      targets: el,
      opacity: [0, 1],
      translateY: [15, 0],
      duration: 400,
      easing: "easeOutQuad",
    });
  }, [location.pathname]);

  // Lock body scroll when mobile menu or login modal is open
  useEffect(() => {
    const lock = mobileOpen || showLogin;
    document.body.style.overflow = lock ? "hidden" : "";
    return () => { document.body.style.overflow = ""; };
  }, [mobileOpen, showLogin]);

  // Check connection status and attempt auto-login if not connected but creds exist
  useEffect(() => {
    if (!user?.email || placementUser) return;
    let cancelled = false;
    setAutoLoggingIn(true);
    (async () => {
      try {
        // First check if already connected in Supabase
        const status = await placementApi.connectionStatus(user.email);
        if (cancelled) return;
        setConnectionStatus(status);

        if (status.connected) {
          // Attempt auto-login
          const result = await placementApi.autoLogin(user.email);
          if (cancelled) return;
          if (result.connected && result.username) {
            loginPlacement(result.username);
            setPlacementConnected(true);
          }
        }
      } catch {
        // Not connected or auto-login failed
      } finally {
        if (!cancelled) setAutoLoggingIn(false);
      }
    })();
    return () => { cancelled = true; };
  }, [user?.email, placementUser, loginPlacement, setPlacementConnected]);

  const handleBackToAcademia = () => {
    navigate("/dashboard");
  };

  const handlePlacementLogout = async () => {
    if (placementUser) {
      try {
        await placementApi.logout(placementUser.username);
      } catch {
        /* ignore */
      }
      logoutPlacement();
    }
    navigate("/placement", { replace: true });
  };

  const handleDisconnectForget = async () => {
    if (!user?.email) return;
    try {
      await placementApi.disconnect(user.email);
    } catch {
      /* ignore */
    }
    if (placementUser) {
      try {
        await placementApi.logout(placementUser.username);
      } catch {
        /* ignore */
      }
    }
    logoutPlacement();
    setPlacementConnected(false);
    setConnectionStatus(null);
    navigate("/placement", { replace: true });
  };

  const handleLoginSuccess = () => {
    setShowLogin(false);
    navigate("/placement", { replace: true });
  };

  if (!placementUser) {
    return (
      <div className="min-h-screen bg-[#F4F0EB] text-[#1A1A1A] font-sans flex flex-col">
        <header className="sticky top-0 z-40 w-full px-6 py-3 lg:py-4 flex items-center justify-between bg-[#F4F0EB]/95 backdrop-blur-md border-b border-slate-200/50">
          <div className="flex items-center gap-3">
            <button
              onClick={handleBackToAcademia}
              className="inline-flex items-center gap-2 rounded-full bg-white border border-slate-200 px-3.5 py-2 text-sm font-bold text-slate-600 hover:text-[#1A1A1A] hover:bg-slate-50 transition-colors cursor-pointer"
            >
              <ArrowLeft size={16} strokeWidth={2.5} />
              Academia
            </button>
            <div className="hidden sm:flex items-center gap-2.5 pl-1">
              <Briefcase size={18} className="text-slate-500" />
              <span className="font-display font-black text-[18px] tracking-tight uppercase">Placement</span>
            </div>
          </div>
          <p className="text-xs font-medium text-slate-500 truncate max-w-[40%] text-right">
            {user?.email}
          </p>
        </header>

        <main className="flex-1 w-full max-w-7xl mx-auto px-6 pb-12 pt-6">
          <div className="bg-[#1A1A1A] rounded-[32px] p-8 md:p-12 text-white min-h-[340px] flex flex-col justify-center">
            {autoLoggingIn ? (
              <>
                <div className="flex items-center gap-3 mb-4">
                  <Loader2 size={28} className="text-white/70 animate-spin" />
                  <h1 className="text-3xl md:text-4xl font-display font-bold">Reconnecting…</h1>
                </div>
                <p className="text-white/60 text-sm md:text-base mb-8 max-w-lg leading-relaxed">
                  Attempting to auto-login to your placement account.
                </p>
              </>
            ) : connectionStatus?.connected ? (
              <>
                <div className="flex items-center gap-3 mb-4">
                  <Briefcase size={28} className="text-white/70" />
                  <h1 className="text-3xl md:text-4xl font-display font-bold">Placement Portal</h1>
                </div>
                <p className="text-white/60 text-sm md:text-base mb-4 max-w-lg leading-relaxed">
                  Your placement account <span className="text-white font-semibold">{connectionStatus.username}</span> is connected but the session expired.
                  Reconnect to continue, or disconnect to remove stored credentials.
                </p>
                <div className="flex flex-wrap gap-3">
                  <button
                    onClick={() => setShowLogin(true)}
                    className="bg-terracotta hover:bg-[#c26245] text-white rounded-full px-6 py-3 font-semibold cursor-pointer transition-colors"
                  >
                    Reconnect
                  </button>
                  <button
                    onClick={handleDisconnectForget}
                    className="bg-white/10 hover:bg-white/20 text-white rounded-full px-6 py-3 font-semibold cursor-pointer transition-colors"
                  >
                    Disconnect & Forget
                  </button>
                  <button
                    onClick={handleBackToAcademia}
                    className="bg-white/10 hover:bg-white/20 text-white rounded-full px-6 py-3 font-semibold cursor-pointer transition-colors"
                  >
                    Back to Academia
                  </button>
                </div>
              </>
            ) : (
              <>
                <div className="flex items-center gap-3 mb-4">
                  <Briefcase size={28} className="text-white/70" />
                  <h1 className="text-3xl md:text-4xl font-display font-bold">Placement Portal</h1>
                </div>
                <p className="text-white/60 text-sm md:text-base mb-8 max-w-lg leading-relaxed">
                  Sign in with your Haveloc credentials to open a dedicated placement workspace —
                  companies, jobs, tracker, notices, and policies.
                </p>
                <div className="flex flex-wrap gap-3">
                  <button
                    onClick={() => setShowLogin(true)}
                    className="bg-terracotta hover:bg-[#c26245] text-white rounded-full px-6 py-3 font-semibold cursor-pointer transition-colors"
                  >
                    Connect Placement Account
                  </button>
                  <button
                    onClick={handleBackToAcademia}
                    className="bg-white/10 hover:bg-white/20 text-white rounded-full px-6 py-3 font-semibold cursor-pointer transition-colors"
                  >
                    Back to Academia
                  </button>
                </div>
              </>
            )}
          </div>
        </main>

        {showLogin && (
          <PlacementLoginModal onClose={() => setShowLogin(false)} onSuccess={handleLoginSuccess} />
        )}
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#F4F0EB] text-[#1A1A1A] font-sans flex flex-col selection:bg-black/10 selection:text-black">
      <header className="sticky top-0 z-40 w-full px-6 py-3 lg:py-4 flex items-center justify-between bg-[#F4F0EB]/95 backdrop-blur-md border-b border-slate-200/50">
        <div className="flex items-center gap-3 flex-shrink-0">
          <button
            onClick={handleBackToAcademia}
            className="inline-flex items-center gap-2 rounded-full bg-white border border-slate-200 px-3.5 py-2 text-sm font-bold text-slate-600 hover:text-[#1A1A1A] hover:bg-slate-50 transition-colors cursor-pointer"
            title="Back to Academia"
          >
            <ArrowLeft size={16} strokeWidth={2.5} />
            <span className="hidden sm:inline">Academia</span>
          </button>
          <div className="flex items-center gap-2 pl-1">
            <div className="w-8 h-8 rounded-full bg-[#1A1A1A] text-white flex items-center justify-center">
              <Briefcase size={15} />
            </div>
            <div className="hidden sm:block leading-tight">
              <p className="font-display font-black text-[15px] tracking-tight uppercase">Placement</p>
              <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider truncate max-w-[140px]">
                {placementUser.username}
              </p>
            </div>
          </div>
        </div>

        <nav className="hidden lg:flex items-center bg-[#F9F7F4] rounded-full shadow-sm border border-slate-200/60 p-1 mx-4 overflow-x-auto hide-scrollbar relative">
          <div
            className="absolute top-1 bottom-1 bg-[#1A1A1A] rounded-full shadow-md transition-all duration-300 ease-out z-0"
            style={indicatorStyle}
          />
          {PLACEMENT_NAV.map((item, idx) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              ref={(el) => (navRefs.current[idx] = el)}
              className={({ isActive }) =>
                `relative z-10 px-5 py-2 rounded-full text-sm font-bold transition-colors duration-300 whitespace-nowrap ${
                  isActive ? "text-white" : "text-slate-600 hover:text-[#1A1A1A] hover:bg-black/5"
                }`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="flex items-center gap-2 flex-shrink-0">
          <button
            onClick={handlePlacementLogout}
            className="hidden sm:inline-flex items-center gap-2 rounded-full bg-white border border-slate-200 px-3.5 py-2 text-sm font-bold text-red-600 hover:bg-red-50 transition-colors cursor-pointer"
          >
            <LogOut size={15} strokeWidth={2.5} />
            Disconnect
          </button>
          <button
            className="lg:hidden w-11 h-11 flex items-center justify-center rounded-full bg-white shadow-sm border border-slate-100"
            onClick={() => setMobileOpen(true)}
          >
            <Menu size={20} />
          </button>
        </div>
      </header>

      <motion.div
        initial={false}
        animate={mobileOpen ? { opacity: 1, scale: 1, pointerEvents: "auto" } : { opacity: 0, scale: 0.95, pointerEvents: "none" }}
        transition={{ type: "tween", duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
        className="fixed inset-0 z-50 bg-[#F4F0EB]/95 backdrop-blur-md flex flex-col lg:hidden origin-top-right"
      >
        <div className="p-6 flex items-center justify-between">
          <span className="font-display font-black text-xl uppercase">Placement</span>
          <button
            className="w-11 h-11 flex items-center justify-center rounded-full bg-white shadow-sm cursor-pointer hover:bg-slate-50 transition-colors"
            onClick={() => setMobileOpen(false)}
          >
            <X size={20} />
          </button>
        </div>
        <nav className="flex-1 flex flex-col justify-center items-center gap-6 px-6 pb-20">
          {PLACEMENT_NAV.map((item, i) => (
            <motion.div
              key={item.to}
              initial={false}
              animate={mobileOpen ? { opacity: 1, y: 0 } : { opacity: 0, y: 10 }}
              transition={{ delay: mobileOpen ? 0.1 + i * 0.05 : 0, type: "tween", duration: 0.2, ease: "easeOut" }}
            >
              <NavLink
                to={item.to}
                end={item.end}
                onClick={() => setMobileOpen(false)}
                className={({ isActive }) =>
                  `text-3xl font-display font-bold transition-colors ${
                    isActive ? "text-[#1A1A1A]" : "text-slate-400"
                  }`
                }
              >
                {item.label}
              </NavLink>
            </motion.div>
          ))}
          <motion.div
            initial={false}
            animate={mobileOpen ? { opacity: 1, y: 0 } : { opacity: 0, y: 10 }}
            transition={{ delay: mobileOpen ? 0.1 + PLACEMENT_NAV.length * 0.05 : 0, type: "tween", duration: 0.2, ease: "easeOut" }}
            className="flex flex-col items-center gap-6 mt-2"
          >
            <button
              onClick={() => {
                setMobileOpen(false);
                setTimeout(() => handleBackToAcademia(), 300);
              }}
              className="text-lg font-bold text-slate-500 cursor-pointer hover:text-slate-700 transition-colors"
            >
              ← Back to Academia
            </button>
            <button
              onClick={() => {
                setMobileOpen(false);
                setTimeout(() => handlePlacementLogout(), 300);
              }}
              className="text-lg font-bold text-red-500 cursor-pointer hover:text-red-700 transition-colors"
            >
              Disconnect Placement
            </button>
          </motion.div>
        </nav>
      </motion.div>

      <main className="flex-1 w-full max-w-7xl mx-auto px-6 pb-12 overflow-hidden flex flex-col">
        <div id="placement-content-area" className="w-full flex-1" style={{ opacity: 0 }}>
          <Routes>
            <Route index element={<PlacementOverview />} />
            <Route path="companies" element={<Companies />} />
            <Route path="jobs" element={<Jobs />} />
            <Route path="tracker" element={<Tracker />} />
            <Route path="notices" element={<Notices />} />
            <Route path="policies" element={<Policies />} />
            <Route path="*" element={<Navigate to="/placement" replace />} />
          </Routes>
        </div>
      </main>
    </div>
  );
}
