import '../../domain/entities/app_settings.dart';

class AppSettingsModel {
  final String? username;
  final String language;
  final String themeMode;
  final bool loggingEnabled;
  final String? downloadDirectory;
  final int maxConcurrentDownloads;
  final bool enableScrobbling;
  final String? lastfmUser;
  final String? lastfmPassword;
  final List<String> lyricsProviders;
  final bool autoFetchLyrics;

  const AppSettingsModel({
    this.username,
    this.language = 'es',
    this.themeMode = 'dark',
    this.loggingEnabled = false,
    this.downloadDirectory,
    this.maxConcurrentDownloads = 3,
    this.enableScrobbling = false,
    this.lastfmUser,
    this.lastfmPassword,
    this.lyricsProviders = const ['genius'],
    this.autoFetchLyrics = true,
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) =>
      AppSettingsModel(
        username: json['username'] as String?,
        language: json['language'] as String? ?? 'es',
        themeMode: json['themeMode'] as String? ?? 'dark',
        loggingEnabled: json['loggingEnabled'] as bool? ?? false,
        downloadDirectory: json['downloadDirectory'] as String?,
        maxConcurrentDownloads:
            json['maxConcurrentDownloads'] as int? ?? 3,
        enableScrobbling: json['enableScrobbling'] as bool? ?? false,
        lastfmUser: json['lastfmUser'] as String?,
        lastfmPassword: json['lastfmPassword'] as String?,
        lyricsProviders: (json['lyricsProviders'] as List<dynamic>?)
                ?.cast<String>() ??
            ['genius'],
        autoFetchLyrics: json['autoFetchLyrics'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'language': language,
        'themeMode': themeMode,
        'loggingEnabled': loggingEnabled,
        'downloadDirectory': downloadDirectory,
        'maxConcurrentDownloads': maxConcurrentDownloads,
        'enableScrobbling': enableScrobbling,
        'lastfmUser': lastfmUser,
        'lastfmPassword': lastfmPassword,
        'lyricsProviders': lyricsProviders,
        'autoFetchLyrics': autoFetchLyrics,
      };

  AppSettings toEntity() => AppSettings(
        username: username,
        language: language,
        themeMode: themeMode,
        loggingEnabled: loggingEnabled,
        downloadDirectory: downloadDirectory,
        maxConcurrentDownloads: maxConcurrentDownloads,
        enableScrobbling: enableScrobbling,
        lastfmUser: lastfmUser,
        lastfmPassword: lastfmPassword,
        lyricsProviders: lyricsProviders,
        autoFetchLyrics: autoFetchLyrics,
      );

  factory AppSettingsModel.fromEntity(AppSettings entity) =>
      AppSettingsModel(
        username: entity.username,
        language: entity.language,
        themeMode: entity.themeMode,
        loggingEnabled: entity.loggingEnabled,
        downloadDirectory: entity.downloadDirectory,
        maxConcurrentDownloads: entity.maxConcurrentDownloads,
        enableScrobbling: entity.enableScrobbling,
        lastfmUser: entity.lastfmUser,
        lastfmPassword: entity.lastfmPassword,
        lyricsProviders: entity.lyricsProviders,
        autoFetchLyrics: entity.autoFetchLyrics,
      );
}
