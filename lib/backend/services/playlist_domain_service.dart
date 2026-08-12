import 'dart:convert';
import '../../injection.dart' as inj;
import '../rpc/backend_service.dart';
import '../../frontend/shared/models/detail_models.dart';
import '../../frontend/shared/models/playlist_domain.dart';
import '../../frontend/shared/detail/load_utils.dart';
import '../cache/collection_cache.dart';
import '../cache/detail_cache.dart';
import '../cache/favorite_cache.dart';

/// Provides domain-level playlist operations on the Flutter side.
class PlaylistDomainService {
  final BackendService _backend;
  final CollectionCache _collections;
  final FavoriteCache _fav;

  PlaylistDomainService(this._backend)
      : _collections = inj.sl<CollectionCache>(),
        _fav = inj.sl<FavoriteCache>();

  /// Create a new playlist. Returns the created [PlaylistDomain] on success,
  /// or `null` if the backend rejected the request.
  Future<PlaylistDomain?> create(String name, {String description = ''}) async {
    final id = await _collections.createCollection(name, '');
    if (id == null || id.isEmpty) return null;
    return PlaylistDomain(
      id: id,
      name: name,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Retrieve a playlist by its collection ID.
  /// Returns `null` if not found.
  Future<PlaylistDomain?> getById(String id) async {
    final detail = await getDetail(id);
    return detail != null ? _fromDetail(detail) : null;
  }

  /// Retrieve the full [PlaylistDetail] (with tracks) by collection ID.
  /// Tries local DB first, then falls back to extension fetch if [source] is provided.
  /// Returns `null` if not found from either source.
  Future<PlaylistDetail?> getDetail(String id, {String? source}) async {
    final cache = inj.sl<DetailCache>();
    return loadDetailWithFallback(
      id: id,
      source: source ?? '',
      getLocal: (id) => cache.getPlaylistDetail(id),
      fetchRemote: (id, src) => _backend.fetchPlaylistDetail(id, src),
      fromJson: PlaylistDetail.fromJson,
    );
  }

  /// Return all playlists for the current user.
  Future<List<PlaylistDomain>> getByUser() async {
    try {
      final json = await _fav.getFavoritePlaylists();
      if (json.isEmpty || json == '[]') return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) =>
              PlaylistDomain.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Add a track to a playlist.
  Future<bool> addTrack(String playlistId, String trackId) async {
    try {
      await _collections.addCollectionTrack(playlistId, trackId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove a track from a playlist.
  Future<bool> removeTrack(String playlistId, String trackId) async {
    try {
      await _collections.removeCollectionTrack(playlistId, trackId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get all tracks in a playlist, ordered by position.
  Future<List<DetailTrack>> getTracks(String playlistId) async {
    try {
      final cache = inj.sl<DetailCache>();
      final json = await cache.getPlaylistDetail(playlistId);
      if (json == null || json.isEmpty || json == '{}') return [];
      final detail = PlaylistDetail.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
      return detail.tracks;
    } catch (_) {
      return [];
    }
  }

  /// Update playlist cover image.
  Future<bool> updateCover(String playlistId, String coverPath) async {
    try {
      await _collections.updateCollectionCover(playlistId, coverPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete a playlist and all its items.
  Future<bool> delete(String id) async {
    try {
      await _collections.deleteCollection(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Load user stats (playlist counts, level, progress).
  Future<UserStats?> getStats() async {
    try {
      final cache = inj.sl<DetailCache>();
      final json = await cache.getUserStats();
      if (json == null || json.isEmpty || json == '{}') return null;
      return UserStats.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────

  static PlaylistDomain _fromDetail(PlaylistDetail d) => PlaylistDomain(
        id: d.id,
        name: d.name,
        trackCount: d.itemCount,
        createdAt: d.createdAt != null ? DateTime.tryParse(d.createdAt!) : null,
        updatedAt: d.updatedAt != null ? DateTime.tryParse(d.updatedAt!) : null,
      );
}


