import 'package:json_annotation/json_annotation.dart';
import 'package:bitly/utils/artist_utils.dart';

part 'app_settings.g.dart';

@JsonSerializable()
class AppSettings {
  static const String homeFeedProviderOff = '__off__';

  final String defaultService;
  final String audioQuality;
  final String filenameFormat;
  final String downloadDirectory;
  final String downloadDirectoryBookmark;
  final String storageMode;
  final String downloadTreeUri;
  final bool autoFallback;
  final bool embedMetadata;
  final String artistTagMode;
  final bool embedLyrics;
  final bool embedReplayGain;
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
  final String tidalHighFormat;
  final bool useAllFilesAccess;
  final bool autoExportFailedDownloads;
  final String downloadNetworkMode;
  final bool networkCompatibilityMode;
  final String songLinkRegion;
  final bool nativeDownloadWorkerEnabled;

  final bool localLibraryEnabled;
  final String localLibraryPath;
  final String localLibraryBookmark;
  final bool localLibraryShowDuplicates;
  final String localLibraryAutoScan;

  final bool hasCompletedTutorial;

  final List<String> lyricsProviders;
  final bool lyricsIncludeTranslationNetease;
  final bool lyricsIncludeRomanizationNetease;
  final bool lyricsMultiPersonWordByWord;
  final String musixmatchLanguage;

  final String lastSeenVersion;

  final bool deduplicateDownloads;

  final bool lyricsAppleElrcWordSync;

  final bool separateSingles;

  final String albumFolderStructure;

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

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);
}
