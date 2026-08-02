/**
 * NotificationBell - Real-time notification indicator
 */
import { Bell } from "lucide-react";
import { useState } from "react";
import { useNotifications } from "../hooks/useNotifications.js";

export default function NotificationBell() {
  const { notifications, unreadCount, markAsRead, markAllAsRead } = useNotifications();
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="relative w-9 h-9 sm:w-11 sm:h-11 rounded-full bg-white border border-slate-200 flex items-center justify-center text-slate-600 hover:text-[#1A1A1A] hover:bg-slate-50 transition-colors shadow-sm"
      >
        <Bell className="w-[16px] h-[16px] sm:w-[18px] sm:h-[18px]" />
        {unreadCount > 0 && (
          <span className="absolute -top-1 -right-1 w-5 h-5 bg-terracotta text-white text-[10px] font-bold rounded-full flex items-center justify-center">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        )}
      </button>

      {isOpen && (
        <>
          <div
            className="fixed inset-0 z-40"
            onClick={() => setIsOpen(false)}
          />
          <div className="fixed sm:absolute top-[70px] sm:top-12 left-4 right-4 sm:left-auto sm:right-0 sm:w-80 max-h-[80vh] sm:max-h-96 bg-white rounded-2xl shadow-xl border border-slate-200 overflow-hidden z-50 flex flex-col">
            <div className="p-4 border-b border-slate-200 flex items-center justify-between flex-shrink-0">
              <h3 className="font-display font-bold text-lg text-[#1A1A1A]">
                Notifications
              </h3>
              {unreadCount > 0 && (
                <button
                  onClick={markAllAsRead}
                  className="text-xs font-semibold text-mint hover:underline"
                >
                  Mark all read
                </button>
              )}
            </div>
            <div className="max-h-80 overflow-y-auto">
              {notifications.length === 0 ? (
                <div className="p-8 text-center text-slate-500 text-sm">
                  No notifications yet
                </div>
              ) : (
                notifications.slice(0, 10).map((notif) => (
                  <button
                    key={notif.id}
                    onClick={() => {
                      markAsRead(notif.id);
                      setIsOpen(false);
                    }}
                    className={`w-full text-left p-4 border-b border-slate-100 hover:bg-slate-50 transition-colors ${
                      !notif.read ? "bg-mint/5" : ""
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="flex-1">
                        <p className="font-semibold text-sm text-[#1A1A1A]">
                          {notif.title}
                        </p>
                        {notif.body && (
                          <p className="text-xs text-slate-600 mt-1">
                            {notif.body}
                          </p>
                        )}
                        <p className="text-[10px] text-slate-400 mt-1">
                          {new Date(notif.created_at).toLocaleString()}
                        </p>
                      </div>
                      {!notif.read && (
                        <div className="w-2 h-2 rounded-full bg-mint flex-shrink-0 mt-1" />
                      )}
                    </div>
                  </button>
                ))
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
