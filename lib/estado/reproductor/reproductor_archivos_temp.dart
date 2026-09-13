// ─────────────────────────────────────────────────────────────
// reproductor_archivos_temp.dart — PART de cubit_reproductor.dart:
// archivos temp y caché de stream: directorio de caché (stream_cache),
// borrado de archivos muertos que media_kit no pudo decodificar y
// limpieza de archivos temp por ID normalizado.
// Se conecta con: reproductor_stream_resolve.dart (misma library).
// Parte del flujo: reproducción (mantenimiento de archivos temp).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Archivos temp del stream. Mixin aplicado en CubitReproductor.
mixin ReproductorArchivosTemp on ReproductorStreamResolve {
  /// Directorio del caché de stream, creándolo si falta.
  @override
  Future<Directory> _getStreamCacheDir() async {
    final appCacheDir = await getApplicationCacheDirectory();
    final dir = Directory(
      '${appCacheDir.path}${Platform.pathSeparator}stream_cache',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Borra un archivo local muerto (stream-cache/descarga que media_kit no
  /// pudo decodificar) para que no se sirva nunca más y el siguiente tap
  /// re-descargue una copia fresca.
  Future<void> _borrarUriMuerta(String fileUri) async {
    try {
      if (!fileUri.startsWith('file://')) return;
      final path = Uri.parse(fileUri).toFilePath();
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Borra un archivo temp de stream por ID normalizado.
  Future<void> _limpiarArchivoTemp(String idNormalizado) async {
    if (!_archivosTempStream.remove(idNormalizado)) return;
    try {
      final cacheDir = await _getStreamCacheDir();
      final sep = Platform.pathSeparator;
      for (final ext in ['flac', 'mp3']) {
        final file = File('${cacheDir.path}$sep$idNormalizado.$ext');
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
  }
}