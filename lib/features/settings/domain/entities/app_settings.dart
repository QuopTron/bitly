class AppSettings {
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

  const AppSettings({
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

  AppSettings copyWith({
    String? username,
    String? language,
    String? themeMode,
    bool? loggingEnabled,
    String? downloadDirectory,
    int? maxConcurrentDownloads,
    bool? enableScrobbling,
    String? lastfmUser,
    String? lastfmPassword,
    List<String>? lyricsProviders,
    bool? autoFetchLyrics,
  }) {
    return AppSettings(
      username: username ?? this.username,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      loggingEnabled: loggingEnabled ?? this.loggingEnabled,
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      enableScrobbling: enableScrobbling ?? this.enableScrobbling,
      lastfmUser: lastfmUser ?? this.lastfmUser,
      lastfmPassword: lastfmPassword ?? this.lastfmPassword,
      lyricsProviders: lyricsProviders ?? this.lyricsProviders,
      autoFetchLyrics: autoFetchLyrics ?? this.autoFetchLyrics,
    );
  }

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

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
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
}
