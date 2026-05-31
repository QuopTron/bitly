/// Modelos de datos para la biblioteca local.
/// Define [LocalLibraryItem], [LibraryLookupIndex], [LocalLibraryAlbumGroup],
/// [QueueLibraryCounts], [QueueLibraryDbQuery], [LocalLibraryPageRequest]
/// y los enums [LocalLibrarySortMode] y [LocalLibraryFilterMode].
library;

class LocalLibraryItem {
  final String id;
  final String trackName;
  final String artistName;
  final String albumName;
  final String? albumArtist;
  final String filePath;
  final String? coverPath;
  final DateTime scannedAt;
  final int? fileModTime;
  final String? isrc;
  final int? trackNumber;
  static bool get isDatabaseAvailable => false;
  final int? totalTracks;
  final int? discNumber;
  final int? totalDiscs;
  final int? duration;
  final String? releaseDate;
  final int? bitDepth;
  final int? sampleRate;
  final int? bitrate;
  final String? genre;
  final String? composer;
  final String? label;
  final String? copyright;
  final String? format;

  const LocalLibraryItem({
    required this.id, required this.trackName, required this.artistName,
    required this.albumName, this.albumArtist, required this.filePath,
    this.coverPath, required this.scannedAt, this.fileModTime, this.isrc,
    this.trackNumber, this.totalTracks, this.discNumber, this.totalDiscs,
    this.duration, this.releaseDate, this.bitDepth, this.sampleRate,
    this.bitrate, this.genre, this.composer, this.label, this.copyright,
    this.format,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'trackName': trackName, 'artistName': artistName,
    'albumName': albumName, 'albumArtist': albumArtist, 'filePath': filePath,
    'coverPath': coverPath, 'scannedAt': scannedAt.toIso8601String(),
    'fileModTime': fileModTime, 'isrc': isrc, 'trackNumber': trackNumber,
    'totalTracks': totalTracks, 'discNumber': discNumber, 'totalDiscs': totalDiscs,
    'duration': duration, 'releaseDate': releaseDate, 'bitDepth': bitDepth,
    'sampleRate': sampleRate, 'bitrate': bitrate, 'genre': genre,
    'composer': composer, 'label': label, 'copyright': copyright, 'format': format,
  };

  factory LocalLibraryItem.fromJson(Map<String, dynamic> json) => LocalLibraryItem(
    id: json['id'] as String,
    trackName: json['trackName'] as String,
    artistName: json['artistName'] as String,
    albumName: json['albumName'] as String,
    albumArtist: json['albumArtist'] as String?,
    filePath: json['filePath'] as String,
    coverPath: json['coverPath'] as String?,
    scannedAt: json['scannedAt'] is String
        ? DateTime.parse(json['scannedAt'] as String)
        : (json['scannedAt'] as DateTime?) ?? DateTime.now(),
    fileModTime: (json['fileModTime'] as num?)?.toInt(),
    isrc: json['isrc'] as String?,
    trackNumber: (json['trackNumber'] as num?)?.toInt(),
    totalTracks: (json['totalTracks'] as num?)?.toInt(),
    discNumber: (json['discNumber'] as num?)?.toInt(),
    totalDiscs: (json['totalDiscs'] as num?)?.toInt(),
    duration: (json['duration'] as num?)?.toInt(),
    releaseDate: json['releaseDate'] as String?,
    bitDepth: (json['bitDepth'] as num?)?.toInt(),
    sampleRate: (json['sampleRate'] as num?)?.toInt(),
    bitrate: (json['bitrate'] as num?)?.toInt(),
    genre: json['genre'] as String?,
    composer: json['composer'] as String?,
    label: json['label'] as String?,
    copyright: json['copyright'] as String?,
    format: json['format'] as String?,
  );

  String get matchKey => '${_normalize(trackName)}|${_normalize(artistName)}';
  String get albumKey => '${_normalize(albumName)}|${_normalize(albumArtist ?? artistName)}';

  static String _normalize(String value) => value.toLowerCase().trim();

  LocalLibraryItem copyWith({
    String? filePath, String? format, int? bitrate, int? sampleRate,
    int? bitDepth, String? trackName, String? artistName, String? albumName,
    String? albumArtist, String? genre, String? releaseDate, int? trackNumber,
    int? totalTracks, int? discNumber, int? totalDiscs, String? isrc,
    String? label, String? composer, String? copyright, int? duration,
  }) {
    return LocalLibraryItem(
      id: id, trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      albumArtist: albumArtist ?? this.albumArtist,
      filePath: filePath ?? this.filePath, coverPath: coverPath,
      scannedAt: scannedAt, fileModTime: fileModTime,
      isrc: isrc ?? this.isrc, trackNumber: trackNumber ?? this.trackNumber,
      totalTracks: totalTracks ?? this.totalTracks,
      discNumber: discNumber ?? this.discNumber,
      totalDiscs: totalDiscs ?? this.totalDiscs,
      duration: duration ?? this.duration,
      releaseDate: releaseDate ?? this.releaseDate,
      bitDepth: bitDepth ?? this.bitDepth,
      sampleRate: sampleRate ?? this.sampleRate,
      bitrate: bitrate ?? this.bitrate, genre: genre ?? this.genre,
      composer: composer ?? this.composer,
      label: label ?? this.label,
      copyright: copyright ?? this.copyright,
      format: format ?? this.format,
    );
  }
}

class LibraryLookupIndex {
  final Set<String> matchKeys;
  final Set<String> isrcs;
  final Map<String, String> filePathById;
  const LibraryLookupIndex({this.matchKeys = const {}, this.isrcs = const {}, this.filePathById = const {}});
  static LibraryLookupIndex empty() => const LibraryLookupIndex();
}

class LocalLibraryAlbumGroup {
  final String albumName; final String artistName;
  final String? coverPath; final int trackCount; final DateTime latestScannedAt;
  const LocalLibraryAlbumGroup({
    required this.albumName, required this.artistName,
    this.coverPath, required this.trackCount, required this.latestScannedAt,
  });
}

enum LocalLibrarySortMode { album, title, artist, latest, quality }
enum LocalLibraryFilterMode { all, albums, singles }

class QueueLibraryCounts {
  final int allTrackCount; final int albumCount; final int singleTrackCount;
  const QueueLibraryCounts({required this.allTrackCount, required this.albumCount, required this.singleTrackCount});
}

class QueueLibraryDbQuery {
  final int? limit; final int? offset; final String? filterMode;
  final String? searchQuery; final String? source; final String? quality;
  final String? format; final String? metadata; final String? sortMode;
  final bool? includeLocal;
  const QueueLibraryDbQuery({this.limit, this.offset, this.filterMode, this.searchQuery, this.source, this.quality, this.format, this.metadata, this.sortMode, this.includeLocal});
}

class LocalLibraryPageRequest {
  final int limit; final int offset;
  final LocalLibrarySortMode sortMode; final LocalLibraryFilterMode filterMode;
  final String? searchQuery; final String? format;
  const LocalLibraryPageRequest({
    this.limit = 100, this.offset = 0, this.sortMode = LocalLibrarySortMode.album,
    this.filterMode = LocalLibraryFilterMode.all, this.searchQuery, this.format,
  });
}
