// ─────────────────────────────────────────────────────────────
// reproductor_video_descarga.dart — PART de cubit_reproductor.dart:
// descarga de URLs crudas a archivo (caché de visualizadores) y el
// sanitizador de nombres para nombres de archivo seguros.
// Se conecta con: reproductor_video_local.dart (misma library).
// Parte del flujo: player grande (caché de video de fondo).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Descarga de URLs crudas. Mixin aplicado en CubitReproductor.
mixin ReproductorVideoDescarga on ReproductorVideoLocal {
  /// Sanitiza un nombre para usarlo como nombre de archivo.
  String _sanitizarNombre(String s) {
    const invalidos = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    var r = s;
    for (final ch in invalidos) {
      r = r.replaceAll(ch, '_');
    }
    r = r.replaceAll(RegExp(r'[. ]+$'), '');
    return r.isEmpty ? 'unknown' : r;
  }

  /// Descarga una URL cruda a [destino] en segundo plano (caché de
  /// visualizadores). Best-effort: si falla, el visualizador igual streamea.
  Future<void> _downloadUrlAArchivo(String url, String destino) async {
    try {
      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(url));
        final streamed = await client.send(req);
        final file = File(destino);
        final sink = file.openWrite();
        try {
          await streamed.stream.pipe(sink);
        } finally {
          await sink.close();
        }
      } finally {
        client.close();
      }
    } catch (_) {
      try {
        if (await File(destino).exists()) await File(destino).delete();
      } catch (_) {}
    }
  }
}