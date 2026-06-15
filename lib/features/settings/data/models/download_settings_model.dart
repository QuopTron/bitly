import '../../domain/entities/download_settings.dart';

class DownloadSettingsModel {
  final String? directory;
  final int maxConcurrent;
  final String preferredQuality;
  final bool autoStart;
  final bool createPlaylist;
  final bool downloadLyrics;
  final bool downloadCover;
  final bool convertToFlac;
  final bool keepOriginal;

  const DownloadSettingsModel({
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

  factory DownloadSettingsModel.fromJson(Map<String, dynamic> json) =>
      DownloadSettingsModel(
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

  DownloadSettings toEntity() => DownloadSettings(
        directory: directory,
        maxConcurrent: maxConcurrent,
        preferredQuality: preferredQuality,
        autoStart: autoStart,
        createPlaylist: createPlaylist,
        downloadLyrics: downloadLyrics,
        downloadCover: downloadCover,
        convertToFlac: convertToFlac,
        keepOriginal: keepOriginal,
      );

  factory DownloadSettingsModel.fromEntity(DownloadSettings entity) =>
      DownloadSettingsModel(
        directory: entity.directory,
        maxConcurrent: entity.maxConcurrent,
        preferredQuality: entity.preferredQuality,
        autoStart: entity.autoStart,
        createPlaylist: entity.createPlaylist,
        downloadLyrics: entity.downloadLyrics,
        downloadCover: entity.downloadCover,
        convertToFlac: entity.convertToFlac,
        keepOriginal: entity.keepOriginal,
      );
}
