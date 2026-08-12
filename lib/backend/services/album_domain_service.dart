import 'dart:convert';
import '../../injection.dart' as inj;
import '../rpc/backend_service.dart';
import '../../frontend/shared/models/album_domain.dart';
import '../../frontend/shared/models/detail_models.dart';
import '../../frontend/shared/detail/load_utils.dart';
import '../cache/detail_cache.dart';
import '../cache/favorite_cache.dart';

/// Provides domain-level album operations on the Flutter side.
///
/// Mirrors the API of [Go] internal/domain/album/ — wraps
/// [BackendService] RPC calls into a clean Dart interface.
///
/// Unlike the Go equivalent, this service does **not** own a database
/// connection; it delegates all persistence to the Go backend via RPC.
class AlbumDomainService {
  final BackendService _backend;
  final FavoriteCache _fav;

  AlbumDomainService(this._backend) : _fav = inj.sl<FavoriteCache>();

  /// Retrieve an album by its ID. Returns `null` if not found.
  Future<AlbumDomain?> getById(String id) async {
    try {
      final cache = inj.sl<DetailCache>();
      final json = await cache.getAlbumDetail(id);
      if (json == null || json.isEmpty || json == '{}') return null;
      final detail = AlbumDetail.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
      return _fromDetail(detail);
    } catch (_) {
      return null;
    }
  }

  /// Retrieve the full [AlbumDetail] (with tracks) by ID.
  /// Tries local DB first, then falls back to extension fetch if [source] is provided.
  /// Returns `null` if not found from either source.
  Future<AlbumDetail?> getDetail(String id, {String? source}) async {
    final cache = inj.sl<DetailCache>();
    return loadDetailWithFallback(
      id: id,
      source: source ?? '',
      getLocal: (id) => cache.getAlbumDetail(id),
      fetchRemote: (id, src) => _backend.fetchAlbumDetail(id, src),
      fromJson: AlbumDetail.fromJson,
    );
  }

  /// Get-or-create logic: attempt to load from local DB first,
  /// fall back to fetching from the extension API, then return the result.
  /// Returns `null` if the album can't be found from either source.
  Future<AlbumDomain?> getOrCreate(
    String id,
    String? source,
  ) async {
    final detail = await getDetail(id, source: source);
    return detail != null ? _fromDetail(detail) : null;
  }

  /// Get all albums by an artist — the Go backend doesn't expose a
  /// dedicated RPC for this, so we use the artist detail instead.
  /// Returns an empty list on error.
  Future<List<AlbumDomain>> getByArtist(String artistId) async {
    try {
      final cache = inj.sl<DetailCache>();
      final json = await cache.getArtistDetail(artistId);
      if (json == null || json.isEmpty || json == '{}') return [];
      final detail = ArtistDetail.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
      return detail.topAlbums
          .map((a) => AlbumDomain(
                id: a.albumId,
                title: a.name,
                coverUrl: a.coverUrl ?? a.coverPath,
                trackCount: a.totalTracks,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get all tracks belonging to an album.
  Future<List<DetailTrack>> getTracks(String albumId) async {
    try {
      final cache = inj.sl<DetailCache>();
      final json = await cache.getAlbumDetail(albumId);
      if (json == null || json.isEmpty || json == '{}') return [];
      final detail = AlbumDetail.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
      return detail.tracks;
    } catch (_) {
      return [];
    }
  }

  /// Calculate the total duration of an album in minutes.
  Future<double> getTotalDuration(String albumId) async {
    final tracks = await getTracks(albumId);
    if (tracks.isEmpty) return 0;
    final totalMs =
        tracks.fold<int>(0, (sum, t) => sum + t.durationMs);
    return totalMs / 1000 / 60;
  }

  /// Toggle the liked/favorite status of an album.
  Future<void> toggleFavorite({
    required String albumId,
    required String name,
    required String artistName,
    required String coverUrl,
    bool liked = true,
  }) async {
    try {
      await _fav.toggleFavoriteAlbum(
        albumId: albumId,
        name: name,
        artistId: '',
        artistName: artistName,
        coverUrl: coverUrl,
        liked: liked,
      );
    } catch (_) {}
  }

  // ── Internal helpers ──────────────────────────────────────────────

  static AlbumDomain _fromDetail(AlbumDetail d) => AlbumDomain(
        id: d.id,
        title: d.name,
        artistId: d.artistName,
        coverUrl: d.coverUrl ?? d.coverPath,
        trackCount: d.totalTracks,
      );
}


