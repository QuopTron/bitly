// ─────────────────────────────────────────────────────────────
// reproductor_init.dart — PART de cubit_reproductor.dart: mixin de
// inicialización del reproductor: caché persistente de URLs de
// stream (cargar/guardar), reacción al cambio de perfil de
// rendimiento, aplicación de los ajustes de descarga al streaming en
// vivo y la ruta de descargas + ajustes + archivos locales al
// arrancar. La carga de archivos locales vive en
// reproductor_locales.dart; el player mpv y el listener de cola en
// reproductor_player_setup.dart y reproductor_listener_cola.dart.
// Se conecta con: reproductor_listener_cola.dart (misma library).
// Parte del flujo: reproducción (arranque del player).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Inicialización del reproductor. Mixin aplicado en CubitReproductor.
mixin ReproductorInit on ReproductorListenerCola {
  /// Cache persistente de URLs de stream: sobrevive reinicios. Clave
  /// `trackId|calidad` → (url, expiry). Entradas >4h o con URL expirada se
  /// descartan (los proveedores expiran tokens).
  static const _claveCachePersistente = 'stream_url_cache_v3';
  static const _edadMaxCache = Duration(hours: 4);
  static const _maxEntradasCache = 50;

  Future<void> _cargarCachePersistente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_claveCachePersistente);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now();
      for (final entry in map.entries) {
        final data = entry.value as Map<String, dynamic>;
        final url = data['url'] as String? ?? '';
        final ts = DateTime.tryParse(data['ts'] as String? ?? '');
        final exp = DateTime.tryParse(data['exp'] as String? ?? '');
        if (url.isNotEmpty &&
            ts != null &&
            now.difference(ts) < _edadMaxCache &&
            (exp == null || now.add(_margenSeguridadUrl).isBefore(exp))) {
          _cacheUrlStream[entry.key] = _StreamCacheado(url, true, exp);
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> _guardarCachePersistente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final map = <String, dynamic>{};
      var count = 0;
      for (final entry in _cacheUrlStream.entries) {
        if (count >= _maxEntradasCache) break;
        final url = entry.value.url;
        if (!url.startsWith('http')) continue;
        map[entry.key] = {
          'url': url,
          'ts': now.toIso8601String(),
          'exp': entry.value.expiraEn?.toIso8601String(),
        };
        count++;
      }
      await prefs.setString(_claveCachePersistente, jsonEncode(map));
    } catch (_) {}
  }

  /// Refleja la calidad del perfil de rendimiento seleccionado en el
  /// streaming en vivo (audio + video) sin requerir reinicio de la app.
  @override
  void _onPerfilCambio() {
    final perfil = di.sl<ValueNotifier<PerfilRendimiento>>().value;
    if (_calidadAudio != perfil.calidadAudio) {
      _calidadAudio = perfil.calidadAudio;
    }
    _videoHabilitado = perfil.nivel != NivelRendimiento.bajo;
  }

  /// Aplica las calidades de los ajustes de descarga al streaming en vivo sin
  /// reiniciar. Se llama desde la hoja de ajustes (estado global).
  void aplicarAjustesDescarga({
    String? calidadAudio,
    String? calidadVideo,
    bool? videoHabilitado,
    bool? letrasHabilitadas,
  }) {
    if (calidadAudio != null && calidadAudio != _calidadAudio) {
      _calidadAudio = calidadAudio;
    }
    if (calidadVideo != null && calidadVideo != _calidadVideo) {
      _calidadVideo = calidadVideo;
    }
    if (videoHabilitado != null) {
      _videoHabilitado = videoHabilitado;
    }
    if (letrasHabilitadas != null) {
      _letrasHabilitadas = letrasHabilitadas;
    }
  }

  Future<void> _initRutaDescargas() async {
    try {
      _rutaDescargas = await di.sl<CacheAjustes>().getRutaDescargas();
      final ajustes = await di.sl<CacheAjustes>().getAjustesDescarga();
      _calidadAudio = ajustes.calidadAudio;
      _calidadVideo = ajustes.calidadVideo;
      _videoHabilitado = ajustes.videoHabilitado;
      _letrasHabilitadas = ajustes.letrasHabilitadas;
      _ttlArchivosLocales = Duration(seconds: ajustes.ttlArchivosLocalesSegundos);
    } catch (_) {
      // Si falla la carga inicial, igual marcamos _listo para no bloquear la
      // reproducción. El streaming usará defaults (flac / 720p).
    }

    // Cargar archivos locales ANTES de marcar _listo para que _openTrack()
    // pueda encontrar tracks descargados inmediatamente.
    _playbackCache = di.sl<ReproduccionCache>();
    await _loadLocalFiles();

    _listo = true;
    if (_trackPendiente != null) {
      _openTrack(_trackPendiente!);
      _trackPendiente = null;
    }
  }
}