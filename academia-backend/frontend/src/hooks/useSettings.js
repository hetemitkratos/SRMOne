/**
 * useSettings hook - Multi-device settings sync via Supabase
 * Replaces localStorage with cloud-synced settings
 */
import { useState, useEffect, useCallback } from "react";
import { api } from "../api/client.js";
import { useAuth } from "./useAuth.jsx";

const DEFAULT_SETTINGS = {
  theme: "light",
  defaultView: "overview",
  attendanceThreshold: 75,
  calendarView: "month",
  timetableView: "week",
  showWeekends: true,
  dashboardWidgets: [],
  customData: {},
};

export function useSettings() {
  const { user } = useAuth();
  const [settings, setSettings] = useState(DEFAULT_SETTINGS);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);

  // Load settings from Supabase on mount
  useEffect(() => {
    if (!user?.email) {
      setLoading(false);
      return;
    }

    api
      .getSettings(user.email)
      .then((res) => {
        if (res.data && Object.keys(res.data).length > 0) {
          setSettings({
            theme: res.data.theme || DEFAULT_SETTINGS.theme,
            defaultView: res.data.default_view || DEFAULT_SETTINGS.defaultView,
            attendanceThreshold: res.data.attendance_threshold || DEFAULT_SETTINGS.attendanceThreshold,
            calendarView: res.data.calendar_view || DEFAULT_SETTINGS.calendarView,
            timetableView: res.data.timetable_view || DEFAULT_SETTINGS.timetableView,
            showWeekends: res.data.show_weekends ?? DEFAULT_SETTINGS.showWeekends,
            dashboardWidgets: res.data.dashboard_widgets || DEFAULT_SETTINGS.dashboardWidgets,
            customData: res.data.custom_data || DEFAULT_SETTINGS.customData,
          });
        }
        setLoading(false);
      })
      .catch((err) => {
        console.error("Failed to load settings:", err);
        setLoading(false);
      });
  }, [user?.email]);

  // Save settings to Supabase
  const saveSettings = useCallback(
    async (updates) => {
      if (!user?.email) return;

      const newSettings = { ...settings, ...updates };
      setSettings(newSettings);
      setSyncing(true);

      try {
        await api.saveSettings(user.email, {
          theme: newSettings.theme,
          default_view: newSettings.defaultView,
          attendance_threshold: newSettings.attendanceThreshold,
          calendar_view: newSettings.calendarView,
          timetable_view: newSettings.timetableView,
          show_weekends: newSettings.showWeekends,
          dashboard_widgets: newSettings.dashboardWidgets,
          custom_data: newSettings.customData,
        });
      } catch (err) {
        console.error("Failed to save settings:", err);
      } finally {
        setSyncing(false);
      }
    },
    [user?.email, settings]
  );

  return {
    settings,
    loading,
    syncing,
    updateSettings: saveSettings,
  };
}
