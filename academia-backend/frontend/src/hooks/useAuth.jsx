import { createContext, useContext, useState, useCallback, useEffect, useRef } from "react";
import { api, setSessionToken, clearSessionToken } from "../api/client.js";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem("srm_user");
    return saved ? JSON.parse(saved) : null;
  });

  const [placementUser, setPlacementUser] = useState(() => {
    const saved = localStorage.getItem("placement_user");
    return saved ? JSON.parse(saved) : null;
  });

  // Tracks whether placement credentials are stored in Supabase (one-time connect)
  const [placementConnected, setPlacementConnectedState] = useState(() => {
    return localStorage.getItem("placement_connected") === "true";
  });

  const [autoLoggingIn, setAutoLoggingIn] = useState(false);

  const login = useCallback((email) => {
    const u = { email };
    localStorage.setItem("srm_user", JSON.stringify(u));
    setUser(u);
  }, []);

  const loginWithToken = useCallback((email, token) => {
    const u = { email };
    localStorage.setItem("srm_user", JSON.stringify(u));
    localStorage.setItem("srm_session_token", token);
    setSessionToken(token);
    setUser(u);
  }, []);

  const autoLogin = useCallback(async (email) => {
    setAutoLoggingIn(true);
    try {
      const savedToken = localStorage.getItem("srm_session_token");
      if (savedToken) setSessionToken(savedToken);
      const result = await api.autoLogin(email);
      // api.autoLogin already calls setSessionToken which saves to localStorage
      const u = { email };
      localStorage.setItem("srm_user", JSON.stringify(u));
      setUser(u);
      return true;
    } catch {
      // Auto-login failed — clear stored user so they see the login form
      localStorage.removeItem("srm_user");
      localStorage.removeItem("srm_session_token");
      clearSessionToken();
      setUser(null);
      return false;
    } finally {
      setAutoLoggingIn(false);
    }
  }, []);

  const loginPlacement = useCallback((username) => {
    const u = { username };
    localStorage.setItem("placement_user", JSON.stringify(u));
    setPlacementUser(u);
  }, []);

  const setPlacementConnected = useCallback((connected) => {
    localStorage.setItem("placement_connected", connected ? "true" : "false");
    setPlacementConnectedState(connected);
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem("srm_user");
    localStorage.removeItem("srm_session_token");
    clearSessionToken();
    setUser(null);
  }, []);

  const logoutPlacement = useCallback(() => {
    localStorage.removeItem("placement_user");
    setPlacementUser(null);
  }, []);

  // Proactive token refresh — refresh every 4 hours to keep session alive
  const refreshTimerRef = useRef(null);
  useEffect(() => {
    if (!user?.email) return;
    const refresh = async () => {
      try {
        await api.autoLogin(user.email);
      } catch {
        // Silent fail — 401 retry logic in client.js handles per-request refresh
      }
    };
    refreshTimerRef.current = setInterval(refresh, 4 * 60 * 60 * 1000);
    return () => clearInterval(refreshTimerRef.current);
  }, [user?.email]);

  return (
    <AuthContext.Provider value={{
      user, login, loginWithToken, autoLogin, logout,
      autoLoggingIn,
      placementUser, loginPlacement, logoutPlacement,
      placementConnected, setPlacementConnected,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
