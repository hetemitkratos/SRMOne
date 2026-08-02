import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useNavigate, Link } from "react-router-dom";
import { Loader2, Eye, EyeOff, Sparkles, GraduationCap, Calendar, BarChart2, Briefcase, ChevronDown, ChevronUp } from "lucide-react";
import { api } from "../api/client.js";
import { placementApi } from "../api/placementClient.js";
import { useAuth } from "../hooks/useAuth.jsx";

function LogoMark({ size = 40 }) {
  return (
    <img src="/assets/logo.png" alt="SRM One logo"
      style={{ width: size, height: size, objectFit: "contain", flexShrink: 0 }} />
  );
}

export default function Login() {
  const { user } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (user) navigate("/dashboard", { replace: true });
  }, [user, navigate]);

  return (
    <div className="min-h-screen bg-white font-sans text-slate-900 grid grid-cols-1 lg:grid-cols-2 relative overflow-hidden">
      
      {/* LEFT SIDE - BRANDING (App Theme) */}
      <div className="hidden lg:flex flex-col justify-between bg-[#F8F6F0] text-slate-900 p-12 xl:p-16 relative overflow-hidden">
        {/* Subtle Decorative Blurs */}
        <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-orange-200/30 rounded-full blur-[100px] pointer-events-none mix-blend-multiply" />
        <div className="absolute bottom-[-10%] right-[-5%] w-[30%] h-[40%] bg-blue-200/30 rounded-full blur-[100px] pointer-events-none mix-blend-multiply" />

        {/* Top Header */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}
          className="relative z-10 flex items-center gap-3">
          <LogoMark size={36} />
          <span className="font-bold text-[22px] tracking-tight text-slate-800">SRM One</span>
        </motion.div>

        {/* Middle Content */}
        <div className="relative z-10 max-w-lg mt-12">
          <motion.h1 
            initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.1 }}
            className="text-[3.5rem] xl:text-[4.5rem] leading-[1.05] font-serif tracking-tight text-slate-900 mb-6">
            Your Academic<br />Life, <span className="text-[#f97316]">Simplified.</span>
          </motion.h1>
          
          <motion.p 
            initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.2 }}
            className="text-[17px] text-slate-600 leading-relaxed font-medium">
            Personalized dashboards designed to help you succeed with the right attendance, marks, placement, and timetable tracking.
          </motion.p>
        </div>

        {/* Large Illustration */}
        <motion.div 
          initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 0.8, delay: 0.3 }}
          className="relative z-10 flex-1 flex items-center justify-center mt-12 w-full max-w-[500px] mx-auto lg:mx-0">
          <img src="/assets/online-learning.svg" alt="Academic Life Illustration" className="w-full h-auto drop-shadow-xl mix-blend-multiply" />
        </motion.div>
      </div>

      {/* RIGHT SIDE - LOGIN FORM */}
      <div className="flex flex-col justify-center px-8 sm:px-16 lg:px-24 xl:px-32 bg-white relative z-10 min-h-screen lg:min-h-0 py-12">
        {/* Mobile Logo */}
        <div className="lg:hidden flex justify-center mb-10">
          <LogoMark size={48} />
        </div>

        <motion.div 
          initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ duration: 0.6, delay: 0.2 }}
          className="w-full max-w-md mx-auto">
          
          <div className="mb-10 text-center lg:text-left">
            <h2 className="text-[32px] font-bold text-slate-900 tracking-tight leading-tight">Welcome back</h2>
            <p className="text-slate-500 text-[16px] mt-2 font-medium">Sign in to your SRM student portal.</p>
          </div>

          <LoginForm />
          
        </motion.div>
      </div>

    </div>
  );
}



function LoginForm() {
  const navigate = useNavigate();
  const { login, loginPlacement, setPlacementConnected } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPwd, setShowPwd] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [agreed, setAgreed] = useState(false);

  // Placement connect section
  const [showPlacement, setShowPlacement] = useState(false);
  const [placementUsername, setPlacementUsername] = useState("");
  const [placementPassword, setPlacementPassword] = useState("");
  const [placementLoading, setPlacementLoading] = useState(false);
  const [placementError, setPlacementError] = useState("");
  const [placementConnected, setPlacementConnectedLocal] = useState(false);

  const usernamePlaceholders = [
    "e.g. ready for placements?",
    "e.g. checking those marks...",
    "e.g. what's the next interview?",
    "e.g. aiming for 100% attendance?"
  ];
  
  const passwordPlaceholders = [
    "Enter your super secret password",
    "Password goes here...",
    "Shh... keep it safe",
    "Unlock your portal"
  ];

  const [placeholderIdx, setPlaceholderIdx] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setPlaceholderIdx((prev) => (prev + 1) % usernamePlaceholders.length);
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    if (!username || !password) { setError("Please fill in all fields."); return; }
    if (!agreed) { setError("Please accept the Terms of Service and Privacy Policy to continue."); return; }
    const email = `${username.trim().toLowerCase()}@srmist.edu.in`;
    setLoading(true);
    try {
      await api.login(email, password);
      login(email);

      // Attempt silent placement auto-login (non-blocking — don't fail academia login if placement fails)
      try {
        const result = await placementApi.autoLogin(email);
        if (result.connected && result.username) {
          loginPlacement(result.username);
          setPlacementConnected(true);
        }
      } catch {
        // Placement not connected or auto-login failed — user can connect later
      }

      navigate("/dashboard", { replace: true });
    } catch (err) {
      setError(err.message || "Login failed. Check your credentials.");
      setLoading(false);
    }
  };

  const handlePlacementConnect = async (e) => {
    e.preventDefault();
    setPlacementError("");
    if (!placementUsername || !placementPassword) {
      setPlacementError("Please fill in placement credentials.");
      return;
    }
    const email = `${username.trim().toLowerCase()}@srmist.edu.in`;
    setPlacementLoading(true);
    try {
      const result = await placementApi.connect(email, placementUsername.trim(), placementPassword);
      if (result.username) {
        loginPlacement(result.username);
        setPlacementConnected(true);
        setPlacementConnectedLocal(true);
      }
    } catch (err) {
      setPlacementError(err.message || "Failed to connect placement account.");
    } finally {
      setPlacementLoading(false);
    }
  };

  return (
    <>
      <AnimatePresence>
        {error && (
          <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }} className="overflow-hidden mb-6">
            <div className="px-4 py-3 rounded-2xl text-[14px] font-medium text-red-600 bg-red-50 border border-red-100 flex items-center gap-2">
              <span className="w-1.5 h-1.5 rounded-full bg-red-500 flex-shrink-0" />
              {error}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <form onSubmit={handleSubmit} className="flex flex-col gap-6">
        <div>
          <label className="block text-[12px] font-bold text-slate-500 uppercase tracking-wider mb-2 ml-1">Student ID</label>
          <div className="relative group">
            <input type="text" value={username} onChange={(e) => setUsername(e.target.value)}
              placeholder={usernamePlaceholders[placeholderIdx]} autoCapitalize="none" autoCorrect="off"
              className="w-full pl-6 pr-32 py-4 rounded-full text-[15px] font-medium outline-none transition-all border border-slate-200 bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-slate-900 placeholder:text-slate-400 focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50" />
            <span className="absolute right-6 top-1/2 -translate-y-1/2 text-slate-400 text-[14px] font-medium pointer-events-none select-none group-focus-within:text-slate-600 transition-colors">@srmist.edu.in</span>
          </div>
        </div>

        <div>
          <label className="block text-[12px] font-bold text-slate-500 uppercase tracking-wider mb-2 ml-1">Password</label>
          <div className="relative group">
            <input type={showPwd ? "text" : "password"} value={password}
              onChange={(e) => setPassword(e.target.value)} placeholder={passwordPlaceholders[placeholderIdx]}
              className="w-full pl-6 pr-14 py-4 rounded-full text-[15px] font-medium outline-none transition-all border border-slate-200 bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-slate-900 placeholder:text-slate-400 focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50" />
            <button type="button" onClick={() => setShowPwd(!showPwd)}
              className="absolute right-5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-700 transition-colors focus:outline-none p-1 rounded-full cursor-pointer">
              {showPwd ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>
        </div>

        <label className="flex items-start gap-3 mt-2 cursor-pointer select-none group">
          <input
            type="checkbox"
            checked={agreed}
            onChange={(e) => setAgreed(e.target.checked)}
            className="mt-0.5 w-[18px] h-[18px] rounded-[6px] border-2 border-slate-300 text-[#1A1A1A] focus:ring-2 focus:ring-slate-200 focus:ring-offset-0 cursor-pointer flex-shrink-0 accent-[#1A1A1A]"
          />
          <span className="text-[13px] text-slate-500 font-medium leading-relaxed">
            I agree to the{" "}
            <Link to="/terms" className="text-slate-700 hover:text-slate-900 underline underline-offset-2 font-semibold">
              Terms of Service
            </Link>{" "}
            and{" "}
            <Link to="/privacy" className="text-slate-700 hover:text-slate-900 underline underline-offset-2 font-semibold">
              Privacy Policy
            </Link>
            .
          </span>
        </label>

        <motion.button
          whileHover={{ scale: 1.01 }}
          whileTap={{ scale: 0.98 }}
          type="submit" disabled={loading || !agreed}
          className="w-full flex items-center justify-center gap-2 py-4 mt-2 rounded-full font-bold text-white text-[15px] bg-[#1A1A1A] hover:bg-black transition-colors disabled:opacity-40 disabled:cursor-not-allowed shadow-[0_8px_20px_rgba(0,0,0,0.12)] cursor-pointer">
          {loading ? <><Loader2 size={18} className="animate-spin" /> Signing in…</> : "Sign In to Portal"}
        </motion.button>
      </form>

      {/* Optional Placement Connect Section */}
      <div className="mt-8 pt-6 border-t border-slate-100">
        <button
          type="button"
          onClick={() => setShowPlacement(!showPlacement)}
          className="w-full flex items-center justify-between text-left cursor-pointer group"
        >
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
              <Briefcase size={15} className="text-slate-500" />
            </div>
            <div>
              <p className="text-[14px] font-bold text-slate-700">
                {placementConnected ? "Placement Connected" : "Track Placements?"}
              </p>
              <p className="text-[12px] text-slate-400 font-medium">
                {placementConnected ? "Auto-login enabled" : "Connect your Haveloc account (optional)"}
              </p>
            </div>
          </div>
          {showPlacement ? <ChevronUp size={18} className="text-slate-400 group-hover:text-slate-600" /> : <ChevronDown size={18} className="text-slate-400 group-hover:text-slate-600" />}
        </button>

        <AnimatePresence>
          {showPlacement && !placementConnected && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              className="overflow-hidden mt-4"
            >
              <form onSubmit={handlePlacementConnect} className="flex flex-col gap-4">
                {placementError && (
                  <div className="px-4 py-3 rounded-2xl text-[13px] font-medium text-red-600 bg-red-50 border border-red-100 flex items-center gap-2">
                    <span className="w-1.5 h-1.5 rounded-full bg-red-500 flex-shrink-0" />
                    {placementError}
                  </div>
                )}
                <div>
                  <label className="block text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1.5 ml-1">Roll Number</label>
                  <input
                    type="text"
                    value={placementUsername}
                    onChange={(e) => setPlacementUsername(e.target.value)}
                    placeholder="RA2311056010266"
                    autoCapitalize="none"
                    className="w-full px-5 py-3.5 rounded-full text-[14px] font-medium outline-none transition-all border border-slate-200 bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-slate-900 placeholder:text-slate-400 focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1.5 ml-1">Placement Password</label>
                  <input
                    type="password"
                    value={placementPassword}
                    onChange={(e) => setPlacementPassword(e.target.value)}
                    placeholder="Haveloc password"
                    className="w-full px-5 py-3.5 rounded-full text-[14px] font-medium outline-none transition-all border border-slate-200 bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-slate-900 placeholder:text-slate-400 focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50"
                  />
                </div>
                <p className="text-[11px] text-slate-400 font-medium leading-relaxed px-1">
                  Your placement credentials are encrypted and stored securely. You'll be auto-logged in on future visits. You can disconnect anytime from the Placement portal.
                </p>
                <button
                  type="submit"
                  disabled={placementLoading}
                  className="w-full flex items-center justify-center gap-2 py-3.5 rounded-full font-bold text-white text-[14px] bg-slate-700 hover:bg-slate-800 transition-colors disabled:opacity-40 cursor-pointer"
                >
                  {placementLoading ? <><Loader2 size={16} className="animate-spin" /> Connecting…</> : "Connect Placement"}
                </button>
              </form>
            </motion.div>
          )}
          {showPlacement && placementConnected && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              className="overflow-hidden mt-4"
            >
              <div className="px-4 py-4 rounded-2xl bg-green-50 border border-green-100 flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center flex-shrink-0">
                  <Sparkles size={15} className="text-green-600" />
                </div>
                <div>
                  <p className="text-[13px] font-bold text-green-700">Placement account connected!</p>
                  <p className="text-[12px] text-green-600 font-medium">You'll be auto-logged in when you sign in to the portal.</p>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </>
  );
}
