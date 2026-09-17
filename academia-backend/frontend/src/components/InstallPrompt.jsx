import { useEffect, useState } from "react";
import { Download, X } from "lucide-react";

// Floating "Install app" chip. Appears when the browser fires
// beforeinstallprompt (Chrome/Edge/Android). On iOS Safari there is no such
// event, so we show a one-time hint on how to add to the home screen.
// Hidden entirely once the app runs standalone (already installed).

function isStandalone() {
  return (
    window.matchMedia?.("(display-mode: standalone)").matches ||
    window.navigator.standalone === true
  );
}

function isIOS() {
  return /iphone|ipad|ipod/i.test(window.navigator.userAgent) && !window.MSStream;
}

const DISMISS_KEY = "srmone_install_dismissed";

export default function InstallPrompt() {
  const [deferred, setDeferred] = useState(null);
  const [show, setShow] = useState(false);
  const [iosHint, setIosHint] = useState(false);

  useEffect(() => {
    if (isStandalone()) return;
    let dismissed = false;
    try {
      dismissed = localStorage.getItem(DISMISS_KEY) === "1";
    } catch {
      /* ignore */
    }
    if (dismissed) return;

    const onPrompt = (e) => {
      e.preventDefault();
      setDeferred(e);
      setShow(true);
    };
    window.addEventListener("beforeinstallprompt", onPrompt);

    const onInstalled = () => {
      setShow(false);
      setDeferred(null);
    };
    window.addEventListener("appinstalled", onInstalled);

    // iOS has no beforeinstallprompt — show the manual hint instead.
    if (isIOS()) {
      setIosHint(true);
      setShow(true);
    }

    return () => {
      window.removeEventListener("beforeinstallprompt", onPrompt);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  if (!show) return null;

  const dismiss = () => {
    setShow(false);
    try {
      localStorage.setItem(DISMISS_KEY, "1");
    } catch {
      /* ignore */
    }
  };

  const install = async () => {
    if (!deferred) return;
    deferred.prompt();
    try {
      await deferred.userChoice;
    } catch {
      /* ignore */
    }
    setDeferred(null);
    setShow(false);
  };

  return (
    <div
      style={{
        position: "fixed",
        left: "50%",
        transform: "translateX(-50%)",
        bottom: "max(16px, env(safe-area-inset-bottom))",
        zIndex: 9999,
        maxWidth: "min(92vw, 420px)",
      }}
    >
      <div className="flex items-center gap-3 rounded-2xl bg-[#111827] text-white shadow-2xl border border-white/10 px-4 py-3">
        <img src="/icon-192.png" alt="SRM One" className="w-9 h-9 rounded-lg" />
        <div className="flex-1 min-w-0">
          <p className="text-sm font-bold leading-tight">Install SRM One</p>
          <p className="text-[11px] text-white/60 leading-snug">
            {iosHint
              ? "Tap Share, then “Add to Home Screen”."
              : "Add it to your home screen — opens like an app, works offline."}
          </p>
        </div>
        {!iosHint && (
          <button
            onClick={install}
            className="inline-flex items-center gap-1.5 rounded-full bg-white text-[#111827] text-xs font-bold px-3.5 py-2 hover:bg-white/90 transition-colors whitespace-nowrap"
          >
            <Download size={14} /> Install
          </button>
        )}
        <button
          onClick={dismiss}
          aria-label="Dismiss"
          className="text-white/50 hover:text-white transition-colors"
        >
          <X size={16} />
        </button>
      </div>
    </div>
  );
}
