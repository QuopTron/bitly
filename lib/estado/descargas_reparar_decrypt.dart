// ─────────────────────────────────────────────────────────────
// descargas_reparar_decrypt.dart — PART de cubit_descargas.dart:
// decrypt de descargas encriptadas/DRM (p.ej. FLAC de amazon con
// mov_key) vía ffmpeg-kit cuando el backend Go no tenía CLI ffmpeg
// (Android). Confía en el archivo sobre el flag del proveedor (un
// stream marcado encriptado puede ser un contenedor plano
// reproducible) y escribe el archivo reproducible junto al
// encriptado, borrando el original al tener éxito.
// Se conecta con: descargas_reparar.dart (misma library).
// Parte del flujo: descargas (post-descarga de streams DRM).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Decrypt de archivos descargados con ffmpeg-kit. Mixin sobre Reparar.
mixin DescargasRepararDecrypt on DescargasReparar {
  /// Desencripta un archivo descargado encriptado/DRM vía ffmpeg-kit.
  /// Devuelve la ruta desencriptada (o null al fallar).
  Future<String?> _desencriptarArchivoDescargado(
      String rutaSrc, String clave, String ext, [String formatoEntrada = '']) async {
    final srcFile = File(rutaSrc);
    if (!await srcFile.exists()) return null;

    // Confiar en el archivo sobre el flag del proveedor: el stream puede estar
    // marcado como encriptado siendo en realidad un contenedor plano
    // reproducible (zarz sirviendo un FLAC plano con clave vieja).
    if (await _esAudioPlano(srcFile)) {
      _log.i('[CubitDescargas] marcado como encriptado pero es audio plano, se usa directo: $rutaSrc');
      return rutaSrc;
    }

    // Pasar la extensión original para que la cadena completa de fallbacks de
    // desencriptarArchivoMovKey esté disponible (.flac → .mp4 → .m4a →
    // re-codificar → nuclear).
    _log.i('[CubitDescargas] decrypt src=$rutaSrc key=$clave ext=$ext inputFormat=$formatoEntrada');
    final resultado = await desencriptarArchivoMovKey(
      rutaOrigen: rutaSrc,
      clave: clave,
      formatoEntrada: formatoEntrada.isNotEmpty ? formatoEntrada : null,
      extensionSalida: ext,
    );

    if (resultado.exito && resultado.rutaArchivo != null) {
      try {
        await srcFile.delete();
      } catch (_) {}
      return resultado.rutaArchivo;
    }
    _log.e('[CubitDescargas] falló el decrypt de ffmpeg-kit: ${resultado.salida}');
    return null;
  }

  /// True cuando [f] empieza con un magic de contenedor de audio plano
  /// (FLAC/MP3/Ogg/WAV) en vez de una caja MP4 — es decir, nunca fue un
  /// stream realmente encriptado.
  Future<bool> _esAudioPlano(File f) async {
    try {
      final raf = await f.open();
      try {
        final head = await raf.read(4);
        final magic = String.fromCharCodes(head);
        return magic == 'fLaC' || magic == 'ID3' || magic == 'OggS' || magic == 'RIFF';
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }
}