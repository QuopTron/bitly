import 'dart:convert' show jsonDecode;

class AlbumDetail {
  final String id, name;
  final String? coverUrl, coverPath, artistName, releaseDate, albumType;
  final int totalTracks;
  final List<DetailTrack> tracks;

  const AlbumDetail({
    required this.id, required this.name,
    this.coverUrl, this.coverPath, this.artistName,
    this.releaseDate, this.albumType,
    this.totalTracks = 0, this.tracks = const [],
  });

  factory AlbumDetail.fromJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List<dynamic>?) ?? [];
    return AlbumDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      coverPath: json['coverPath'] as String?,
      artistName: json['artistName'] as String?,
      releaseDate: json['releaseDate'] as String?,
      albumType: json['albumType'] as String?,
      totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
      tracks: rawTracks.map((e) => DetailTrack.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class PlaylistDetail {
  final String id, name;
  final String? coverPath, createdAt, updatedAt;
  final int itemCount;
  final List<DetailTrack> tracks;

  const PlaylistDetail({
    required this.id, required this.name,
    this.coverPath, this.createdAt, this.updatedAt,
    this.itemCount = 0, this.tracks = const [],
  });

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List<dynamic>?) ?? [];
    return PlaylistDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      coverPath: json['coverPath'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      tracks: rawTracks.map((e) => DetailTrack.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ArtistDetail {
  final String id, name;
  final String? imageUrl, imagePath;
  final List<DetailTrack> topTracks;
  final List<DetailAlbum> topAlbums;

  const ArtistDetail({
    required this.id, required this.name,
    this.imageUrl, this.imagePath,
    this.topTracks = const [], this.topAlbums = const [],
  });

  factory ArtistDetail.fromJson(Map<String, dynamic> json) {
    final rawTracks = _parseList(json['topTracks']);
    final rawAlbums = _parseList(json['topAlbums']);
    return ArtistDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      topTracks: rawTracks.map((e) => DetailTrack.fromJson(e as Map<String, dynamic>)).toList(),
      topAlbums: rawAlbums.map((e) => DetailAlbum.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  static List<dynamic> _parseList(dynamic v) {
    if (v is String) {
      try { return jsonDecode(v) as List<dynamic>; } catch (_) { return []; }
    }
    if (v is List) return v;
    return [];
  }
}

class DetailTrack {
  final String trackId, name, isrc;
  final int durationMs, trackNumber;
  final String? coverUrl, coverPath, filePath, artistName, albumName, provider;
  final bool isLiked, isDownloaded;

  const DetailTrack({
    required this.trackId, required this.name,
    this.durationMs = 0, this.trackNumber = 0,
    this.isrc = '', this.coverUrl, this.coverPath, this.filePath,
    this.artistName, this.albumName,
    this.isLiked = false, this.isDownloaded = false,
    this.provider,
  });

  factory DetailTrack.fromJson(Map<String, dynamic> json) => DetailTrack(
    trackId: json['trackId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    trackNumber: (json['trackNumber'] as num?)?.toInt() ?? 0,
    isrc: json['isrc'] as String? ?? '',
    coverUrl: json['coverUrl'] as String?,
    coverPath: json['coverPath'] as String?,
    filePath: json['filePath'] as String?,
    artistName: json['artistName'] as String?,
    albumName: json['albumName'] as String?,
    isLiked: json['isLiked'] == true,
    isDownloaded: json['isDownloaded'] == true,
    provider: json['provider'] as String?,
  );
}

class DetailAlbum {
  final String albumId, name;
  final String? coverUrl, coverPath, releaseDate;
  final int totalTracks, playCount;

  const DetailAlbum({
    required this.albumId, required this.name,
    this.coverUrl, this.coverPath, this.releaseDate,
    this.totalTracks = 0, this.playCount = 0,
  });

  factory DetailAlbum.fromJson(Map<String, dynamic> json) => DetailAlbum(
    albumId: json['albumId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    coverUrl: json['coverUrl'] as String?,
    coverPath: json['coverPath'] as String?,
    releaseDate: json['releaseDate'] as String?,
    totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
    playCount: (json['playCount'] as num?)?.toInt() ?? 0,
  );
}

class UserStats {
  final int totalDownloads, totalLikes, totalPlaybackMs, totalPlaylistTracks;
  final int totalTracks, totalAlbums, totalArtists;
  final int level, nextLevel;
  final double progress;

  const UserStats({
    this.totalDownloads = 0, this.totalLikes = 0, this.totalPlaybackMs = 0,
    this.totalPlaylistTracks = 0, this.totalTracks = 0, this.totalAlbums = 0,
    this.totalArtists = 0, this.level = 0, this.nextLevel = 1, this.progress = 0.0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    totalDownloads: (json['totalDownloads'] as num?)?.toInt() ?? 0,
    totalLikes: (json['totalLikes'] as num?)?.toInt() ?? 0,
    totalPlaybackMs: (json['totalPlaybackMs'] as num?)?.toInt() ?? 0,
    totalPlaylistTracks: (json['totalPlaylistTracks'] as num?)?.toInt() ?? 0,
    totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
    totalAlbums: (json['totalAlbums'] as num?)?.toInt() ?? 0,
    totalArtists: (json['totalArtists'] as num?)?.toInt() ?? 0,
    level: (json['level'] as num?)?.toInt() ?? 0,
    nextLevel: (json['nextLevel'] as num?)?.toInt() ?? 1,
    progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
  );
}

