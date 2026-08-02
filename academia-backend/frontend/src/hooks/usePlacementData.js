import { useEffect, useState, useCallback, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/useAuth.jsx";
import { placementApi } from "../api/placementClient.js";

export function usePlacementData(section, options = {}) {
  const { placementUser, logoutPlacement } = useAuth();
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const cooldownRef = useRef(false);
  const fetchedRef = useRef(false);

  const fetchData = useCallback(async (force = false) => {
    if (!placementUser) {
      setError("Not logged in to placement portal");
      setLoading(false);
      return;
    }
    if (cooldownRef.current && !force) return;
    cooldownRef.current = true;
    setLoading(true);
    setError("");
    try {
      if (force) {
        await placementApi.refresh(placementUser.username, section);
      }
      const result = await placementApi[section](placementUser.username, ...(options.args || []));
      if (result.data && result.data.error) {
        setError(result.data.error);
        setData(null);
      } else {
        setData(result.data);
        fetchedRef.current = true;
      }
    } catch (err) {
      // If server is down or auth failed, redirect to placement login
      const errorMsg = err.message || "";
      if (
        errorMsg.includes("backend") ||
        errorMsg.includes("Empty response") ||
        errorMsg.includes("session") ||
        errorMsg.includes("unauthorized") ||
        errorMsg.includes("not logged in") ||
        errorMsg.includes("not authenticated")
      ) {
        logoutPlacement();
        navigate("/placement", { replace: true });
        return;
      }
      setError(err.message);
      setData(null);
    } finally {
      setLoading(false);
      setTimeout(() => { cooldownRef.current = false; }, 2000);
    }
  }, [placementUser, section, logoutPlacement, navigate]);

  useEffect(() => {
    if (placementUser && !fetchedRef.current) {
      fetchData();
    } else if (!placementUser) {
      setLoading(false);
    }
  }, [placementUser, fetchData]);

  return { data, loading, error, refetch: () => fetchData(true) };
}
