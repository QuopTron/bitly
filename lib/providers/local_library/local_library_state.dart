import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/services/library/library_database.dart';

class LocalLibraryState {
  final List<LocalLibraryItem> allTracks;
  final List<LocalLibraryAlbumGroup> albums;
  final bool isLoading;
  final int loadedIndexVersion;
  final bool isScanning;
  final bool scanIsFinalizing;
  final double scanProgress;
  final String? scanCurrentFile;
  final int scanTotalFiles;
  final int scannedFiles;
  final DateTime? lastScannedAt;
  final bool scanWasCancelled;
  final int excludedDownloadedCount;
  final int totalCount;

  const LocalLibraryState({
    this.allTracks = const [],
    this.albums = const [],
    this.isLoading = false,
    this.loadedIndexVersion = 0,
    this.isScanning = false,
    this.scanIsFinalizing = false,
    this.scanProgress = 0.0,
    this.scanCurrentFile,
    this.scanTotalFiles = 0,
    this.scannedFiles = 0,
    this.lastScannedAt,
    this.scanWasCancelled = false,
    this.excludedDownloadedCount = 0,
    this.totalCount = 0,
  });

  List<LocalLibraryItem> get items => allTracks;

  LocalLibraryState copyWith({
    List<LocalLibraryItem>? allTracks,
    List<LocalLibraryAlbumGroup>? albums,
    bool? isLoading,
    int? loadedIndexVersion,
    bool? isScanning,
    bool? scanIsFinalizing,
    double? scanProgress,
    String? scanCurrentFile,
    int? scanTotalFiles,
    int? scannedFiles,
    DateTime? lastScannedAt,
    bool? scanWasCancelled,
    int? excludedDownloadedCount,
    int? totalCount,
  }) {
    return LocalLibraryState(
      allTracks: allTracks ?? this.allTracks,
      albums: albums ?? this.albums,
      isLoading: isLoading ?? this.isLoading,
      loadedIndexVersion: loadedIndexVersion ?? this.loadedIndexVersion,
      isScanning: isScanning ?? this.isScanning,
      scanIsFinalizing: scanIsFinalizing ?? this.scanIsFinalizing,
      scanProgress: scanProgress ?? this.scanProgress,
      scanCurrentFile: scanCurrentFile ?? this.scanCurrentFile,
      scanTotalFiles: scanTotalFiles ?? this.scanTotalFiles,
      scannedFiles: scannedFiles ?? this.scannedFiles,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      scanWasCancelled: scanWasCancelled ?? this.scanWasCancelled,
      excludedDownloadedCount: excludedDownloadedCount ?? this.excludedDownloadedCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  bool existsInLibrary({String? isrc, String? trackName, String? artistName}) {
    if (isrc != null && isrc.isNotEmpty) {
      if (allTracks.any((t) => t.isrc == isrc)) return true;
    }
    if (trackName != null && artistName != null) {
      final mk = LibraryDatabase.matchKeyFor(trackName, artistName).toLowerCase();
      if (allTracks.any((t) => t.matchKey.toLowerCase() == mk)) return true;
    }
    return false;
  }
}

class LocalLibraryCoverRequest {
  final String? trackName;
  final String? artistName;
  final String? albumName;
  final String? isrc;

  const LocalLibraryCoverRequest({this.trackName, this.artistName, this.albumName, this.isrc});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalLibraryCoverRequest &&
          trackName == other.trackName &&
          artistName == other.artistName &&
          albumName == other.albumName &&
          isrc == other.isrc;

  @override
  int get hashCode => trackName.hashCode ^ artistName.hashCode ^ albumName.hashCode ^ isrc.hashCode;
}

class LocalLibraryCoverBatchRequest {
  final List<LocalLibraryCoverRequest> requests;
  const LocalLibraryCoverBatchRequest(this.requests);
}

final localLibraryCoverProvider = FutureProvider.family<String?, LocalLibraryCoverRequest>((ref, req) async {
  final db = LibraryDatabase.instance;
  LocalLibraryItem? item;
  if (req.isrc != null) item = await db.getByIsrc(req.isrc!);
  if (item == null && req.trackName != null && req.artistName != null) {
    item = await db.findFirstByTrackAndArtist(req.trackName!, req.artistName!);
  }
  return item?.coverPath;
});

final localLibraryFirstCoverProvider = FutureProvider.family<String?, LocalLibraryCoverBatchRequest>((ref, batch) async {
  final db = LibraryDatabase.instance;
  for (final req in batch.requests) {
    LocalLibraryItem? item;
    if (req.isrc != null) item = await db.getByIsrc(req.isrc!);
    if (item == null && req.trackName != null && req.artistName != null) {
      item = await db.findFirstByTrackAndArtist(req.trackName!, req.artistName!);
    }
    if (item?.coverPath != null) return item!.coverPath;
  }
  return null;
});
