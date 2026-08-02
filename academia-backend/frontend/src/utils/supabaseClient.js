/**
 * Supabase client for frontend (anon key).
 * Used for Realtime subscriptions to notifications and job bookmarks.
 * All CRUD operations go through the academia/placement backend APIs.
 */
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || "https://kolpioxbznypmvivbdhn.supabase.co";
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtvbHBpb3hiem55cG12aXZiZGhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg0MzEzOTMsImV4cCI6MjA1NDAwNzM5M30.ypQPxHEr8zXgJxVJHDqQhqMCpWVPSqRrCGmBhKZmxqE";

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: { persistSession: false, autoRefreshToken: false },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});

export default supabase;
