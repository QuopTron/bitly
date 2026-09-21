// ─────────────────────────────────────────────────────────────
// descargas_lote_caratula.dart — PART de cubit_descargas.dart:
// resuelve el nombre y la carátula de un lote (álbum/playlist) que
// acaba de completarse, con cadena de fallbacks. El lote llegaba a
// la BD con nombre y carátula VACÍOS cuando _datosLote ya se había
// vaciado (el lote terminó de a un track suelto): la tarjeta del
// álbum quedaba sin portada para siempre.
// Se conecta con: descargas_lote_finalizar.dart (misma library).
// Parte del flujo: descargas (lotes → BD y Mi Espacio).
// ─────────────────────────────────────────────────────────────

part of '../../cubit_descargas.dart';

/// Nombre y carátula resueltos de un lote. [coverPath] solo lleva rutas
/// locales (nunca una URL: la UI lo trata como archivo en disco).
class _DatosCaratulaLote {
  final String nombre;
  final String coverUrl;
  final String coverPath;

  const _DatosCaratulaLote(this.nombre, this.coverUrl, this.coverPath);
}

/// Resolución de datos del lote. Mixin aplicado en CubitDescargas.
mixin DescargasLoteCaratula on DescargasLoteFinalizar {
  /// True si [ruta] es un archivo local (no una URL): evita guardar una URL
  /// en `cover_path`, que la UI abriría como archivo inexistente.
  static bool _esRutaLocal(String? ruta) =>
      ruta != null &&
      ruta.isNotEmpty &&
      !ruta.startsWith('http://') &&
      !ruta.startsWith('https://');

  /// Resuelve nombre + carátula de un lote recién completado.
  ///
  /// Orden de preferencia (el primero que aporta dato gana):
  /// 1. los datos del lote en memoria (lo que lanzó la descarga),
  /// 2. la metadata de sus tracks (sobrevive a que `_datosLote` se vacíe),
  /// 3. el álbum/playlist amado (su like ya guardó la carátula local),
  /// 4. la biblioteca local (el álbum conoce su nombre y su portada).
  @override
  Future<_DatosCaratulaLote> _resolverDatosLote({
    required String itemType,
    required String itemId,
    required List<String> trackIds,
    _DatosLote? batchData,
  }) async {
    var nombre = '';
    var coverUrl = '';
    var coverPath = '';

    void tomarNombre(String? valor) {
      final v = valor?.trim() ?? '';
      if (nombre.isEmpty && v.isNotEmpty) nombre = v;
    }

    void tomarCover(String? url, String? ruta) {
      final u = url?.trim() ?? '';
      if (coverPath.isEmpty && _esRutaLocal(ruta)) coverPath = ruta!.trim();
      if (coverUrl.isEmpty && u.isNotEmpty && !u.startsWith('/')) coverUrl = u;
      // Un único dato puede servir para las dos cosas: si lo que llegó es una
      // ruta local, ya quedó en coverPath; si es URL, en coverUrl.
      if (coverUrl.isEmpty && u.isNotEmpty) coverUrl = u;
    }

    // 1) La descarga en memoria: es la fuente del nombre del álbum.
    final tracks = batchData?.tracks ?? const <Map<String, dynamic>>[];
    if (tracks.isNotEmpty) {
      tomarNombre(tracks.first['album_name'] as String?);
      tomarCover(tracks.first['cover_url'] as String?, null);
    }

    // 2) Los tracks ya descargados: su carátula pudo guardarse en el download.
    for (final stateKey in trackIds) {
      final meta = _metaTrack[stateKey];
      if (meta == null) continue;
      tomarCover(meta.coverUrl, meta.coverPath);
      if (nombre.isNotEmpty && coverPath.isNotEmpty && coverUrl.isNotEmpty) {
        break;
      }
    }

    // 3) Amado: el like baja la portada a disco, se reusa tal cual.
    final amado =
        di
            .sl<CubitLikes>()
            .state
            .todosAmados
            .values
            .where(
              (i) =>
                  i.type == itemType &&
                  normalizarIdTrack(i.id) == normalizarIdTrack(itemId),
            )
            .firstOrNull;
    if (amado != null) {
      tomarNombre(amado.name);
      tomarCover(amado.coverUrl, amado.rutaCaratulaLocal);
    }

    // 4) Biblioteca local: el álbum ya tiene nombre y URL de portada.
    if (nombre.isEmpty || coverUrl.isEmpty) {
      final album = await _contentLote.getAlbumPorIdNormalizado(itemId);
      if (album != null) {
        tomarNombre(album.name);
        tomarCover(album.coverUrl, album.coverPath);
      }
    }

    return _DatosCaratulaLote(nombre, coverUrl, coverPath);
  }
}
