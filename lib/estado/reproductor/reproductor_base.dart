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

/// Mixin base del reproductor: player, subs y estado del usuario.
mixin ReproductorBase on Cubit<EstadoAudioReproductor> {
  // Motor de audio de la plataforma: media_kit (mpv) en nativo y el
  // elemento <audio> del navegador en web. Cuál se usa lo decide el import
  // condicional de cubit_reproductor.dart, así que este mixin no conoce
  // media_kit ni puede arrastrarlo a la compilación web.
  final ReproductorAudio _player = crearReproductorAudio();

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
  final ValueNotifier<String?> videoPrecargadoListo = ValueNotifier<String?>(
    null,
  );
  bool precargandoLetras = false;
  bool precargandoVideo = false;
  bool _listo = false;
  ItemFeed? _trackPendiente;
  String _calidadAudio = 'flac';
  String _calidadVideo = '720p';
  bool _videoHabilitado = false;
  bool _letrasHabilitadas = true;
}
