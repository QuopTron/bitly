// ─────────────────────────────────────────────────────────────
// app_router_enlaces.dart — Puente entre un enlace que llega de
// FUERA (WhatsApp, navegador, PWA instalada) y las rutas de la app.
//
// Qué problema resuelve: go_router recibe la location entrante tal
// cual (en web/PWA la dirección del navegador ES la ruta) y, como no
// existe una ruta `/open`, lanzaba
//   GoException: no routes for location: https://<host>/open?s=...
// mostrando su pantalla de error con la URL a la vista. Ahora ese
// enlace se redirige al home y, de paso, se registra la carta "te
// compartieron" con el payload cifrado (?s=...).
//
// Se conecta con: app_router (redirect y errorBuilder) +
// servicio_compartir (leerEnlace) + servicio_deep_link (pendiente).
// Parte del flujo: enlace entrante → carta compartida.
// ─────────────────────────────────────────────────────────────

import '../core/plataforma/sistema/servicio_deep_link.dart';
import '../core/servicios/compartir/servicio_compartir.dart';
import 'route_names.dart';

/// Rutas que el router sabe pintar (splash, setup, home, tutorial).
final Set<String> _rutasInternas = {
  for (final ruta in RouteNames.values) ruta.path,
};

/// Destino para una location entrante: null cuando ya es una ruta interna
/// (no se toca nada) y el home cuando viene de un enlace de fuera.
///
/// Lo usa el `redirect` del router. Devolver una ruta es lo que evita la
/// pantalla de error de go_router, que mostraba la URL del enlace.
String? destinoDeLocationExterna(String location) {
  final uri = Uri.tryParse(location.trim());
  if (uri == null) return null;
  final path = uri.path.isEmpty ? '/' : uri.path;
  if (_rutasInternas.contains(path)) return null;
  // Enlace de fuera: si trae el payload compartido, queda guardado para que
  // la carta aparezca apenas la app esté lista.
  registrarCompartidoDeLocation(uri);
  return RouteNames.home.path;
}

/// Registra la carta de un enlace compartido si la location lo trae.
/// Con enlaces de otras fuentes o manipulados no hace nada.
void registrarCompartidoDeLocation(Uri uri) {
  final compartido = ServicioCompartir.instance.leerEnlace(_urlAbsoluta(uri));
  if (compartido == null) return;
  ServicioDeepLink.instance.guardarPendiente(
    DatosDeepLink(
      type: compartido.tipo,
      id: compartido.isrc,
      query: compartido.nombre,
      compartido: compartido,
    ),
  );
}

/// `leerEnlace` espera un enlace con host; una location relativa
/// (`/open?s=...`, la forma en que llega en web) se completa con el host
/// declarado por la app.
String _urlAbsoluta(Uri uri) =>
    uri.hasScheme ? uri.toString() : 'https://${ServicioCompartir.host}$uri';
