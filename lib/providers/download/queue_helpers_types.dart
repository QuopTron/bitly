part of 'package:bitly/providers/download/download_queue_provider.dart';
int? _readPositiveIntValue(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final asInt = value.toInt();
    return asInt > 0 ? asInt : null;
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

int? _readPositiveBitrateKbps(dynamic value) {
  final parsed = _readPositiveIntValue(value);
  if (parsed == null) return null;
  return parsed >= 10000 ? (parsed / 1000).round() : parsed;
}

String? _audioFormatForPath(String? filePath, {String? fileName}) {
  final candidates = <String>[
    if (filePath != null) filePath,
    if (fileName != null) fileName,
  ];
  for (final candidate in candidates) {
    final lower = candidate.trim().toLowerCase();
    if (lower.endsWith('.opus') || lower.endsWith('.ogg')) return 'OPUS';
    if (lower.endsWith('.mp3')) return 'MP3';
    if (lower.endsWith('.aac')) return 'AAC';
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'M4A';
  }
  return null;
}

bool _isLossyAudioFormat(String? format, {int? bitDepth}) {
  if (format == null) return false;
  switch (format) {
    case 'OPUS':
    case 'MP3':
    case 'AAC':
      return true;
    case 'M4A':
      return bitDepth == null || bitDepth <= 0;
    default:
      return false;
  }
}

String? _nonPlaceholderQuality(String? quality) {
  final normalized = normalizeOptionalString(quality);
  if (normalized == null || isPlaceholderQualityLabel(normalized)) {
    return null;
  }
  final lower = normalized.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  const requestedLosslessLabels = {
    'hi_res_lossless',
    'hires_lossless',
    'hi_res',
    'hires',
    'flac_best_available',
  };
  if (requestedLosslessLabels.contains(lower)) return null;
  return normalized;
}

String? _resolveDisplayQuality({
  required String? filePath,
  String? fileName,
  int? bitDepth,
  int? sampleRate,
  int? bitrateKbps,
  String? storedQuality,
}) {
  final format = _audioFormatForPath(filePath, fileName: fileName);
  if (_isLossyAudioFormat(format, bitDepth: bitDepth)) {
    return buildDisplayAudioQuality(bitrateKbps: bitrateKbps, format: format) ??
        _nonPlaceholderQuality(storedQuality) ??
        format;
  }
  return buildDisplayAudioQuality(
    bitDepth: bitDepth,
    sampleRate: sampleRate,
    storedQuality: _nonPlaceholderQuality(storedQuality) ?? storedQuality,
  );
}

/// log10 helper using dart:math's natural log.
double _log10(num x) => log(x) / ln10;
final _yearRegex = RegExp(r'^(\d{4})');
const _defaultOutputFolderName = 'Bitly';
const _defaultAndroidMusicSubpath = 'Music/$_defaultOutputFolderName';
const _maxSafFilenameUtf8Bytes = 180;
const _maxSafDirSegmentUtf8Bytes = 120;


class DownloadHistoryItem {
  final String id;
  final String trackName;
  final String artistName;
  final String albumName;
  final String? albumArtist;
  final String? coverUrl;
  final String filePath;
  final String? storageMode;
  final String? downloadTreeUri;
  final String? safRelativeDir;
  final String? safFileName;
  final bool safRepaired;
  final String? service;
  final DateTime? downloadedAt;
  final String? isrc;
  final String? spotifyId;
  final int? trackNumber;
  final int? totalTracks;
  final int? discNumber;
  final int? totalDiscs;
  final int? duration;
  final String? releaseDate;
  final String? quality;
  final int? bitDepth;
  final int? sampleRate;
  final int? bitrate;
  final String? format;
  final String? videoFilePath;
  final String? genre;
  final String? composer;
  final String? label;
  final String? copyright;

  const DownloadHistoryItem({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    this.albumArtist,
    this.coverUrl,
    this.filePath = '',
    this.storageMode,
    this.downloadTreeUri,
    this.safRelativeDir,
    this.safFileName,
    this.safRepaired = false,
    this.service = '',
    this.downloadedAt,
    this.isrc,
    this.spotifyId,
    this.trackNumber,
    this.totalTracks,
    this.discNumber,
    this.totalDiscs,
    this.duration,
    this.releaseDate,
    this.quality,
    this.bitDepth,
    this.sampleRate,
    this.bitrate,
    this.format,
    this.videoFilePath,
    this.genre,
    this.composer,
    this.label,
    this.copyright,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'trackName': trackName,
    'artistName': artistName,
    'albumName': albumName,
    'albumArtist': albumArtist,
    'coverUrl': coverUrl,
    'filePath': filePath,
    'storageMode': storageMode,
    'downloadTreeUri': downloadTreeUri,
    'safRelativeDir': safRelativeDir,
    'safFileName': safFileName,
    'safRepaired': safRepaired,
    'service': service,
    'downloadedAt': downloadedAt?.toIso8601String(),
    'isrc': isrc,
    'spotifyId': spotifyId,
    'trackNumber': trackNumber,
    'totalTracks': totalTracks,
    'discNumber': discNumber,
    'totalDiscs': totalDiscs,
    'duration': duration,
    'releaseDate': releaseDate,
    'quality': quality,
    'bitDepth': bitDepth,
    'sampleRate': sampleRate,
    'bitrate': bitrate,
    'format': format,
    'videoFilePath': videoFilePath,
    'genre': genre,
    'composer': composer,
    'label': label,
    'copyright': copyright,
  };

  factory DownloadHistoryItem.fromJson(Map<String, dynamic> json) =>
      DownloadHistoryItem(
        id: json['id'] as String,
        trackName: json['trackName'] as String,
        artistName: json['artistName'] as String,
        albumName: json['albumName'] as String,
        albumArtist: normalizeOptionalString(json['albumArtist'] as String?),
         coverUrl: normalizeCoverReference(json['coverUrl']?.toString()),
         filePath: json['filePath'] as String? ?? '',
        storageMode: json['storageMode'] as String?,
        downloadTreeUri: json['downloadTreeUri'] as String?,
        safRelativeDir: json['safRelativeDir'] as String?,
        safFileName: json['safFileName'] as String?,
        safRepaired: json['safRepaired'] == true,
         service: json['service'] as String?,
        downloadedAt: json['downloadedAt'] == null ? null : DateTime.parse(json['downloadedAt'] as String),
        isrc: json['isrc'] as String?,
        spotifyId: json['spotifyId'] as String?,
        trackNumber: json['trackNumber'] as int?,
        totalTracks: json['totalTracks'] as int?,
        discNumber: json['discNumber'] as int?,
        totalDiscs: json['totalDiscs'] as int?,
        duration: json['duration'] as int?,
        releaseDate: json['releaseDate'] as String?,
        quality: json['quality'] as String?,
        bitDepth: json['bitDepth'] as int?,
        sampleRate: json['sampleRate'] as int?,
        bitrate: json['bitrate'] as int?,
        format: json['format'] as String?,
        videoFilePath: json['videoFilePath'] as String?,
        genre: json['genre'] as String?,
        composer: json['composer'] as String?,
        label: json['label'] as String?,
        copyright: json['copyright'] as String?,
      );

  DownloadHistoryItem copyWith({
    String? trackName,
    String? artistName,
    String? albumName,
    String? albumArtist,
    String? coverUrl,
    String? filePath,
    String? storageMode,
    String? downloadTreeUri,
    String? safRelativeDir,
    String? safFileName,
    bool? safRepaired,
    String? isrc,
    String? spotifyId,
    int? trackNumber,
    int? totalTracks,
    int? discNumber,
    int? totalDiscs,
    int? duration,
    String? releaseDate,
    String? quality,
    int? bitDepth,
    int? sampleRate,
    int? bitrate,
    String? format,
    String? videoFilePath,
    String? genre,
    String? composer,
    String? label,
    String? copyright,
  }) {
    return DownloadHistoryItem(
      id: id,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      albumArtist: albumArtist ?? this.albumArtist,
      coverUrl: normalizeCoverReference(coverUrl ?? this.coverUrl),
      filePath: filePath ?? this.filePath,
      storageMode: storageMode ?? this.storageMode,
      downloadTreeUri: downloadTreeUri ?? this.downloadTreeUri,
      safRelativeDir: safRelativeDir ?? this.safRelativeDir,
      safFileName: safFileName ?? this.safFileName,
      safRepaired: safRepaired ?? this.safRepaired,
      service: service,
      downloadedAt: downloadedAt,
      isrc: isrc ?? this.isrc,
      spotifyId: spotifyId ?? this.spotifyId,
      trackNumber: trackNumber ?? this.trackNumber,
      totalTracks: totalTracks ?? this.totalTracks,
      discNumber: discNumber ?? this.discNumber,
      totalDiscs: totalDiscs ?? this.totalDiscs,
      duration: duration ?? this.duration,
      releaseDate: releaseDate ?? this.releaseDate,
      quality: quality ?? this.quality,
      bitDepth: bitDepth ?? this.bitDepth,
      sampleRate: sampleRate ?? this.sampleRate,
      bitrate: bitrate ?? this.bitrate,
      format: format ?? this.format,
      videoFilePath: videoFilePath ?? this.videoFilePath,
      genre: genre ?? this.genre,
      composer: composer ?? this.composer,
      label: label ?? this.label,
      copyright: copyright ?? this.copyright,
    );
  }

  Track toTrack() {
    return Track(
      id: spotifyId ?? id,
      name: trackName,
      artistName: artistName,
      albumName: albumName,
      albumArtist: albumArtist,
      coverUrl: coverUrl,
      isrc: isrc,
      duration: duration ?? 0,
      trackNumber: trackNumber,
      discNumber: discNumber,
      totalDiscs: totalDiscs,
      releaseDate: releaseDate,
      source: service,
      totalTracks: totalTracks,
      composer: composer,
      bitDepth: bitDepth,
      sampleRate: sampleRate,
    );
  }
}

class DownloadHistoryState {
  final List<DownloadHistoryItem> items;
  final int totalCount;
  final int loadedIndexVersion;
  final List<DownloadHistoryItem> _lookupItems;
  final Map<String, DownloadHistoryItem> _bySpotifyId;
  final Map<String, DownloadHistoryItem> _byIsrc;
  final Map<String, DownloadHistoryItem> _byTrackArtistKey;
  final Map<String, DownloadHistoryItem> _byNormalizedTrackArtistKey;

  DownloadHistoryState({
    this.items = const [],
    this.totalCount = 0,
    this.loadedIndexVersion = 0,
    List<DownloadHistoryItem>? lookupItems,
  }) : _lookupItems = List.unmodifiable(lookupItems ?? items),
       _bySpotifyId = Map.fromEntries(
         (lookupItems ?? items)
             .where(
               (item) => item.spotifyId != null && item.spotifyId!.isNotEmpty,
             )
             .map((item) => MapEntry(item.spotifyId!, item)),
       ),
       _byIsrc = Map.fromEntries(
         (lookupItems ?? items)
             .where((item) => item.isrc != null && item.isrc!.isNotEmpty)
             .map((item) => MapEntry(item.isrc!, item)),
       ),
       _byTrackArtistKey = Map.fromEntries(
         (lookupItems ?? items)
             .map(
               (item) => MapEntry(
                 _trackArtistKey(item.trackName, item.artistName),
                 item,
               ),
             )
             .where((entry) => entry.key.isNotEmpty),
       ),
       _byNormalizedTrackArtistKey = Map.fromEntries(
         (lookupItems ?? items)
             .map(
               (item) => MapEntry(
                 _normalizedArtistKey(item.trackName, item.artistName),
                 item,
               ),
             )
             .where((entry) => entry.key.isNotEmpty),
       );

  static String _trackArtistKey(String trackName, String artistName) {
    final normalizedTrack = trackName.trim().toLowerCase();
    if (normalizedTrack.isEmpty) return '';
    final normalizedArtist = artistName.trim().toLowerCase();
    return '$normalizedTrack|$normalizedArtist';
  }

  static String _normalizedArtistKey(String trackName, String artistName) {
    final key = '${normalizeForMatch(trackName)}|${normalizeForMatch(artistName)}';
    if (key == '|') return '';
    return key;
  }

  bool isDownloaded(String spotifyId) => _bySpotifyId.containsKey(spotifyId);

  DownloadHistoryItem? getBySpotifyId(String spotifyId) =>
      _bySpotifyId[spotifyId];

  DownloadHistoryItem? getByIsrc(String isrc) => _byIsrc[isrc];

  DownloadHistoryItem? findByTrackAndArtist(
    String trackName,
    String artistName,
  ) {
    final key = _trackArtistKey(trackName, artistName);
    if (key.isEmpty) return null;
    return _byTrackArtistKey[key];
  }

  DownloadHistoryItem? findByNormalizedName(
    String trackName,
    String artistName,
  ) {
    final key = _normalizedArtistKey(trackName, artistName);
    if (key.isEmpty) return null;
    return _byNormalizedTrackArtistKey[key];
  }

  DownloadHistoryItem? findExistingTrack(HistoryLookupRequest request) {
    // 1. By ID
    final byId = getBySpotifyId(request.spotifyId);
    if (byId != null) return byId;

    // 2. By ISRC
    final isrc = request.isrc?.trim();
    if (isrc != null && isrc.isNotEmpty) {
      final byIsrc = getByIsrc(isrc);
      if (byIsrc != null) return byIsrc;
    }

    // 3. By name|artist (exact lowercase)
    final byName = findByTrackAndArtist(request.trackName, request.artistName);
    if (byName != null) return byName;

    // 4. By normalized name|artist (cross-source)
    return findByNormalizedName(request.trackName, request.artistName);
  }

  List<DownloadHistoryItem> get lookupItems => _lookupItems;

  DownloadHistoryState copyWith({
    List<DownloadHistoryItem>? items,
    int? totalCount,
    int? loadedIndexVersion,
    List<DownloadHistoryItem>? lookupItems,
  }) {
    return DownloadHistoryState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      loadedIndexVersion: loadedIndexVersion ?? this.loadedIndexVersion,
      lookupItems: lookupItems ?? _lookupItems,
    );
  }
}

class DownloadHistoryPageRequest {
  final int limit;
  final int offset;

  const DownloadHistoryPageRequest({this.limit = 100, this.offset = 0});

  @override
  bool operator ==(Object other) =>
      other is DownloadHistoryPageRequest &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(limit, offset);
}

final downloadHistoryPageProvider =
    FutureProvider.family<
      List<DownloadHistoryItem>,
      DownloadHistoryPageRequest
    >((ref, request) async {
      ref.watch(
        downloadHistoryProvider.select((state) => state.loadedIndexVersion),
      );
      final rows = await HistoryDatabase.instance.getAll(
        limit: request.limit,
        offset: request.offset,
      );
      return rows.map(DownloadHistoryItem.fromJson).toList(growable: false);
    });

class DownloadHistoryGroupedCounts {
  final int albumCount;
  final int singleTrackCount;

  const DownloadHistoryGroupedCounts({
    required this.albumCount,
    required this.singleTrackCount,
  });
}

final downloadHistoryGroupedCountsProvider =
    FutureProvider<DownloadHistoryGroupedCounts>((ref) async {
      ref.watch(
        downloadHistoryProvider.select((state) => state.loadedIndexVersion),
      );
      final counts = await HistoryDatabase.instance.getGroupedCounts();
      return DownloadHistoryGroupedCounts(
        albumCount: counts['albums'] ?? 0,
        singleTrackCount: counts['singles'] ?? 0,
      );
    });

HistoryLookupRequest HistoryLookupForTrack(Track track) {
  return HistoryLookupRequest(
    spotifyId: track.id,
    isrc: track.isrc,
    trackName: track.name,
    artistName: track.artistName,
  );
}

final downloadHistoryExistsProvider =
    FutureProvider.family<bool, HistoryLookupRequest>((ref, request) async {
      final state = ref.watch(downloadHistoryProvider);
      if (state.loadedIndexVersion > 0) {
        if (request.spotifyId != null && state.isDownloaded(request.spotifyId!)) {
          return true;
        }
        if (request.isrc != null && state.getByIsrc(request.isrc!) != null) {
          return true;
        }
        if (state.findByTrackAndArtist(request.trackName, request.artistName) != null) {
          return true;
        }
      }
      return HistoryDatabase.instance.existsTrack(request);
    });

final downloadHistoryBatchExistsProvider =
    FutureProvider.family<Set<String>, HistoryBatchLookupRequest>((
      ref,
      request,
    ) async {
      final state = ref.watch(downloadHistoryProvider);
      if (state.loadedIndexVersion > 0) {
        return request.tracks
            .where((t) =>
              (t.spotifyId != null && state.isDownloaded(t.spotifyId!)) ||
              (t.isrc != null && state.getByIsrc(t.isrc!) != null) ||
              state.findByTrackAndArtist(t.trackName, t.artistName) != null)
            .map((t) => t.lookupKey)
            .toSet();
      }
      return HistoryDatabase.instance.existingTrackKeys(request.tracks);
    });

class DownloadedAlbumTracksRequest {
  final String albumName;
  final String artistName;

  const DownloadedAlbumTracksRequest({
    required this.albumName,
    required this.artistName,
  });

  @override
  bool operator ==(Object other) =>
      other is DownloadedAlbumTracksRequest &&
      other.albumName == albumName &&
      other.artistName == artistName;

  @override
  int get hashCode => Object.hash(albumName, artistName);
}

final downloadedAlbumTracksProvider =
    FutureProvider.family<
      List<DownloadHistoryItem>,
      DownloadedAlbumTracksRequest
    >((ref, request) async {
      ref.watch(
        downloadHistoryProvider.select((state) => state.loadedIndexVersion),
      );
      final rows = await HistoryDatabase.instance.getAlbumTracks(
        request.albumName,
        request.artistName,
      );
      return rows.map(DownloadHistoryItem.fromJson).toList(growable: false);
    });

class DownloadQueueState {
  static const Object _noChange = Object();
  final List<DownloadItem> items;
  final DownloadQueueLookup lookup;
  final DownloadItem? currentDownload;
  final bool isProcessing;
  final bool isPaused;
  final String outputDir;
  final String filenameFormat;
  final String audioQuality;
  final bool autoFallback;
  final int concurrentDownloads;

  const DownloadQueueState({
    this.items = const [],
    this.lookup = const DownloadQueueLookup.empty(),
    this.currentDownload,
    this.isProcessing = false,
    this.isPaused = false,
    this.outputDir = '',
    this.filenameFormat = '{artist} - {title}',
    this.audioQuality = 'LOSSLESS',
    this.autoFallback = true,
    this.concurrentDownloads = 1,
  });

  DownloadQueueState copyWith({
    List<DownloadItem>? items,
    DownloadQueueLookup? lookup,
    Object? currentDownload = _noChange,
    bool? isProcessing,
    bool? isPaused,
    String? outputDir,
    String? filenameFormat,
    String? audioQuality,
    bool? autoFallback,
    int? concurrentDownloads,
  }) {
    final resolvedItems = items ?? this.items;
    return DownloadQueueState(
      items: resolvedItems,
      lookup:
          lookup ??
          (items != null
              ? DownloadQueueLookup.fromItems(resolvedItems)
              : this.lookup),
      currentDownload: identical(currentDownload, _noChange)
          ? this.currentDownload
          : currentDownload as DownloadItem?,
      isProcessing: isProcessing ?? this.isProcessing,
      isPaused: isPaused ?? this.isPaused,
      outputDir: outputDir ?? this.outputDir,
      filenameFormat: filenameFormat ?? this.filenameFormat,
      audioQuality: audioQuality ?? this.audioQuality,
      autoFallback: autoFallback ?? this.autoFallback,
      concurrentDownloads: concurrentDownloads ?? this.concurrentDownloads,
    );
  }

  int get queuedCount => items.isEmpty ? 0 : lookup.queuedCount;
  int get completedCount => items.isEmpty ? 0 : lookup.completedCount;
  int get failedCount => items.isEmpty ? 0 : lookup.failedCount;
  int get activeDownloadsCount =>
      items.isEmpty ? 0 : lookup.activeDownloadsCount;
}

class _ProgressUpdate {
  final DownloadStatus status;
  final double progress;
  final double? speedMBps;
  final int? bytesReceived;
  final int? bytesTotal;

  const _ProgressUpdate({
    required this.status,
    required this.progress,
    this.speedMBps,
    this.bytesReceived,
    this.bytesTotal,
  });
}

class _NativeWorkerRequestContext {
  final DownloadItem item;
  final String requestJson;
  final String outputDir;
  final String quality;
  final String storageMode;
  final String outputExt;
  final String? downloadTreeUri;
  final String? safRelativeDir;
  final String? safFileName;

  const _NativeWorkerRequestContext({
    required this.item,
    required this.requestJson,
    required this.outputDir,
    required this.quality,
    required this.storageMode,
    required this.outputExt,
    this.downloadTreeUri,
    this.safRelativeDir,
    this.safFileName,
  });
}
