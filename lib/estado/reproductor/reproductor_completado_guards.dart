// ─────────────────────────────────────────────────────────────
// reproductor_completado_guards.dart — PART de cubit_reproductor.dart:
// detección de completaciones FALSAS del track — EOF de stream
// muerto/truncado (el player quedaría en un limbo de silencio) y
// stream corto tipo preview de 30s. En ambos casos re-abre el MISMO
// track una vez por el pipeline con respaldo de descarga y avisa al
// llamador que NO hay que avanzar la cola.
// Cadena de mixins: … → limpieza → completado_guards → completado.
// Se conecta con: cubit_reproductor.dart (misma library).
// Parte del flujo: reproducción (fin de canción / stream roto).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

mixin ReproductorCompletadoGuards on ReproductorLimpieza {
  /// True cuando la completación fue FALSA y ya se reintentó: el
  /// llamador debe salir sin avanzar la cola.
  bool _completacionFalsa(
    ItemFeed? completado,
    bool desdeHttp,
    int durMs,
    int posMs,
  ) {
    // ── Guard de EOF de stream muerto/truncado ─────────────────────────────
    // Una completación con duración real que murió antes de entregar audio
    // significativo = media muerto (proxy vacío, 403 silencioso, tubería
    // cortada). NO es fin de archivo: el player quedaba en un limbo
    // "pausado sin reproducir" que solo limpiaba una descarga de fondo
    // (30s+ de silencio). Re-resolver el MISMO track una vez por el pipeline
    // de descarga; si muere igual, avanzar y pasarlo.
    final eofStreamMuerto =
        completado != null && desdeHttp && durMs > 0 && posMs <= durMs * 0.10;
    if (eofStreamMuerto) {
      final normId = normalizarId(completado.id);
      if (_muertosStreamRecuperados.add(normId)) {
        debugPrint(
          '[Player] EOF de stream muerto (pos=$posMs, dur=$durMs) '
          'para $normId — re-resolviendo vía respaldo de descarga.',
        );
        _cacheUrlStream.remove(_claveCacheStream(normId));
        _futuresStream.remove(_claveCacheStream(normId));
        _urlRotaPorTrack[normId] = _ultimaUriAbierta ?? '';
        unawaited(_openTrack(completado));
        return true;
      }
    } else if (durMs <= 0 || posMs < durMs - 1500) {
      return true;
    }

    // ── Guard anti-preview ─────────────────────────────────────────────────
    // Un stream http directo que termina MUY corto de la duración real es casi
    // seguro un preview/clip de 30s. Avanzar en esa completación falsa
    // saltaría la canción real — re-abrir el MISMO track una vez vía respaldo
    // de descarga (que valida la longitud completa).
    final esperadoMs = completado?.durationMs ?? 0;
    final reproducidoMs = durMs;
    if (completado != null &&
        desdeHttp &&
        esperadoMs >= 60000 &&
        reproducidoMs > 0 &&
        reproducidoMs <= esperadoMs * 0.55) {
      final normId = normalizarId(completado.id);
      if (_tracksRecuperadosPreview.add(normId)) {
        debugPrint(
          '[Player] Stream corto para $normId: sonó $reproducidoMs '
          'ms de $esperadoMs ms esperados — re-resolviendo vía respaldo.',
        );
        _cacheUrlStream.remove(_claveCacheStream(normId));
        _futuresStream.remove(_claveCacheStream(normId));
        _urlRotaPorTrack[normId] = _ultimaUriAbierta!;
        unawaited(_openTrack(completado));
        return true; // NO avanzar la cola en la completación falsa del clip
      }
    }

    return false;
  }
}
