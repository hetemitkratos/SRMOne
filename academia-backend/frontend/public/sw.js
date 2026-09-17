// SRM One service worker — makes the app installable and resilient offline.
// Strategy:
//  - API calls (/api/*): always network, never cached (live data, auth).
//  - Navigations (HTML): network-first, fall back to cached app shell offline.
//  - Static assets (JS/CSS/img/fonts): stale-while-revalidate.
// Bump CACHE_VERSION to invalidate old caches on deploy.

const CACHE_VERSION = "srmone-v1";
const APP_SHELL = "/index.html";

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll([APP_SHELL, "/"])).catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);

  // Never cache API/auth traffic or cross-origin requests.
  if (url.origin !== self.location.origin || url.pathname.startsWith("/api/")) {
    return;
  }

  // App navigations: network-first with offline shell fallback.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then((c) => c.put(APP_SHELL, copy)).catch(() => {});
          return res;
        })
        .catch(() => caches.match(APP_SHELL).then((r) => r || caches.match("/")))
    );
    return;
  }

  // Static assets: stale-while-revalidate.
  event.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request)
        .then((res) => {
          if (res && res.status === 200 && res.type === "basic") {
            const copy = res.clone();
            caches.open(CACHE_VERSION).then((c) => c.put(request, copy)).catch(() => {});
          }
          return res;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});
