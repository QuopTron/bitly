// ─────────────────────────────────────────────────────────────
// datos_compartido.dart — Lo que viaja dentro de un enlace compartido:
// tipo, ISRC, nombre, artista, álbum, carátula, duración, ids
// cross-proveedor y quién lo comparte.
//
// Por qué el ISRC y los ids van primero: al abrir el enlace en otro
// celu, Bitly resuelve por ISRC (match exacto) y, si no está, por
// nombre+artista. Mandar los ids de cada extensión evita búsquedas
// lentas por nombre en la otra punta.
//
// Las claves del JSON son cortas a propósito: el payload viaja cifrado
// dentro de una URL de WhatsApp, así que cada byte cuenta.
//
// Se conecta con: servicio_compartir (serializa) + servicio_deep_link
// (deserializa) + overlay_compartido (lo pinta).
// Parte del flujo: compartir canción → enlace → abrir en el otro celu.
// ─────────────────────────────────────────────────────────────

import '../../modelos/feed/item_feed.dart';

/// Contenido de un enlace compartido, ya descifrado.
class DatosCompartido {
  final String tipo;
  final String isrc;
  final String nombre;
  final String artista;
  final String album;
  final String caratula;
  final int duracionMs;
  final String emisor;
  final String spotifyId;
  final String deezerId;
  final String tidalId;
  final String qobuzId;

  const DatosCompartido({
    this.tipo = 'track',
    this.isrc = '',
    this.nombre = '',
    this.artista = '',
    this.album = '',
    this.caratula = '',
    this.duracionMs = 0,
    this.emisor = '',
    this.spotifyId = '',
    this.deezerId = '',
    this.tidalId = '',
    this.qobuzId = '',
  });

  /// ¿Trae algo con lo que buscar? (si no, el enlace se ignora)
  bool get valido =>
      nombre.isNotEmpty || isrc.isNotEmpty || spotifyId.isNotEmpty;

  /// Ítem listo para la tarjeta del overlay.
  ItemFeed get comoItem => ItemFeed(
        id: isrc.isNotEmpty ? isrc : nombre,
        type: tipo,
        name: nombre,
        artists: artista.isEmpty ? null : artista,
        coverUrl: caratula.isEmpty ? null : caratula,
        albumName: album.isEmpty ? null : album,
        durationMs: duracionMs > 0 ? duracionMs : null,
        isrc: isrc.isEmpty ? null : isrc,
        spotifyId: spotifyId.isEmpty ? null : spotifyId,
        deezerId: deezerId.isEmpty ? null : deezerId,
        tidalId: tidalId.isEmpty ? null : tidalId,
        qobuzId: qobuzId.isEmpty ? null : qobuzId,
      );

  /// Toma la identidad del ítem que el usuario compartió.
  factory DatosCompartido.desdeItem(ItemFeed item, {String emisor = ''}) =>
      DatosCompartido(
        tipo: item.type,
        isrc: item.isrc ?? '',
        nombre: item.name,
        artista: item.artists ?? '',
        album: item.albumName ?? '',
        caratula: item.coverUrl ?? '',
        duracionMs: item.durationMs ?? 0,
        emisor: emisor,
        spotifyId: item.spotifyId ?? '',
        deezerId: item.deezerId ?? '',
        tidalId: item.tidalId ?? '',
        qobuzId: item.qobuzId ?? '',
      );

  /// JSON compacto (solo lo que tiene contenido).
  Map<String, dynamic> aJson() {
    final m = <String, dynamic>{'t': tipo, 'u': emisor};
    void put(String k, String v) {
      if (v.trim().isNotEmpty) m[k] = v.trim();
    }

    put('i', isrc);
    put('n', nombre);
    put('a', artista);
    put('al', album);
    put('c', caratula);
    if (duracionMs > 0) m['d'] = duracionMs;
    put('sp', spotifyId);
    put('dz', deezerId);
    put('td', tidalId);
    put('qz', qobuzId);
    return m;
  }

  factory DatosCompartido.desdeJson(Map<String, dynamic> json) {
    String s(String k) => json[k]?.toString() ?? '';
    return DatosCompartido(
      tipo: s('t').isEmpty ? 'track' : s('t'),
      isrc: s('i'),
      nombre: s('n'),
      artista: s('a'),
      album: s('al'),
      caratula: s('c'),
      duracionMs: int.tryParse(s('d')) ?? 0,
      emisor: s('u'),
      spotifyId: s('sp'),
      deezerId: s('dz'),
      tidalId: s('td'),
      qobuzId: s('qz'),
    );
  }
}
