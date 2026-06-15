class AppearanceSettings {
  final String themeMode;
  final bool useMaterialYou;
  final bool useGlassEffects;
  final bool showAlbumArt;
  final bool showLyricsOnLock;
  final double coverArtSize;

  const AppearanceSettings({
    this.themeMode = 'dark',
    this.useMaterialYou = false,
    this.useGlassEffects = true,
    this.showAlbumArt = true,
    this.showLyricsOnLock = false,
    this.coverArtSize = 48.0,
  });

  AppearanceSettings copyWith({
    String? themeMode,
    bool? useMaterialYou,
    bool? useGlassEffects,
    bool? showAlbumArt,
    bool? showLyricsOnLock,
    double? coverArtSize,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      useMaterialYou: useMaterialYou ?? this.useMaterialYou,
      useGlassEffects: useGlassEffects ?? this.useGlassEffects,
      showAlbumArt: showAlbumArt ?? this.showAlbumArt,
      showLyricsOnLock: showLyricsOnLock ?? this.showLyricsOnLock,
      coverArtSize: coverArtSize ?? this.coverArtSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode,
        'useMaterialYou': useMaterialYou,
        'useGlassEffects': useGlassEffects,
        'showAlbumArt': showAlbumArt,
        'showLyricsOnLock': showLyricsOnLock,
        'coverArtSize': coverArtSize,
      };

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) =>
      AppearanceSettings(
        themeMode: json['themeMode'] as String? ?? 'dark',
        useMaterialYou: json['useMaterialYou'] as bool? ?? false,
        useGlassEffects: json['useGlassEffects'] as bool? ?? true,
        showAlbumArt: json['showAlbumArt'] as bool? ?? true,
        showLyricsOnLock: json['showLyricsOnLock'] as bool? ?? false,
        coverArtSize: (json['coverArtSize'] as num?)?.toDouble() ?? 48.0,
      );
}
