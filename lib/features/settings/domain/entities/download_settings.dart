class DownloadSettings {
  final String? directory;
  final int maxConcurrent;
  final String preferredQuality;
  final bool autoStart;
  final bool createPlaylist;
  final bool downloadLyrics;
  final bool downloadCover;
  final bool convertToFlac;
  final bool keepOriginal;

  const DownloadSettings({
    this.directory,
    this.maxConcurrent = 3,
    this.preferredQuality = 'flac',
    this.autoStart = true,
    this.createPlaylist = false,
    this.downloadLyrics = true,
    this.downloadCover = true,
    this.convertToFlac = false,
    this.keepOriginal = true,
  });

  DownloadSettings copyWith({
    String? directory,
    int? maxConcurrent,
    String? preferredQuality,
    bool? autoStart,
    bool? createPlaylist,
    bool? downloadLyrics,
    bool? downloadCover,
    bool? convertToFlac,
    bool? keepOriginal,
  }) {
    return DownloadSettings(
      directory: directory ?? this.directory,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      autoStart: autoStart ?? this.autoStart,
      createPlaylist: createPlaylist ?? this.createPlaylist,
      downloadLyrics: downloadLyrics ?? this.downloadLyrics,
      downloadCover: downloadCover ?? this.downloadCover,
      convertToFlac: convertToFlac ?? this.convertToFlac,
      keepOriginal: keepOriginal ?? this.keepOriginal,
    );
  }

  Map<String, dynamic> toJson() => {
        'directory': directory,
        'maxConcurrent': maxConcurrent,
        'preferredQuality': preferredQuality,
        'autoStart': autoStart,
        'createPlaylist': createPlaylist,
        'downloadLyrics': downloadLyrics,
        'downloadCover': downloadCover,
        'convertToFlac': convertToFlac,
        'keepOriginal': keepOriginal,
      };

  factory DownloadSettings.fromJson(Map<String, dynamic> json) =>
      DownloadSettings(
        directory: json['directory'] as String?,
        maxConcurrent: json['maxConcurrent'] as int? ?? 3,
        preferredQuality: json['preferredQuality'] as String? ?? 'flac',
        autoStart: json['autoStart'] as bool? ?? true,
        createPlaylist: json['createPlaylist'] as bool? ?? false,
        downloadLyrics: json['downloadLyrics'] as bool? ?? true,
        downloadCover: json['downloadCover'] as bool? ?? true,
        convertToFlac: json['convertToFlac'] as bool? ?? false,
        keepOriginal: json['keepOriginal'] as bool? ?? true,
      );
}
