// ─────────────────────────────────────────────────────────────
// descargas_base_caches.dart — PART de cubit_descargas.dart: mixin con
// los caches y contadores de estado del cubit de descargas — récords
// de completados sin archivo, historial saltado, cola de redescarga,
// flags de verificación/polling/reparación y contadores de fallos.
// Cadena de mixins: … → base_caches → base.
// Se conecta con: cubit_descargas.dart (misma library).
// Parte del flujo: descargas (estado interno del cubit).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

mixin DescargasBaseCaches on Cubit<EstadoCubitDescargas> {
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

  /// Último trackMap con el que se intentó cada baseId (título, artista, ISRC,
  /// duración, item_id). Permite reintentar una canción que quedó en fallo
  /// definitivo desde el aviso de descarga, con los MISMOS datos del intento
  /// original: sin esto, reintentar exigiría volver a armar la metadata y el
  /// guard anti-preview se quedaría sin duración de referencia.
  final Map<String, Map<String, dynamic>> _trackMapPorBaseId = {};

  /// Map de IDs de extensión → nombres amigables para mostrar.
  final Map<String, String> _nombresMostrarProveedor = {
    'deezer': 'Deezer',
    'qobuz-web': 'Qobuz',
    'tidal-web': 'Tidal',
    'amazon': 'Amazon Music',
    'apple-music': 'Apple Music',
    'soundcloud': 'SoundCloud',
    'pandora': 'Pandora',
    'internetarchive': 'Internet Archive',
  };

  /// Timestamp ISO 8601 de la última carga de lotes. Se pasa como 'since' a
  /// getLotesDescargados para delta loading.
  String? _ultimoTimestampLotes;
}
