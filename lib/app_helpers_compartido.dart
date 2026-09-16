// ─────────────────────────────────────────────────────────────
// app_helpers_compartido.dart — PART de app_helpers.dart: resolución
// y reproducción de un enlace compartido.
//
// Dos caminos: el enlace de Bitly (datos cifrados: se resuelve por
// ISRC, que es match exacto, y solo si falla se busca por
// nombre+artista y se elige el candidato que más se parece) y el
// enlace de otra fuente (Spotify/YouTube...), que resuelve Go.
//
// Se conecta con: app_helpers.dart (misma library).
// Parte del flujo: enlace entrante → canción reproducible.
// ─────────────────────────────────────────────────────────────

part of 'app_helpers.dart';

/// Qué hacer con la canción compartida al tocar el botón de la carta.
enum ModoCompartido {
  /// Reproduce ya (reemplaza la cola).
  reproducir,

  /// La agrega al final, sin cortar la reproducción actual.
  encolar,
}

/// Resuelve el enlace compartido contra Go y lo reproduce; si no se puede,
/// deja al usuario en el home.
///
/// Dos caminos: el enlace de Bitly (datos cifrados: se resuelve por ISRC, que
/// es match exacto, y solo si falla se busca por nombre+artista) y el enlace
/// de otra fuente (Spotify/YouTube...), que resuelve Go.
Future<void> reproducirCompartidoApp({
  required DatosDeepLink? link,
  required GoRouter router,
  required VoidCallback limpiarLink,
  required void Function(ResultadoEnlace) onResuelto,
  ModoCompartido modo = ModoCompartido.reproducir,
}) async {
  limpiarLink();
  if (link == null) return;
  final compartido = link.compartido;
  final resuelto = compartido != null
      ? await resolverCompartidoBitly(compartido)
      : (link.url.isNotEmpty
          ? await ServicioEnlaces.instance.resolver(link.url)
          : null);
  if (resuelto != null) {
    if (modo == ModoCompartido.encolar) {
      _encolarCompartido(resuelto);
      return;
    }
    onResuelto(resuelto);
    return;
  }
  router.go(RouteNames.home.path);
}

/// Mete lo compartido al final de la cola sin cortar lo que suena.
/// Si es una colección (álbum/playlist) encola todos sus tracks.
void _encolarCompartido(ResultadoEnlace resuelto) {
  final cola = di.sl<CubitCola>();
  final tracks = resuelto.paraReproducir;
  if (tracks.length > 1) {
    cola.agregarTracks(tracks);
  } else {
    cola.agregarAlFinal(resuelto.item);
  }
}

/// Canción de un enlace de Bitly: primero por ISRC (identidad exacta),
/// después por nombre + artista. null si ninguna vía encontró nada.
/// La búsqueda vive en ServicioCompartir para que Ajustes → Compartidos
/// pueda reusarla sin depender de la raíz de la app.
Future<ResultadoEnlace?> resolverCompartidoBitly(DatosCompartido datos) =>
    ServicioCompartir.instance.resolver(datos);
