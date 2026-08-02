import { useEffect, useState, useRef } from "react";
import { Routes, Route, NavLink, Navigate, useNavigate, useLocation } from "react-router-dom";
import { Bell, Mail, Menu, X, LogOut, Briefcase } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import anime from "animejs";
import { useAuth } from "../hooks/useAuth.jsx";
import { api } from "../api/client.js";
import { placementApi, setAcademiaEmail } from "../api/placementClient.js";
import ImagePreview from "../components/ImagePreview.jsx";
import NotificationBell from "../components/NotificationBell.jsx";
import PlacementConnectModal from "../components/PlacementConnectModal.jsx";

import Overview from "./Overview.jsx";
import Attendance from "./Attendance.jsx";
import Timetable from "./Timetable.jsx";
import Marks from "./Marks.jsx";
import Calendar from "./Calendar.jsx";

const NAV_ITEMS = [
  { to: "/dashboard", label: "Home", end: true },
  { to: "/dashboard/attendance", label: "Attendance" },
  { to: "/dashboard/timetable", label: "Timetable" },
  { to: "/dashboard/marks", label: "Marks" },
  { to: "/dashboard/calendar", label: "Calendar" },
];

export default function Dashboard() {
  const { user, logout, placementUser, loginPlacement, logoutPlacement, setPlacementConnected, placementConnected } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);

  // Set academia email for placement API notifications
  useEffect(() => {
    if (user?.email) setAcademiaEmail(user.email);
  }, [user?.email]);
  const [profileMenuOpen, setProfileMenuOpen] = useState(false);
  const [photoPreviewOpen, setPhotoPreviewOpen] = useState(false);
  const [studentInfo, setStudentInfo] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showPlacementConnect, setShowPlacementConnect] = useState(false);

  const navRefs = useRef([]);
  const [indicatorStyle, setIndicatorStyle] = useState({ width: 0, left: 0, opacity: 0 });

  // Auto-login to placement on mount if not already connected
  useEffect(() => {
    if (!user?.email || placementUser) return;
    let cancelled = false;
    (async () => {
      try {
        const result = await placementApi.autoLogin(user.email);
        if (cancelled) return;
        if (result.connected && result.username) {
          loginPlacement(result.username);
          setPlacementConnected(true);
        }
      } catch {
        // Not connected or auto-login failed — user can connect from Placement page
      }
    })();
    return () => { cancelled = true; };
  }, [user?.email, placementUser, loginPlacement, setPlacementConnected]);

  useEffect(() => {
    const t = setTimeout(() => {
      const activeIdx = NAV_ITEMS.findIndex((item) =>
        item.end
          ? location.pathname === item.to || location.pathname === item.to + "/"
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
  }, [location.pathname]);

  useEffect(() => {
    const el = document.getElementById("main-content-area");
    if (el) {
      anime({
        targets: el,
        opacity: [0, 1],
        translateY: [15, 0],
        duration: 400,
        easing: "easeOutQuad",
      });
    }
  }, [location.pathname]);

  // Lock body scroll when mobile menu or photo preview is open
  useEffect(() => {
    const lock = mobileOpen || photoPreviewOpen || showPlacementConnect;
    document.body.style.overflow = lock ? "hidden" : "";
    return () => { document.body.style.overflow = ""; };
  }, [mobileOpen, photoPreviewOpen, showPlacementConnect]);

  // Handle placement button click — navigate if connected, open modal if not
  const handlePlacementClick = () => {
    setProfileMenuOpen(false);
    setMobileOpen(false);
    if (placementUser || placementConnected) {
      navigate("/placement");
    } else {
      setShowPlacementConnect(true);
    }
  };

  const handlePlacementConnectSuccess = () => {
    setShowPlacementConnect(false);
    // Small delay then navigate to placement
    setTimeout(() => navigate("/placement"), 300);
  };

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const data = await api.student(user.email);
        if (!cancelled) setStudentInfo(data.studentInfo);
      } catch (err) {
        // If server is down or auth failed, redirect to login
        if (!cancelled) {
          const errorMsg = err.message || "";
          if (
            errorMsg.includes("backend running") ||
            errorMsg.includes("Empty response") ||
            errorMsg.includes("session") ||
            errorMsg.includes("unauthorized") ||
            errorMsg.includes("not logged in")
          ) {
            logout();
            navigate("/login", { replace: true });
            return;
          }
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [user.email, logout, navigate]);

  const handleLogout = async () => {
    try {
      await api.logout(user.email);
    } catch { /* ignore */ }
    if (placementUser) {
      try {
        await import("../api/placementClient.js").then((m) => m.placementApi.logout(placementUser.username));
      } catch { /* ignore */ }
      logoutPlacement();
    }
    logout();
    navigate("/login", { replace: true });
  };

  const fullName = studentInfo?.Name || user?.email?.split("@")[0] || "Student";
  const initials = fullName
    .split(" ")
    .map((w) => w[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();

  return (
    <div className="min-h-screen bg-[#F4F0EB] text-[#1A1A1A] font-sans flex flex-col selection:bg-black/10 selection:text-black">
      <header className="sticky top-0 z-40 w-full px-6 py-3 lg:py-4 flex items-center justify-between bg-[#F4F0EB]/95 backdrop-blur-md border-b border-slate-200/50">
        <div className="flex items-center gap-2.5 flex-shrink-0">
          <img src="/assets/logo.png" alt="Logo" className="w-9 h-9 object-contain" />
          <span className="font-display font-black text-[22px] tracking-tight block uppercase whitespace-nowrap">SRM ONE</span>
        </div>

        <nav className="hidden lg:flex items-center bg-[#F9F7F4] rounded-full shadow-sm border border-slate-200/60 p-1 mx-4 overflow-x-auto hide-scrollbar relative">
          <div
            className="absolute top-1 bottom-1 bg-[#1A1A1A] rounded-full shadow-md transition-all duration-300 ease-out z-0"
            style={indicatorStyle}
          />

          {NAV_ITEMS.map((item, idx) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              ref={(el) => (navRefs.current[idx] = el)}
              className={({ isActive }) =>
                `relative z-10 px-5 py-2 rounded-full text-sm font-bold transition-colors duration-300 whitespace-nowrap ${
                  isActive
                    ? "text-white"
                    : "text-slate-600 hover:text-[#1A1A1A] hover:bg-black/5"
                }`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="flex items-center gap-3 flex-shrink-0">
          <button
            onClick={handlePlacementClick}
            className="hidden md:inline-flex items-center gap-2 rounded-full bg-[#1A1A1A] text-white px-4 py-2.5 text-sm font-bold hover:bg-black transition-colors cursor-pointer shadow-sm"
            title={placementUser || placementConnected ? "Open Placement Portal" : "Connect Placement Account"}
          >
            <Briefcase size={15} strokeWidth={2.5} />
            {placementUser || placementConnected ? "Placement" : "Connect Placement"}
          </button>

          <button
            onClick={() => navigate("/placement/notices")}
            className="relative w-11 h-11 rounded-full bg-white flex items-center justify-center text-slate-500 hover:text-[#1A1A1A] hover:bg-slate-50 transition-colors shadow-sm hidden sm:flex cursor-pointer border border-slate-100"
            title="Notices"
          >
            <Mail size={19} strokeWidth={2.5} />
          </button>
          <div className="hidden sm:block">
            <NotificationBell />
          </div>

          <div className="relative ml-1 flex items-center">
            <button
              onClick={() => setProfileMenuOpen(!profileMenuOpen)}
              className="relative flex items-center justify-center cursor-pointer group rounded-full w-11 h-11"
              title="Profile Menu"
            >
              {loading ? (
                <div className="w-11 h-11 rounded-full bg-slate-200 animate-pulse" />
              ) : studentInfo?.PhotoUrl ? (
                <img
                  src={studentInfo.PhotoUrl}
                  alt="Profile"
                  className="w-11 h-11 rounded-full object-cover border-2 border-white shadow-sm transition-transform group-hover:scale-105"
                />
              ) : (
                <div className="w-11 h-11 rounded-full bg-[#1A1A1A] text-white flex items-center justify-center font-bold text-sm border-2 border-white shadow-sm transition-transform group-hover:scale-105">
                  {initials}
                </div>
              )}
            </button>

            {profileMenuOpen && (
              <>
                <div
                  className="fixed inset-0 z-40"
                  onClick={() => setProfileMenuOpen(false)}
                />
                <div className="absolute top-full right-0 mt-3 w-64 bg-white rounded-[24px] border border-slate-100 shadow-[0_10px_40px_rgba(0,0,0,0.08)] z-50 overflow-hidden flex flex-col">
                  <div className="p-5 border-b border-slate-100 bg-slate-50/50">
                    <div className="flex items-center gap-3 mb-3">
                      {studentInfo?.PhotoUrl ? (
                        <button
                          type="button"
                          onClick={() => {
                            setProfileMenuOpen(false);
                            setPhotoPreviewOpen(true);
                          }}
                          className="rounded-full overflow-hidden border-2 border-white shadow-sm cursor-zoom-in hover:ring-2 hover:ring-[#1A1A1A]/15 transition-shadow flex-shrink-0"
                          title="View full photo"
                          aria-label="Enlarge profile photo"
                        >
                          <img
                            src={studentInfo.PhotoUrl}
                            alt={studentInfo?.Name || "Profile"}
                            className="w-14 h-14 object-cover"
                          />
                        </button>
                      ) : (
                        <div className="w-14 h-14 rounded-full bg-[#1A1A1A] text-white flex items-center justify-center font-bold text-base flex-shrink-0">
                          {initials}
                        </div>
                      )}
                      <div className="min-w-0">
                        <p className="font-bold text-[#1A1A1A] text-[15px] truncate">{studentInfo?.Name || "Student"}</p>
                        <p className="text-xs font-medium text-slate-500 truncate mt-0.5">{user.email}</p>
                      </div>
                    </div>
                    {studentInfo?.RegistrationNumber && (
                      <p className="text-[10px] font-bold font-mono text-slate-400 uppercase tracking-wider">
                        {studentInfo.RegistrationNumber}
                      </p>
                    )}
                  </div>

                  {studentInfo && (
                    <div className="p-4 border-b border-slate-100 flex flex-col gap-3 bg-white">
                      {studentInfo.Program && (
                        <div className="flex flex-col">
                          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Program</span>
                          <span className="text-[13px] font-semibold text-slate-700">{studentInfo.Program}</span>
                        </div>
                      )}
                      {studentInfo.Department && (
                        <div className="flex flex-col">
                          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Department</span>
                          <span className="text-[13px] font-semibold text-slate-700">{studentInfo.Department}</span>
                        </div>
                      )}
                      <div className="flex gap-6">
                        {studentInfo.Semester && (
                          <div className="flex flex-col">
                            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Semester</span>
                            <span className="text-[13px] font-semibold text-slate-700">{studentInfo.Semester}</span>
                          </div>
                        )}
                        {studentInfo.Section && (
                          <div className="flex flex-col">
                            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Section</span>
                            <span className="text-[13px] font-semibold text-slate-700">{studentInfo.Section}</span>
                          </div>
                        )}
                      </div>
                    </div>
                  )}
                  <div className="p-2 space-y-1">
                    <button
                      onClick={handlePlacementClick}
                      className="w-full flex items-center gap-3 px-4 py-3 rounded-[16px] text-[#1A1A1A] hover:bg-slate-50 transition-colors cursor-pointer font-bold text-sm"
                    >
                      <Briefcase size={16} strokeWidth={2.5} />
                      {placementUser || placementConnected ? "Placement Portal" : "Connect Placement"}
                    </button>
                    <button
                      onClick={() => { setProfileMenuOpen(false); handleLogout(); }}
                      className="w-full flex items-center gap-3 px-4 py-3 rounded-[16px] text-red-600 hover:bg-red-50 hover:text-red-700 transition-colors cursor-pointer font-bold text-sm"
                    >
                      <LogOut size={16} strokeWidth={2.5} /> Logout
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>

          <button
            className="lg:hidden w-11 h-11 flex items-center justify-center rounded-full bg-white shadow-sm border border-slate-100 ml-2"
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
          <div className="flex items-center gap-2.5">
            <img src="/assets/logo.png" alt="Logo" className="w-9 h-9 object-contain" />
            <span className="font-display font-black text-xl uppercase">SRM ONE</span>
          </div>
          <button
            className="w-11 h-11 flex items-center justify-center rounded-full bg-white shadow-sm cursor-pointer hover:bg-slate-50 transition-colors"
            onClick={() => setMobileOpen(false)}
          >
            <X size={20} />
          </button>
        </div>
        <nav className="flex-1 flex flex-col justify-center items-center gap-6 px-6 pb-20">
          {NAV_ITEMS.map((item, i) => (
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
            transition={{ delay: mobileOpen ? 0.1 + NAV_ITEMS.length * 0.05 : 0, type: "tween", duration: 0.2, ease: "easeOut" }}
          >
            <button
              onClick={handlePlacementClick}
              className="text-3xl font-display font-bold text-[#1A1A1A] cursor-pointer hover:text-slate-600 transition-colors"
            >
              {placementUser || placementConnected ? "Placement" : "Connect Placement"}
            </button>
          </motion.div>
        </nav>
      </motion.div>

      <main className="flex-1 w-full max-w-7xl mx-auto px-6 pb-12 overflow-hidden flex flex-col">
        <div id="main-content-area" className="w-full flex-1" style={{ opacity: 0 }}>
          <Routes>
            <Route index element={<Overview />} />
            <Route path="attendance" element={<Attendance />} />
            <Route path="timetable" element={<Timetable />} />
            <Route path="marks" element={<Marks />} />
            <Route path="calendar" element={<Calendar />} />
            <Route path="placement" element={<Navigate to="/placement" replace />} />
            <Route path="companies" element={<Navigate to="/placement/companies" replace />} />
            <Route path="jobs" element={<Navigate to="/placement/jobs" replace />} />
            <Route path="tracker" element={<Navigate to="/placement/tracker" replace />} />
            <Route path="notices" element={<Navigate to="/placement/notices" replace />} />
            <Route path="policies" element={<Navigate to="/placement/policies" replace />} />
          </Routes>
        </div>
      </main>

      <ImagePreview
        open={photoPreviewOpen}
        src={studentInfo?.PhotoUrl || ""}
        alt={studentInfo?.Name || "Profile photo"}
        caption={studentInfo?.Name || "Your profile photo"}
        onClose={() => setPhotoPreviewOpen(false)}
      />

      {showPlacementConnect && (
        <PlacementConnectModal
          onClose={() => setShowPlacementConnect(false)}
          onSuccess={handlePlacementConnectSuccess}
        />
      )}
    </div>
  );
}
