// ─────────────────────────────────────────────────────────────
// modelos_item.dart — Modelos de ítem de Mi Espacio: Item (una
// canción, playlist, álbum o artista de la biblioteca), su tipo y
// su origen (amado, descargado o creado por el usuario). Lo usan
// los datos y el contenido de la vista para armar las tarjetas.
// Se conecta con: datos_mi_espacio + contenido_mi_espacio.
// Parte del flujo: Home → Mi Espacio (pestañas de biblioteca).
// ─────────────────────────────────────────────────────────────

/// Tipo de ítem de la biblioteca.
enum TipoItem { cancion, playlist, album, artista }

/// Origen del ítem: amado, descargado, propio o ninguno.
enum OrigenItem { amado, descargado, propio, ninguno }

/// Ítem de la biblioteca personal (canción/playlist/álbum/artista).
class Item {
  final String titulo;
  final String subtitulo;
  final TipoItem tipo;
  final String? coverUrl;
  final String idReal;
  final String fuente;
  final OrigenItem origen;

  const Item(
    this.titulo,
    this.subtitulo,
    this.tipo, {
    this.coverUrl,
    this.idReal = '',
    this.fuente = '',
    this.origen = OrigenItem.ninguno,
  });
}