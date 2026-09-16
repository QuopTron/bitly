// ─────────────────────────────────────────────────────────────
// descargas_base.dart — PART de cubit_descargas.dart: mixin base
// con TODOS los campos de estado del cubit: timers, lotes,
// metadata, sets anti-reproceso, cola secuencial y flags. Las
// clases auxiliares viven en descargas_modelos.dart.
// Parte del flujo: descargas (Mi Espacio y botón de descarga).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Campos de estado del cubit de descargas.
mixin DescargasBase on DescargasBaseCaches {
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

  /// Reintentos EN SITIO por track (baseId → reintentos ya consumidos). Una
  /// canción que falla NO deja avanzar el FIFO: se reencola al FRENTE con la
  /// calidad degradada hasta agotar [_maxReintentosInSitu]. Se limpia cuando
  /// el track completa y cuando la cola se vacía.
  final Map<String, int> _intentosPorTrack = {};

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

  @override
  Future<void> close() {
    _timerProgreso?.cancel();
    _timerHistorial?.cancel();
    return super.close();
  }
}
