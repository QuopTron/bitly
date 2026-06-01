part of 'package:bitly/providers/library/library_collections_provider.dart';

class LibraryCollectionsNotifier extends _LibraryCollectionsNotifierBase
    with CollectionsCrudMixin, CollectionsFavoritesMixin, CollectionsLikesMixin {

  @override
  LibraryCollectionsState build() {
    _loadFuture = _load().then((_) => _runPostLoadMigrations());
    return LibraryCollectionsState();
  }

  Future<void> _runPostLoadMigrations() async {
    // TODO: Implement these in a separate migration file when needed
  }

  Future<bool> toggleWishlist(Track track) async {
    await _ensureLoaded();
    final key = trackCollectionKey(track);
    if (state.containsWishlistKey(key)) {
      await _db.deleteWishlistEntry(key);
      state = state.copyWith(wishlist: state.wishlist.where((e) => e.key != key).toList(growable: false));
      return false;
    }
    final entry = CollectionTrackEntry(key: key, track: track, addedAt: DateTime.now());
    await _db.upsertWishlistEntry(trackKey: key, trackJson: jsonEncode(track.toJson()), addedAt: entry.addedAt.toIso8601String(), matchKey: canonicalLoveKey(track));
    state = state.copyWith(wishlist: [entry, ...state.wishlist]);
    return true;
  }

  Future<void> removeFromWishlist(String trackKey) async {
    await _ensureLoaded();
    if (!state.containsWishlistKey(trackKey)) return;
    await _db.deleteWishlistEntry(trackKey);
    state = state.copyWith(wishlist: state.wishlist.where((e) => e.key != trackKey).toList(growable: false));
  }

  Future<void> updateTrackPaths({required Track track, String? audioPath, String? coverPath, String? codec, int? bitDepth, int? sampleRate}) async {
    await _ensureLoaded();
    final key = trackCollectionKey(track);
    final cKey = canonicalLoveKey(track);
    final tJson = jsonEncode(track.toJson());
    await _db.updateLovedTrackPathsByCanonicalKey(canonicalKey: cKey, trackJson: tJson, audioPath: audioPath, coverPath: coverPath, codec: codec, bitDepth: bitDepth, sampleRate: sampleRate);
    for (final m in await _db.getPlaylistTracksByCanonicalKey(cKey)) { await _db.updatePlaylistTrackPaths(playlistId: m.playlistId, trackKey: m.trackKey, trackJson: tJson, audioPath: audioPath, coverPath: coverPath, codec: codec, bitDepth: bitDepth, sampleRate: sampleRate); }
    state = state.copyWith(
      loved: state.loved.map((e) => (e.key == key || canonicalLoveKey(e.track) == cKey) ? CollectionTrackEntry(key: e.key, track: e.track, addedAt: e.addedAt, audioPath: audioPath, coverPath: coverPath ?? e.coverPath, codec: codec ?? e.codec, bitDepth: bitDepth ?? e.bitDepth, sampleRate: sampleRate ?? e.sampleRate) : e).toList(),
      wishlist: state.wishlist.map((e) => (e.key == key || canonicalLoveKey(e.track) == cKey) ? CollectionTrackEntry(key: e.key, track: e.track, addedAt: e.addedAt, audioPath: audioPath, coverPath: coverPath ?? e.coverPath, codec: codec ?? e.codec, bitDepth: bitDepth ?? e.bitDepth, sampleRate: sampleRate ?? e.sampleRate) : e).toList(),
      playlists: state.playlists.map((pl) => pl.copyWith(tracks: pl.tracks.map((e) => (e.key == key || canonicalLoveKey(e.track) == cKey) ? CollectionTrackEntry(key: e.key, track: e.track, addedAt: e.addedAt, audioPath: audioPath, coverPath: coverPath ?? e.coverPath, codec: codec ?? e.codec, bitDepth: bitDepth ?? e.bitDepth, sampleRate: sampleRate ?? e.sampleRate) : e).toList())).toList(),
    );
  }

  Future<void> cleanupFoldersOnRemoveDownload(Track track) async {
    // Future implementation when needed
  }

  Future<void> migratePathsToNewDirectory(String newDir) async {
    await _ensureLoaded();
    for (final e in state.loved) {
      if (e.audioPath != null || e.coverPath != null) {
        await updateTrackPaths(track: e.track, audioPath: e.audioPath != null ? p.join(newDir, 'audio', p.basename(e.audioPath!)) : e.audioPath!, coverPath: e.coverPath != null ? p.join(newDir, 'cover', p.basename(e.coverPath!)) : null);
      }
    }
  }
}