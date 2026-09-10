// ─────────────────────────────────────────────────────────────
// reproductor_estado_cache.dart — PART de cubit_reproductor.dart:
// campos de caché/errores del reproductor: URLs de stream cacheadas,
// resoluciones en vuelo, archivos locales, reintentos, generaciones
// anti-carrera y el prefetch con su throttle (3 slots). Se aplica
// justo después de ReproductorBase.
// Se conecta con: reproductor_base.dart (misma library).
// Parte del flujo: reproducción (estado compartido del player).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Estado de caché/errores. Mixin aplicado en CubitReproductor.
mixin ReproductorEstadoCache on ReproductorBase {
  /// Map trackId → ruta real del archivo (del historial de descargas).
  final Map<String, String> _archivosLocales = {};
  String? _rutaDescargas;

  /// Ruta del directorio de descargas (público para la UI de descargas).
  String? get rutaDescargas => _rutaDescargas;

  /// IDs normalizados de tracks streameados (no locales): se limpian sus
  /// archivos cacheados al completar la reproducción.
  final Set<String> _idsStremeados = {};

  /// IDs de archivos temp descargados para streaming. Se limpian al completar
  /// la reproducción o al cerrar la app.
  final Set<String> _archivosTempStream = {};

  /// Caché de URLs de stream resueltas, clave `trackId|calidad`.
  final Map<String, _StreamCacheado> _cacheUrlStream = {};

  /// Resoluciones de stream en vuelo (id normalizado → (Future, eraPreload)).
  /// Deduplica resoluciones concurrentes.
  final Map<String, (Future<String?>, bool)> _futuresStream = {};

  /// Errores de decode consecutivos del track actual — rompe el loop infinito
  /// de retry de libmpv sobre un recurso que no puede decodificar.
  int _erroresConsecutivos = 0;

  /// True mientras se cae de un archivo local que falló a su stream.
  bool _recuperando = false;

  /// Última URI entregada al player (diagnósticos / tracking roto).
  String? _ultimaUriAbierta;

  /// URL base del proxy de streaming Go, arrancado lazy al primer playback de
  /// YouTube (las URLs googlevideo se reproducen por el proxy local).
  String? _baseProxyStream;
  Future<String?>? _futuroProxyStream;

  /// URLs de stream que ya fallaron al decodificar (id → url).
  final Map<String, String> _urlRotaPorTrack = {};

  /// Reintentos de re-descarga de archivo muerto por track (id → count).
  final Map<String, int> _reintentosArchivoMuerto = {};

  /// Re-resoluciones por open-stall (id → count). Acota el loop del watchdog.
  final Map<String, int> _reintentosStall = {};

  /// Tracks recuperados de un stream corto/preview (una re-apertura por track).
  final Set<String> _tracksRecuperadosPreview = {};

  /// Tracks recuperados de un EOF de stream muerto/truncado (una vez por track).
  final Set<String> _muertosStreamRecuperados = {};

  /// True mientras un switch a un track no-local nuevo está resolviendo.
  bool _switchPendiente = false;

  /// Generación monotónica de _openTrack: una llamada más nueva supersede a
  /// las in-flight más viejas (evita que una resolución lenta pise un track
  /// abierto después).
  int _generacionOpen = 0;

  /// Generación capturada cuando el último media terminó de abrir. Un evento
  /// `completed` cuya generación no coincide no debe avanzar la cola.
  int _generacionAbiertaEn = 0;

  /// Identidad (id|source) del track que el último open está abriendo/abrió.
  String? _claveTrackAbierto;

  /// True mientras una completación real de EOF está avanzando la cola, para
  /// que el replay del mismo track (repeat-one) reabra en vez de ser saltado.
  bool _forzarReopen = false;

  /// Último error de backend/resolución para el intento de open actual.
  String _ultimoErrorStream = '';
  String _ultimoTipoErrorStream = '';
  String _ultimoServicioStream = '';

  /// Resolución de URL de stream — la implementación concreta vive en
  /// ReproductorStreamResolve (arriba en la cadena); declaración para poder
  /// llamarla desde el prefetch.
  Future<String?> _resolveStreamUrl(
    ItemFeed track, {
    bool esPreload = false,
    bool conRespaldo = false,
  });

  /// Throttle de prefetch: máximo [slotsPrefetch] resoluciones de stream en
  /// vuelo a la vez — prefetches de fondo en paralelo saturan el executor.
  static const int slotsPrefetch = 3;
  int _prefetchUsados = 0;
  final List<(ItemFeed, bool)> _colaPrefetch = [];

  /// Encola una resolución de stream de fondo para [track]. Los probes solo
  /// resuelven streams directos (barato); un preload completo
  /// ([conRespaldo] true) corre todo el pipeline para que la URL/archivo esté
  /// listo cuando el track se toque de verdad.
  void _programarPrefetch(ItemFeed track, {bool conRespaldo = false}) {
    if (_prefetchUsados >= slotsPrefetch) {
      _colaPrefetch.add((track, conRespaldo));
      return;
    }
    _prefetchUsados++;
    unawaited(_ejecutarPrefetch(track, conRespaldo: conRespaldo));
  }

  Future<void> _ejecutarPrefetch(
    ItemFeed track, {
    bool conRespaldo = false,
  }) async {
    try {
      await _resolveStreamUrl(track, esPreload: true, conRespaldo: conRespaldo);
    } finally {
      _prefetchUsados--;
      if (_colaPrefetch.isNotEmpty) {
        final (siguiente, siguienteFull) = _colaPrefetch.removeAt(0);
        _prefetchUsados++;
        unawaited(_ejecutarPrefetch(siguiente, conRespaldo: siguienteFull));
      }
    }
  }
}