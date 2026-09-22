// ─────────────────────────────────────────────────────────────
// descargas_reparar_escaneo.dart — PART de cubit_descargas.dart:
// escaneo único de arranque que detecta archivos descargados que NO
// son audio reproducible (p.ej. streams amazon encriptados guardados
// antes del decrypt por ffmpeg-kit) y los re-descarga automáticamente
// reconstruyendo la estrategia desde la fila de historial.
//
// NO BORRA NADA. Antes quitaba la fila de BD y borraba el archivo
// con la esperanza de reemplazarlo; si la re-descarga no podía correr
// (gate del plan free vencido, sin red, fuente caída) el usuario
// perdía la descarga PARA SIEMPRE — exactamente el "me dura un día y
// se pierde". Ahora la descarga nueva se escribe en el mismo camino
// (mismo stem) y sobrescribe a la rota; si no se puede, el usuario
// conserva lo que tenía.
//
// Y solo se considera roto un archivo con EVIDENCIA POSITIVA de otro
// contenedor (ver audio_archivo_estado.dart): no poder leerlo no es
// prueba de nada.
// Se conecta con: descargas_reparar_decrypt.dart (misma library).
// Parte del flujo: descargas (reparación de arranque).
// ─────────────────────────────────────────────────────────────

part of '../cubit_descargas.dart';

/// Escaneo de arranque de descargas rotas. Mixin aplicado en CubitDescargas.
mixin DescargasRepararEscaneo on DescargasRepararDecrypt {
  /// Escaneo único de arranque que detecta archivos descargados que NO son
  /// audio reproducible y los re-descarga. No toca la BD ni el disco: la
  /// descarga nueva sobrescribe a la rota por sí sola.
  Future<void> _repararDescargasRotas() async {
    if (_reparacionIntentada) return;
    _reparacionIntentada = true;
    try {
      final historialJson = await _downloadCache.getHistorialDescargas();
      if (historialJson.isEmpty || historialJson == '[]') return;
      final lista = jsonDecode(historialJson) as List;
      final rotas = <Map<String, dynamic>>[];
      for (final e in lista) {
        final m = e as Map<String, dynamic>;
        final fp = (m['file_path'] ?? '').toString();
        if (fp.isEmpty) continue;
        // `estadoAudioEnDisco` distingue "es otro contenedor" (corrupto, se
        // repara) de "no se pudo leer" (desconocido: se deja quieto).
        final estado = await estadoAudioEnDisco(fp);
        if (estado != EstadoArchivoAudio.corrupto) continue;
        rotas.add(m);
        _log.w('[CubitDescargas] Descarga ilegible (otro contenedor): $fp');
      }
      if (rotas.isEmpty) return;
      _log.w(
        '[CubitDescargas] Re-descargando ${rotas.length} descarga(s) rota(s) '
        'sin borrar nada',
      );

      // Re-descargar cada track roto (usa el nuevo decrypt al descargar). La
      // fila y el archivo viejos quedan hasta que llegue el reemplazo.
      for (final m in rotas) {
        await _redescargarTrackRoto(m);
      }
    } catch (e) {
      _log.e('[CubitDescargas] error de reparación: $e');
    }
  }

  /// Re-descarga un track roto descubierto por [_repararDescargasRotas],
  /// reconstruyendo la estrategia de despacho desde su fila de historial.
  Future<void> _redescargarTrackRoto(Map<String, dynamic> m) async {
    try {
      final trackId = ((m['providerTrackId'] ?? m['id']) ?? '').toString();
      if (trackId.isEmpty) return;
      final src = ((m['providerSource'] ?? m['service']) ?? '').toString();
      if (src.isEmpty) return; // sin fuente conocida no se puede re-descargar

      final baseId = 'track_${normalizarId(trackId)}_$src';
      if (state.descargas[baseId]?.estado == EstadoDescarga.enProgreso) return;

      final metaComun = <String, dynamic>{
        'track_id': trackId,
        'item_id': (m['id'] ?? trackId).toString(),
        'track_title': (m['track_name'] ?? '').toString(),
        'artist_name': (m['artist_name'] ?? '').toString(),
        'album_name': (m['album_name'] ?? '').toString(),
        'source': src,
        'isrc': (m['isrc'] ?? '').toString(),
        'duration_ms': (m['duration'] ?? 0),
        if ((m['cover_url'] ?? '').toString().isNotEmpty)
          'cover_url': (m['cover_url'] ?? '').toString(),
      };
      await despacharTrackIndividual(
        metaComun: metaComun,
        ajustes: const AjustesDescarga(),
        baseId: baseId,
      );
    } catch (e) {
      _log.e('[CubitDescargas] error de re-descarga: $e');
    }
  }
}
