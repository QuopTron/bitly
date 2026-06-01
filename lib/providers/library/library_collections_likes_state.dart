part of 'package:bitly/providers/library/library_collections_provider.dart';

mixin CollectionsLikesStateMixin on _LibraryCollectionsNotifierBase {
  Future<void> _migrateIsrcKeys() async {
    try {
      var changed = false;
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('_migrated_isrc_keys') ?? false;
      final snapshot = await _db.loadSnapshot();
      for (final row in snapshot.lovedRows) {
        final parsed = _parseTrackEntryRow(row); if (parsed == null) continue;
        final oldKey = parsed.key; if (!oldKey.startsWith('isrc:')) continue;
        if (migrated) continue;
        final track = parsed.track;
        final source = (track.source?.trim().isNotEmpty ?? false) ? normalizeSource(track.source!.trim()) : 'builtin';
        final newKey = '$source:${track.id}';
        if (newKey == oldKey || newKey == 'builtin:') continue;
        changed = true;
        if (state.containsLovedKey(newKey)) { await _db.deleteLovedEntry(oldKey); state = state.copyWith(loved: state.loved.where((e) => e.key != oldKey).toList(growable: false)); }
        else {
          await _db.deleteLovedEntry(oldKey); await _db.upsertLovedEntry(trackKey: newKey, trackJson: jsonEncode(track.toJson()), addedAt: parsed.addedAt.toIso8601String(), audioPath: parsed.audioPath, coverPath: parsed.coverPath);
          final updated = state.loved.where((e) => e.key != oldKey).toList(growable: false);
          updated.add(CollectionTrackEntry(key: newKey, track: track, addedAt: parsed.addedAt, audioPath: parsed.audioPath, coverPath: parsed.coverPath));
          state = state.copyWith(loved: updated);
        }
      }
      for (final row in snapshot.wishlistRows) {
        final parsed = _parseTrackEntryRow(row); if (parsed == null) continue;
        final oldKey = parsed.key; if (!oldKey.startsWith('isrc:')) continue;
        if (migrated) continue;
        final track = parsed.track;
        final source = (track.source?.trim().isNotEmpty ?? false) ? normalizeSource(track.source!.trim()) : 'builtin';
        final newKey = '$source:${track.id}';
        if (newKey == oldKey || newKey == 'builtin:') continue;
        changed = true;
        if (state.containsWishlistKey(newKey)) { await _db.deleteWishlistEntry(oldKey); state = state.copyWith(wishlist: state.wishlist.where((e) => e.key != oldKey).toList(growable: false)); }
        else {
          await _db.deleteWishlistEntry(oldKey); await _db.upsertWishlistEntry(trackKey: newKey, trackJson: jsonEncode(track.toJson()), addedAt: parsed.addedAt.toIso8601String());
          final updated = state.wishlist.where((e) => e.key != oldKey).toList(growable: false);
          updated.add(CollectionTrackEntry(key: newKey, track: track, addedAt: parsed.addedAt));
          state = state.copyWith(wishlist: updated);
        }
      }
      for (final row in snapshot.playlistTrackRows) {
        final plId = row['playlist_id'] as String?; if (plId == null || plId.isEmpty) continue;
        final parsed = _parseTrackEntryRow(row); if (parsed == null) continue;
        final oldKey = parsed.key; if (!oldKey.startsWith('isrc:')) continue;
        if (migrated) continue;
        final track = parsed.track;
        final source = (track.source?.trim().isNotEmpty ?? false) ? normalizeSource(track.source!.trim()) : 'builtin';
        final newKey = '$source:${track.id}';
        if (newKey == oldKey || newKey == 'builtin:') continue;
        changed = true;
        await _db.deletePlaylistTrack(playlistId: plId, trackKey: oldKey, playlistUpdatedAt: DateTime.now().toIso8601String());
        await _db.upsertPlaylistTrack(playlistId: plId, trackKey: newKey, trackJson: jsonEncode(track.toJson()), addedAt: parsed.addedAt.toIso8601String(), playlistUpdatedAt: DateTime.now().toIso8601String());
        final pl = state.playlistById(plId);
        if (pl != null) {
          _replacePlaylistById(plId, (p) => p.copyWith(tracks: p.tracks.map((e) => e.key == oldKey ? CollectionTrackEntry(key: newKey, track: track, addedAt: e.addedAt, audioPath: e.audioPath, coverPath: e.coverPath) : e).toList(), updatedAt: DateTime.now()));
        }
      }
      if (changed) _log.i('Migrated ISRC-based keys to source:id keys');
      await prefs.setBool('_migrated_isrc_keys', true);
    } catch (e, st) { _log.e('Failed to migrate ISRC keys', e, st); }
  }

  Future<void> _migrateOldKeys() async {
    try {
      var changed = false;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('_migrated_old_keys_v1') == true) return;
      final snapshot = await _db.loadSnapshot();
      for (final row in snapshot.lovedRows) {
        final parsed = _parseTrackEntryRow(row); if (parsed == null) continue;
        final newKey = trackCollectionKey(parsed.track);
        if (parsed.key == newKey) continue;
        changed = true;
        if (state.containsLovedKey(newKey)) { await _db.deleteLovedEntry(parsed.key); state = state.copyWith(loved: state.loved.where((e) => e.key != parsed.key).toList(growable: false)); }
        else { await _db.deleteLovedEntry(parsed.key); await _db.upsertLovedEntry(trackKey: newKey, trackJson: jsonEncode(parsed.track.toJson()), addedAt: parsed.addedAt.toIso8601String(), audioPath: parsed.audioPath, coverPath: parsed.coverPath);
          final updated = state.loved.where((e) => e.key != parsed.key).toList(growable: false);
          updated.add(CollectionTrackEntry(key: newKey, track: parsed.track, addedAt: parsed.addedAt, audioPath: parsed.audioPath, coverPath: parsed.coverPath));
          state = state.copyWith(loved: updated);
        }
      }
      for (final row in snapshot.wishlistRows) {
        final parsed = _parseTrackEntryRow(row); if (parsed == null) continue;
        final newKey = trackCollectionKey(parsed.track);
        if (parsed.key == newKey) continue;
        changed = true;
        if (state.containsWishlistKey(newKey)) { await _db.deleteWishlistEntry(parsed.key); state = state.copyWith(wishlist: state.wishlist.where((e) => e.key != parsed.key).toList(growable: false)); }
        else { await _db.deleteWishlistEntry(parsed.key); await _db.upsertWishlistEntry(trackKey: newKey, trackJson: jsonEncode(parsed.track.toJson()), addedAt: parsed.addedAt.toIso8601String());
          final updated = state.wishlist.where((e) => e.key != parsed.key).toList(growable: false);
          updated.add(CollectionTrackEntry(key: newKey, track: parsed.track, addedAt: parsed.addedAt));
          state = state.copyWith(wishlist: updated);
        }
      }
      if (changed) _log.i('Migrated old-format keys');
      await prefs.setBool('_migrated_old_keys_v1', true);
    } catch (e, st) { _log.e('Failed to migrate old keys', e, st); }
  }
}
