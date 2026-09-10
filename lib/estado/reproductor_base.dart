// ─────────────────────────────────────────────────────────────
// reproductor_base.dart — PART de cubit_reproductor.dart: mixin
// base con los campos del player mpv (colá, subscriptions, crossfade,
// volumen, calidad, precarga de media) y los getters públicos. Los
// campos de caché/errores viven en reproductor_estado_cache.dart.
// Cadena de mixins: base → estado_cache → stream → stream_proxy →
// stream_pipeline → stream_resolve → archivos_temp → video_local →
// video_descarga → video_fondo → preload → preload_media →
// controles → verificacion → reporte → apertura_helpers →
// apertura → autoplay → limpieza → completado → locales →
// player_setup → listener_cola → init.
// Se conecta con: cubit_reproductor.dart (misma library).
// Parte del flujo: reproducción (estado compartido del player).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Stream URL resuelta, guardada en el caché en memoria/persistente.
class _StreamCacheado {
  final String url;
  final bool conRespaldo;

  /// Expiración propia de la URL (las URLs de YouTube llevan `expire`), o
  /// null para archivos locales / desconocidos — ver [_expiryForUrl].
  final DateTime? expiraEn;

  const _StreamCacheado(this.url, this.conRespaldo, this.expiraEn);
}

/// URLs de stream cuya vida restante está dentro de esta ventana se tratan
/// como viejas y se re-resuelven (mismo margen de 60s de ArchiveTune).
const _margenSeguridadUrl = Duration(seconds: 60);

/// Vida útil conservadora para streams http(s) directos sin expiración
/// explícita (CDN de soundcloud/deezer...). Las de YouTube llevan su propio
/// `expire` que [_expiryForUrl] parsea en su lugar.
const _ttlStreamDefault = Duration(hours: 6);

/// Crossfade: cuando es true, el listener de posición hace fade-out cerca del
/// final del track y el handler de completado hace fade-in del siguiente.
const _crossfadeHabilitado = true;

/// Ventana corta a propósito: el fade-out empieza 1.5s antes del final y dura
/// 0.8s, así el silencio entre canciones queda en ~0.7s máximo. Antes era
/// 5s/3s → el volumen llegaba a 0 con 2s de canción restante y el usuario
/// percibía un "muteo" de 2 segundos entre canciones.
const _duracionCrossfade = Duration(milliseconds: 800);
const _crossfadeInicioAntesDelFinal = Duration(milliseconds: 1500);

/// Fuentes de stream completo (el backend sirve audio COMPLETO): un preload
/// de una de estas es un track entero, un tap puede reusarlo sin re-resolver.
const _fuentesStreamCompleto = {
  'ytmusic-spotiflac',
  'youtube',
  'soundcloud',
  'deezer',
  'qobuz-web',
  'tidal-web',
  'ytmusic',
};

/// Mixin base del reproductor: player, subs y estado del usuario.
mixin ReproductorBase on Cubit<EstadoAudioReproductor> {
  // TEMP-DIAG: nivel debug para que el listener vea los errores de open de
  // mpv (403 etc.) mientras se diagnostican URLs muertas de YouTube.
  final Player _player = Player(
    configuration: PlayerConfiguration(logLevel: MPVLogLevel.debug),
  );

  /// Cola de reproducción — se asigna en el constructor de CubitReproductor
  /// (los mixins no tienen constructores, así que el campo es late final).
  late final CubitCola _queueCubit;

  StreamSubscription<Duration>? _subPosicion;
  StreamSubscription<Duration>? _subDuracion;
  StreamSubscription<void>? _subCompletado;
  StreamSubscription<bool>? _subPlaying;
  StreamSubscription? _subError;
  StreamSubscription? _subCola;
  VoidCallback? _subPerfil;

  /// Cola de serialización de operaciones destructivas sobre el Player nativo
  /// (open/stop/pause). Sin esto, media_kit crashea con "Callback invoked
  /// after it has been deleted" (hilo mpv) cuando un segundo open/stop llega
  /// mientras el primero sigue en vuelo — p.ej. el watchdog anti-stall
  /// re-resolviendo un stream lento. Cada operación se encadena al final de
  /// la cola y se ejecuta solo cuando la anterior terminó.
  Future<void> _colaPlayer = Future<void>.value();

  /// Encadena [op] al final de la cola del player. Un error de [op] no rompe
  /// la cadena (las operaciones siguientes siguen ejecutándose).
  Future<void> _enColaPlayer(Future<void> Function() op) {
    final siguiente = _colaPlayer.then((_) => op());
    _colaPlayer = siguiente.catchError((_) {});
    return siguiente;
  }

  bool _crossfadingOut = false;

  /// Marca que el media ACTUAL ya confirmó arrancar desde el inicio (~0s).
  /// Tras un open(), mpv emite la primera posición cerca de 0; un evento de
  /// posición residual del track ANTERIOR (encolado en el stream) llega con
  /// valor ALTO justo después del open y, con duraciones parecidas, podía
  /// disparar el crossfade-out en el track NUEVO a los ~2s y dejarlo mudo
  /// (el muteo intermitente al cambiar de canción). Solo arrancar el
  /// crossfade una vez confirmado que la posición viene del media nuevo.
  bool _mediaNuevoConfirmado = false;

  /// Volumen intencional del usuario (0.0–1.0). Las animaciones de crossfade
  /// modifican el volumen real de mpv sin tocar este valor, así la
  /// configuración del usuario nunca se pierde entre tracks.
  double _volumenUsuario = 1.0;

  /// IDs normalizados listos para reproducir al instante (stream ya resuelto o
  /// archivo local disponible). Respaldan el indicador "ready" de las tarjetas.
  final ValueNotifier<Set<String>> tracksListos = ValueNotifier(
    const <String>{},
  );

  /// Marca [idNormalizado] como listo para reproducir y notifica.
  void _marcarListo(String idNormalizado) {
    final actual = tracksListos.value;
    if (actual.contains(idNormalizado)) return;
    tracksListos.value = {...actual, idNormalizado};
  }

  /// Caché local de reproducción (Drift) para logging de plays.
  ReproduccionCache? _playbackCache;

  /// TTL del caché de _archivosLocales (desde AjustesDescarga). Default 5s.
  Duration _ttlArchivosLocales = const Duration(seconds: 5);
  DateTime? _archivosLocalesCargadosEn;

  /// Timestamp ISO 8601 de la última carga de _archivosLocales, pasado como
  /// 'since' al backend en cargas delta posteriores.
  String? _ultimoTimestampCarga;

  // ── Getters públicos ─────────────────────────────────────────────────────
  String get calidadAudio => _calidadAudio;
  String get calidadVideo => _calidadVideo;
  bool get videoHabilitado => _videoHabilitado;
  bool get letrasHabilitadas => _letrasHabilitadas;

  /// Letras (LRC) precargadas del track actual.
  String? letrasPrecargadas;

  /// URL de video precargada del track actual.
  String? urlVideoPrecargado;

  /// Se dispara con la URL del video de fondo cuando está listo (el player
  /// grande lo usa para auto-arrancar el "canvas" sin esperar un emit).
  final ValueNotifier<String?> videoPrecargadoListo = ValueNotifier<String?>(null);
  bool precargandoLetras = false;
  bool precargandoVideo = false;
  bool _listo = false;
  ItemFeed? _trackPendiente;
  String _calidadAudio = 'flac';
  String _calidadVideo = '720p';
  bool _videoHabilitado = false;
  bool _letrasHabilitadas = true;
}