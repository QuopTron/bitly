// ─────────────────────────────────────────────────────────────
// route_names.dart — Nombres de rutas centralizados de la app.
// Un solo lugar para los paths del router (splash, setup, home,
// tutorial) así las páginas navegan con constantes en vez de
// strings mágicos.
// Se conecta con: app_router.dart (registro) + splash/setup/tutorial.
// Parte del flujo: navegación raíz (router de go_router).
// ─────────────────────────────────────────────────────────────

/// ¿La app ya salió del splash (y del setup, si era la primera vez)?
///
/// Lo consultan los enlaces que llegan por deep link: la carta "te compartieron"
/// no se muestra hasta que la app esté usable, porque sus botones necesitan el
/// backend cargado. `''` (todavía sin ruta resuelta) cuenta como que no.
bool pasoElArranque(String ruta) =>
    ruta.isNotEmpty &&
    ruta != RouteNames.splash.path &&
    ruta != RouteNames.setup.path;

/// Rutas raíz de la app. `path` es el segmento URL de go_router.
enum RouteNames {
  splash('/'),
  setup('/setup'),
  home('/home'),
  tutorial('/tutorial');

  final String path;

  const RouteNames(this.path);
}