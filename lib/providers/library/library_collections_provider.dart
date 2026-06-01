import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/download/download_queue_provider.dart';
import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/services/history/history_database.dart';
import 'package:bitly/services/library/collections/library_collections_database.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/artist_utils.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/providers/library/library_collections_state.dart';

export 'package:bitly/providers/library/library_collections_state.dart';

part 'library_collections_crud.dart';
part 'library_collections_favorites.dart';
part 'library_collections_wishlist.dart';
part 'library_collections_likes.dart';
part 'library_collections_likes_state.dart';
part 'library_collections_cleanup.dart';

final _log = AppLogger('LibraryCollections');

abstract class _LibraryCollectionsNotifierBase extends Notifier<LibraryCollectionsState> {
  final _db = LibraryCollectionsDatabase.instance;
  Future<void>? _loadFuture;

  Future<void> _ensureLoaded() async {
    if (state.isLoaded) return;
    await (_loadFuture ?? _load());
  }

  Future<void> _load() async {
    try {
      final snapshot = await _db.loadSnapshot();
      final wishlist = <CollectionTrackEntry>[];
      for (final row in snapshot.wishlistRows) { final p = _parseTrackEntryRow(row); if (p != null) wishlist.add(p); }
      final loved = <CollectionTrackEntry>[];
      for (final row in snapshot.lovedRows) { final p = _parseTrackEntryRow(row); if (p != null) loved.add(p); }
      final favoriteArtists = <CollectionArtistEntry>[];
      for (final row in snapshot.favoriteArtistRows) { final p = _parseArtistEntryRow(row); if (p != null) favoriteArtists.add(p); }
      final favoriteAlbums = <CollectionAlbumEntry>[];
      for (final row in snapshot.favoriteAlbumRows) {
        final albumJson = (row['album_json'] ?? row['item_json']) as String?;
        if (albumJson == null || albumJson.isEmpty) continue;
        try {
          final decoded = jsonDecode(albumJson);
          if (decoded is Map) favoriteAlbums.add(CollectionAlbumEntry.fromJson({...Map<String, dynamic>.from(decoded), 'coverPath': row['cover_path'] as String?}));
        } catch (_) {}
      }
      final favoritePlaylists = <CollectionPlaylistEntry>[];
      for (final row in snapshot.favoritePlaylistRows) {
        final plJson = (row['playlist_json'] ?? row['item_json']) as String?;
        if (plJson == null || plJson.isEmpty) continue;
        try {
          final decoded = jsonDecode(plJson);
          if (decoded is Map) favoritePlaylists.add(CollectionPlaylistEntry.fromJson({...Map<String, dynamic>.from(decoded), 'coverPath': row['cover_path'] as String?}));
        } catch (_) {}
      }
      final tracksByPlaylist = <String, List<CollectionTrackEntry>>{};
      for (final row in snapshot.playlistTrackRows) {
        final plId = row['playlist_id'] as String?;
        if (plId == null || plId.isEmpty) continue;
        final parsed = _parseTrackEntryRow(row);
        if (parsed != null) tracksByPlaylist.putIfAbsent(plId, () => []).add(parsed);
      }
      final playlists = <UserPlaylistCollection>[];
      for (final row in snapshot.playlistRows) {
        final id = row['id'] as String?;
        if (id == null || id.isEmpty) continue;
        final ca = DateTime.tryParse((row['created_at'] as String?) ?? '') ?? DateTime.now();
        final ua = DateTime.tryParse((row['updated_at'] as String?) ?? '') ?? ca;
        playlists.add(UserPlaylistCollection(id: id, name: row['name'] as String? ?? '', coverImagePath: row['cover_image_path'] as String?, createdAt: ca, updatedAt: ua, tracks: tracksByPlaylist[id] ?? const []));
      }
      state = LibraryCollectionsState(wishlist: wishlist, loved: loved, playlists: playlists, favoriteArtists: favoriteArtists, favoriteAlbums: favoriteAlbums, favoritePlaylists: favoritePlaylists, isLoaded: true);
      final corruptedKeys = <String>[];
      for (final entry in loved) {
        final tid = entry.track.id;
        if (tid.contains('loved_') || tid.contains('isrc:') || (entry.track.source == null && !tid.contains(':'))) corruptedKeys.add(entry.key);
      }
      if (corruptedKeys.isNotEmpty) {
        for (final key in corruptedKeys) { await _db.deleteLovedEntry(key); }
        state = state.copyWith(loved: loved.where((e) => !corruptedKeys.contains(e.key)).toList());
      }
    } catch (e) { state = state.copyWith(isLoaded: true); }
  }

  void _replacePlaylistById(String plId, UserPlaylistCollection Function(UserPlaylistCollection) updater) {
    final index = state.playlists.indexWhere((p) => p.id == plId);
    if (index < 0) return;
    final updated = [...state.playlists];
    updated[index] = updater(updated[index]);
    state = state.copyWith(playlists: updated);
  }

  void _invalidatePlaylistPickerSummaries() => ref.invalidate(libraryPlaylistPickerSummariesProvider);

  CollectionTrackEntry? _parseTrackEntryRow(Map<String, dynamic> row) {
    final key = (row['track_key'] ?? row['item_id']) as String?;
    final trackJson = (row['track_json'] ?? row['item_json']) as String?;
    if (key == null || key.isEmpty || trackJson == null || trackJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(trackJson);
      if (decoded is! Map) return null;
      final track = Track.fromJson(Map<String, dynamic>.from(decoded));
      return CollectionTrackEntry(key: key, track: track, addedAt: DateTime.tryParse((row['added_at'] as String?) ?? '') ?? DateTime.now(), audioPath: row['audio_path'] as String?, coverPath: row['cover_path'] as String?);
    } catch (_) { return null; }
  }

  CollectionArtistEntry? _parseArtistEntryRow(Map<String, dynamic> row) {
    final key = (row['artist_key'] ?? row['item_id']) as String?;
    final artistJson = (row['artist_json'] ?? row['item_json']) as String?;
    if (key == null || key.isEmpty || artistJson == null || artistJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(artistJson);
      if (decoded is! Map) return null;
      return CollectionArtistEntry.fromJson({...Map<String, dynamic>.from(decoded), 'key': key, 'addedAt': decoded['addedAt'] ?? row['added_at'], 'coverPath': row['cover_path'] as String?});
    } catch (_) { return null; }
  }

}

final libraryCollectionsProvider = NotifierProvider<LibraryCollectionsNotifier, LibraryCollectionsState>(LibraryCollectionsNotifier.new);

final libraryPlaylistPickerSummariesProvider = FutureProvider.family<List<PlaylistPickerSummary>, PlaylistPickerSummaryRequest>((ref, request) async {
  final db = LibraryCollectionsDatabase.instance;
  final rows = await db.loadPlaylistPickerSummaries(request.trackKeys);
  return rows.map((r) => PlaylistPickerSummary(id: r.id, name: r.name, coverImagePath: r.coverImagePath, previewCover: r.previewCover, createdAt: r.createdAt, updatedAt: r.updatedAt, trackCount: r.trackCount, containsAllRequestedTracks: r.containsAllRequestedTracks)).toList(growable: false);
});
