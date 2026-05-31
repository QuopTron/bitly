import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/services/history/history_database.dart';
import 'package:bitly/services/library/collections/library_collections_database.dart';
import 'package:bitly/services/library/library_database.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/artist_utils.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('LibraryCollections');

String _sanitizeFolderName(String name) {
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

String _stripCollectionResourcePrefix(String value) {
  final colonIndex = value.indexOf(':');
  if (colonIndex <= 0 || colonIndex == value.length - 1) {
    return value.trim();
  }
  return value.substring(colonIndex + 1).trim();
}

String albumCollectionKey({
  required String albumId,
  required String? providerId,
}) {
  final trimmedId = albumId.trim();
  final rawSource = providerId?.trim().isNotEmpty == true
      ? providerId!.trim()
      : (trimmedId.contains(':')
          ? trimmedId.split(':').first.trim()
          : null);
  final source = normalizeSource(rawSource);
  return '$source:${_stripCollectionResourcePrefix(trimmedId)}';
}

String playlistCollectionKey({
  required String playlistId,
  required String? providerId,
}) {
  final trimmedId = playlistId.trim();
  final rawSource = providerId?.trim().isNotEmpty == true
      ? providerId!.trim()
      : (trimmedId.contains(':')
          ? trimmedId.split(':').first.trim()
          : null);
  final source = normalizeSource(rawSource);
  return '$source:${_stripCollectionResourcePrefix(trimmedId)}';
}

String artistCollectionKey({
  required String artistId,
  required String? providerId,
}) {
  final trimmedArtistId = artistId.trim();
  final trimmedProviderId = providerId?.trim();
  final rawSource = trimmedProviderId != null && trimmedProviderId.isNotEmpty
      ? trimmedProviderId
      : (trimmedArtistId.contains(':')
          ? trimmedArtistId.split(':').first.trim()
          : null);
  final source = normalizeSource(rawSource);
  return '$source:${_stripCollectionResourcePrefix(trimmedArtistId)}';
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
    String? key,
    String? artistId,
    String? providerId,
    String? name,
    String? imageUrl,
    String? coverPath,
    List<String>? alternateCovers,
    DateTime? addedAt,
  }) {
    return CollectionArtistEntry(
      key: key ?? this.key,
      artistId: artistId ?? this.artistId,
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      coverPath: coverPath ?? this.coverPath,
      alternateCovers: alternateCovers ?? this.alternateCovers,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'artistId': artistId,
    'providerId': providerId,
    'name': name,
    'imageUrl': imageUrl,
    'coverPath': coverPath,
    'alternateCovers': alternateCovers,
    'addedAt': addedAt.toIso8601String(),
  };

  factory CollectionArtistEntry.fromJson(Map<String, dynamic> json) {
    final artistId = json['artistId'] as String;
    final providerId = json['providerId'] as String?;
    final addedAtRaw = json['addedAt'] as String?;
    final rawCovers = json['alternateCovers'];
    final covers = (rawCovers is List)
        ? rawCovers.whereType<String>().toList()
        : <String>[];
    return CollectionArtistEntry(
      key: json['key'] as String? ??
          artistCollectionKey(artistId: artistId, providerId: providerId),
      artistId: artistId,
      providerId: providerId,
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      coverPath: json['coverPath'] as String?,
      alternateCovers: covers,
      addedAt: DateTime.tryParse(addedAtRaw ?? '') ?? DateTime.now(),
    );
  }
}

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
    required this.key,
    required this.albumId,
    required this.providerId,
    required this.name,
    this.artistName,
    this.coverUrl,
    this.imageUrl,
    this.coverPath,
    required this.addedAt,
    this.totalTracks,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'albumId': albumId,
    'providerId': providerId,
    'name': name,
    'artistName': artistName,
    'coverUrl': coverUrl,
    'imageUrl': imageUrl,
    'coverPath': coverPath,
    'addedAt': addedAt.toIso8601String(),
    'totalTracks': totalTracks,
  };

  factory CollectionAlbumEntry.fromJson(Map<String, dynamic> json) {
    final albumId = json['albumId'] as String;
    final providerId = json['providerId'] as String?;
    final addedAtRaw = json['addedAt'] as String?;
    return CollectionAlbumEntry(
      key: json['key'] as String? ??
          albumCollectionKey(albumId: albumId, providerId: providerId),
      albumId: albumId,
      providerId: providerId,
      name: json['name'] as String? ?? '',
      artistName: json['artistName'] as String?,
      coverUrl: json['coverUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
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
    required this.key,
    required this.playlistId,
    this.providerId,
    required this.name,
    this.imageUrl,
    this.coverPath,
    required this.addedAt,
    this.tracks,
  });

  int get trackCount => tracks?.length ?? 0;

  Map<String, dynamic> toJson() => {
    'key': key,
    'playlistId': playlistId,
    'providerId': providerId,
    'name': name,
    'imageUrl': imageUrl,
    'coverPath': coverPath,
    'addedAt': addedAt.toIso8601String(),
    if (tracks != null) 'tracks': tracks!.map((t) => t.toJson()).toList(),
  };

  factory CollectionPlaylistEntry.fromJson(Map<String, dynamic> json) {
    final playlistId = json['playlistId'] as String;
    final providerId = json['providerId'] as String?;
    final addedAtRaw = json['addedAt'] as String?;
    return CollectionPlaylistEntry(
      key: json['key'] as String? ??
          playlistCollectionKey(playlistId: playlistId, providerId: providerId),
      playlistId: playlistId,
      providerId: providerId,
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      coverPath: json['coverPath'] as String?,
      addedAt: DateTime.tryParse(addedAtRaw ?? '') ?? DateTime.now(),
      tracks: (json['tracks'] as List?)?.map((t) => CollectionTrackEntry.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}

class UserPlaylistCollection {
  final String id;
  final String name;
  final String? coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CollectionTrackEntry> tracks;
  final Set<String> _trackKeys;

  UserPlaylistCollection({
    required this.id,
    required this.name,
    this.coverImagePath,
    required this.createdAt,
    required this.updatedAt,
    required this.tracks,
    Set<String>? trackKeys,
  }) : _trackKeys = trackKeys ?? tracks.map((entry) => entry.key).toSet();

  UserPlaylistCollection copyWith({
    String? id,
    String? name,
    String? Function()? coverImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CollectionTrackEntry>? tracks,
  }) {
    final nextTracks = tracks ?? this.tracks;
    final keepTrackIndex = identical(nextTracks, this.tracks);
    return UserPlaylistCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      coverImagePath:
          coverImagePath != null ? coverImagePath() : this.coverImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tracks: nextTracks,
      trackKeys: keepTrackIndex ? _trackKeys : null,
    );
  }

  bool containsTrack(Track track) => containsTrackKey(trackCollectionKey(track));
  bool containsTrackKey(String key) => _trackKeys.contains(key);

  String? findAudioPathForTrack(String trackKey) {
    for (final entry in tracks) {
      if (entry.key == trackKey && entry.audioPath != null) {
        return entry.audioPath;
      }
    }
    return null;
  }

  String? findCoverPathForTrack(String trackKey) {
    for (final entry in tracks) {
      if (entry.key == trackKey && entry.coverPath != null) {
        return entry.coverPath;
      }
    }
    return null;
  }
}

class LibraryCollectionsState {
  final List<CollectionTrackEntry> wishlist;
  final List<CollectionTrackEntry> loved;
  final List<UserPlaylistCollection> playlists;
  final List<CollectionArtistEntry> favoriteArtists;
  final List<CollectionAlbumEntry> favoriteAlbums;
  final List<CollectionPlaylistEntry> favoritePlaylists;
  final bool isLoaded;
  final Set<String> _wishlistKeys;
  final Set<String> _lovedKeys;
  final Set<String> _canonicalLovedKeys;
  final Set<String> _favoriteArtistKeys;
  final Set<String> _favoriteAlbumKeys;
  final Set<String> _favoritePlaylistKeys;
  final Map<String, UserPlaylistCollection> _playlistsById;
  final Set<String> _allPlaylistTrackKeys;

  LibraryCollectionsState({
    this.wishlist = const [],
    this.loved = const [],
    this.playlists = const [],
    this.favoriteArtists = const [],
    this.favoriteAlbums = const [],
    this.favoritePlaylists = const [],
    this.isLoaded = false,
    Set<String>? wishlistKeys,
    Set<String>? lovedKeys,
    Set<String>? canonicalLovedKeys,
    Set<String>? favoriteArtistKeys,
    Set<String>? favoriteAlbumKeys,
    Set<String>? favoritePlaylistKeys,
    Map<String, UserPlaylistCollection>? playlistsById,
    Set<String>? allPlaylistTrackKeys,
  })  : _wishlistKeys =
            wishlistKeys ?? wishlist.map((entry) => entry.key).toSet(),
        _lovedKeys = lovedKeys ?? loved.map((entry) => entry.key).toSet(),
        _canonicalLovedKeys = canonicalLovedKeys ??
            loved.map((entry) => canonicalLoveKey(entry.track)).toSet(),
        _favoriteArtistKeys = favoriteArtistKeys ??
            favoriteArtists.map((entry) => entry.key).toSet(),
        _favoriteAlbumKeys = favoriteAlbumKeys ??
            favoriteAlbums.map((entry) => entry.key).toSet(),
        _favoritePlaylistKeys = favoritePlaylistKeys ??
            favoritePlaylists.map((entry) => entry.key).toSet(),
        _playlistsById = playlistsById ??
            Map.fromEntries(
              playlists.map((playlist) => MapEntry(playlist.id, playlist)),
            ),
        _allPlaylistTrackKeys =
            allPlaylistTrackKeys ?? _buildPlaylistTrackKeys(playlists);

  static Set<String> _buildPlaylistTrackKeys(
    List<UserPlaylistCollection> playlists,
  ) {
    final keys = <String>{};
    for (final playlist in playlists) {
      keys.addAll(playlist._trackKeys);
    }
    return keys;
  }

  int get wishlistCount => wishlist.length;
  int get lovedCount => loved.length;
  int get playlistCount => playlists.length;
  int get favoriteArtistCount => favoriteArtists.length;
  int get favoriteAlbumCount => favoriteAlbums.length;
  int get favoritePlaylistCount => favoritePlaylists.length;

  bool isInWishlist(Track track) {
    final key = trackCollectionKey(track);
    return _wishlistKeys.contains(key);
  }

  bool isLoved(Track track) {
    final cKey = canonicalLoveKey(track);
    return _canonicalLovedKeys.contains(cKey);
  }

  String? findAudioPath(Track track) {
    final key = trackCollectionKey(track);
    for (final entry in loved) {
      if (entry.key == key && entry.audioPath != null) return entry.audioPath;
    }
    for (final entry in wishlist) {
      if (entry.key == key && entry.audioPath != null) return entry.audioPath;
    }
    return null;
  }

  String? findCoverPath(Track track) {
    final key = trackCollectionKey(track);
    for (final entry in loved) {
      if (entry.key == key && entry.coverPath != null) return entry.coverPath;
    }
    for (final entry in wishlist) {
      if (entry.key == key && entry.coverPath != null) return entry.coverPath;
    }
    return null;
  }

  bool containsWishlistKey(String trackKey) =>
      _wishlistKeys.contains(trackKey);
  bool containsLovedKey(String trackKey) => _lovedKeys.contains(trackKey);

  bool isFavoriteArtist({
    required String artistId,
    required String? providerId,
    String? name,
  }) {
    final key =
        artistCollectionKey(artistId: artistId, providerId: providerId);
    if (_favoriteArtistKeys.contains(key)) return true;
    if (name != null && name.isNotEmpty) {
      final n = normalizeForMatch(name);
      return favoriteArtists.any((e) => normalizeForMatch(e.name) == n);
    }
    return false;
  }

  bool containsFavoriteArtistKey(String artistKey) =>
      _favoriteArtistKeys.contains(artistKey);

  bool isFavoriteAlbum({
    required String albumId,
    required String? providerId,
    String? name,
  }) {
    if (name != null && name.isNotEmpty) {
      final n = normalizeForMatch(name);
      return favoriteAlbums.any((e) => normalizeForMatch(e.name) == n);
    }
    final key = albumCollectionKey(albumId: albumId, providerId: providerId);
    return _favoriteAlbumKeys.contains(key);
  }

  bool containsFavoriteAlbumKey(String albumKey) =>
      _favoriteAlbumKeys.contains(albumKey);

  bool isFavoritePlaylist({
    required String playlistId,
    required String? providerId,
  }) {
    final key =
        playlistCollectionKey(playlistId: playlistId, providerId: providerId);
    return _favoritePlaylistKeys.contains(key);
  }

  bool containsFavoritePlaylistKey(String playlistKey) =>
      _favoritePlaylistKeys.contains(playlistKey);

  UserPlaylistCollection? playlistById(String id) => _playlistsById[id];

  bool isTrackInAnyPlaylist(String trackKey) =>
      _allPlaylistTrackKeys.contains(trackKey);

  bool get hasPlaylistTracks => playlists.isNotEmpty;

  LibraryCollectionsState copyWith({
    List<CollectionTrackEntry>? wishlist,
    List<CollectionTrackEntry>? loved,
    List<UserPlaylistCollection>? playlists,
    List<CollectionArtistEntry>? favoriteArtists,
    List<CollectionAlbumEntry>? favoriteAlbums,
    List<CollectionPlaylistEntry>? favoritePlaylists,
    bool? isLoaded,
  }) {
    final nextWishlist = wishlist ?? this.wishlist;
    final nextLoved = loved ?? this.loved;
    final nextPlaylists = playlists ?? this.playlists;
    final nextFavoriteArtists = favoriteArtists ?? this.favoriteArtists;
    final nextFavoriteAlbums = favoriteAlbums ?? this.favoriteAlbums;
    final nextFavoritePlaylists = favoritePlaylists ?? this.favoritePlaylists;
    final keepWishlistIndex = identical(nextWishlist, this.wishlist);
    final keepLovedIndex = identical(nextLoved, this.loved);
    final keepPlaylistIndex = identical(nextPlaylists, this.playlists);
    final keepFavoriteArtistIndex =
        identical(nextFavoriteArtists, this.favoriteArtists);
    final keepFavoriteAlbumIndex =
        identical(nextFavoriteAlbums, this.favoriteAlbums);
    final keepFavoritePlaylistIndex =
        identical(nextFavoritePlaylists, this.favoritePlaylists);

    return LibraryCollectionsState(
      wishlist: nextWishlist,
      loved: nextLoved,
      playlists: nextPlaylists,
      favoriteArtists: nextFavoriteArtists,
      favoriteAlbums: nextFavoriteAlbums,
      favoritePlaylists: nextFavoritePlaylists,
      isLoaded: isLoaded ?? this.isLoaded,
      wishlistKeys: keepWishlistIndex ? _wishlistKeys : null,
      lovedKeys: keepLovedIndex ? _lovedKeys : null,
      favoriteArtistKeys: keepFavoriteArtistIndex ? _favoriteArtistKeys : null,
      favoriteAlbumKeys: keepFavoriteAlbumIndex ? _favoriteAlbumKeys : null,
      favoritePlaylistKeys:
          keepFavoritePlaylistIndex ? _favoritePlaylistKeys : null,
      playlistsById: keepPlaylistIndex ? _playlistsById : null,
      allPlaylistTrackKeys:
          keepPlaylistIndex ? _allPlaylistTrackKeys : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'wishlist': wishlist.map((e) => e.toJson()).toList(),
    'loved': loved.map((e) => e.toJson()).toList(),
    'playlists': playlists
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'tracks': p.tracks.map((t) => t.toJson()).toList(),
            })
        .toList(),
    'favoriteArtists': favoriteArtists.map((e) => e.toJson()).toList(),
  };

  factory LibraryCollectionsState.fromJson(Map<String, dynamic> json) =>
      LibraryCollectionsState(isLoaded: true);
}

class PlaylistAddBatchResult {
  final int addedCount;
  final int alreadyInPlaylistCount;

  const PlaylistAddBatchResult({
    required this.addedCount,
    required this.alreadyInPlaylistCount,
  });
}

class PlaylistPickerSummaryRequest {
  final List<String> trackKeys;

  PlaylistPickerSummaryRequest({required this.trackKeys});

  factory PlaylistPickerSummaryRequest.fromTracks(List<Track> tracks) {
    return PlaylistPickerSummaryRequest(
      trackKeys: tracks.map((t) => trackCollectionKey(t)).toList(),
    );
  }
}

class PlaylistPickerSummary {
  final String id;
  final String name;
  final String? coverImagePath;
  final String? previewCover;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int trackCount;
  final bool containsAllRequestedTracks;

  PlaylistPickerSummary({
    required this.id,
    required this.name,
    this.coverImagePath,
    this.previewCover,
    required this.createdAt,
    required this.updatedAt,
    required this.trackCount,
    required this.containsAllRequestedTracks,
  });
}

class LibraryCollectionsNotifier extends Notifier<LibraryCollectionsState> {
  LibraryCollectionsNotifier();

  final _db = LibraryCollectionsDatabase.instance;

  Future<void>? _loadFuture;

  Future<void> _ensureLoaded() async {
    if (state.isLoaded) return;
    await (_loadFuture ?? _load());
  }

  @override
  LibraryCollectionsState build() {
    _loadFuture = _load();
    return LibraryCollectionsState();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _db.loadSnapshot();

      final wishlist = <CollectionTrackEntry>[];
      for (final row in snapshot.wishlistRows) {
        final parsed = _parseTrackEntryRow(row);
        if (parsed != null) wishlist.add(parsed);
      }

      final loved = <CollectionTrackEntry>[];
      for (final row in snapshot.lovedRows) {
        final parsed = _parseTrackEntryRow(row);
        if (parsed != null) loved.add(parsed);
      }

      final favoriteArtists = <CollectionArtistEntry>[];
      for (final row in snapshot.favoriteArtistRows) {
        final parsed = _parseArtistEntryRow(row);
        if (parsed != null) favoriteArtists.add(parsed);
      }

      final favoriteAlbums = <CollectionAlbumEntry>[];
      for (final row in snapshot.favoriteAlbumRows) {
        final albumJson = (row['album_json'] ?? row['item_json']) as String?;
        if (albumJson == null || albumJson.isEmpty) continue;
        try {
          final decoded = jsonDecode(albumJson);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            favoriteAlbums.add(CollectionAlbumEntry.fromJson({
              ...map,
              'coverPath': row['cover_path'] as String?,
            }));
          }
        } catch (e) {}
      }

      final favoritePlaylists = <CollectionPlaylistEntry>[];
      for (final row in snapshot.favoritePlaylistRows) {
        final playlistJson = (row['playlist_json'] ?? row['item_json']) as String?;
        if (playlistJson == null || playlistJson.isEmpty) continue;
        try {
          final decoded = jsonDecode(playlistJson);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            favoritePlaylists.add(CollectionPlaylistEntry.fromJson({
              ...map,
              'coverPath': row['cover_path'] as String?,
            }));
          }
        } catch (e) {}
      }

      final tracksByPlaylist = <String, List<CollectionTrackEntry>>{};
      for (final row in snapshot.playlistTrackRows) {
        final playlistId = row['playlist_id'] as String?;
        if (playlistId == null || playlistId.isEmpty) continue;
        final parsed = _parseTrackEntryRow(row);
        if (parsed == null) continue;
        tracksByPlaylist.putIfAbsent(playlistId, () => []).add(parsed);
      }

      final playlists = <UserPlaylistCollection>[];
      for (final row in snapshot.playlistRows) {
        final id = row['id'] as String?;
        if (id == null || id.isEmpty) continue;
        final createdAtRaw = row['created_at'] as String?;
        final updatedAtRaw = row['updated_at'] as String?;
        final createdAt =
            DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now();
        final updatedAt =
            DateTime.tryParse(updatedAtRaw ?? '') ?? createdAt;
        playlists.add(UserPlaylistCollection(
          id: id,
          name: row['name'] as String? ?? '',
          coverImagePath: row['cover_image_path'] as String?,
          createdAt: createdAt,
          updatedAt: updatedAt,
          tracks: tracksByPlaylist[id] ?? const [],
        ));
      }

      state = LibraryCollectionsState(
        wishlist: wishlist,
        loved: loved,
        playlists: playlists,
        favoriteArtists: favoriteArtists,
        favoriteAlbums: favoriteAlbums,
        favoritePlaylists: favoritePlaylists,
        isLoaded: true,
      );
      _log.d('_load complete: wishlist=${wishlist.length}, loved=${loved.length}, playlists=${playlists.length}');
      final corruptedKeys = <String>[];
      for (final entry in loved) {
        _log.d('_load loved entry: key=${entry.key}, trackId=${entry.track.id}, source=${entry.track.source}, isrc=${entry.track.isrc}');
        final tid = entry.track.id;
        final isCorrupted = tid.contains('loved_') || tid.contains('isrc:') || (entry.track.source == null && !tid.contains(':'));
        if (isCorrupted) {
          corruptedKeys.add(entry.key);
        }
      }
      if (corruptedKeys.isNotEmpty) {
        _log.w('Removing ${corruptedKeys.length} corrupted loved entries: $corruptedKeys');
        for (final key in corruptedKeys) {
          await _db.deleteLovedEntry(key);
        }
      state = state.copyWith(loved: loved.where((e) => !corruptedKeys.contains(e.key)).toList());
      }

      // Migrate old-format keys to normalized source keys
      // (e.g. "qobuz_kennyy:1234" → "qobuz:1234")
      await _migrateOldKeys();

      // Migrate ISRC-based keys to source:id keys (per-source likes)
      await _migrateIsrcKeys();

      _log.d('_load complete: wishlist=${wishlist.length}, loved=${loved.length}, playlists=${playlists.length}');
    } catch (e) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> _migrateIsrcKeys() async {
    try {
      var changed = false;
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('_migrated_isrc_keys') ?? false;

      final snapshot = await _db.loadSnapshot();

      // Migrate loved entries
      for (final row in snapshot.lovedRows) {
        final parsed = _parseTrackEntryRow(row);
        if (parsed == null) continue;
        final oldKey = parsed.key;
        if (!oldKey.startsWith('isrc:')) continue;
        if (migrated) {
          // Already migrated, but key might still be isrc: if track had no source/id
          continue;
        }

        final track = parsed.track;
        final source = (track.source?.trim().isNotEmpty ?? false)
            ? normalizeSource(track.source!.trim())
            : 'builtin';
        final newKey = '$source:${track.id}';

        if (newKey == oldKey || newKey == 'builtin:') continue;

        changed = true;
        if (state.containsLovedKey(newKey)) {
          // Duplicate: delete old entry
          await _db.deleteLovedEntry(oldKey);
          final updated = state.loved
              .where((e) => e.key != oldKey)
              .toList(growable: false);
          state = state.copyWith(loved: updated);
        } else {
          // Re-insert with new key
          await _db.deleteLovedEntry(oldKey);
          await _db.upsertLovedEntry(
            trackKey: newKey,
            trackJson: jsonEncode(track.toJson()),
            addedAt: parsed.addedAt.toIso8601String(),
            audioPath: parsed.audioPath,
            coverPath: parsed.coverPath,
            codec: parsed.codec,
            bitDepth: parsed.bitDepth,
            sampleRate: parsed.sampleRate,
          );
          final updated = state.loved
              .where((e) => e.key != oldKey)
              .toList(growable: false);
          updated.add(CollectionTrackEntry(
            key: newKey,
            track: track,
            addedAt: parsed.addedAt,
            audioPath: parsed.audioPath,
            coverPath: parsed.coverPath,
            codec: parsed.codec,
            bitDepth: parsed.bitDepth,
            sampleRate: parsed.sampleRate,
          ));
          state = state.copyWith(loved: updated);
        }
      }

      // Migrate wishlist entries with isrc: keys
      for (final row in snapshot.wishlistRows) {
        final parsed = _parseTrackEntryRow(row);
        if (parsed == null) continue;
        final oldKey = parsed.key;
        if (!oldKey.startsWith('isrc:')) continue;
        if (migrated) continue;

        final track = parsed.track;
        final source = (track.source?.trim().isNotEmpty ?? false)
            ? normalizeSource(track.source!.trim())
            : 'builtin';
        final newKey = '$source:${track.id}';

        if (newKey == oldKey || newKey == 'builtin:') continue;

        changed = true;
        if (state.containsWishlistKey(newKey)) {
          await _db.deleteWishlistEntry(oldKey);
          final updated = state.wishlist
              .where((e) => e.key != oldKey)
              .toList(growable: false);
          state = state.copyWith(wishlist: updated);
        } else {
          await _db.deleteWishlistEntry(oldKey);
          await _db.upsertWishlistEntry(
            trackKey: newKey,
            trackJson: jsonEncode(track.toJson()),
            addedAt: parsed.addedAt.toIso8601String(),
          );
          final updated = state.wishlist
              .where((e) => e.key != oldKey)
              .toList(growable: false);
          updated.add(CollectionTrackEntry(
            key: newKey,
            track: track,
            addedAt: parsed.addedAt,
          ));
          state = state.copyWith(wishlist: updated);
        }
      }

      // Migrate playlist tracks with isrc: keys
      for (final row in snapshot.playlistTrackRows) {
        final playlistId = row['playlist_id'] as String?;
        if (playlistId == null || playlistId.isEmpty) continue;
        final parsed = _parseTrackEntryRow(row);
        if (parsed == null) continue;
        final oldKey = parsed.key;
        if (!oldKey.startsWith('isrc:')) continue;
        if (migrated) continue;

        final track = parsed.track;
        final source = (track.source?.trim().isNotEmpty ?? false)
            ? normalizeSource(track.source!.trim())
            : 'builtin';
        final newKey = '$source:${track.id}';

        if (newKey == oldKey || newKey == 'builtin:') continue;

        changed = true;
        await _db.deletePlaylistTrack(
          playlistId: playlistId,
          trackKey: oldKey,
          playlistUpdatedAt: DateTime.now().toIso8601String(),
        );
        await _db.upsertPlaylistTrack(
          playlistId: playlistId,
          trackKey: newKey,
          trackJson: jsonEncode(track.toJson()),
          addedAt: parsed.addedAt.toIso8601String(),
          playlistUpdatedAt: DateTime.now().toIso8601String(),
        );

        // Update in-memory state for this playlist
        final playlist = state.playlistById(playlistId);
        if (playlist != null) {
          final updatedTracks = playlist.tracks.map((e) {
            if (e.key == oldKey) {
              return CollectionTrackEntry(
                key: newKey,
                track: track,
                addedAt: e.addedAt,
                audioPath: e.audioPath,
                coverPath: e.coverPath,
                codec: e.codec,
                bitDepth: e.bitDepth,
                sampleRate: e.sampleRate,
              );
            }
            return e;
          }).toList();
          _replacePlaylistById(playlistId, (p) =>
            p.copyWith(tracks: updatedTracks, updatedAt: DateTime.now()));
        }
      }

      if (changed) {
        _log.i('Migrated ISRC-based keys to source:id keys');
      }
      await prefs.setBool('_migrated_isrc_keys', true);
    } catch (e, st) {
      _log.e('Failed to migrate ISRC keys', e, st);
    }
  }

  Future<void> _migrateOldKeys() async {
    try {
      var changed = false;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('_migrated_old_keys_v1') == true) return;

      final snapshot = await _db.loadSnapshot();

      // Migrate loved entries
      for (final row in snapshot.lovedRows) {
        final parsed = _parseTrackEntryRow(row);
        if (parsed == null) continue;
        final newKey = trackCollectionKey(parsed.track);
        if (parsed.key != newKey) {
          changed = true;
          if (state.containsLovedKey(newKey)) {
            // Duplicate: delete old entry
            await _db.deleteLovedEntry(parsed.key);
            final updated = state.loved
                .where((e) => e.key != parsed.key)
                .toList(growable: false);
            state = state.copyWith(loved: updated);
          } else {
            // Re-insert with new key
            await _db.deleteLovedEntry(parsed.key);
            await _db.upsertLovedEntry(
              trackKey: newKey,
              trackJson: jsonEncode(parsed.track.toJson()),
              addedAt: parsed.addedAt.toIso8601String(),
              audioPath: parsed.audioPath,
              coverPath: parsed.coverPath,
              codec: parsed.codec,
              bitDepth: parsed.bitDepth,
              sampleRate: parsed.sampleRate,
            );
            final updated = state.loved
                .where((e) => e.key != parsed.key)
                .toList(growable: false);
            updated.add(CollectionTrackEntry(
              key: newKey,
              track: parsed.track,
              addedAt: parsed.addedAt,
              audioPath: parsed.audioPath,
              coverPath: parsed.coverPath,
              codec: parsed.codec,
              bitDepth: parsed.bitDepth,
              sampleRate: parsed.sampleRate,
            ));
            state = state.copyWith(loved: updated);
          }
        }
      }

      // Migrate wishlist entries
      for (final row in snapshot.wishlistRows) {
        final parsed = _parseTrackEntryRow(row);
        if (parsed == null) continue;
        final newKey = trackCollectionKey(parsed.track);
        if (parsed.key != newKey) {
          changed = true;
          if (state.containsWishlistKey(newKey)) {
            await _db.deleteWishlistEntry(parsed.key);
            final updated = state.wishlist
                .where((e) => e.key != parsed.key)
                .toList(growable: false);
            state = state.copyWith(wishlist: updated);
          } else {
            await _db.deleteWishlistEntry(parsed.key);
            await _db.upsertWishlistEntry(
              trackKey: newKey,
              trackJson: jsonEncode(parsed.track.toJson()),
              addedAt: parsed.addedAt.toIso8601String(),
            );
            final updated = state.wishlist
                .where((e) => e.key != parsed.key)
                .toList(growable: false);
            updated.add(CollectionTrackEntry(
              key: newKey,
              track: parsed.track,
              addedAt: parsed.addedAt,
            ));
            state = state.copyWith(wishlist: updated);
          }
        }
      }

      if (changed) {
        _log.i('Migrated old-format keys to normalized source keys');
      }
      await prefs.setBool('_migrated_old_keys_v1', true);
    } catch (e, st) {
      _log.e('Failed to migrate old keys', e, st);
    }
  }

  CollectionTrackEntry? _parseTrackEntryRow(Map<String, dynamic> row) {
    final key = (row['track_key'] ?? row['item_id']) as String?;
    final trackJson = (row['track_json'] ?? row['item_json']) as String?;
    if (key == null ||
        key.isEmpty ||
        trackJson == null ||
        trackJson.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trackJson);
      if (decoded is! Map) return null;
      final track = Track.fromJson(Map<String, dynamic>.from(decoded));
      final addedAtRaw = row['added_at'] as String?;
      return CollectionTrackEntry(
        key: key,
        track: track,
        addedAt: DateTime.tryParse(addedAtRaw ?? '') ?? DateTime.now(),
        audioPath: row['audio_path'] as String?,
        coverPath: row['cover_path'] as String?,
        codec: row['codec'] as String?,
        bitDepth: row['bit_depth'] as int?,
        sampleRate: row['sample_rate'] as int?,
      );
    } catch (e) {
      return null;
    }
  }

  CollectionArtistEntry? _parseArtistEntryRow(Map<String, dynamic> row) {
    final key = (row['artist_key'] ?? row['item_id']) as String?;
    final artistJson = (row['artist_json'] ?? row['item_json']) as String?;
    if (key == null ||
        key.isEmpty ||
        artistJson == null ||
        artistJson.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(artistJson);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final addedAtRaw = row['added_at'] as String?;
      return CollectionArtistEntry.fromJson({
        ...map,
        'key': key,
        'addedAt': map['addedAt'] ?? addedAtRaw,
        'coverPath': row['cover_path'] as String?,
      });
    } catch (e) {
      return null;
    }
  }

  Future<bool> toggleLoved(Track track) async {
    await _ensureLoaded();
    final cKey = canonicalLoveKey(track);
    if (state.isLoved(track)) {
      for (final entry in state.loved) {
        if (canonicalLoveKey(entry.track) == cKey) {
          await _db.deleteLovedEntry(entry.key);
        }
      }
      final updated = state.loved
          .where((entry) => canonicalLoveKey(entry.track) != cKey)
          .toList(growable: false);
      state = state.copyWith(loved: updated);
      await _cleanupFoldersOnUnlike(track);
      return false;
    }

    var savedTrack = track;
    String? savedCoverPath;
    String? savedAudioPath;
    final hasCoverUrl =
        track.coverUrl != null && track.coverUrl!.isNotEmpty;
    if (hasCoverUrl) {
      try {
        String? localFilePath;
        final isrc = track.isrc?.trim();
        if (isrc != null && isrc.isNotEmpty) {
          final byIsrc = await HistoryDatabase.instance.getByIsrc(isrc);
          if (byIsrc != null) {
            localFilePath = DownloadHistoryItem.fromJson(byIsrc).filePath;
          }
        }
        if (localFilePath == null) {
          final byTrack = await HistoryDatabase.instance
              .findByTrackAndArtist(track.name, track.artistName);
          if (byTrack != null) {
            localFilePath = DownloadHistoryItem.fromJson(byTrack).filePath;
          }
        }
        if (localFilePath == null && track.id.isNotEmpty) {
          final byId =
              await HistoryDatabase.instance.getBySpotifyId(track.id);
          if (byId != null) {
            localFilePath = DownloadHistoryItem.fromJson(byId).filePath;
          }
        }

        final settings = ref.read(settingsProvider);
        final baseDir =
            settings.storageMode == 'saf' &&
                    settings.downloadTreeUri.isNotEmpty
                ? settings.downloadTreeUri
                : settings.downloadDirectory;

        _log.d('toggleLoved: baseDir=$baseDir, coverUrl=${track.coverUrl}, localFilePath=$localFilePath');
        if (baseDir.isEmpty) {
          _log.w('toggleLoved: baseDir is empty, skipping cover extraction');
        } else if (localFilePath == null && track.coverUrl != null && track.coverUrl!.isNotEmpty) {
          // No local file found, but we have a cover URL - download directly from URL
          _log.d('toggleLoved: no local file, downloading cover from URL');
          final primaryArtist = primaryArtistName(track.artistName);
          final sanitizedArtist = _sanitizeFolderName(primaryArtist);
          final sanitizedAlbum = track.albumName.trim().isNotEmpty
              ? _sanitizeFolderName(track.albumName)
              : null;
          final sanitizedSong = _sanitizeFolderName(track.name);
          final sanitizedSingleOrAlbum = sanitizedAlbum ?? sanitizedSong;

          final artistDir = Directory(p.join(baseDir, sanitizedArtist));
          if (!await artistDir.exists()) {
            await artistDir.create(recursive: true);
          }
          final containerDir =
              Directory(p.join(artistDir.path, sanitizedSingleOrAlbum));
          if (!await containerDir.exists()) {
            await containerDir.create(recursive: true);
          }

          final songDirPath = p.join(containerDir.path, sanitizedSong);
          final songDir = Directory(songDirPath);
          if (!await songDir.exists()) await songDir.create(recursive: true);
          final localPath = p.join(songDirPath, 'cover.jpg');

          // Download cover from URL
          final uri = Uri.parse(track.coverUrl!);
          for (int attempt = 0; attempt < 3; attempt++) {
            try {
              final resp = await http.get(uri, headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': 'https://music.apple.com/',
              });
              if (resp.statusCode == 200) {
                await File(localPath).writeAsBytes(resp.bodyBytes);
                savedCoverPath = localPath;
                // Save album/playlist cover (container level)
                final containerCoverPath =
                    p.join(containerDir.path, 'cover.jpg');
                if (!await File(containerCoverPath).exists()) {
                  await File(containerCoverPath).writeAsBytes(resp.bodyBytes);
                }
                break;
              }
            } catch (e) {
              if (attempt < 2) await Future.delayed(const Duration(seconds: 1));
            }
          }
        } else if (localFilePath != null) {
          final primaryArtist = primaryArtistName(track.artistName);
          final sanitizedArtist = _sanitizeFolderName(primaryArtist);
          final sanitizedAlbum = track.albumName.trim().isNotEmpty
              ? _sanitizeFolderName(track.albumName)
              : null;
          final sanitizedSong = _sanitizeFolderName(track.name);
          final sanitizedSingleOrAlbum = sanitizedAlbum ?? sanitizedSong;

          final artistDir = Directory(p.join(baseDir, sanitizedArtist));
          if (!await artistDir.exists()) {
            await artistDir.create(recursive: true);
          }
          final containerDir =
              Directory(p.join(artistDir.path, sanitizedSingleOrAlbum));
          if (!await containerDir.exists()) {
            await containerDir.create(recursive: true);
          }

          String? localPath;
          String? songDirPath;
          if (localFilePath != null && await fileExists(localFilePath)) {
            songDirPath = p.join(containerDir.path, sanitizedSong);
            final songDir = Directory(songDirPath);
            if (!await songDir.exists()) await songDir.create(recursive: true);
            localPath = p.join(songDirPath, 'cover.jpg');
            if (!await File(localPath).exists()) {
              try {
                await PlatformBridge.extractCoverToFile(localFilePath, localPath);
              } catch (e) {
                // fall through to URL download
              }
            }
            if (await File(localPath).exists()) {
              savedCoverPath = localPath;
              savedAudioPath = localFilePath;
              // Save album/playlist cover (container level), NOT artist cover
              final containerCoverPath =
                  p.join(containerDir.path, 'cover.jpg');
              if (!await File(containerCoverPath).exists()) {
                await PlatformBridge.extractCoverToFile(
                    localFilePath, containerCoverPath);
              }
            }
          }
        }

        if (savedCoverPath != null) {
          savedTrack = Track(
            id: track.id,
            name: track.name,
            artistName: track.artistName,
            albumName: track.albumName,
            coverUrl: track.coverUrl,
            artistId: track.artistId,
            albumId: track.albumId,
            isrc: track.isrc,
            duration: track.duration,
            trackNumber: track.trackNumber,
            discNumber: track.discNumber,
            totalDiscs: track.totalDiscs,
            releaseDate: track.releaseDate,
            deezerId: track.deezerId,
            source: track.source,
            albumType: track.albumType,
            totalTracks: track.totalTracks,
            composer: track.composer,
            itemType: track.itemType,
            audioQuality: track.audioQuality,
            audioModes: track.audioModes,
            codec: track.codec,
            bitDepth: track.bitDepth,
            sampleRate: track.sampleRate,
          );
        }
      } catch (e, st) {
        _log.e('toggleLoved: error extracting cover', e, st);
      }
    }

    _log.d('toggleLoved: savedCoverPath=$savedCoverPath, savedAudioPath=$savedAudioPath');
    final entryKey = 'loved_$cKey';
    final entry = CollectionTrackEntry(
      key: entryKey,
      track: savedTrack,
      addedAt: DateTime.now(),
      audioPath: savedAudioPath,
      coverPath: savedCoverPath,
      codec: savedTrack.codec,
      bitDepth: savedTrack.bitDepth,
      sampleRate: savedTrack.sampleRate,
    );
    _log.d('toggleLoved: entry created, key=$entryKey, track=${savedTrack.name}, artist=${savedTrack.artistName}');

    final existingIndex = state.loved.indexWhere((e) => e.key == entryKey);
    List<CollectionTrackEntry> updated;
    if (existingIndex >= 0) {
      updated = [...state.loved];
      updated[existingIndex] = entry;
    } else {
      updated = [entry, ...state.loved];
    }

    await _db.upsertLovedEntry(
      trackKey: entryKey,
      trackJson: jsonEncode(savedTrack.toJson()),
      addedAt: entry.addedAt.toIso8601String(),
      matchKey: cKey,
      audioPath: savedAudioPath,
      coverPath: savedCoverPath,
      codec: savedTrack.codec,
      bitDepth: savedTrack.bitDepth,
      sampleRate: savedTrack.sampleRate,
    );
    _log.d('toggleLoved: DB saved trackJson name=${savedTrack.name}');
    state = state.copyWith(loved: updated);
    return true;
  }

  Future<bool> toggleFavoriteArtist({
    required String artistId,
    required String? providerId,
    required String name,
    String? imageUrl,
  }) async {
    await _ensureLoaded();
    final key =
        artistCollectionKey(artistId: artistId, providerId: providerId);
    final sourceSeparator = key.indexOf(':');
    final source =
        sourceSeparator > 0 ? key.substring(0, sourceSeparator) : '';
    final trimmedProviderId = providerId?.trim();
    final effectiveProviderId =
        trimmedProviderId != null && trimmedProviderId.isNotEmpty
            ? trimmedProviderId
            : (source.isNotEmpty && source != 'builtin' ? source : null);

    final normalizedName = normalizeForMatch(name);
    final existingSameName = state.favoriteArtists.where(
      (e) => normalizeForMatch(e.name) == normalizedName,
    ).toList();

    if (existingSameName.any((e) => e.key == key)) {
      await _db.deleteFavoriteArtistEntry(key);
      final updated = state.favoriteArtists
          .where((e) => e.key != key)
          .toList(growable: false);
      state = state.copyWith(favoriteArtists: updated);
      if (existingSameName.length <= 1) {
        await _cleanupFoldersOnUnlikeArtist(name);
      }
      return false;
    }

    if (existingSameName.isNotEmpty) {
      final existing = existingSameName.first;
      final merged = existing.mergeCover(imageUrl);
      final updated = state.favoriteArtists.map((e) {
        if (e.key == existing.key) return merged;
        return e;
      }).toList(growable: false);
      final savedCoverPath = await _saveArtistCoverLocally(name, imageUrl);
      await _db.upsertFavoriteArtistEntry(
        artistKey: existing.key,
        artistJson: jsonEncode(merged.toJson()),
        addedAt: merged.addedAt.toIso8601String(),
        coverPath: savedCoverPath ?? merged.coverPath,
      );
      state = state.copyWith(favoriteArtists: updated);
      return true;
    }

    String? savedCoverPath = await _saveArtistCoverLocally(name, imageUrl);

    final entry = CollectionArtistEntry(
      key: key,
      artistId: _stripCollectionResourcePrefix(artistId),
      providerId: effectiveProviderId,
      name: name,
      imageUrl: imageUrl,
      coverPath: savedCoverPath,
      addedAt: DateTime.now(),
    );
    await _db.upsertFavoriteArtistEntry(
      artistKey: key,
      artistJson: jsonEncode(entry.toJson()),
      addedAt: entry.addedAt.toIso8601String(),
      coverPath: savedCoverPath,
    );
    state = state.copyWith(
      favoriteArtists: [entry, ...state.favoriteArtists],
    );
    return true;
  }

  Future<bool> toggleFavoriteArtistByKey({
    required String key,
    required String artistId,
    required String? providerId,
    required String name,
    String? imageUrl,
  }) async {
    await _ensureLoaded();
    if (state.containsFavoriteArtistKey(key)) {
      await _db.deleteFavoriteArtistEntry(key);
      final updated = state.favoriteArtists
          .where((e) => e.key != key)
          .toList(growable: false);
      state = state.copyWith(favoriteArtists: updated);
      return false;
    }
    return await toggleFavoriteArtist(
      artistId: artistId,
      providerId: providerId,
      name: name,
      imageUrl: imageUrl,
    );
  }

  Future<String?> _saveArtistCoverLocally(String name, String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final settings = ref.read(settingsProvider);
      final baseDir =
          settings.storageMode == 'saf' && settings.downloadTreeUri.isNotEmpty
              ? settings.downloadTreeUri
              : settings.downloadDirectory;
      final artistDir =
          Directory(p.join(baseDir, _sanitizeFolderName(name)));
      if (!await artistDir.exists()) await artistDir.create(recursive: true);
      final coverPath = p.join(artistDir.path, 'cover.jpg');
      String targetPath = coverPath;
      if (await File(coverPath).exists()) {
        int idx = 0;
        do {
          idx++;
          targetPath = p.join(artistDir.path, 'cover_$idx.jpg');
        } while (await File(targetPath).exists());
      }
      final uri = Uri.parse(imageUrl);
      final resp = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': '${uri.scheme}://${uri.host}/',
      });
      if (resp.statusCode == 200) {
        await File(targetPath).writeAsBytes(resp.bodyBytes);
      }
      if (await File(targetPath).exists()) return targetPath;
    } catch (e) {}
    return null;
  }

  Future<void> removeFavoriteArtist(String artistKey) async {
    await _ensureLoaded();
    if (!state.containsFavoriteArtistKey(artistKey)) return;
    await _db.deleteFavoriteArtistEntry(artistKey);
    final updated = state.favoriteArtists
        .where((entry) => entry.key != artistKey)
        .toList(growable: false);
    state = state.copyWith(favoriteArtists: updated);
  }

  Future<void> removeFromWishlist(String trackKey) async {
    await _ensureLoaded();
    if (!state.containsWishlistKey(trackKey)) return;
    await _db.deleteWishlistEntry(trackKey);
    final updated = state.wishlist
        .where((entry) => entry.key != trackKey)
        .toList(growable: false);
    state = state.copyWith(wishlist: updated);
  }

  Future<void> removeFromLoved(String trackKey) async {
    await _ensureLoaded();
    if (!state.containsLovedKey(trackKey)) return;
    await _db.deleteLovedEntry(trackKey);
    final updated = state.loved
        .where((entry) => entry.key != trackKey)
        .toList(growable: false);
    state = state.copyWith(loved: updated);
  }

  Future<bool> toggleLovedByKey(String key, Track track) async {
    return await toggleLoved(track);
  }

  Future<void> _cleanupFoldersOnUnlikeArtist(String artistName) async {
    try {
      final settings = ref.read(settingsProvider);
      final baseDir =
          settings.storageMode == 'saf' && settings.downloadTreeUri.isNotEmpty
              ? settings.downloadTreeUri
              : settings.downloadDirectory;
      if (baseDir.isEmpty) return;

      final sanitizedArtist = _sanitizeFolderName(primaryArtistName(artistName));
      final artistDir = Directory(p.join(baseDir, sanitizedArtist));
      final artistCover = File(p.join(artistDir.path, 'cover.jpg'));
      if (await artistCover.exists()) await artistCover.delete();

      if (await artistDir.exists()) {
        final contents = await artistDir.list().toList();
        final hasSubDirs = contents.any((e) => e is Directory);
        if (!hasSubDirs) {
          await artistDir.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  Future<void> _cleanupFoldersOnUnlike(Track track) async {
    try {
      final settings = ref.read(settingsProvider);
      final baseDir =
          settings.storageMode == 'saf' && settings.downloadTreeUri.isNotEmpty
              ? settings.downloadTreeUri
              : settings.downloadDirectory;
      if (baseDir.isEmpty) return;

      String? localFilePath;
      final isrc = track.isrc?.trim();
      if (isrc != null && isrc.isNotEmpty) {
        final byIsrc = await HistoryDatabase.instance.getByIsrc(isrc);
        if (byIsrc != null) {
          localFilePath = DownloadHistoryItem.fromJson(byIsrc).filePath;
        }
      }
      if (localFilePath == null) {
        final byTrack = await HistoryDatabase.instance
            .findByTrackAndArtist(track.name, track.artistName);
        if (byTrack != null) {
          localFilePath = DownloadHistoryItem.fromJson(byTrack).filePath;
        }
      }
      if (localFilePath == null && track.id.isNotEmpty) {
        final byId = await HistoryDatabase.instance.getBySpotifyId(track.id);
        if (byId != null) {
          localFilePath = DownloadHistoryItem.fromJson(byId).filePath;
        }
      }

      final isDownloaded = localFilePath != null && await fileExists(localFilePath);
      if (isDownloaded) return;

      final primaryArtist = primaryArtistName(track.artistName);
      final sanitizedArtist = _sanitizeFolderName(primaryArtist);
      final sanitizedAlbum = track.albumName.trim().isNotEmpty
          ? _sanitizeFolderName(track.albumName)
          : null;
      final sanitizedSong = _sanitizeFolderName(track.name);
      final sanitizedSingleOrAlbum = sanitizedAlbum ?? sanitizedSong;

      final artistDir = Directory(p.join(baseDir, sanitizedArtist));
      final containerDir = Directory(p.join(artistDir.path, sanitizedSingleOrAlbum));
      final songDir = Directory(p.join(containerDir.path, sanitizedSong));

      final songCover = File(p.join(songDir.path, 'cover.jpg'));
      if (await songCover.exists()) await songCover.delete();

      final dirsInAlbum = await containerDir.exists()
          ? (await containerDir.list().toList()).whereType<Directory>().toList()
          : <Directory>[];
      final otherSongsInAlbum = dirsInAlbum.where((d) => d.path != songDir.path).length;
      if (otherSongsInAlbum == 0) {
        final albumCover = File(p.join(containerDir.path, 'cover.jpg'));
        if (await albumCover.exists()) await albumCover.delete();
      }

      final dirsByArtist = await artistDir.exists()
          ? (await artistDir.list().toList()).whereType<Directory>().toList()
          : <Directory>[];
      final otherAlbumsByArtist = dirsByArtist.where((d) => d.path != containerDir.path).length;
      if (otherAlbumsByArtist == 0) {
        final artistIsFavorited = state.favoriteArtists.any(
          (a) => a.name.toLowerCase().trim() == primaryArtist.toLowerCase().trim(),
        );
        if (!artistIsFavorited) {
          final artistCover = File(p.join(artistDir.path, 'cover.jpg'));
          if (await artistCover.exists()) await artistCover.delete();
        }
      }

      if (await songDir.exists()) {
        final contents = await songDir.list().toList();
        if (contents.isEmpty) await songDir.delete(recursive: true);
      }
      await _cleanupEmptyParentDir(containerDir, artistDir);
    } catch (_) {}
  }

  Future<void> _cleanupEmptyParentDir(Directory containerDir, Directory artistDir) async {
    try {
      if (await containerDir.exists()) {
        final contents = await containerDir.list().toList();
        if (contents.isEmpty) {
          await containerDir.delete(recursive: true);
          if (await artistDir.exists()) {
            final artistContents = await artistDir.list().toList();
            if (artistContents.isEmpty) {
              await artistDir.delete(recursive: true);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> cleanupFoldersOnRemoveDownload(Track track) async {
    await _ensureLoaded();
    final key = trackCollectionKey(track);
    final isLoved = state.containsLovedKey(key);

    try {
      final settings = ref.read(settingsProvider);
      final baseDir =
          settings.storageMode == 'saf' && settings.downloadTreeUri.isNotEmpty
              ? settings.downloadTreeUri
              : settings.downloadDirectory;
      if (baseDir.isEmpty) return;

      final primaryArtist = primaryArtistName(track.artistName);
      final sanitizedArtist = _sanitizeFolderName(primaryArtist);
      final sanitizedAlbum = track.albumName.trim().isNotEmpty
          ? _sanitizeFolderName(track.albumName)
          : null;
      final sanitizedSong = _sanitizeFolderName(track.name);
      final sanitizedSingleOrAlbum = sanitizedAlbum ?? sanitizedSong;

      final artistDir = Directory(p.join(baseDir, sanitizedArtist));
      final containerDir = Directory(p.join(artistDir.path, sanitizedSingleOrAlbum));
      final songDir = Directory(p.join(containerDir.path, sanitizedSong));

      if (await songDir.exists()) {
        final contents = await songDir.list().toList();
        for (final entity in contents) {
          if (entity is File) {
            final name = p.basename(entity.path).toLowerCase();
            final isAudio = name.endsWith('.flac') || name.endsWith('.mp3') || name.endsWith('.m4a') || name.endsWith('.opus') || name.endsWith('.wav');
            final isLyrics = name.endsWith('.lrc') || name.endsWith('.txt');
            if (isAudio || isLyrics) {
              await entity.delete();
            }
          }
        }
        final remaining = await songDir.list().toList();
        if (remaining.isEmpty && !isLoved) {
          await songDir.delete(recursive: true);
          await _cleanupEmptyParentDir(containerDir, artistDir);
        }
      }
    } catch (_) {}
  }

  Future<bool> toggleWishlist(Track track) async {
    await _ensureLoaded();
    final key = trackCollectionKey(track);
    if (state.containsWishlistKey(key)) {
      await _db.deleteWishlistEntry(key);
      final updated = state.wishlist.where((entry) => entry.key != key).toList(growable: false);
      state = state.copyWith(wishlist: updated);
      return false;
    }
    final entry = CollectionTrackEntry(key: key, track: track, addedAt: DateTime.now());
    await _db.upsertWishlistEntry(
      trackKey: key,
      trackJson: jsonEncode(track.toJson()),
      addedAt: entry.addedAt.toIso8601String(),
      matchKey: canonicalLoveKey(track),
    );
    state = state.copyWith(wishlist: [entry, ...state.wishlist]);
    return true;
  }

  Future<void> updateTrackPaths({
    required Track track,
    String? audioPath,
    String? coverPath,
    String? codec,
    int? bitDepth,
    int? sampleRate,
  }) async {
    await _ensureLoaded();
    final key = trackCollectionKey(track);
    final trackJson = jsonEncode(track.toJson());

    // 1. Find all tracks that match this one (either by key or canonical name|artist)
    final canonicalKey = canonicalLoveKey(track);
    
    // 2. Perform DB updates for all matching items in loved/wishlist
    // We update by match key instead of just the primary key to handle cross-source synchronization
    await _db.updateLovedTrackPathsByCanonicalKey(
      canonicalKey: canonicalKey,
      trackJson: trackJson,
      audioPath: audioPath,
      coverPath: coverPath,
      codec: codec,
      bitDepth: bitDepth,
      sampleRate: sampleRate,
    );

    // Also update all occurrences in playlists
    final matchingKeysInPlaylists = await _db.getPlaylistTracksByCanonicalKey(canonicalKey);
    for (final keyInPlaylist in matchingKeysInPlaylists) {
      await _db.updatePlaylistTrackPaths(
        playlistId: keyInPlaylist.playlistId,
        trackKey: keyInPlaylist.trackKey,
        trackJson: trackJson,
        audioPath: audioPath,
        coverPath: coverPath,
        codec: codec,
        bitDepth: bitDepth,
        sampleRate: sampleRate,
      );
    }

    // 3. Update state
    state = state.copyWith(
      loved: state.loved.map((entry) {
        if (entry.key == key || canonicalLoveKey(entry.track) == canonicalKey) {
          return CollectionTrackEntry(
            key: entry.key,
            track: entry.track, // Keep original track identity but update metadata/paths
            addedAt: entry.addedAt,
            audioPath: audioPath,
            coverPath: coverPath ?? entry.coverPath,
            codec: codec ?? entry.codec,
            bitDepth: bitDepth ?? entry.bitDepth,
            sampleRate: sampleRate ?? entry.sampleRate,
          );
        }
        return entry;
      }).toList(),
      wishlist: state.wishlist.map((entry) {
        if (entry.key == key || canonicalLoveKey(entry.track) == canonicalKey) {
          return CollectionTrackEntry(
            key: entry.key,
            track: entry.track,
            addedAt: entry.addedAt,
            audioPath: audioPath,
            coverPath: coverPath ?? entry.coverPath,
            codec: codec ?? entry.codec,
            bitDepth: bitDepth ?? entry.bitDepth,
            sampleRate: sampleRate ?? entry.sampleRate,
          );
        }
        return entry;
      }).toList(),
      playlists: state.playlists.map((playlist) {
        return playlist.copyWith(
          tracks: playlist.tracks.map((entry) {
            if (entry.key == key || canonicalLoveKey(entry.track) == canonicalKey) {
              return CollectionTrackEntry(
                key: entry.key,
                track: entry.track,
                addedAt: entry.addedAt,
                audioPath: audioPath,
                coverPath: coverPath ?? entry.coverPath,
                codec: codec ?? entry.codec,
                bitDepth: bitDepth ?? entry.bitDepth,
                sampleRate: sampleRate ?? entry.sampleRate,
              );
            }
            return entry;
          }).toList(),
        );
      }).toList(),
    );
  }

  Future<void> migratePathsToNewDirectory(String newDirectory) async {
    await _ensureLoaded();
    for (final entry in state.loved) {
      if (entry.audioPath != null || entry.coverPath != null) {
        String? newAudioPath;
        String? newCoverPath;
        if (entry.audioPath != null) {
          final fileName = p.basename(entry.audioPath!);
          newAudioPath = p.join(newDirectory, 'audio', fileName);
        }
        if (entry.coverPath != null) {
          final fileName = p.basename(entry.coverPath!);
          newCoverPath = p.join(newDirectory, 'cover', fileName);
        }
        await updateTrackPaths(
          track: entry.track,
          audioPath: newAudioPath ?? entry.audioPath!,
          coverPath: newCoverPath,
        );
      }
    }
  }

  Future<bool> toggleFavoriteAlbum({
    required String albumId,
    required String? providerId,
    required String name,
    String? artistName,
    String? coverUrl,
    String? imageUrl,
    int? totalTracks,
  }) async {
    await _ensureLoaded();
    final normalizedName = normalizeForMatch(name);
    final existing = state.favoriteAlbums.where(
      (e) => normalizeForMatch(e.name) == normalizedName,
    ).toList();

    if (existing.isNotEmpty) {
      final keysToRemove = existing.map((e) => e.key).toSet();
      for (final k in keysToRemove) {
        await _db.deleteFavoriteAlbumEntry(k);
      }
      final updated = state.favoriteAlbums
          .where((e) => !keysToRemove.contains(e.key))
          .toList(growable: false);
      state = state.copyWith(favoriteAlbums: updated);
      await _cleanupFoldersOnUnlikeAlbum(name, artistName ?? 'Unknown');
      return false;
    }

    final key = albumCollectionKey(albumId: albumId, providerId: providerId);
    String? savedCoverPath;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      try {
        final settings = ref.read(settingsProvider);
        final baseDir =
            settings.storageMode == 'saf' &&
                    settings.downloadTreeUri.isNotEmpty
                ? settings.downloadTreeUri
                : settings.downloadDirectory;
        final sanitizedArtist = artistName ?? 'Unknown';
        final sanitizedAlbum = _sanitizeFolderName(name);
        final artistDir =
            Directory(p.join(baseDir, _sanitizeFolderName(sanitizedArtist)));
        if (!await artistDir.exists()) {
          await artistDir.create(recursive: true);
        }
        final albumDir =
            Directory(p.join(artistDir.path, sanitizedAlbum));
        if (!await albumDir.exists()) {
          await albumDir.create(recursive: true);
        }
        final coverPath = p.join(albumDir.path, 'cover.jpg');
        if (!await File(coverPath).exists()) {
          final uri = Uri.parse(coverUrl);
          final resp = await http.get(uri, headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': '${uri.scheme}://${uri.host}/',
          });
          if (resp.statusCode == 200) {
            await File(coverPath).writeAsBytes(resp.bodyBytes);
          }
        }
        if (await File(coverPath).exists()) savedCoverPath = coverPath;
      } catch (_) {}
    }

    final entry = CollectionAlbumEntry(
      key: key,
      albumId: _stripCollectionResourcePrefix(albumId),
      providerId: providerId,
      name: name,
      artistName: artistName,
      coverUrl: coverUrl,
      imageUrl: imageUrl,
      coverPath: savedCoverPath,
      addedAt: DateTime.now(),
      totalTracks: totalTracks,
    );
    await _db.upsertFavoriteAlbumEntry(
      albumKey: key,
      albumJson: jsonEncode(entry.toJson()),
      addedAt: entry.addedAt.toIso8601String(),
      coverPath: savedCoverPath,
    );
    state = state.copyWith(favoriteAlbums: [entry, ...state.favoriteAlbums]);
    return true;
  }

  Future<bool> toggleFavoriteAlbumByKey({
    required String key,
    required String albumId,
    required String? providerId,
    required String name,
    String? artistName,
    String? coverUrl,
    String? imageUrl,
    int? totalTracks,
  }) async {
    await _ensureLoaded();
    final normalizedName = normalizeForMatch(name);
    final existing = state.favoriteAlbums.where(
      (e) => normalizeForMatch(e.name) == normalizedName,
    ).toList();
    if (existing.isNotEmpty) {
      final keysToRemove = existing.map((e) => e.key).toSet();
      for (final k in keysToRemove) {
        await _db.deleteFavoriteAlbumEntry(k);
      }
      final updated = state.favoriteAlbums
          .where((e) => !keysToRemove.contains(e.key))
          .toList(growable: false);
      state = state.copyWith(favoriteAlbums: updated);
      return false;
    }
    return await toggleFavoriteAlbum(
      albumId: albumId,
      providerId: providerId,
      name: name,
      artistName: artistName,
      coverUrl: coverUrl,
      imageUrl: imageUrl,
      totalTracks: totalTracks,
    );
  }

  Future<void> removeFavoriteAlbum(String albumKey) async {
    await _ensureLoaded();
    if (!state.containsFavoriteAlbumKey(albumKey)) return;
    await _db.deleteFavoriteAlbumEntry(albumKey);
    final updated = state.favoriteAlbums
        .where((entry) => entry.key != albumKey)
        .toList(growable: false);
    state = state.copyWith(favoriteAlbums: updated);
  }

  Future<void> _cleanupFoldersOnUnlikeAlbum(String albumName, String artistName) async {
    try {
      final settings = ref.read(settingsProvider);
      final baseDir =
          settings.storageMode == 'saf' && settings.downloadTreeUri.isNotEmpty
              ? settings.downloadTreeUri
              : settings.downloadDirectory;
      if (baseDir.isEmpty) return;

      final sanitizedArtist = _sanitizeFolderName(primaryArtistName(artistName));
      final sanitizedAlbum = _sanitizeFolderName(albumName);
      final artistDir = Directory(p.join(baseDir, sanitizedArtist));
      final albumDir = Directory(p.join(artistDir.path, sanitizedAlbum));

      final albumCover = File(p.join(albumDir.path, 'cover.jpg'));
      if (await albumCover.exists()) await albumCover.delete();

      final hasLikedOrDownloadedTracks = await _albumHasLocalTracks(albumDir);
      if (!hasLikedOrDownloadedTracks) {
        if (await albumDir.exists()) {
          final contents = await albumDir.list().toList();
          if (contents.isEmpty) await albumDir.delete(recursive: true);
          await _cleanupEmptyParentDir(albumDir, artistDir);
        }
      }
    } catch (_) {}
  }

  Future<bool> _albumHasLocalTracks(Directory albumDir) async {
    if (!await albumDir.exists()) return false;
    final contents = await albumDir.list().toList();
    for (final entity in contents) {
      if (entity is Directory) {
        final songContents = await entity.list().toList();
        if (songContents.isNotEmpty) return true;
      }
    }
    return false;
  }

  Future<void> downloadAlbum({
    required String albumId,
    required String? providerId,
    required String name,
    required String artistName,
    required List<Track> tracks,
    String? quality,
  }) async {
    final queueNotifier = ref.read(downloadQueueProvider.notifier);
    for (final track in tracks) {
      queueNotifier.addToQueue(
        track,
        track.source ?? 'deezer',
        qualityOverride: quality,
      );
    }
  }

  Future<void> removeDownloadAlbum({
    required String albumId,
    required String? providerId,
    required String name,
    required String artistName,
    required List<Track> tracks,
  }) async {
    await _ensureLoaded();
    final historyNotifier = ref.read(downloadHistoryProvider.notifier);
    final localLibraryDb = LibraryDatabase.instance;

    for (final track in tracks) {
      final key = trackCollectionKey(track);
      final isLoved = state.containsLovedKey(key);

      String? localFilePath;
      final isrc = track.isrc?.trim();
      if (isrc != null && isrc.isNotEmpty) {
        final byIsrc = await HistoryDatabase.instance.getByIsrc(isrc);
        if (byIsrc != null) {
          localFilePath = DownloadHistoryItem.fromJson(byIsrc).filePath;
        }
      }
      if (localFilePath == null) {
        final byTrack = await HistoryDatabase.instance
            .findByTrackAndArtist(track.name, track.artistName);
        if (byTrack != null) {
          localFilePath = DownloadHistoryItem.fromJson(byTrack).filePath;
        }
      }
      if (localFilePath == null && track.id.isNotEmpty) {
        final byId = await HistoryDatabase.instance.getBySpotifyId(track.id);
        if (byId != null) {
          localFilePath = DownloadHistoryItem.fromJson(byId).filePath;
        }
      }

      if (localFilePath != null) {
        try { await deleteFile(localFilePath); } catch (_) {}
        final historyItem = await HistoryDatabase.instance.findByTrackAndArtist(track.name, track.artistName);
        if (historyItem != null) {
          historyNotifier.removeFromHistory(DownloadHistoryItem.fromJson(historyItem).id);
        }
        await localLibraryDb.deleteByPath(localFilePath);
      }

      if (!isLoved) {
        final sanitizedArtist = _sanitizeFolderName(primaryArtistName(artistName));
        final sanitizedAlbum = _sanitizeFolderName(name);
        final sanitizedSong = _sanitizeFolderName(track.name);
        final baseDir = ref.read(settingsProvider).downloadDirectory;
        final artistDir = Directory(p.join(baseDir, sanitizedArtist));
        final albumDir = Directory(p.join(artistDir.path, sanitizedAlbum));
        final songDir = Directory(p.join(albumDir.path, sanitizedSong));

        final songCover = File(p.join(songDir.path, 'cover.jpg'));
        if (await songCover.exists()) await songCover.delete();
        if (await songDir.exists()) {
          final contents = await songDir.list().toList();
          if (contents.isEmpty) await songDir.delete(recursive: true);
        }
      }
    }

    final sanitizedArtist = _sanitizeFolderName(primaryArtistName(artistName));
    final sanitizedAlbum = _sanitizeFolderName(name);
    final baseDir = ref.read(settingsProvider).downloadDirectory;
    final artistDir = Directory(p.join(baseDir, sanitizedArtist));
    final albumDir = Directory(p.join(artistDir.path, sanitizedAlbum));

    final albumCover = File(p.join(albumDir.path, 'cover.jpg'));
    if (await albumCover.exists()) await albumCover.delete();

    final hasRemaining = await _albumHasLocalTracks(albumDir);
    if (!hasRemaining) {
      if (await albumDir.exists()) {
        final contents = await albumDir.list().toList();
        if (contents.isEmpty) await albumDir.delete(recursive: true);
        await _cleanupEmptyParentDir(albumDir, artistDir);
      }
    }
  }

  Future<bool> toggleFavoritePlaylist({
    required String playlistId,
    required String? providerId,
    required String name,
    String? imageUrl,
    int? trackCount,
    List<CollectionTrackEntry>? tracks,
  }) async {
    await _ensureLoaded();
    final key =
        playlistCollectionKey(playlistId: playlistId, providerId: providerId);
    if (state.containsFavoritePlaylistKey(key)) {
      await _db.deleteFavoritePlaylistEntry(key);
      final updated = state.favoritePlaylists
          .where((entry) => entry.key != key)
          .toList(growable: false);
      state = state.copyWith(favoritePlaylists: updated);
      await _cleanupFoldersOnUnlikePlaylist(name);
      return false;
    }

    final entry = CollectionPlaylistEntry(
      key: key,
      playlistId: _stripCollectionResourcePrefix(playlistId),
      providerId: providerId,
      name: name,
      imageUrl: imageUrl,
      addedAt: DateTime.now(),
      tracks: tracks,
    );
    await _db.upsertFavoritePlaylistEntry(
      playlistKey: key,
      playlistJson: jsonEncode(entry.toJson()),
      addedAt: entry.addedAt.toIso8601String(),
    );
    state = state.copyWith(
      favoritePlaylists: [entry, ...state.favoritePlaylists],
    );
    return true;
  }

  Future<bool> toggleFavoritePlaylistByKey({
    required String key,
    required String playlistId,
    required String? providerId,
    required String name,
    String? imageUrl,
    int? trackCount,
    List<CollectionTrackEntry>? tracks,
  }) async {
    await _ensureLoaded();
    if (state.containsFavoritePlaylistKey(key)) {
      await _db.deleteFavoritePlaylistEntry(key);
      final updated = state.favoritePlaylists
          .where((entry) => entry.key != key)
          .toList(growable: false);
      state = state.copyWith(favoritePlaylists: updated);
      return false;
    }
    return await toggleFavoritePlaylist(
      playlistId: playlistId,
      providerId: providerId,
      name: name,
      imageUrl: imageUrl,
      trackCount: trackCount,
      tracks: tracks,
    );
  }

  Future<void> removeFavoritePlaylist(String playlistKey) async {
    await _ensureLoaded();
    if (!state.containsFavoritePlaylistKey(playlistKey)) return;
    await _db.deleteFavoritePlaylistEntry(playlistKey);
    final updated = state.favoritePlaylists
        .where((entry) => entry.key != playlistKey)
        .toList(growable: false);
    state = state.copyWith(favoritePlaylists: updated);
  }

  Future<void> _cleanupFoldersOnUnlikePlaylist(String playlistName) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final coversDir = Directory(p.join(appDir.path, 'playlist_covers'));
      if (!await coversDir.exists()) return;

      final files = await coversDir.list().toList();
      for (final file in files) {
        if (file is File) {
          final name = p.basenameWithoutExtension(file.path);
          if (name == playlistName || name.contains(playlistName)) {
            await file.delete();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> downloadPlaylist({
    required String playlistId,
    required String? providerId,
    required String name,
    required List<Track> tracks,
    String? quality,
  }) async {
    final queueNotifier = ref.read(downloadQueueProvider.notifier);

    for (final track in tracks) {
      final isrc = track.isrc?.trim();
      final byIsrc = isrc != null && isrc.isNotEmpty
          ? await HistoryDatabase.instance.getByIsrc(isrc)
          : null;
      final byTrack = byIsrc == null
          ? await HistoryDatabase.instance.findByTrackAndArtist(track.name, track.artistName)
          : null;
      final byId = track.id.isNotEmpty
          ? await HistoryDatabase.instance.getBySpotifyId(track.id)
          : null;

      final exists = byIsrc != null || byTrack != null || byId != null;
      if (!exists) {
        queueNotifier.addToQueue(track, track.source ?? 'deezer', qualityOverride: quality);
      }
    }
  }

  Future<UserPlaylistCollection> createPlaylist(String name, {List<Track>? tracks}) async {
    await _ensureLoaded();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    
    final trackEntries = tracks?.map((track) {
      final key = trackCollectionKey(track);
      return CollectionTrackEntry(key: key, track: track, addedAt: now);
    }).toList() ?? [];

    final playlist = UserPlaylistCollection(
      id: id,
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
      tracks: trackEntries,
    );
    await _db.upsertPlaylist(
      id: id,
      name: playlist.name,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );
    
    // Insert initial tracks if any
    for (final entry in trackEntries) {
      await _db.upsertPlaylistTrack(
        playlistId: id,
        trackKey: entry.key,
        trackJson: jsonEncode(entry.track.toJson()),
        addedAt: entry.addedAt.toIso8601String(),
        playlistUpdatedAt: now.toIso8601String(),
      );
    }
    
    state = state.copyWith(playlists: [playlist, ...state.playlists]);
    _invalidatePlaylistPickerSummaries();
    return playlist;
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    await _ensureLoaded();
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final playlist = state.playlistById(playlistId);
    if (playlist == null || playlist.name == trimmed) return;
    final now = DateTime.now();
    await _db.renamePlaylist(
      playlistId: playlistId,
      name: trimmed,
    );
    _replacePlaylistById(
      playlistId,
      (playlist) => playlist.copyWith(name: trimmed, updatedAt: now),
    );
    _invalidatePlaylistPickerSummaries();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _ensureLoaded();
    final playlistIndex =
        state.playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex < 0) return;
    await _db.deletePlaylist(playlistId);
    final updatedPlaylists = [...state.playlists]..removeAt(playlistIndex);
    state = state.copyWith(playlists: updatedPlaylists);
    _invalidatePlaylistPickerSummaries();
  }

  Future<bool> addTrackToPlaylist(String playlistId, Track track) async {
    await _ensureLoaded();
    final playlist = state.playlistById(playlistId);
    if (playlist == null) return false;
    final key = trackCollectionKey(track);
    if (playlist.containsTrackKey(key)) return false;
    final now = DateTime.now();
    final entry = CollectionTrackEntry(key: key, track: track, addedAt: now);
    await _db.upsertPlaylistTrack(
      playlistId: playlistId,
      trackKey: key,
      trackJson: jsonEncode(track.toJson()),
      addedAt: entry.addedAt.toIso8601String(),
      playlistUpdatedAt: now.toIso8601String(),
    );
    _replacePlaylistById(playlistId, (playlist) {
      if (playlist.containsTrackKey(key)) return playlist;
      return playlist.copyWith(
        tracks: [entry, ...playlist.tracks],
        updatedAt: now,
      );
    });
    _invalidatePlaylistPickerSummaries();
    return true;
  }

  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackKey,
  ) async {
    await _ensureLoaded();
    final playlist = state.playlistById(playlistId);
    if (playlist == null || !playlist.containsTrackKey(trackKey)) return;
    final now = DateTime.now();
    await _db.deletePlaylistTrack(
      playlistId: playlistId,
      trackKey: trackKey,
      playlistUpdatedAt: now.toIso8601String(),
    );
    _replacePlaylistById(playlistId, (playlist) {
      final nextTracks = playlist.tracks
          .where((entry) => entry.key != trackKey)
          .toList(growable: false);
      if (nextTracks.length == playlist.tracks.length) return playlist;
      return playlist.copyWith(tracks: nextTracks, updatedAt: now);
    });
    _invalidatePlaylistPickerSummaries();
  }

  Future<Directory> _playlistCoversDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'playlist_covers'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> setPlaylistCover(
    String playlistId,
    String sourceFilePath,
  ) async {
    await _ensureLoaded();
    final playlist = state.playlistById(playlistId);
    if (playlist == null) return;
    final coversDir = await _playlistCoversDir();
    final ext = p.extension(sourceFilePath).toLowerCase();
    final destPath = p.join(coversDir.path, '$playlistId$ext');
    if (playlist.coverImagePath == destPath) return;
    await File(sourceFilePath).copy(destPath);
    final now = DateTime.now();
    await _db.updatePlaylistCover(
      playlistId: playlistId,
      coverImagePath: destPath,
      updatedAt: now.toIso8601String(),
    );
    _replacePlaylistById(playlistId, (playlist) {
      if (playlist.coverImagePath == destPath) return playlist;
      return playlist.copyWith(
        coverImagePath: () => destPath,
        updatedAt: now,
      );
    });
    _invalidatePlaylistPickerSummaries();
  }

  Future<void> removePlaylistCover(String playlistId) async {
    await _ensureLoaded();
    final playlist = state.playlistById(playlistId);
    if (playlist == null || playlist.coverImagePath == null) return;
    final path = playlist.coverImagePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    final now = DateTime.now();
    await _db.updatePlaylistCover(
      playlistId: playlistId,
      coverImagePath: null,
      updatedAt: now.toIso8601String(),
    );
    _replacePlaylistById(playlistId, (playlist) {
      if (playlist.coverImagePath == null) return playlist;
      return playlist.copyWith(coverImagePath: () => null, updatedAt: now);
    });
    _invalidatePlaylistPickerSummaries();
  }

  void _replacePlaylistById(
    String playlistId,
    UserPlaylistCollection Function(UserPlaylistCollection) updater,
  ) {
    final index = state.playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return;
    final updated = [...state.playlists];
    updated[index] = updater(updated[index]);
    state = state.copyWith(playlists: updated);
  }

  void _invalidatePlaylistPickerSummaries() {
    ref.invalidate(libraryPlaylistPickerSummariesProvider);
  }

  Future<PlaylistAddBatchResult> addTracksToPlaylist(
    String playlistId,
    Iterable<Track> tracks,
  ) async {
    await _ensureLoaded();
    final playlist = state.playlistById(playlistId);
    if (playlist == null) {
      return const PlaylistAddBatchResult(
        addedCount: 0,
        alreadyInPlaylistCount: 0,
      );
    }

    final now = DateTime.now();
    final knownKeys = <String>{...playlist._trackKeys};
    final entriesToAdd = <CollectionTrackEntry>[];
    var alreadyInPlaylistCount = 0;

    for (final track in tracks) {
      final key = trackCollectionKey(track);
      if (!knownKeys.add(key)) {
        alreadyInPlaylistCount++;
        continue;
      }
      entriesToAdd.add(
        CollectionTrackEntry(key: key, track: track, addedAt: now),
      );
    }

    if (entriesToAdd.isEmpty) {
      return PlaylistAddBatchResult(
        addedCount: 0,
        alreadyInPlaylistCount: alreadyInPlaylistCount,
      );
    }

    await _db.upsertPlaylistTracksBatch(
      playlistId: playlistId,
      playlistUpdatedAt: now.toIso8601String(),
      tracks: entriesToAdd
          .map(
            (entry) => <String, String?>{
              'track_key': entry.key,
              'track_json': jsonEncode(entry.track.toJson()),
              'added_at': entry.addedAt.toIso8601String(),
              'match_key': canonicalLoveKey(entry.track),
            },
          )
          .toList(growable: false),
    );
    _replacePlaylistById(playlistId, (current) {
      return current.copyWith(
        tracks: [...entriesToAdd.reversed, ...current.tracks],
        updatedAt: now,
      );
    });
    _invalidatePlaylistPickerSummaries();
    return PlaylistAddBatchResult(
      addedCount: entriesToAdd.length,
      alreadyInPlaylistCount: alreadyInPlaylistCount,
    );
  }
}

final libraryCollectionsProvider =
    NotifierProvider<LibraryCollectionsNotifier, LibraryCollectionsState>(
      LibraryCollectionsNotifier.new,
    );

final libraryPlaylistPickerSummariesProvider = FutureProvider.family<
    List<PlaylistPickerSummary>,
    PlaylistPickerSummaryRequest>((ref, request) async {
  final db = LibraryCollectionsDatabase.instance;
  final rows = await db.loadPlaylistPickerSummaries(request.trackKeys);
  return rows
      .map(
        (row) => PlaylistPickerSummary(
          id: row.id,
          name: row.name,
          coverImagePath: row.coverImagePath,
          previewCover: row.previewCover,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          trackCount: row.trackCount,
          containsAllRequestedTracks: row.containsAllRequestedTracks,
        ),
      )
      .toList(growable: false);
});