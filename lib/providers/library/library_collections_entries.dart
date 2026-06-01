import 'package:bitly/models/track.dart';
import 'library_collections_album_entries.dart';

export 'library_collections_album_entries.dart';

String sanitizeFolderName(String name) {
  final result = name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return result.isEmpty ? 'Unknown' : result;
}

String trackCollectionKey(Track track) {
  final source = (track.source?.trim().isNotEmpty ?? false)
      ? normalizeSource(track.source!.trim())
      : 'builtin';
  return '$source:${track.id}';
}

String canonicalLoveKey(Track track) {
  return '${normalizeForMatch(track.name)}|${normalizeForMatch(track.artistName)}';
}

String stripCollectionResourcePrefix(String value) {
  final colonIndex = value.indexOf(':');
  if (colonIndex <= 0 || colonIndex == value.length - 1) return value.trim();
  return value.substring(colonIndex + 1).trim();
}

String albumCollectionKey({required String albumId, required String? providerId}) {
  final trimmedId = albumId.trim();
  final rawSource = providerId?.trim().isNotEmpty == true
      ? providerId!.trim()
      : (trimmedId.contains(':') ? trimmedId.split(':').first.trim() : null);
  final source = normalizeSource(rawSource);
  return '$source:${stripCollectionResourcePrefix(trimmedId)}';
}

String playlistCollectionKey({required String playlistId, required String? providerId}) {
  final trimmedId = playlistId.trim();
  final rawSource = providerId?.trim().isNotEmpty == true
      ? providerId!.trim()
      : (trimmedId.contains(':') ? trimmedId.split(':').first.trim() : null);
  final source = normalizeSource(rawSource);
  return '$source:${stripCollectionResourcePrefix(trimmedId)}';
}

String artistCollectionKey({required String artistId, required String? providerId}) {
  final trimmedArtistId = artistId.trim();
  final trimmedProviderId = providerId?.trim();
  final rawSource = trimmedProviderId != null && trimmedProviderId.isNotEmpty
      ? trimmedProviderId
      : (trimmedArtistId.contains(':') ? trimmedArtistId.split(':').first.trim() : null);
  final source = normalizeSource(rawSource);
  return '$source:${stripCollectionResourcePrefix(trimmedArtistId)}';
}

class CollectionTrackEntry {
  final String key;
  final Track track;
  final DateTime addedAt;
  final String? audioPath;
  final String? coverPath;
  final String? codec;
  final int? bitDepth;
  final int? sampleRate;
  const CollectionTrackEntry({
    required this.key,
    required this.track,
    required this.addedAt,
    this.audioPath,
    this.coverPath,
    this.codec,
    this.bitDepth,
    this.sampleRate,
  });
  Map<String, dynamic> toJson() => {
    'key': key,
    'track': track.toJson(),
    'addedAt': addedAt.toIso8601String(),
    if (audioPath != null) 'audioPath': audioPath,
    if (coverPath != null) 'coverPath': coverPath,
    if (codec != null) 'codec': codec,
    if (bitDepth != null) 'bitDepth': bitDepth,
    if (sampleRate != null) 'sampleRate': sampleRate,
  };
  factory CollectionTrackEntry.fromJson(Map<String, dynamic> json) {
    final addedAtRaw = json['addedAt'] as String?;
    return CollectionTrackEntry(
      key: json['key'] as String,
      track: Track.fromJson(Map<String, dynamic>.from(json['track'] as Map)),
      addedAt: DateTime.tryParse(addedAtRaw ?? '') ?? DateTime.now(),
      audioPath: json['audioPath'] as String?,
      coverPath: json['coverPath'] as String?,
      codec: json['codec'] as String?,
      bitDepth: json['bitDepth'] as int?,
      sampleRate: json['sampleRate'] as int?,
    );
  }
}

class CollectionArtistEntry {
  final String key;
  final String artistId;
  final String? providerId;
  final String name;
  final String? imageUrl;
  final String? coverPath;
  final List<String> alternateCovers;
  final DateTime addedAt;
  const CollectionArtistEntry({
    required this.key,
    required this.artistId,
    required this.providerId,
    required this.name,
    this.imageUrl,
    this.coverPath,
    this.alternateCovers = const [],
    required this.addedAt,
  });
  List<String> get allCovers {
    final urls = <String>[];
    if (imageUrl != null && imageUrl!.isNotEmpty) urls.add(imageUrl!);
    urls.addAll(alternateCovers);
    return urls.toSet().toList();
  }
  CollectionArtistEntry mergeCover(String? newUrl) {
    if (newUrl == null || newUrl.isEmpty) return this;
    final existing = allCovers;
    if (existing.contains(newUrl)) return this;
    if (imageUrl == null) return copyWith(imageUrl: newUrl);
    return copyWith(alternateCovers: [...alternateCovers, newUrl]);
  }
  CollectionArtistEntry copyWith({
    String? key, String? artistId, String? providerId, String? name,
    String? imageUrl, String? coverPath, List<String>? alternateCovers, DateTime? addedAt,
  }) {
    return CollectionArtistEntry(
      key: key ?? this.key, artistId: artistId ?? this.artistId,
      providerId: providerId ?? this.providerId, name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl, coverPath: coverPath ?? this.coverPath,
      alternateCovers: alternateCovers ?? this.alternateCovers,
      addedAt: addedAt ?? this.addedAt,
    );
  }
  Map<String, dynamic> toJson() => {
    'key': key, 'artistId': artistId, 'providerId': providerId,
    'name': name, 'imageUrl': imageUrl, 'coverPath': coverPath,
    'alternateCovers': alternateCovers, 'addedAt': addedAt.toIso8601String(),
  };
  factory CollectionArtistEntry.fromJson(Map<String, dynamic> json) {
    final artistId = json['artistId'] as String;
    final providerId = json['providerId'] as String?;
    final addedAtRaw = json['addedAt'] as String?;
    final rawCovers = json['alternateCovers'];
    final covers = (rawCovers is List) ? rawCovers.whereType<String>().toList() : <String>[];
    return CollectionArtistEntry(
      key: json['key'] as String? ?? artistCollectionKey(artistId: artistId, providerId: providerId),
      artistId: artistId, providerId: providerId,
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?, coverPath: json['coverPath'] as String?,
      alternateCovers: covers,
      addedAt: DateTime.tryParse(addedAtRaw ?? '') ?? DateTime.now(),
    );
  }
}
