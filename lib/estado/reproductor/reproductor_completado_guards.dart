// ─────────────────────────────────────────────────────────────
// reproductor_completado_guards.dart — PART de cubit_reproductor.dart:
// detección de completaciones FALSAS del track — EOF de stream
// muerto/truncado, clip corto tipo preview de 30s y evento espurio de
// media_kit — re-abriendo el MISMO track una vez por el pipeline con
// respaldo de descarga.
//
// La DECISIÓN vive en decision_completado.dart (pura y testeada); acá
// solo se aplica: se reabre cuando corresponde y se avisa al llamador
// que NO hay que avanzar la cola. Ninguna rama deja la cola en pausa
// sin avanzar: ese era el bug de "termina y se queda muda". Cuando la
// decisión es IGNORAR queda agendada la red de seguridad del avance
// (reproductor_avance_seguro.dart) por si el audio ya había terminado.
// Cadena de mixins: … → limpieza → completado_guards → completado.
// Se conecta con: cubit_reproductor.dart (misma library).
// Parte del flujo: reproducción (fin de canción / stream roto).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

mixin ReproductorCompletadoGuards on ReproductorAvanceSeguro {
  /// True cuando la completación fue FALSA y ya se recuperó: el llamador debe
  /// salir sin avanzar la cola. En cualquier otro caso devuelve false y la
  /// cola avanza (nunca se queda muda).
  bool _completacionFalsa(
    ItemFeed? completado,
    bool desdeHttp,
    int durMs,
    int posMs,
  ) {
    if (completado == null) return false;
    final normId = normalizarId(completado.id);
    final msDesdeOpen = _tsMediaAbierto == null
        ? -1
        : DateTime.now().difference(_tsMediaAbierto!).inMilliseconds;

    final decision = decidirCompletado(
      desdeHttp: desdeHttp,
      durMs: durMs,
      posMs: posMs,
      duracionCatalogoMs: completado.durationMs ?? 0,
      msDesdeOpen: msDesdeOpen,
      yaSeIntentoPreview: _tracksRecuperadosPreview.contains(normId),
      yaSeIntentoStreamMuerto: _muertosStreamRecuperados.contains(normId),
    );

    switch (decision) {
      case DecisionCompletado.avanzar:
        return false;
      case DecisionCompletado.ignorar:
        // `completed` espurio justo tras open: se asume que el audio sigue
        // sonando y no se avanza. Pero si en realidad el media terminó, la
        // cola quedaría muda: se agenda la revisión de seguridad.
        _agendarAvanceSeguro('completado espurio descartado');
        return true;
      case DecisionCompletado.reabrirMismo:
        _recuperarMismoTrack(completado, normId, durMs, posMs);
        return true;
    }
  }

  /// Re-resuelve el MISMO track por el pipeline con respaldo de descarga,
  /// marcando cuál de los dos presupuestos se gastó (preview o stream muerto).
  /// Cada track tiene UNA recuperación por motivo: si se agota, la cola avanza
  /// para no quedar en pausa.
  void _recuperarMismoTrack(
    ItemFeed completado,
    String normId,
    int durMs,
    int posMs,
  ) {
    final esPreview = durMs > 0 &&
        (completado.durationMs ?? 0) >= 60000 &&
        durMs <= (completado.durationMs ?? 0) * fraccionPreviewCompletado;
    final marca = esPreview ? _tracksRecuperadosPreview : _muertosStreamRecuperados;
    marca.add(normId);
    debugPrint(
      '[Player] completación falsa (${esPreview ? "clip corto" : "stream truncado"}) '
      'pos=$posMs dur=$durMs para $normId — re-resolviendo el MISMO track.',
    );
    // La URL cacheada es la que falló: descartarla para forzar el respaldo —
    // y PERSISTIR el descarte, porque si no el caché en disco la revive en el
    // próximo arranque y la canción vuelve a cortarse a los 30s. La re-apertura
    // pide el pipeline completo (con respaldo), así que el backend devuelve el
    // archivo real en vez de otro clip.
    final clave = _claveCacheStream(normId);
    _cacheUrlStream.remove(clave);
    _futuresStream.remove(clave);
    _urlRotaPorTrack[normId] = _ultimaUriAbierta ?? '';
    unawaited(_guardarCachePersistente());
    unawaited(_openTrack(completado));
  }
}
