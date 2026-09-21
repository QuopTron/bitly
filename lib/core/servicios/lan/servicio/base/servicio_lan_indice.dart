// ─────────────────────────────────────────────────────────────
// servicio_lan_indice.dart — PART de servicio_lan.dart: el catálogo propio y
// el asentado de lo que llega de otro aparato.
//
// El catálogo se arma de la tabla de descargas, salteando lo que ya no está
// en el disco (una fila vieja sin archivo no se puede prestar). De cada
// canción viaja la identidad (ISRC o nombre+artista) y el tamaño, para que el
// otro lado sepa qué le falta y cuánto va a bajar.
//
// Lo que llega se deja en la carpeta de descargas del usuario y se registra
// como descarga propia: así la app lo trata igual que si lo hubiera bajado
// ella (suena, se ve en Mi Espacio y no se vuelve a bajar).
//
// Se conecta con: servicio_lan.dart (misma library) + download_dao +
// cache_descargas.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

part of 'servicio_lan.dart';

/// Armar el catálogo propio y asentar lo que llega.
extension IndiceLan on ServicioLan {
  /// Lo descargado en este aparato, listo para prestar.
  Future<List<CancionLan>> indicePropio() async {
    final filas = await _db.downloadDao.getAllHistory();
    final lista = <CancionLan>[];
    for (final f in filas) {
      final ruta = f.filePath;
      if (ruta == null || ruta.isEmpty) continue;
      final archivo = io.File(ruta);
      if (!await archivo.exists()) continue;
      // La carátula solo se anuncia si el archivo está de verdad: así el otro
      // aparato no pide un 404 que le dejaría la tarjeta gris.
      final extCover = extImagenDe(f.coverPath ?? '');
      lista.add(
        CancionLan(
          id: f.id,
          nombre: f.trackName,
          artista: f.artistName,
          album: f.albumName ?? '',
          isrc: f.isrc ?? '',
          origen: f.service ?? '',
          duracionMs: f.duration ?? 0,
          bytes: await archivo.length(),
          ext: _extensionDe(ruta),
          coverUrl: f.coverUrl ?? '',
          extCover:
              extCover.isEmpty
                  ? ''
                  : (await _existeCover(f.coverPath!) ? extCover : ''),
          tieneLetra: await hayLetraAlLado(ruta, f.id),
        ),
      );
    }
    return lista;
  }

  /// Las identidades de lo que YA tengo: con esto se decide qué me falta sin
  /// bajar nada de más.
  Future<Set<String>> clavesLocales() async => {
    for (final c in await indicePropio()) c.clave,
  };

  /// Deja en la carpeta de descargas lo que llegó, y lo registra como
  /// descarga propia. Reusa el id del catálogo de origen (es el id de la
  /// canción en la fuente, así que la app la reconoce igual).
  Future<String> asentarArchivo(
    CancionLan cancion,
    List<int> bytes, {
    List<int>? cover,
    List<int>? letra,
  }) async {
    final carpeta = await _cache.getRutaDescargas();
    if (carpeta == null || carpeta.isEmpty) {
      throw StateError('no hay carpeta de descargas configurada');
    }
    final dir = io.Directory(carpeta);
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = cancion.ext.isEmpty ? 'flac' : cancion.ext;
    final destino = io.File(
      '${dir.path}${io.Platform.pathSeparator}${cancion.id}.$ext',
    );
    await destino.writeAsBytes(bytes, flush: true);
    // La carátula y la letra son un extra: si alguna falla, la canción igual
    // queda descargada y suena (y la letra se resuelve de nuevo si hace falta).
    String? coverPath;
    try {
      coverPath = await escribirCover(cancion, dir.path, cover);
      await escribirLetra(dir.path, cancion.id, letra);
    } catch (e) {
      debugPrint('[Lan] sidecars de ${cancion.nombre} fallaron: $e');
    }
    await _descargas.guardarTrackDescargado(
      id: cancion.id,
      trackName: cancion.nombre,
      artistName: cancion.artista,
      albumName: cancion.album.isEmpty ? null : cancion.album,
      isrc: cancion.isrc.isEmpty ? null : cancion.isrc,
      filePath: destino.path,
      service: cancion.origen.isEmpty ? null : cancion.origen,
      duration: cancion.duracionMs,
      coverUrl: cancion.coverUrl.isEmpty ? null : cancion.coverUrl,
      coverPath: coverPath,
    );
    return destino.path;
  }

  /// ¿La carátula que apunta la fila está de verdad en el disco?
  Future<bool> _existeCover(String ruta) => io.File(ruta).exists();

  /// La extensión de un archivo local ('flac', 'mp3'...), sin el punto.
  String _extensionDe(String ruta) {
    final punto = ruta.lastIndexOf('.');
    if (punto < 0 || punto == ruta.length - 1) return '';
    final ext = ruta.substring(punto + 1).toLowerCase();
    return ext.length > 5 ? '' : ext;
  }
}
