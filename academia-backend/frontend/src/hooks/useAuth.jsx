import { createContext, useContext, useState, useCallback } from "react";
import { api } from "../api/client.js";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem("srm_user");
    return saved ? JSON.parse(saved) : null;
  });

  const [autoLoggingIn, setAutoLoggingIn] = useState(false);

  const login = useCallback((email) => {
    const u = { email };
    localStorage.setItem("srm_user", JSON.stringify(u));
    setUser(u);
  }, []);

  const autoLogin = useCallback(async (email) => {
    setAutoLoggingIn(true);
    try {
      await api.autoLogin(email);
      const u = { email };
    localStorage.setItem("srm_user", JSON.stringify(u));
    setUser(u);
      return true;
    } catch {
      // Auto-login failed — clear stored user so they see the login form
      localStorage.removeItem("srm_user");
      setUser(null);
      return false;
    } finally {
      setAutoLoggingIn(false);
    }
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem("srm_user");
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider value={{
      user, login, autoLogin, logout,
      autoLoggingIn,
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
