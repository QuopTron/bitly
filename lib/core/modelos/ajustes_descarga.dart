// ─────────────────────────────────────────────────────────────
// ajustes_descarga.dart — Preferencias de descarga del usuario:
// calidad de audio, video, letras, descarga rápida y TTL del caché
// de archivos locales del player.
// Se conecta con: caches (drift) + DownloadCubit + PlayerCubit.
// Parte del flujo: Ajustes → Descargas y reproducción local.
// ─────────────────────────────────────────────────────────────

class AjustesDescarga {
  final String calidadAudio;
  final bool videoHabilitado;
  final String calidadVideo;
  final bool letrasHabilitadas;
  final String fuenteLetras;

  /// Si es true, el botón de descarga salta la hoja de opciones y descarga
  /// directo con las preferencias guardadas.
  final bool descargaRapida;

  /// TTL en segundos para el caché de archivos locales en el player.
  /// Controla cada cuánto se recarga el mapa _archivosLocales desde el
  /// backend. Valores: 5–120s. Default: 30.
  final int ttlArchivosLocalesSegundos;

  const AjustesDescarga({
    this.calidadAudio = 'flac',
    this.videoHabilitado = false,
    this.calidadVideo = '720p',
    this.letrasHabilitadas = true,
    this.fuenteLetras = 'lrclib',
    this.descargaRapida = false,
    this.ttlArchivosLocalesSegundos = 30,
  });

  factory AjustesDescarga.desdeJson(Map<String, dynamic> json) {
    return AjustesDescarga(
      calidadAudio: json['download_audio_quality'] as String? ?? 'flac',
      videoHabilitado: json['download_video_enabled'] as bool? ?? false,
      calidadVideo: json['download_video_quality'] as String? ?? '720p',
      letrasHabilitadas: json['download_lyrics_enabled'] as bool? ?? true,
      fuenteLetras: json['download_lyrics_source'] as String? ?? 'lrclib',
      descargaRapida: json['download_quick'] as bool? ?? false,
      ttlArchivosLocalesSegundos: json['local_files_ttl_seconds'] as int? ?? 30,
    );
  }

  Map<String, dynamic> aJson() => {
    'download_audio_quality': calidadAudio,
    'download_video_enabled': videoHabilitado,
    'download_video_quality': calidadVideo,
    'download_lyrics_enabled': letrasHabilitadas,
    'download_lyrics_source': fuenteLetras,
    'download_quick': descargaRapida,
    'local_files_ttl_seconds': ttlArchivosLocalesSegundos,
  };

  AjustesDescarga copiarCon({
    String? calidadAudio,
    bool? videoHabilitado,
    String? calidadVideo,
    bool? letrasHabilitadas,
    String? fuenteLetras,
    bool? descargaRapida,
    int? ttlArchivosLocalesSegundos,
  }) {
    return AjustesDescarga(
      calidadAudio: calidadAudio ?? this.calidadAudio,
      videoHabilitado: videoHabilitado ?? this.videoHabilitado,
      calidadVideo: calidadVideo ?? this.calidadVideo,
      letrasHabilitadas: letrasHabilitadas ?? this.letrasHabilitadas,
      fuenteLetras: fuenteLetras ?? this.fuenteLetras,
      descargaRapida: descargaRapida ?? this.descargaRapida,
      ttlArchivosLocalesSegundos: ttlArchivosLocalesSegundos ?? this.ttlArchivosLocalesSegundos,
    );
  }

  static const opcionesCalidadAudio = ['flac', 'hifi', 'high', 'medium', 'low'];
  static const opcionesCalidadVideo = ['720p', '1080p', '480p'];
  static const opcionesFuenteLetras = [
    'lrclib',
    'apple_music',
    'musixmatch',
    'genius',
    'netease',
    'deezer',
    'spotify',
  ];
}