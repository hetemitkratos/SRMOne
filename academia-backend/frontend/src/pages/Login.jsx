import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useNavigate, Link } from "react-router-dom";
import { Loader2, Eye, EyeOff, ChevronDown, ChevronUp, CalendarCheck } from "lucide-react";
import { api } from "../api/client.js";
import { useAuth } from "../hooks/useAuth.jsx";

function LogoMark({ size = 40 }) {
  return (
    <img
      src="/assets/logo.png"
      alt="SRM One logo"
      style={{ width: size, height: size, objectFit: "contain", flexShrink: 0 }}
    />
  );
}

export default function Login() {
  const { user, autoLogin, autoLoggingIn } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (user) {
      // Try auto-login with stored credentials
      autoLogin(user.email).then((success) => {
        if (success) {
          navigate("/dashboard", { replace: true });
        }
      });
    }
  }, [user, autoLogin, navigate]);

  return (
    <div className="min-h-screen bg-[#F4F0EB] font-sans text-slate-900 lg:grid lg:grid-cols-2 relative overflow-x-hidden">
      {/* ─── DESKTOP LEFT: branding ─── */}
      <div className="hidden lg:flex flex-col justify-between bg-[#F8F6F0] text-slate-900 p-12 xl:p-16 relative overflow-hidden">
        <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-orange-200/20 rounded-full blur-[100px] pointer-events-none" />
        <div className="absolute bottom-[-10%] right-[-5%] w-[30%] h-[40%] bg-[#BDE3D5]/30 rounded-full blur-[100px] pointer-events-none" />

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="relative z-10 flex items-center gap-3"
        >
          <LogoMark size={36} />
          <span className="font-display font-bold text-[22px] tracking-tight text-slate-800">SRM One</span>
        </motion.div>

        <div className="relative z-10 max-w-lg mt-12">
          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="text-[3.5rem] xl:text-[4.5rem] leading-[1.05] font-display font-bold tracking-tight text-slate-900 mb-6"
          >
            Your Academic
            <br />
            Life, <span className="text-[#D97757]">Simplified.</span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-[17px] text-slate-600 leading-relaxed font-medium"
          >
            Personalized dashboards for attendance, marks, and timetable — all in one place.
          </motion.p>
        </div>

        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.8, delay: 0.3 }}
          className="relative z-10 flex-1 flex items-center justify-center mt-12 w-full max-w-[500px] mx-auto lg:mx-0"
        >
          <img
            src="/assets/online-learning.svg"
            alt="Academic life illustration"
            className="w-full h-auto drop-shadow-xl mix-blend-multiply"
          />
        </motion.div>
      </div>

      {/* ─── MOBILE HERO + FORM / DESKTOP FORM ─── */}
      <div className="flex flex-col min-h-screen lg:min-h-0 lg:justify-center relative z-10">
        {/* Auto-login overlay */}
        {autoLoggingIn && (
          <div className="absolute inset-0 z-50 flex items-center justify-center bg-white/80 backdrop-blur-sm">
            <div className="flex flex-col items-center gap-3">
              <Loader2 className="w-8 h-8 animate-spin text-[#D97757]" />
              <p className="text-sm font-medium text-slate-600">Reconnecting your session…</p>
            </div>
          </div>
        )}
        {/* Mobile hero — one quiet composition */}
        <div className="lg:hidden px-8 pt-12 pb-2">
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55, ease: [0.22, 1, 0.36, 1] }}
            className="mx-auto w-full max-w-[340px] flex flex-col items-center text-center"
          >
            <div className="flex items-center justify-center gap-3">
              <LogoMark size={40} />
              <span className="font-display font-black text-[28px] tracking-[-0.03em] uppercase text-[#1A1A1A] leading-none">
                SRM One
              </span>
            </div>

            <p className="mt-6 text-[15px] leading-snug text-slate-600 font-medium tracking-tight">
              Attendance, marks
              <br />
              and timetable — in one place.
            </p>

            <motion.div
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.65, delay: 0.12, ease: [0.22, 1, 0.36, 1] }}
              className="mt-8 w-[86%]"
            >
              <img
                src="/assets/studying.svg"
                alt=""
                className="w-full h-auto select-none pointer-events-none"
                draggable={false}
              />
            </motion.div>
          </motion.div>
        </div>

        {/* Form panel */}
        <div className="flex-1 flex flex-col justify-start lg:justify-center px-6 sm:px-10 lg:px-24 xl:px-32 bg-white rounded-t-[32px] lg:rounded-none shadow-[0_-12px_40px_rgba(26,26,26,0.06)] lg:shadow-none pt-8 pb-12 lg:py-12 mt-4 lg:mt-0">
          <motion.div
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.08 }}
            className="w-full max-w-md mx-auto"
          >
            <div className="mb-7">
              <div className="hidden lg:flex items-center gap-2.5 mb-8">
                <LogoMark size={32} />
                <span className="font-display font-bold text-lg text-slate-800">SRM One</span>
              </div>
              <h2 className="text-[24px] sm:text-[30px] font-display font-bold text-[#1A1A1A] tracking-tight leading-none">
                Welcome back
              </h2>
              <p className="text-slate-500 text-[14px] sm:text-[15px] mt-2 font-medium leading-relaxed">
                Sign in with your SRM student ID.
              </p>
            </div>

            <LoginForm />
          </motion.div>
        </div>
      </div>
    </div>
  );
}

function LoginForm() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPwd, setShowPwd] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [agreed, setAgreed] = useState(false);

  // Optional Student Portal password (if different from academia password)
  const [showSpPwd, setShowSpPwd] = useState(false);
  const [spPassword, setSpPassword] = useState("");

  // SP login prompt (shown after academia login if no SP password was provided)
  const [showSpPrompt, setShowSpPrompt] = useState(false);
  const [spPromptPassword, setSpPromptPassword] = useState("");
  const [spPromptLoading, setSpPromptLoading] = useState(false);
  const [spPromptError, setSpPromptError] = useState("");
  const [spPromptCaptchaImg, setSpPromptCaptchaImg] = useState("");
  const [spPromptCaptcha, setSpPromptCaptcha] = useState("");
  const [loggedInEmail, setLoggedInEmail] = useState("");

  const usernamePlaceholders = [
    "e.g. ready for placements?",
    "e.g. checking those marks...",
    "e.g. what's the next interview?",
    "e.g. aiming for 100% attendance?",
  ];

  const passwordPlaceholders = [
    "Enter your super secret password",
    "Password goes here...",
    "Shh... keep it safe",
    "Unlock your portal",
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
    if (!username || !password) {
      setError("Please fill in all fields.");
      return;
    }
    if (!agreed) {
      setError("Please accept the Terms of Service and Privacy Policy to continue.");
      return;
    }
    const email = `${username.trim().toLowerCase()}@srmist.edu.in`;
    setLoading(true);
    try {
      await api.login(email, password, spPassword || undefined);
      login(email);
      setLoggedInEmail(email);

      // If no SP password provided, show prompt after navigating to dashboard
      if (!spPassword) {
        setShowSpPrompt(true);
      }

      navigate("/dashboard", { replace: true });
    } catch (err) {
      setError(err.message || "Login failed. Check your credentials.");
      setLoading(false);
    }
  };

  const handleSpPromptLogin = async (e) => {
    e.preventDefault();
    if (!spPromptPassword) {
      setSpPromptError("Please enter your Student Portal password.");
      return;
    }
    setSpPromptLoading(true);
    setSpPromptError("");
    try {
      const result = await api.spLogin(loggedInEmail, spPromptPassword);
      if (result.captchaRequired) {
        setSpPromptCaptchaImg(result.captchaImage);
        setSpPromptCaptcha("");
      } else {
        setShowSpPrompt(false);
        setSpPromptPassword("");
        setSpPromptCaptchaImg("");
        setSpPromptCaptcha("");
      }
    } catch (err) {
      setSpPromptError(err.message || "Student Portal login failed. Check your SP password.");
    } finally {
      setSpPromptLoading(false);
    }
  };

  const handleSpPromptCaptcha = async (e) => {
    e.preventDefault();
    if (!spPromptCaptcha.trim()) {
      setSpPromptError("Please type the captcha text.");
      return;
    }
    setSpPromptLoading(true);
    setSpPromptError("");
    try {
      const result = await api.spSolveCaptcha(loggedInEmail, spPromptCaptcha.trim());
      if (result.captchaRequired) {
        setSpPromptCaptchaImg(result.captchaImage);
        setSpPromptCaptcha("");
        setSpPromptError(result.message || "Solve the new captcha to continue.");
      } else {
        setShowSpPrompt(false);
        setSpPromptPassword("");
        setSpPromptCaptchaImg("");
        setSpPromptCaptcha("");
      }
    } catch (err) {
      setSpPromptCaptchaImg("");
      setSpPromptCaptcha("");
      setSpPromptError(err.message || "Captcha verification failed.");
    } finally {
      setSpPromptLoading(false);
    }
  };

  return (
    <>
      <AnimatePresence>
        {error && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            className="overflow-hidden mb-5"
          >
            <div className="px-4 py-3 rounded-2xl text-[14px] font-medium text-red-600 bg-red-50 border border-red-100 flex items-center gap-2">
              <span className="w-1.5 h-1.5 rounded-full bg-red-500 flex-shrink-0" />
              {error}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <form onSubmit={handleSubmit} className="flex flex-col gap-5">
        <div>
          <label className="block text-[11px] sm:text-[12px] font-bold text-slate-500 uppercase tracking-wider mb-2 ml-1">
            Student ID
          </label>
          <div className="relative group">
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder={usernamePlaceholders[placeholderIdx]}
              autoCapitalize="none"
              autoCorrect="off"
              className="w-full pl-5 sm:pl-6 pr-[7.5rem] sm:pr-32 py-3.5 sm:py-4 rounded-full text-[15px] font-medium outline-none transition-all border border-slate-200 bg-[#F8F6F0]/60 lg:bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-slate-900 placeholder:text-slate-400 focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50 focus:bg-white"
            />
            <span className="absolute right-4 sm:right-6 top-1/2 -translate-y-1/2 text-slate-400 text-[12px] sm:text-[14px] font-medium pointer-events-none select-none group-focus-within:text-slate-600 transition-colors">
              @srmist.edu.in
            </span>
          </div>
        </div>

        <div>
          <label className="block text-[11px] sm:text-[12px] font-bold text-slate-500 uppercase tracking-wider mb-2 ml-1">
            Password
          </label>
          <div className="relative group">
            <input
              type={showPwd ? "text" : "password"}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder={passwordPlaceholders[placeholderIdx]}
              className="w-full pl-5 sm:pl-6 pr-14 py-3.5 sm:py-4 rounded-full text-[15px] font-medium outline-none transition-all border border-slate-200 bg-[#F8F6F0]/60 lg:bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-slate-900 placeholder:text-slate-400 focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50 focus:bg-white"
            />
            <button
              type="button"
              onClick={() => setShowPwd(!showPwd)}
              className="absolute right-4 sm:right-5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-700 transition-colors focus:outline-none p-1 rounded-full cursor-pointer"
            >
              {showPwd ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>
        </div>

        <label className="flex items-start gap-3 mt-1 cursor-pointer select-none group">
          <input
            type="checkbox"
            checked={agreed}
            onChange={(e) => setAgreed(e.target.checked)}
            className="mt-0.5 w-[18px] h-[18px] rounded-[6px] border-2 border-slate-300 text-[#1A1A1A] focus:ring-2 focus:ring-slate-200 focus:ring-offset-0 cursor-pointer flex-shrink-0 accent-[#1A1A1A]"
          />
          <span className="text-[13px] text-slate-500 font-medium leading-relaxed">
            I agree to the{" "}
            <Link
              to="/terms"
              className="text-slate-700 hover:text-slate-900 underline underline-offset-2 font-semibold"
            >
              Terms of Service
            </Link>{" "}
            and{" "}
            <Link
              to="/privacy"
              className="text-slate-700 hover:text-slate-900 underline underline-offset-2 font-semibold"
            >
              Privacy Policy
            </Link>
            .
          </span>
        </label>

        <motion.button
          whileHover={{ scale: 1.01 }}
          whileTap={{ scale: 0.98 }}
          type="submit"
          disabled={loading || !agreed}
          className="w-full flex items-center justify-center gap-2 py-4 mt-1 rounded-full font-bold text-white text-[15px] bg-[#1A1A1A] hover:bg-black transition-colors disabled:opacity-40 disabled:cursor-not-allowed shadow-[0_8px_20px_rgba(0,0,0,0.12)] cursor-pointer"
        >
          {loading ? (
            <>
              <Loader2 size={18} className="animate-spin" /> Signing in…
            </>
          ) : (
            "Sign In to Portal"
          )}
        </motion.button>
      </form>

      {/* Optional: Different Student Portal password */}
      <div className="mt-5">
        <button
          type="button"
          onClick={() => setShowSpPwd(!showSpPwd)}
          className="w-full flex items-center justify-between text-left cursor-pointer group"
        >
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-full bg-[#F4F0EB] flex items-center justify-center">
              <CalendarCheck size={16} className="text-slate-500" />
            </div>
            <div>
              <p className="text-[14px] font-bold text-slate-700">
                {spPassword ? "Student Portal password set" : "Different Student Portal password?"}
              </p>
              <p className="text-[12px] text-slate-400 font-medium">
                {spPassword ? "Will use this for SP login" : "Only if your SP password differs (optional)"}
              </p>
            </div>
          </div>
          {showSpPwd ? (
            <ChevronUp size={18} className="text-slate-400 group-hover:text-slate-600" />
          ) : (
            <ChevronDown size={18} className="text-slate-400 group-hover:text-slate-600" />
          )}
        </button>

        <AnimatePresence>
          {showSpPwd && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              className="overflow-hidden mt-4"
            >
              <div>
                <label className="block text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1.5 ml-1">
                  Student Portal Password
                </label>
                <input
                  type="password"
                  value={spPassword}
                  onChange={(e) => setSpPassword(e.target.value)}
                  placeholder="Leave empty to use same password"
                  className="w-full px-5 py-3.5 rounded-full text-[14px] font-medium outline-none transition-all border border-slate-200 bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-slate-900 placeholder:text-slate-400 focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50"
                />
                <p className="text-[11px] text-slate-400 font-medium leading-relaxed px-1 mt-2">
                  If your Student Portal (sp.srmist.edu.in) password is different from your academia password, enter it here. We'll only try once to avoid lockout.
                </p>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Student Portal Login Prompt */}
      <AnimatePresence>
        {showSpPrompt && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm"
            onClick={() => setShowSpPrompt(false)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              onClick={(e) => e.stopPropagation()}
              className="bg-white rounded-3xl p-7 max-w-md w-full mx-4 shadow-2xl"
            >
              <div className="flex items-center gap-3 mb-4">
                <div className="w-11 h-11 rounded-full bg-amber-50 flex items-center justify-center">
                  <CalendarCheck size={20} className="text-amber-600" />
                </div>
                <div>
                  <h3 className="text-[16px] font-bold text-slate-800">Student Portal Login</h3>
                  <p className="text-[12px] text-slate-400 font-medium">Required for attendance data</p>
                </div>
              </div>

              <p className="text-[13px] text-slate-500 font-medium leading-relaxed mb-4">
                Your Student Portal password may be different from your academia password. Enter it below to fetch attendance. We'll only try once to avoid lockout.
              </p>

              {spPromptError && (
                <div className="mb-3 px-4 py-2.5 rounded-xl bg-red-50 border border-red-100 text-[12px] font-medium text-red-600">
                  {spPromptError}
                </div>
              )}

              <form onSubmit={spPromptCaptchaImg ? handleSpPromptCaptcha : handleSpPromptLogin}>
                <input
                  type="password"
                  value={spPromptPassword}
                  onChange={(e) => setSpPromptPassword(e.target.value)}
                  placeholder="Student Portal password"
                  autoFocus
                  className="w-full px-5 py-3.5 rounded-full text-[14px] font-medium outline-none transition-all border border-slate-200 bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-slate-900 placeholder:text-slate-400 focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50 mb-4"
                />
                {spPromptCaptchaImg && (
                  <div className="mb-4">
                    <div className="flex items-center justify-between mb-2">
                      <p className="text-[12px] text-slate-500 font-medium">
                        Type the text in this image — <span className="font-bold">case-sensitive</span>
                      </p>
                      <button
                        type="button"
                        onClick={async () => {
                          try {
                            const r = await api.spRefreshCaptcha(loggedInEmail);
                            if (r.captchaRequired) {
                              setSpPromptCaptchaImg(r.captchaImage);
                              setSpPromptCaptcha("");
                            }
                          } catch { /* keep current captcha */ }
                        }}
                        className="text-slate-500 text-[12px] font-bold hover:text-slate-800"
                      >
                        New image
                      </button>
                    </div>
                    <img
                      src={spPromptCaptchaImg}
                      alt="Student Portal captcha"
                      className="h-16 rounded-xl border border-slate-200 bg-white mb-3"
                    />
                    <input
                      type="text"
                      value={spPromptCaptcha}
                      onChange={(e) => setSpPromptCaptcha(e.target.value)}
                      placeholder="Captcha text"
                      autoCapitalize="none"
                      autoCorrect="off"
                      spellCheck={false}
                      className="w-full px-5 py-3.5 rounded-full text-[16px] tracking-widest font-mono font-medium outline-none transition-all border border-slate-200 bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)] text-slate-900 placeholder:text-slate-400 placeholder:tracking-normal placeholder:font-sans placeholder:text-[14px] focus:border-slate-300 focus:ring-4 focus:ring-slate-100/50"
                    />
                  </div>
                )}
                <div className="flex gap-3">
                  <button
                    type="button"
                    onClick={() => setShowSpPrompt(false)}
                    className="flex-1 py-3.5 rounded-full font-bold text-[14px] text-slate-500 bg-slate-100 hover:bg-slate-200 transition-colors cursor-pointer"
                  >
                    Skip for now
                  </button>
                  <button
                    type="submit"
                    disabled={spPromptLoading}
                    className="flex-1 flex items-center justify-center gap-2 py-3.5 rounded-full font-bold text-white text-[14px] bg-slate-700 hover:bg-slate-800 transition-colors disabled:opacity-40 cursor-pointer"
                  >
                    {spPromptLoading ? (
                      <><Loader2 size={16} className="animate-spin" /> Logging in…</>
                    ) : (
                      "Login & Fetch"
                    )}
                  </button>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
