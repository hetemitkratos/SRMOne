/**
 * useNotifications hook - Real-time notifications via Supabase Realtime
 */
import { useState, useEffect, useCallback } from "react";
import { api } from "../api/client.js";
import { useAuth } from "./useAuth.jsx";
import supabase from "../utils/supabaseClient.js";

export function useNotifications() {
  const { user } = useAuth();
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);

  // Load notifications on mount
  useEffect(() => {
    if (!user?.email) {
      setLoading(false);
      return;
    }

    api
      .getNotifications(user.email, false)
      .then((res) => {
        const notifs = res.data || [];
        setNotifications(notifs);
        setUnreadCount(notifs.filter((n) => !n.read).length);
        setLoading(false);
      })
      .catch((err) => {
        console.error("Failed to load notifications:", err);
        setLoading(false);
      });
  }, [user?.email]);

  // Subscribe to real-time notifications
  useEffect(() => {
    if (!user?.email || !supabase) return;

    const channel = supabase
      .channel(`notifications:${user.email}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "notifications",
          filter: `academia_email=eq.${user.email}`,
        },
        (payload) => {
          const newNotif = payload.new;
          setNotifications((prev) => [newNotif, ...prev]);
          if (!newNotif.read) {
            setUnreadCount((prev) => prev + 1);
          }
        }
      )
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "notifications",
          filter: `academia_email=eq.${user.email}`,
        },
        (payload) => {
          const updated = payload.new;
          setNotifications((prev) =>
            prev.map((n) => (n.id === updated.id ? updated : n))
          );
          if (updated.read) {
            setUnreadCount((prev) => Math.max(0, prev - 1));
          }
        }
      )
      .subscribe();

    return () => {
      if (supabase) supabase.removeChannel(channel);
    };
  }, [user?.email]);

  const markAsRead = useCallback(
    async (id) => {
      if (!user?.email) return;
      try {
        await api.markNotificationRead(id);
        setNotifications((prev) =>
          prev.map((n) => (n.id === id ? { ...n, read: true } : n))
        );
        setUnreadCount((prev) => Math.max(0, prev - 1));
      } catch (err) {
        console.error("Failed to mark notification as read:", err);
      }
    },
    [user?.email]
  );

  const markAllAsRead = useCallback(async () => {
    if (!user?.email) return;
    try {
      await api.markAllNotificationsRead(user.email);
      setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
      setUnreadCount(0);
    } catch (err) {
      console.error("Failed to mark all notifications as read:", err);
    }
  }, [user?.email]);

  return {
    notifications,
    unreadCount,
    loading,
    markAsRead,
    markAllAsRead,
  };
}
