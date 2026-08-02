/**
 * PlacementConnectModal - Connects placement account (stores credentials + auto-login)
 * Different from PlacementLoginModal which only does a one-time login without storing.
 */
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, Loader2, Eye, EyeOff, Briefcase, CheckCircle2, Shield } from "lucide-react";
import { useAuth } from "../hooks/useAuth.jsx";
import { placementApi } from "../api/placementClient.js";

export default function PlacementConnectModal({ onClose, onSuccess }) {
  const { user, loginPlacement, setPlacementConnected } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPwd, setShowPwd] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  const handleConnect = async (e) => {
    e.preventDefault();
    setError("");
    if (!username || !password) {
      setError("Please fill in all fields.");
      return;
    }
    if (!user?.email) {
      setError("Academia session not found. Please login first.");
      return;
    }
    setLoading(true);
    try {
      // 1. Store credentials in Supabase (encrypted)
      const connectResult = await placementApi.connect(user.email, username.trim(), password);
      // 2. Auto-login to establish session
      const loginResult = await placementApi.autoLogin(user.email);
      if (loginResult.connected && loginResult.username) {
        loginPlacement(loginResult.username);
        setPlacementConnected(true);
        setSuccess(true);
        setTimeout(() => {
          if (onSuccess) onSuccess(loginResult.username);
          else onClose();
        }, 1500);
      } else {
        throw new Error("Connection stored but auto-login failed. Try again from Placement portal.");
      }
    } catch (err) {
      setError(err.message || "Failed to connect placement account.");
    } finally {
      setLoading(false);
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
          <button
            onClick={onClose}
            className="absolute top-5 right-5 text-slate-400 hover:text-slate-700 bg-slate-100 hover:bg-slate-200 p-2.5 rounded-full cursor-pointer transition-colors"
          >
            <X size={18} />
          </button>

          {success ? (
            <div className="text-center py-8">
              <div className="w-16 h-16 rounded-full bg-mint/20 flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 size={32} className="text-mint" />
              </div>
              <h2 className="text-2xl font-bold text-slate-900 tracking-tight mb-2">
                Connected!
              </h2>
              <p className="text-slate-500 text-sm">
                Your placement account is now linked. You'll be auto-logged in on future visits.
              </p>
            </div>
          ) : (
            <>
              <div className="mb-6">
                <div className="w-12 h-12 rounded-2xl bg-[#1A1A1A] flex items-center justify-center mx-auto mb-4">
                  <Briefcase size={22} className="text-white" />
                </div>
                <h2 className="text-2xl font-bold text-slate-900 tracking-tight text-center">
                  Connect Placement
                </h2>
                <p className="text-slate-500 text-sm mt-2 text-center">
                  Link your Haveloc account once for auto-login on every visit.
                </p>
              </div>

              <AnimatePresence>
                {error && (
                  <motion.div
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: "auto" }}
                    exit={{ opacity: 0, height: 0 }}
                    className="overflow-hidden mb-4"
                  >
                    <div className="px-4 py-3 rounded-xl text-[13px] font-medium text-red-600 bg-red-50 border border-red-100">
                      {error}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>

              <form onSubmit={handleConnect} className="flex flex-col gap-4">
                <div>
                  <label className="block text-[12px] font-bold text-slate-700 uppercase tracking-wide mb-1.5">
                    Roll Number
                  </label>
                  <input
                    type="text"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    placeholder="RA2311056010266"
                    autoCapitalize="none"
                    className="w-full px-4 py-3 rounded-xl text-[14px] outline-none border-2 border-slate-100 bg-slate-50 text-slate-900 placeholder:text-slate-400 focus:border-[#1A1A1A] focus:bg-white transition-colors"
                  />
                </div>
                <div>
                  <label className="block text-[12px] font-bold text-slate-700 uppercase tracking-wide mb-1.5">
                    Placement Password
                  </label>
                  <div className="relative">
                    <input
                      type={showPwd ? "text" : "password"}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Haveloc password"
                      className="w-full px-4 py-3 pr-11 rounded-xl text-[14px] outline-none border-2 border-slate-100 bg-slate-50 text-slate-900 placeholder:text-slate-400 focus:border-[#1A1A1A] focus:bg-white transition-colors"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPwd(!showPwd)}
                      className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 cursor-pointer"
                    >
                      {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>

                <div className="flex items-start gap-2 px-1">
                  <Shield size={14} className="text-slate-400 mt-0.5 flex-shrink-0" />
                  <p className="text-[11px] text-slate-400 font-medium leading-relaxed">
                    Credentials are encrypted with AES-256 and stored securely. You can disconnect anytime from the Placement portal settings.
                  </p>
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full flex items-center justify-center gap-2 py-3.5 mt-1 rounded-xl font-bold text-white text-[14px] bg-[#1A1A1A] hover:bg-black transition-transform active:scale-[0.98] disabled:opacity-60 cursor-pointer"
                >
                  {loading ? (
                    <>
                      <Loader2 size={16} className="animate-spin" /> Connecting…
                    </>
                  ) : (
                    "Connect & Save"
                  )}
                </button>
              </form>
            </>
          )}
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
