// ─────────────────────────────────────────────────────────────
// route_names.dart — Nombres de rutas centralizados de la app.
// Un solo lugar para los paths del router (splash, setup, home,
// tutorial) así las páginas navegan con constantes en vez de
// strings mágicos.
// Se conecta con: app_router.dart (registro) + splash/setup/tutorial.
// Parte del flujo: navegación raíz (router de go_router).
// ─────────────────────────────────────────────────────────────

/// Rutas raíz de la app. `path` es el segmento URL de go_router.
enum RouteNames {
  splash('/'),
  setup('/setup'),
  home('/home'),
  tutorial('/tutorial');

  final String path;

  const RouteNames(this.path);
}