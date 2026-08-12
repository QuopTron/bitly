import 'dart:convert';

import '../../../injection.dart' as inj;
import '../backend_service.dart';
import '../../cache/detail_cache.dart';
import '../../cache/playback_cache.dart';
import '../../../frontend/shared/models/detail_models.dart';

/// Detail views — extension fetches (RPC) with local Drift sync.
mixin DetailMixin on BackendService {
  PlaybackCache? _pbCache;
  PlaybackCache get _pb => _pbCache ??= inj.sl<PlaybackCache>();
  DetailCache? _cache;
  DetailCache get _c => _cache ??= inj.sl<DetailCache>();

  // ── Extension Fetches with local Drift sync ────────────────────

  @override
  Future<String> fetchAlbumDetail(String albumId, String source) async {
    try {
      final json = await rpcCall('fetchAlbumDetail', {'album_id': albumId, 'source': source}) as String;
      if (json.isNotEmpty && json != '{}') {
        try {
          final detail = AlbumDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
          await _pb.syncAlbumDetail(detail, source: source);
          await _c.invalidateAlbum(albumId);
        } catch (_) { /* sync is best-effort */ }
      }
      return json;
    } catch (_) { return '{}'; }
  }

  @override
  Future<String> fetchPlaylistDetail(String collectionId, String source) async {
    try {
      final json = await rpcCall('fetchPlaylistDetail', {'collection_id': collectionId, 'source': source}) as String;
      if (json.isNotEmpty && json != '{}') {
        try {
          final detail = PlaylistDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
          await _pb.syncPlaylistDetail(detail, source: source);
          await _c.invalidatePlaylist(collectionId);
        } catch (_) { /* sync is best-effort */ }
      }
      return json;
    } catch (_) { return '{}'; }
  }

  @override
  Future<String> fetchArtistDetail(String artistId, String source) async {
    try {
      final json = await rpcCall('fetchArtistDetail', {'artist_id': artistId, 'source': source}) as String;
      // Sync extension data to local Drift for future offline/local use
      if (json.isNotEmpty && json != '{}') {
        try {
          final detail = ArtistDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
          await _pb.syncArtistDetail(detail, source: source);
          // Invalidate DetailCache so next getArtistDetail picks up fresh local data
          await _c.invalidateArtist(artistId);
        } catch (_) { /* sync is best-effort */ }
      }
      return json;
    } catch (_) { return '{}'; }
  }
}


