import 'package:json_annotation/json_annotation.dart';
import 'package:bitly/utils/artist_utils.dart';

part 'settings.g.dart';

@JsonSerializable()
class AppSettings {
  static const String homeFeedProviderOff = '__off__';

  final String defaultService;
  final String audioQuality;
  final String filenameFormat;
  final String downloadDirectory;
  final String downloadDirectoryBookmark;
  final String storageMode; // 'app' or 'saf'
  final String downloadTreeUri; // SAF persistable tree URI
  final bool autoFallback;
  final bool embedMetadata; // Master switch for metadata/cover/lyrics embedding
  final String
  artistTagMode; // 'joined' or 'split_vorbis' for Vorbis-based formats
  final bool embedLyrics;
  final bool embedReplayGain; // Calculate and embed ReplayGain tags
  final bool maxQualityCover;
  final bool downloadVideo;
  final bool isFirstLaunch;
  final int concurrentDownloads;
  final bool checkForUpdates;
  final String updateChannel;
  final bool hasSearchedBefore;

  final String historyViewMode;
  final String historyFilterMode;
  final bool askQualityBeforeDownload;
  final bool enableLogging;
  final bool useExtensionProviders;
  final List<String>? downloadFallbackExtensionIds;
  final String? searchProvider;
  final String defaultSearchTab;
  final String? homeFeedProvider;

  final bool showExtensionStore;
  final String locale;
  final String lyricsMode;
  final String
  tidalHighFormat; // Format for Tidal HIGH quality: 'mp3_320', 'opus_256', or 'opus_128'
  final bool
  useAllFilesAccess; // Android 13+ only: enable MANAGE_EXTERNAL_STORAGE
  final bool
  autoExportFailedDownloads; // Auto export failed downloads to TXT file
  final String
  downloadNetworkMode; // 'any' = WiFi + Mobile, 'wifi_only' = WiFi only
  final bool
  networkCompatibilityMode; // Try HTTP + allow invalid TLS cert for API requests
  final String
  songLinkRegion; // SongLink userCountry region code used for platform lookup
  final bool
  nativeDownloadWorkerEnabled; // Experimental Android service-owned worker

  final bool localLibraryEnabled; // Enable local library scanning
  final String localLibraryPath; // Path to scan for audio files
  final String
  localLibraryBookmark; // Base64-encoded iOS security-scoped bookmark
  final bool
  localLibraryShowDuplicates; // Show indicator when searching for existing tracks
  final String
  localLibraryAutoScan; // Auto-scan mode: 'off', 'on_open', 'daily', 'weekly'

  final bool
  hasCompletedTutorial; // Track if user has completed the app tutorial

  final List<String>
  lyricsProviders; // Ordered list of enabled lyrics provider IDs
  final bool
  lyricsIncludeTranslationNetease; // Append translated lyrics (Netease)
  final bool
  lyricsIncludeRomanizationNetease; // Append romanized lyrics (Netease)
  final bool
  lyricsMultiPersonWordByWord; // Enable v1/v2 + [bg:] tags for Apple/QQ syllable lyrics
  final String
  musixmatchLanguage; // Optional ISO language code for Musixmatch localized lyrics

  final String
  lastSeenVersion; // Last app version the user has acknowledged (e.g. '3.7.0')

  final bool
  deduplicateDownloads; // Skip downloading tracks already present in history

  final bool
  lyricsAppleElrcWordSync; // Preserve Apple ELRC word-level timings in synced lyrics

  final bool
  separateSingles; // Separate singles from albums in folder structure

  final String
  albumFolderStructure; // Folder structure: 'album' (Artist/Album) or 'artist' (Artist - Album)

  final String username;
  final bool isPremium;
  final int premiumUntil;
  final String premiumCode;

  const AppSettings({
    this.defaultService = '',
    this.audioQuality = 'LOSSLESS',
    this.filenameFormat = '{title} - {artist}',
    this.downloadDirectory = '',
    this.downloadDirectoryBookmark = '',
    this.storageMode = 'app',
    this.downloadTreeUri = '',
    this.autoFallback = true,
    this.embedMetadata = true,
    this.artistTagMode = artistTagModeJoined,
    this.embedLyrics = true,
    this.embedReplayGain = false,
    this.maxQualityCover = true,
    this.downloadVideo = false,
    this.isFirstLaunch = true,
    this.concurrentDownloads = 1,
    this.checkForUpdates = true,
    this.updateChannel = 'stable',
    this.hasSearchedBefore = false,

    this.historyViewMode = 'grid',
    this.historyFilterMode = 'all',
    this.askQualityBeforeDownload = true,
    this.enableLogging = false,
    this.useExtensionProviders = true,
    this.downloadFallbackExtensionIds,
    this.searchProvider,
    this.defaultSearchTab = 'all',
    this.homeFeedProvider,

    this.showExtensionStore = true,
    this.locale = 'es',
    this.lyricsMode = 'embed',
    this.tidalHighFormat = 'mp3_320',
    this.useAllFilesAccess = false,
    this.autoExportFailedDownloads = false,
    this.downloadNetworkMode = 'any',
    this.networkCompatibilityMode = false,
    this.songLinkRegion = 'US',
    this.nativeDownloadWorkerEnabled = false,
    this.localLibraryEnabled = false,
    this.localLibraryPath = '',
    this.localLibraryBookmark = '',
    this.localLibraryShowDuplicates = true,
    this.localLibraryAutoScan = 'off',
    this.hasCompletedTutorial = false,
    this.lyricsProviders = const ['lrclib', 'apple_music'],
    this.lyricsIncludeTranslationNetease = false,
    this.lyricsIncludeRomanizationNetease = false,
    this.lyricsMultiPersonWordByWord = false,
    this.musixmatchLanguage = '',
    this.lastSeenVersion = '',
    this.deduplicateDownloads = true,
    this.lyricsAppleElrcWordSync = false,
    this.separateSingles = true,
    this.albumFolderStructure = 'album',
    this.username = '',
    this.isPremium = false,
    this.premiumUntil = 0,
    this.premiumCode = '',
  });

  AppSettings copyWith({
    String? defaultService,
    String? audioQuality,
    String? filenameFormat,
    String? downloadDirectory,
    String? downloadDirectoryBookmark,
    String? storageMode,
    String? downloadTreeUri,
    bool? autoFallback,
    bool? embedMetadata,
    String? artistTagMode,
    bool? embedLyrics,
    bool? embedReplayGain,
    bool? maxQualityCover,
    bool? downloadVideo,
    bool? isFirstLaunch,
    int? concurrentDownloads,
    bool? checkForUpdates,
    String? updateChannel,
    bool? hasSearchedBefore,

    String? historyViewMode,
    String? historyFilterMode,
    bool? askQualityBeforeDownload,
    bool? enableLogging,
    bool? useExtensionProviders,
    List<String>? downloadFallbackExtensionIds,
    bool clearDownloadFallbackExtensionIds = false,
    String? searchProvider,
    bool clearSearchProvider = false,
    String? defaultSearchTab,
    String? homeFeedProvider,
    bool clearHomeFeedProvider = false,

    bool? showExtensionStore,
    String? locale,
    String? lyricsMode,
    String? tidalHighFormat,
    bool? useAllFilesAccess,
    bool? autoExportFailedDownloads,
    String? downloadNetworkMode,
    bool? networkCompatibilityMode,
    String? songLinkRegion,
    bool? nativeDownloadWorkerEnabled,
    bool? localLibraryEnabled,
    String? localLibraryPath,
    String? localLibraryBookmark,
    bool? localLibraryShowDuplicates,
    String? localLibraryAutoScan,
    bool? hasCompletedTutorial,
    List<String>? lyricsProviders,
    bool? lyricsIncludeTranslationNetease,
    bool? lyricsIncludeRomanizationNetease,
    bool? lyricsMultiPersonWordByWord,
    String? musixmatchLanguage,
    String? lastSeenVersion,
    bool? deduplicateDownloads,
    bool? lyricsAppleElrcWordSync,
    bool? separateSingles,
    String? albumFolderStructure,
    String? username,
    bool? isPremium,
    int? premiumUntil,
    String? premiumCode,
  }) {
    return AppSettings(
      defaultService: defaultService ?? this.defaultService,
      audioQuality: audioQuality ?? this.audioQuality,
      filenameFormat: filenameFormat ?? this.filenameFormat,
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
      downloadDirectoryBookmark:
          downloadDirectoryBookmark ?? this.downloadDirectoryBookmark,
      storageMode: storageMode ?? this.storageMode,
      downloadTreeUri: downloadTreeUri ?? this.downloadTreeUri,
      autoFallback: autoFallback ?? this.autoFallback,
      embedMetadata: embedMetadata ?? this.embedMetadata,
      artistTagMode: artistTagMode ?? this.artistTagMode,
      embedLyrics: embedLyrics ?? this.embedLyrics,
      embedReplayGain: embedReplayGain ?? this.embedReplayGain,
      maxQualityCover: maxQualityCover ?? this.maxQualityCover,
      downloadVideo: downloadVideo ?? this.downloadVideo,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      concurrentDownloads: concurrentDownloads ?? this.concurrentDownloads,
      checkForUpdates: checkForUpdates ?? this.checkForUpdates,
      updateChannel: updateChannel ?? this.updateChannel,
      hasSearchedBefore: hasSearchedBefore ?? this.hasSearchedBefore,

      historyViewMode: historyViewMode ?? this.historyViewMode,
      historyFilterMode: historyFilterMode ?? this.historyFilterMode,
      askQualityBeforeDownload:
          askQualityBeforeDownload ?? this.askQualityBeforeDownload,
      enableLogging: enableLogging ?? this.enableLogging,
      useExtensionProviders:
          useExtensionProviders ?? this.useExtensionProviders,
      downloadFallbackExtensionIds: clearDownloadFallbackExtensionIds
          ? null
          : (downloadFallbackExtensionIds ?? this.downloadFallbackExtensionIds),
      searchProvider: clearSearchProvider
          ? null
          : (searchProvider ?? this.searchProvider),
      defaultSearchTab: defaultSearchTab ?? this.defaultSearchTab,
      homeFeedProvider: clearHomeFeedProvider
          ? null
          : (homeFeedProvider ?? this.homeFeedProvider),

      showExtensionStore: showExtensionStore ?? this.showExtensionStore,
      locale: locale ?? this.locale,
      lyricsMode: lyricsMode ?? this.lyricsMode,
      tidalHighFormat: tidalHighFormat ?? this.tidalHighFormat,
      useAllFilesAccess: useAllFilesAccess ?? this.useAllFilesAccess,
      autoExportFailedDownloads:
          autoExportFailedDownloads ?? this.autoExportFailedDownloads,
      downloadNetworkMode: downloadNetworkMode ?? this.downloadNetworkMode,
      networkCompatibilityMode:
          networkCompatibilityMode ?? this.networkCompatibilityMode,
      songLinkRegion: songLinkRegion ?? this.songLinkRegion,
      nativeDownloadWorkerEnabled:
          nativeDownloadWorkerEnabled ?? this.nativeDownloadWorkerEnabled,
      localLibraryEnabled: localLibraryEnabled ?? this.localLibraryEnabled,
      localLibraryPath: localLibraryPath ?? this.localLibraryPath,
      localLibraryBookmark: localLibraryBookmark ?? this.localLibraryBookmark,
      localLibraryShowDuplicates:
          localLibraryShowDuplicates ?? this.localLibraryShowDuplicates,
      localLibraryAutoScan: localLibraryAutoScan ?? this.localLibraryAutoScan,
      hasCompletedTutorial: hasCompletedTutorial ?? this.hasCompletedTutorial,
      lyricsProviders: lyricsProviders ?? this.lyricsProviders,
      lyricsIncludeTranslationNetease:
          lyricsIncludeTranslationNetease ??
          this.lyricsIncludeTranslationNetease,
      lyricsIncludeRomanizationNetease:
          lyricsIncludeRomanizationNetease ??
          this.lyricsIncludeRomanizationNetease,
      lyricsMultiPersonWordByWord:
          lyricsMultiPersonWordByWord ?? this.lyricsMultiPersonWordByWord,
      musixmatchLanguage: musixmatchLanguage ?? this.musixmatchLanguage,
      lastSeenVersion: lastSeenVersion ?? this.lastSeenVersion,
      deduplicateDownloads: deduplicateDownloads ?? this.deduplicateDownloads,
      lyricsAppleElrcWordSync:
          lyricsAppleElrcWordSync ?? this.lyricsAppleElrcWordSync,
      separateSingles: separateSingles ?? this.separateSingles,
      albumFolderStructure: albumFolderStructure ?? this.albumFolderStructure,
      username: username ?? this.username,
      isPremium: isPremium ?? this.isPremium,
      premiumUntil: premiumUntil ?? this.premiumUntil,
      premiumCode: premiumCode ?? this.premiumCode,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);
}
