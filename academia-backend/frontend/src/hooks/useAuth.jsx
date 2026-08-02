import { createContext, useContext, useState, useCallback } from "react";

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

  const login = useCallback((email) => {
    const u = { email };
    localStorage.setItem("srm_user", JSON.stringify(u));
    setUser(u);
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
    setUser(null);
  }, []);

  const logoutPlacement = useCallback(() => {
    localStorage.removeItem("placement_user");
    setPlacementUser(null);
  }, []);

  return (
    <AuthContext.Provider value={{
      user, login, logout,
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
