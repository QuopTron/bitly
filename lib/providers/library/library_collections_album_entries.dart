import 'library_collections_entries.dart';

class CollectionAlbumEntry {
  final String key;
  final String albumId;
  final String? providerId;
  final String name;
  final String? artistName;
  final String? coverUrl;
  final String? imageUrl;
  final String? coverPath;
  final DateTime addedAt;
  final int? totalTracks;
  const CollectionAlbumEntry({
    required this.key, required this.albumId, required this.providerId,
    required this.name, this.artistName, this.coverUrl, this.imageUrl,
    this.coverPath, required this.addedAt, this.totalTracks,
  });
  Map<String, dynamic> toJson() => {
    'key': key, 'albumId': albumId, 'providerId': providerId, 'name': name,
    'artistName': artistName, 'coverUrl': coverUrl, 'imageUrl': imageUrl,
    'coverPath': coverPath, 'addedAt': addedAt.toIso8601String(), 'totalTracks': totalTracks,
  };
  factory CollectionAlbumEntry.fromJson(Map<String, dynamic> json) {
    final albumId = json['albumId'] as String;
    final providerId = json['providerId'] as String?;
    final addedAtRaw = json['addedAt'] as String?;
    return CollectionAlbumEntry(
      key: json['key'] as String? ?? albumCollectionKey(albumId: albumId, providerId: providerId),
      albumId: albumId, providerId: providerId,
      name: json['name'] as String? ?? '', artistName: json['artistName'] as String?,
      coverUrl: json['coverUrl'] as String?, imageUrl: json['imageUrl'] as String?,
      coverPath: json['coverPath'] as String?,
      addedAt: DateTime.tryParse(addedAtRaw ?? '') ?? DateTime.now(),
      totalTracks: json['totalTracks'] as int?,
    );
  }
}

class CollectionPlaylistEntry {
  final String key;
  final String playlistId;
  final String? providerId;
  final String name;
  final String? imageUrl;
  final String? coverPath;
  final DateTime addedAt;
  final List<CollectionTrackEntry>? tracks;
  const CollectionPlaylistEntry({
    required this.key, required this.playlistId, this.providerId, required this.name,
    this.imageUrl, this.coverPath, required this.addedAt, this.tracks,
  });
  int get trackCount => tracks?.length ?? 0;
  Map<String, dynamic> toJson() => {
    'key': key, 'playlistId': playlistId, 'providerId': providerId, 'name': name,
    'imageUrl': imageUrl, 'coverPath': coverPath, 'addedAt': addedAt.toIso8601String(),
    if (tracks != null) 'tracks': tracks!.map((t) => t.toJson()).toList(),
  };
  factory CollectionPlaylistEntry.fromJson(Map<String, dynamic> json) {
    final playlistId = json['playlistId'] as String;
    final providerId = json['providerId'] as String?;
    final addedAtRaw = json['addedAt'] as String?;
    return CollectionPlaylistEntry(
      key: json['key'] as String? ?? playlistCollectionKey(playlistId: playlistId, providerId: providerId),
      playlistId: playlistId, providerId: providerId,
      name: json['name'] as String? ?? '', imageUrl: json['imageUrl'] as String?,
      coverPath: json['coverPath'] as String?,
      addedAt: DateTime.tryParse(addedAtRaw ?? '') ?? DateTime.now(),
      tracks: (json['tracks'] as List?)?.map((t) => CollectionTrackEntry.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}
