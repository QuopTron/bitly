part of 'package:bitly/providers/library/library_collections_provider.dart';

// ignore: library_private_types_in_public_api
mixin CollectionsCrudMixin on _LibraryCollectionsNotifierBase {
  Future<UserPlaylistCollection> createPlaylist(String name, {List<Track>? tracks}) async {
    await _ensureLoaded();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final entries = tracks?.map((t) => CollectionTrackEntry(key: trackCollectionKey(t), track: t, addedAt: now)).toList() ?? [];
    final pl = UserPlaylistCollection(id: id, name: name.trim(), createdAt: now, updatedAt: now, tracks: entries);
    await _db.upsertPlaylist(id: id, name: pl.name, createdAt: now.toIso8601String(), updatedAt: now.toIso8601String());
    for (final e in entries) {
      await _db.upsertPlaylistTrack(playlistId: id, trackKey: e.key, trackJson: jsonEncode(e.track.toJson()), addedAt: e.addedAt.toIso8601String(), playlistUpdatedAt: now.toIso8601String());
    }
    state = state.copyWith(playlists: [pl, ...state.playlists]);
    _invalidatePlaylistPickerSummaries();
    return pl;
  }

  Future<void> renamePlaylist(String plId, String newName) async {
    await _ensureLoaded();
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final pl = state.playlistById(plId);
    if (pl == null || pl.name == trimmed) return;
    final now = DateTime.now();
    await _db.renamePlaylist(playlistId: plId, name: trimmed);
    _replacePlaylistById(plId, (p) => p.copyWith(name: trimmed, updatedAt: now));
    _invalidatePlaylistPickerSummaries();
  }

  Future<void> deletePlaylist(String plId) async {
    await _ensureLoaded();
    final idx = state.playlists.indexWhere((p) => p.id == plId);
    if (idx < 0) return;
    await _db.deletePlaylist(plId);
    final updated = [...state.playlists]..removeAt(idx);
    state = state.copyWith(playlists: updated);
    _invalidatePlaylistPickerSummaries();
  }

  Future<bool> addTrackToPlaylist(String plId, Track track) async {
    await _ensureLoaded();
    final pl = state.playlistById(plId);
    if (pl == null) return false;
    final key = trackCollectionKey(track);
    if (pl.containsTrackKey(key)) return false;
    final now = DateTime.now();
    final entry = CollectionTrackEntry(key: key, track: track, addedAt: now);
    await _db.upsertPlaylistTrack(playlistId: plId, trackKey: key, trackJson: jsonEncode(track.toJson()), addedAt: entry.addedAt.toIso8601String(), playlistUpdatedAt: now.toIso8601String());
    _replacePlaylistById(plId, (p) => p.containsTrackKey(key) ? p : p.copyWith(tracks: [entry, ...p.tracks], updatedAt: now));
    _invalidatePlaylistPickerSummaries();
    return true;
  }

  Future<void> removeTrackFromPlaylist(String plId, String trackKey) async {
    await _ensureLoaded();
    final pl = state.playlistById(plId);
    if (pl == null || !pl.containsTrackKey(trackKey)) return;
    final now = DateTime.now();
    await _db.deletePlaylistTrack(playlistId: plId, trackKey: trackKey, playlistUpdatedAt: now.toIso8601String());
    _replacePlaylistById(plId, (p) {
      final nt = p.tracks.where((e) => e.key != trackKey).toList(growable: false);
      return nt.length == p.tracks.length ? p : p.copyWith(tracks: nt, updatedAt: now);
    });
    _invalidatePlaylistPickerSummaries();
  }

  Future<PlaylistAddBatchResult> addTracksToPlaylist(String plId, Iterable<Track> tracks) async {
    await _ensureLoaded();
    final pl = state.playlistById(plId);
    if (pl == null) return const PlaylistAddBatchResult(addedCount: 0, alreadyInPlaylistCount: 0);
    final now = DateTime.now();
    final knownKeys = <String>{...pl.trackKeys};
    final toAdd = <CollectionTrackEntry>[];
    var already = 0;
    for (final track in tracks) {
      final key = trackCollectionKey(track);
      if (!knownKeys.add(key)) { already++; continue; }
      toAdd.add(CollectionTrackEntry(key: key, track: track, addedAt: now));
    }
    if (toAdd.isEmpty) return PlaylistAddBatchResult(addedCount: 0, alreadyInPlaylistCount: already);
    await _db.upsertPlaylistTracksBatch(playlistId: plId, playlistUpdatedAt: now.toIso8601String(), tracks: toAdd.map((e) => <String, String?>{'track_key': e.key, 'track_json': jsonEncode(e.track.toJson()), 'added_at': e.addedAt.toIso8601String(), 'match_key': canonicalLoveKey(e.track)}).toList(growable: false));
    _replacePlaylistById(plId, (c) => c.copyWith(tracks: [...toAdd.reversed, ...c.tracks], updatedAt: now));
    _invalidatePlaylistPickerSummaries();
    return PlaylistAddBatchResult(addedCount: toAdd.length, alreadyInPlaylistCount: already);
  }

  Future<void> setPlaylistCover(String plId, String srcPath) async {
    await _ensureLoaded();
    final pl = state.playlistById(plId);
    if (pl == null) return;
    final coversDir = await _playlistCoversDir();
    final ext = p.extension(srcPath).toLowerCase();
    final dest = p.join(coversDir.path, '$plId$ext');
    if (pl.coverImagePath == dest) return;
    await File(srcPath).copy(dest);
    final now = DateTime.now();
    await _db.updatePlaylistCover(playlistId: plId, coverImagePath: dest, updatedAt: now.toIso8601String());
    _replacePlaylistById(plId, (pl) => pl.coverImagePath == dest ? pl : pl.copyWith(coverImagePath: () => dest, updatedAt: now));
    _invalidatePlaylistPickerSummaries();
  }

  Future<void> removePlaylistCover(String plId) async {
    await _ensureLoaded();
    final pl = state.playlistById(plId);
    if (pl == null || pl.coverImagePath == null) return;
    final path = pl.coverImagePath;
    if (path != null) { final f = File(path); if (await f.exists()) await f.delete(); }
    final now = DateTime.now();
    await _db.updatePlaylistCover(playlistId: plId, coverImagePath: null, updatedAt: now.toIso8601String());
    _replacePlaylistById(plId, (pl) => pl.coverImagePath == null ? pl : pl.copyWith(coverImagePath: () => null, updatedAt: now));
    _invalidatePlaylistPickerSummaries();
  }

  Future<Directory> _playlistCoversDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'playlist_covers'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
