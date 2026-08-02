import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, Loader2, Eye, EyeOff } from "lucide-react";
import { useAuth } from "../hooks/useAuth.jsx";
import { placementApi } from "../api/placementClient.js";

export default function PlacementLoginModal({ onClose, onSuccess }) {
  const { loginPlacement } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPwd, setShowPwd] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [mfaRequired, setMfaRequired] = useState(false);
  const [mfaToken, setMfaToken] = useState("");
  const [totpCode, setTotpCode] = useState("");
  const [emailOtp, setEmailOtp] = useState("");

  const finishLogin = (usernameValue) => {
    loginPlacement(usernameValue);
    if (onSuccess) onSuccess(usernameValue);
    else onClose();
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    setError("");
    if (!username || !password) { setError("Please fill in all fields."); return; }
    setLoading(true);
    try {
      const result = await placementApi.login(username.trim(), password);
      if (result.requiresMfa) {
        setMfaToken(result.mfaToken);
        setMfaRequired(true);
      } else {
        finishLogin(username.trim());
      }
    } catch (err) {
      setError(err.message || "Login failed.");
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyMfa = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await placementApi.verifyMfa(username.trim(), mfaToken, totpCode, emailOtp);
      finishLogin(username.trim());
    } catch (err) {
      setError(err.message || "MFA verification failed.");
    } finally {
      setLoading(false);
    }
  };

  const handleSendMfaEmail = async () => {
    setError("");
    try {
      await placementApi.sendMfaEmail(mfaToken);
      setError("Email OTP sent. Check your inbox.");
    } catch (err) {
      setError(err.message || "Failed to send OTP.");
    }
  };

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <motion.div
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
          className="absolute inset-0 bg-slate-900/40 backdrop-blur-sm"
          onClick={onClose}
        />
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 20 }}
          className="relative bg-white rounded-[28px] shadow-2xl p-8 w-full max-w-md z-10"
        >
          <button onClick={onClose} className="absolute top-5 right-5 text-slate-400 hover:text-slate-700 bg-slate-100 hover:bg-slate-200 p-2.5 rounded-full cursor-pointer transition-colors">
            <X size={18} />
          </button>

          <div className="mb-6">
            <h2 className="text-2xl font-bold text-slate-900 tracking-tight text-center">
              {mfaRequired ? "Verify MFA" : "Placement Login"}
            </h2>
            <p className="text-slate-500 text-sm mt-2 text-center">
              {mfaRequired ? "Enter your TOTP or email OTP code." : "Sign in with your Haveloc placement credentials."}
            </p>
          </div>

          <AnimatePresence>
            {error && (
              <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }} className="overflow-hidden mb-4">
                <div className="px-4 py-3 rounded-xl text-[13px] font-medium text-red-600 bg-red-50 border border-red-100">
                  {error}
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {!mfaRequired ? (
            <form onSubmit={handleLogin} className="flex flex-col gap-4">
              <div>
                <label className="block text-[12px] font-bold text-slate-700 uppercase tracking-wide mb-1.5">Roll Number</label>
                <input type="text" value={username} onChange={(e) => setUsername(e.target.value)}
                  placeholder="RA2311056010266" autoCapitalize="none"
                  className="w-full px-4 py-3 rounded-xl text-[14px] outline-none border-2 border-slate-100 bg-slate-50 text-slate-900 placeholder:text-slate-400 focus:border-[#60a5fa] focus:bg-white" />
              </div>
              <div>
                <label className="block text-[12px] font-bold text-slate-700 uppercase tracking-wide mb-1.5">Password</label>
                <div className="relative">
                  <input type={showPwd ? "text" : "password"} value={password}
                    onChange={(e) => setPassword(e.target.value)} placeholder="Enter password"
                    className="w-full px-4 py-3 pr-11 rounded-xl text-[14px] outline-none border-2 border-slate-100 bg-slate-50 text-slate-900 placeholder:text-slate-400 focus:border-[#60a5fa] focus:bg-white" />
                  <button type="button" onClick={() => setShowPwd(!showPwd)}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 cursor-pointer">
                    {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>
              <button type="submit" disabled={loading}
                className="w-full flex items-center justify-center gap-2 py-3.5 mt-1 rounded-xl font-bold text-white text-[14px] bg-slate-900 hover:bg-black transition-transform active:scale-[0.98] disabled:opacity-60 cursor-pointer">
                {loading ? <><Loader2 size={16} className="animate-spin" /> Signing in…</> : "Connect"}
              </button>
            </form>
          ) : (
            <form onSubmit={handleVerifyMfa} className="flex flex-col gap-4">
              <div>
                <label className="block text-[12px] font-bold text-slate-700 uppercase tracking-wide mb-1.5">TOTP Code</label>
                <input type="text" value={totpCode} onChange={(e) => setTotpCode(e.target.value)}
                  placeholder="6-digit code from authenticator app" autoCapitalize="none"
                  className="w-full px-4 py-3 rounded-xl text-[14px] outline-none border-2 border-slate-100 bg-slate-50 text-slate-900 placeholder:text-slate-400 focus:border-[#60a5fa] focus:bg-white font-mono tracking-wider" />
              </div>
              <div className="flex items-center gap-3">
                <div className="flex-1 h-px bg-slate-200" />
                <span className="text-[11px] text-slate-400 font-medium">OR</span>
                <div className="flex-1 h-px bg-slate-200" />
              </div>
              <div>
                <label className="block text-[12px] font-bold text-slate-700 uppercase tracking-wide mb-1.5">Email OTP</label>
                <input type="text" value={emailOtp} onChange={(e) => setEmailOtp(e.target.value)}
                  placeholder="Email OTP code" autoCapitalize="none"
                  className="w-full px-4 py-3 rounded-xl text-[14px] outline-none border-2 border-slate-100 bg-slate-50 text-slate-900 placeholder:text-slate-400 focus:border-[#60a5fa] focus:bg-white font-mono tracking-wider" />
              </div>
              <button type="button" onClick={handleSendMfaEmail}
                className="text-[13px] font-semibold text-[#60a5fa] hover:text-[#3d6bb8] transition-colors text-left cursor-pointer">
                Send Email OTP →
              </button>
              <button type="submit" disabled={loading}
                className="w-full flex items-center justify-center gap-2 py-3.5 mt-1 rounded-xl font-bold text-white text-[14px] bg-slate-900 hover:bg-black transition-transform active:scale-[0.98] disabled:opacity-60 cursor-pointer">
                {loading ? <><Loader2 size={16} className="animate-spin" /> Verifying…</> : "Verify"}
              </button>
            </form>
          )}
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
