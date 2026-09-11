// Service Worker para Bitly PWA
// Cachea los assets de Flutter web para funcionar offline después de la primera carga.

const CACHE_NAME = "bitly-v1";
const ASSETS_TO_CACHE = [
  "/",
  "/index.html",
  "/manifest.json",
  "/favicon.png",
  "/icons/Icon-192.png",
  "/icons/Icon-512.png",
  "/main.dart.js",
  "/flutter.js",
  "/flutter_bootstrap.js",
];

// Instalar: cachear assets estáticos
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE).catch((err) => {
        console.log("[SW] Cache install fallback:", err);
      });
    }),
  );
  self.skipWaiting();
});

// Activar: limpiar caches viejos
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key)),
      );
    }),
  );
  self.clients.claim();
});

// Fetch: network-first para API, cache-first para assets
self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  // No cachear peticiones a la API del backend
  if (
    url.pathname.startsWith("/api/") ||
    url.pathname.startsWith("/search") ||
    url.pathname.startsWith("/stream") ||
    url.pathname.startsWith("/cover") ||
    url.pathname.startsWith("/download") ||
    url.pathname.startsWith("/feed") ||
    url.pathname.startsWith("/rpc") ||
    url.pathname === "/ping" ||
    url.pathname === "/health"
  ) {
    return;
  }

  // Para assets de Flutter: cache-first
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;

      return fetch(event.request)
        .then((response) => {
          // Cachear respuestas exitosas
          if (response.ok && event.request.method === "GET") {
            const responseClone = response.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, responseClone);
            });
          }
          return response;
        })
        .catch(() => {
          // Offline: devolver index.html para navegación SPA
          if (event.request.mode === "navigate") {
            return caches.match("/index.html");
          }
        });
    }),
  );
});
