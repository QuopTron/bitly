import 'package:equatable/equatable.dart';

/// Returns [path] only when it's a usable local cover file path.
/// Legacy rows stored the desktop cover-cache HTTP URL
/// (http://127.0.0.1:55009/cover/...) which does not exist on mobile;
/// such values are treated as "no local cover" so the card falls back to
/// the network cover instead of rendering gray.
String? cleanLocalCoverPath(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.contains('127.0.0.1')) return null;
  return path;
}

class LikedItemData {
  final String id;
  final String type;
  final String name;
  final String? artists;
  final String? coverUrl;
  final String? localCoverPath;
  final String? source;
  final String? albumName;
  final int? durationMs;
  final String? isrc;

  const LikedItemData({
    required this.id,
    required this.type,
    required this.name,
    this.artists,
    this.coverUrl,
    this.localCoverPath,
    this.source,
    this.albumName,
    this.durationMs,
    this.isrc,
  });

  LikedItemData copyWith({String? localCoverPath}) => LikedItemData(
        id: id,
        type: type,
        name: name,
        artists: artists,
        coverUrl: coverUrl,
        localCoverPath: localCoverPath ?? this.localCoverPath,
        source: source,
        albumName: albumName,
        durationMs: durationMs,
        isrc: isrc,
      );
}

class LikeState extends Equatable {
  final bool loading;
  final String? error;
  final Set<String> likedFingerprints;
  final Map<String, LikedItemData> allLiked;

  const LikeState({
    this.loading = false,
    this.error,
    this.likedFingerprints = const {},
    this.allLiked = const {},
  });

  LikeState copyWith({
    bool? loading,
    String? error,
    Set<String>? likedFingerprints,
    Map<String, LikedItemData>? allLiked,
    bool clearError = false,
  }) =>
      LikeState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        likedFingerprints: likedFingerprints ?? this.likedFingerprints,
        allLiked: allLiked ?? this.allLiked,
      );

  @override
  List<Object?> get props => [loading, error, likedFingerprints, allLiked];
}
