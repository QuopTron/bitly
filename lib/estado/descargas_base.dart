// ─────────────────────────────────────────────────────────────
// descargas_base.dart — PART de cubit_descargas.dart: mixin base
// con TODOS los campos de estado del cubit: timers, lotes,
// metadata, sets anti-reproceso, cola secuencial y flags. Las
// clases auxiliares viven en descargas_modelos.dart.
// Parte del flujo: descargas (Mi Espacio y botón de descarga).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Campos de estado del cubit de descargas.
mixin DescargasBase on Cubit<EstadoCubitDescargas> {
  /// Backend Go inyectado desde el constructor de CubitDescargas.
  late BackendService _backend;

  /// Caché de descargas (BD drift) resuelto desde la inyección.
  late CacheDescargas _downloadCache;
  Timer? _timerProgreso;
  Timer? _timerHistorial;

  /// Cuándo arrancó cada descarga (detección de timeout).
  final Map<String, DateTime> _iniciadosEn = {};

  /// Ciclos consecutivos donde el backend devolvió progreso vacío con items
  /// en curso. Detecta reinicio del backend.
  int _rachaProgresoVacio = 0;

  /// Clave de lote (p.ej. "album_123_spotify") → lista de IDs de audio, para
  /// calcular el progreso agregado desde los estados individuales.
  final Map<String, List<String>> _batchTrackIds = {};

  /// Datos originales del lote para reintentar tracks fallidos.
  final Map<String, _DatosLote> _datosLote = {};

  /// Lotes ya persistidos como completados ({key, item_type, item_id,
  /// source}) para que _finalizarLoteCompletado guarde/invalide solo una vez.
  final Set<String> _lotesGuardadosCompletados = {};

  /// Reintento automático por lote: cuando un lote llega a allDone con
  /// rezagados, se agenda un reintento retrasado hasta [_maxReintentosAutoLote]
  /// veces para que el álbum/playlist quede en verde sin intervención.
  final Map<String, int> _reintentosAutoPorLote = {};
  final int _maxReintentosAutoLote = 2;

  /// IDs de track ya reintentados y fallidos en este lote. Evita loops
  /// infinitos para tracks que fallan consistentemente.
  final Map<String, Set<String>> _reintentosFallidosPorLote = {};

  /// Clave "track_{id}_{source}" → metadata, poblada desde la BD y lotes.
  final Map<String, _InfoTrack> _metaTrack = {};

  /// IDs normalizados que ya existen en el historial de descargas.
  final Set<String> _idsTracksDescargados = {};

  /// Clave de lote → metadata del lote, poblada desde la BD.
  final Map<String, _MetaLote> _metaLote = {};

  /// [item_id] de Go → state key (p.ej. "deezer:3171003131" →
  /// "track_3171003131_deezer"). Traduce entradas de progreso de Go a keys
  /// locales en _pollProgreso.
  final Map<String, String> _itemIdAKeyEstado = {};

  /// IDs crudos de Go cuya descarga encriptada/DRM ya la manejó el decrypt
  /// del cliente (ffmpeg-kit). Evita reprocesar la misma entrada completada.
  final Set<String> _decryptClienteHecho = {};

  /// IDs crudos de Go cuyo decrypt del cliente FALLÓ. Sin esto, el tracker de
  /// Go (que reporta completados para siempre) dispararía un intento nuevo de
  /// ffmpeg-kit en cada poll de 3s, inundando el log.
  final Set<String> _decryptClienteSaltado = {};

  /// IDs crudos de Go cuya completación ya se persistió (fila BD, carátula,
  /// fingerprint) en un poll anterior. El tracker reporta completados para
  /// siempre; sin esto el poller de 3s re-guardaría cada descarga terminada.
  final Set<String> _completadosPersistidos = {};

  /// IDs crudos de Go cuya descarga borró el usuario. Evita que el poll de 3s
  /// resucite un track borrado antes de que el RPC cancel de Go surta efecto.
  final Set<String> _borradosPendientes = {};

  /// IDs crudos de Go donde ya se resolvió una carrera de proveedores (se
  /// encontró archivo alternativo reproducible). Evita re-chequeos por poll.
  final Set<String> _carreraResuelta = {};

  /// Contador de polls "completado pero no reproducible". Cuando Go dice
  /// 'completed' pero el archivo no es reproducible (p.ej. el .mp3 de
  /// SoundCloud llegó antes que el .m4a de Apple Music), se esperan hasta 4
  /// ciclos (~12s) por el archivo alternativo.
  final Map<String, int> _completadosSinArchivoCount = {};

  /// IDs de track cuyos archivos se confirmaron ausentes del disco durante
  /// _cargarHistorial. Evita el loop donde _cargarHistorial reprocesa la
  /// misma entrada sin archivo cada 10-30s.
  final Set<String> _historialSaltados = {};

  /// Tracks que se están re-despachando tras una verificación fallida.
  final Set<String> _colaRedescarga = {};

  /// No-null cuando hay un snackbar de fallo de decrypt pendiente.
  String? _errorDesencriptadoPendiente;

  /// Evita flujos de verificación concurrentes disparados por _pollProgreso.
  bool _verificacionEnCurso = false;

  /// Evita polls superpuestos: el decrypt con ffmpeg-kit puede durar más que
  /// el timer de 3s y polls concurrentes correrían sobre el mismo archivo.
  bool _pollingEnCurso = false;

  /// True una vez que corrió la reparación de arranque de descargas rotas.
  bool _reparacionIntentada = false;

  /// Fallos de decrypt por ID crudo de Go. Un fallo se reintenta en polls
  /// posteriores hasta [_maxReintentosDecrypt] veces antes de marcarlo
  /// saltado (fallos transitorios de ffmpeg-kit son comunes en emuladores).
  final Map<String, int> _fallosDecryptCount = {};
  final int _maxReintentosDecrypt = 3;

  /// Ciclos de poll donde Go reporta `failed` + cola activa + sin archivo.
  /// Tras [_maxPollFallidosSinArchivo] ciclos (~15s), la cola abandona y pasa
  /// al siguiente track en vez de loopear para siempre.
  final Map<String, int> _fallidosSinArchivoCount = {};
  final int _maxPollFallidosSinArchivo = 5;

  // ── Cola secuencial de descargas con consciencia de lote ────────────────
  final List<_TrackEnCola> _colaDescargas = [];
  bool _procesandoCola = false;
  Completer<void>? _completadorTrackActual;
  String? _idTrackActualCola;

  /// Map de IDs de extensión → nombres amigables para mostrar.
  final Map<String, String> _nombresMostrarProveedor = {
    'deezer': 'Deezer',
    'qobuz-web': 'Qobuz',
    'tidal-web': 'Tidal',
    'amazon': 'Amazon Music',
    'apple-music': 'Apple Music',
    'soundcloud': 'SoundCloud',
    'pandora': 'Pandora',
  };

  /// Timestamp ISO 8601 de la última carga de lotes. Se pasa como 'since' a
  /// getLotesDescargados para delta loading.
  String? _ultimoTimestampLotes;

  @override
  Future<void> close() {
    _timerProgreso?.cancel();
    _timerHistorial?.cancel();
    return super.close();
  }
}