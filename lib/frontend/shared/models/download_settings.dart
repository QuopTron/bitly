class DownloadSettings {
  final String audioQuality;
  final bool videoEnabled;
  final String videoQuality;
  final bool lyricsEnabled;
  final String lyricsSource;
  /// When true, the download button skips the options sheet and
  /// directly downloads with saved preferences.
  final bool quickDownload;
  /// TTL en segundos para el cache de archivos locales en el player.
  /// Controla cada cuánto se recarga el mapa _localFiles desde el backend.
  /// Valores: 5–120s. Default: 30.
  final int localFilesTtlSeconds;

  const DownloadSettings({
    this.audioQuality = 'flac',
    this.videoEnabled = false,
    this.videoQuality = '720p',
    this.lyricsEnabled = true,
    this.lyricsSource = 'lrclib',
    this.quickDownload = false,
    this.localFilesTtlSeconds = 30,
  });

  factory DownloadSettings.fromJson(Map<String, dynamic> json) {
    return DownloadSettings(
      audioQuality: json['download_audio_quality'] as String? ?? 'flac',
      videoEnabled: json['download_video_enabled'] as bool? ?? false,
      videoQuality: json['download_video_quality'] as String? ?? '720p',
      lyricsEnabled: json['download_lyrics_enabled'] as bool? ?? true,
      lyricsSource: json['download_lyrics_source'] as String? ?? 'lrclib',
      quickDownload: json['download_quick'] as bool? ?? false,
      localFilesTtlSeconds: json['local_files_ttl_seconds'] as int? ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {
    'download_audio_quality': audioQuality,
    'download_video_enabled': videoEnabled,
    'download_video_quality': videoQuality,
    'download_lyrics_enabled': lyricsEnabled,
    'download_lyrics_source': lyricsSource,
    'download_quick': quickDownload,
    'local_files_ttl_seconds': localFilesTtlSeconds,
  };

  DownloadSettings copyWith({
    String? audioQuality,
    bool? videoEnabled,
    String? videoQuality,
    bool? lyricsEnabled,
    String? lyricsSource,
    bool? quickDownload,
    int? localFilesTtlSeconds,
  }) {
    return DownloadSettings(
      audioQuality: audioQuality ?? this.audioQuality,
      videoEnabled: videoEnabled ?? this.videoEnabled,
      videoQuality: videoQuality ?? this.videoQuality,
      lyricsEnabled: lyricsEnabled ?? this.lyricsEnabled,
      lyricsSource: lyricsSource ?? this.lyricsSource,
      quickDownload: quickDownload ?? this.quickDownload,
      localFilesTtlSeconds: localFilesTtlSeconds ?? this.localFilesTtlSeconds,
    );
  }

  static const audioQualityOptions = ['flac', 'hifi', 'high', 'medium', 'low'];
  static const videoQualityOptions = ['720p', '1080p', '480p'];
  static const lyricsSourceOptions = ['lrclib', 'apple_music', 'musixmatch', 'genius', 'netease', 'deezer', 'spotify'];
}

