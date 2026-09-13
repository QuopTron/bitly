// ─────────────────────────────────────────────────────────────
// descargas_despacho.dart — PART de cubit_descargas.dart: despacho
// directo de audio/video/letras de UN track (llamado por la cola
// secuencial). Chequea el gate del plan free (premium = siempre;
// free = ventana de 8h), registra el state key → item id de Go,
// guarda metadata del track y dispara los RPC downloadByStrategy de
// cada subtarea. Actualiza el estado una sola vez al final para
// evitar races con _pollProgreso entre emisiones intermedias.
// Se conecta con: descargas_borrar_lote.dart (misma library).
// Parte del flujo: descargas (cola secuencial → backend Go).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Despacho directo de un track. Mixin aplicado en CubitDescargas.
mixin DescargasDespacho on DescargasBorrarLote {
  /// Despacha audio/video/letras de un track desde la cola de lote.
  @override
  Future<void> despacharTrackIndividual({
    required Map<String, dynamic> metaComun,
    required AjustesDescarga ajustes,
    required String baseId,
    String? calidadForzada,
  }) async {
    // Gate del plan free: premium = siempre; free = solo en la ventana de 8h.
    final acceso = await VerificadorAccesoDescarga.verificar();
    if (acceso == AccesoDescarga.expirado) {
      _log.w('[despacharTrackIndividual] bloqueado por gate free: $baseId');
      bloquearDescarga(
        baseId,
        'Tu prueba gratis de 8 horas terminó. Activa Premium para seguir descargando.',
      );
      return;
    }
    if (!await _verificarSesionesAntesDeDescargar()) return;
    final itemId = metaComun['item_id'] as String? ?? '';

    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    // Guardar SOLO por baseId — no agregar audioKey al mapa de descargas
    // porque el escaneo por prefijo de la UI lo vería como entrada aparte,
    // mostrando varios puntos naranjas para el mismo track.
    dl[baseId] = const DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: 0.0);
    if (itemId.isNotEmpty) _itemIdAKeyEstado[itemId] = baseId;
    // Usar el ID normalizado para consistencia con BD y borrado.
    final normalizedTrackId = normalizarId(itemId);
    _metaTrack[baseId] = _InfoTrack(
      normalizedTrackId,
      (metaComun['track_title'] as String?) ?? '',
      metaComun['artist_name'] as String?,
      metaComun['cover_url'] as String?,
      (metaComun['source'] as String?) ?? '',
      null,
      (metaComun['isrc'] as String?) ?? '',
    );
    _iniciadosEn[baseId] = DateTime.now();
    _log.i('[despacharTrackIndividual] baseId=$baseId itemId="$itemId" titulo="${metaComun['track_title']}" '
        'artista="${metaComun['artist_name']}" isrc="${metaComun['isrc']}" source="${metaComun['source']}"');
    _asegurarPolling();

    final audioStrategy = <String, dynamic>{
      ...metaComun,
      'type': 'audio',
      'item_id': '${itemId}_audio',
      'quality': calidadForzada ?? ajustes.calidadAudio,
    };
    _itemIdAKeyEstado['${itemId}_audio'] = baseId;
    _backend.downloadByStrategy(jsonEncode(audioStrategy));

    if (ajustes.videoHabilitado) {
      final videoKey = '${baseId}_video';
      // Trackear el video internamente pero NO agregarlo al mapa de descargas
      // (el escaneo por prefijo de la UI lo vería como punto naranja aparte).
      final videoStrategy = <String, dynamic>{
        ...metaComun,
        'type': 'video',
        'item_id': '${itemId}_video',
        'quality': ajustes.calidadVideo,
      };
      _itemIdAKeyEstado['${itemId}_video'] = videoKey;
      _backend.downloadByStrategy(jsonEncode(videoStrategy));
    }

    if (ajustes.letrasHabilitadas) {
      final lyricsKey = '${baseId}_lyrics';
      final lyricsStrategy = <String, dynamic>{
        ...metaComun,
        'type': 'lyrics',
        'item_id': '${itemId}_lyrics',
        'source': ajustes.fuenteLetras,
      };
      _itemIdAKeyEstado['${itemId}_lyrics'] = lyricsKey;
      _backend.downloadByStrategy(jsonEncode(lyricsStrategy));
    }

    // Un solo emit después de todos los RPC — evita la race donde
    // _pollProgreso lee estado intermedio entre los dos emits viejos.
    emit(state.copiarCon(descargas: dl));
  }
}