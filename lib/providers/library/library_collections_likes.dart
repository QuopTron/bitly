part of 'package:bitly/providers/library/library_collections_provider.dart';

// ignore: library_private_types_in_public_api
mixin CollectionsLikesMixin on _LibraryCollectionsNotifierBase {
  Future<bool> toggleLoved(Track track) async {
    await _ensureLoaded();
    final cKey = canonicalLoveKey(track);
    if (state.isLoved(track)) {
      for (final entry in state.loved) { if (canonicalLoveKey(entry.track) == cKey) await _db.deleteLovedEntry(entry.key); }
      state = state.copyWith(loved: state.loved.where((e) => canonicalLoveKey(e.track) != cKey).toList(growable: false));
      await _cleanupFoldersOnUnlike(track);
      return false;
    }
    var savedTrack = track;
    String? savedCoverPath, savedAudioPath;
    if (track.coverUrl != null && track.coverUrl!.isNotEmpty) {
      try {
        String? localFilePath;
        final isrc = track.isrc?.trim();
        if (isrc != null && isrc.isNotEmpty) { final by = await HistoryDatabase.instance.getByIsrc(isrc); if (by != null) localFilePath = DownloadHistoryItem.fromJson(by).filePath; }
        if (localFilePath == null) { final by = await HistoryDatabase.instance.findByTrackAndArtist(track.name, track.artistName); if (by != null) localFilePath = DownloadHistoryItem.fromJson(by).filePath; }
        if (localFilePath == null && track.id.isNotEmpty) { final by = await HistoryDatabase.instance.getBySpotifyId(track.id); if (by != null) localFilePath = DownloadHistoryItem.fromJson(by).filePath; }
        final settings = ref.read(settingsProvider);
        final baseDir = settings.storageMode == 'saf' && settings.downloadTreeUri.isNotEmpty ? settings.downloadTreeUri : settings.downloadDirectory;
        if (baseDir.isEmpty) {} else if (localFilePath == null && track.coverUrl != null) {
          final pa = primaryArtistName(track.artistName);
          final sa = sanitizeFolderName(pa); final sal = track.albumName.trim().isNotEmpty ? sanitizeFolderName(track.albumName) : null;
          final ss = sanitizeFolderName(track.name); final sco = sal ?? ss;
          final ad = Directory(p.join(baseDir, sa)); if (!await ad.exists()) await ad.create(recursive: true);
          final cd = Directory(p.join(ad.path, sco)); if (!await cd.exists()) await cd.create(recursive: true);
          final sdp = p.join(cd.path, ss); final sd = Directory(sdp); if (!await sd.exists()) await sd.create(recursive: true);
          final lp = p.join(sdp, 'cover.jpg'); final uri = Uri.parse(track.coverUrl!);
          for (int a = 0; a < 3; a++) {
            try { final r = await http.get(uri, headers: {'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.apple.com/'}); if (r.statusCode == 200) { await File(lp).writeAsBytes(r.bodyBytes); savedCoverPath = lp; break; } } catch (_) { if (a < 2) await Future.delayed(const Duration(seconds: 1)); }
          }
        } else if (localFilePath != null) {
          final pa = primaryArtistName(track.artistName); final sa = sanitizeFolderName(pa);
          final sal = track.albumName.trim().isNotEmpty ? sanitizeFolderName(track.albumName) : null;
          final ss = sanitizeFolderName(track.name); final sco = sal ?? ss;
          final ad = Directory(p.join(baseDir, sa)); if (!await ad.exists()) await ad.create(recursive: true);
          final cd = Directory(p.join(ad.path, sco)); if (!await cd.exists()) await cd.create(recursive: true);
          final sdp = p.join(cd.path, ss); final sd = Directory(sdp);
          if (!await sd.exists()) await sd.create(recursive: true);
          final lp = p.join(sdp, 'cover.jpg');
          if (!await File(lp).exists()) { try { await PlatformBridge.extractCoverToFile(localFilePath, lp); } catch (_) {} }
          if (await File(lp).exists()) { savedCoverPath = lp; savedAudioPath = localFilePath; }
        }
      } catch (e, st) { _log.e('toggleLoved: error', e, st); }
    }
    final entryKey = 'loved_$cKey';
    final entry = CollectionTrackEntry(key: entryKey, track: savedTrack, addedAt: DateTime.now(), audioPath: savedAudioPath, coverPath: savedCoverPath);
    final ei = state.loved.indexWhere((e) => e.key == entryKey);
    List<CollectionTrackEntry> updated;
    if (ei >= 0) {
      updated = List<CollectionTrackEntry>.of(state.loved);
      updated[ei] = entry;
    } else {
      updated = [entry, ...state.loved];
    }
    await _db.upsertLovedEntry(trackKey: entryKey, trackJson: jsonEncode(savedTrack.toJson()), addedAt: entry.addedAt.toIso8601String(), matchKey: cKey, audioPath: savedAudioPath, coverPath: savedCoverPath);
    state = state.copyWith(loved: updated);
    return true;
  }

  Future<void> removeFromLoved(String trackKey) async {
    await _ensureLoaded();
    if (!state.containsLovedKey(trackKey)) return;
    await _db.deleteLovedEntry(trackKey);
    state = state.copyWith(loved: state.loved.where((e) => e.key != trackKey).toList(growable: false));
  }

  Future<bool> toggleFavoriteArtistByKey({required String key, required String artistId, required String? providerId, required String name, String? imageUrl}) async {
    await _ensureLoaded();
    if (state.containsFavoriteArtistKey(key)) {
      await _db.deleteFavoriteArtistEntry(key);
      state = state.copyWith(favoriteArtists: state.favoriteArtists.where((e) => e.key != key).toList(growable: false));
      return false;
    }
    final savedCover = await _saveArtistCoverLocally(name, imageUrl);
    final entry = CollectionArtistEntry(key: key, artistId: artistId, providerId: providerId, name: name, imageUrl: imageUrl, coverPath: savedCover, addedAt: DateTime.now());
    await _db.upsertFavoriteArtistEntry(artistKey: key, artistJson: jsonEncode(entry.toJson()), addedAt: entry.addedAt.toIso8601String(), coverPath: savedCover);
    state = state.copyWith(favoriteArtists: [entry, ...state.favoriteArtists]);
    return true;
  }

  Future<bool> toggleFavoriteAlbumByKey({required String key, required String albumId, required String? providerId, required String name, String? artistName, String? coverUrl, String? imageUrl, int? totalTracks}) async {
    await _ensureLoaded();
    if (state.containsFavoriteAlbumKey(key)) {
      await _db.deleteFavoriteAlbumEntry(key);
      state = state.copyWith(favoriteAlbums: state.favoriteAlbums.where((e) => e.key != key).toList(growable: false));
      return false;
    }
    final entry = CollectionAlbumEntry(key: key, albumId: albumId, providerId: providerId, name: name, artistName: artistName, coverUrl: coverUrl, imageUrl: imageUrl, addedAt: DateTime.now(), totalTracks: totalTracks);
    await _db.upsertFavoriteAlbumEntry(albumKey: key, albumJson: jsonEncode(entry.toJson()), addedAt: entry.addedAt.toIso8601String());
    state = state.copyWith(favoriteAlbums: [entry, ...state.favoriteAlbums]);
    return true;
  }

  Future<bool> toggleFavoritePlaylistByKey({required String key, required String playlistId, required String? providerId, required String name, String? imageUrl}) async {
    await _ensureLoaded();
    if (state.containsFavoritePlaylistKey(key)) {
      await _db.deleteFavoritePlaylistEntry(key);
      state = state.copyWith(favoritePlaylists: state.favoritePlaylists.where((e) => e.key != key).toList(growable: false));
      return false;
    }
    final entry = CollectionPlaylistEntry(key: key, playlistId: playlistId, providerId: providerId, name: name, imageUrl: imageUrl, addedAt: DateTime.now());
    await _db.upsertFavoritePlaylistEntry(playlistKey: key, playlistJson: jsonEncode(entry.toJson()), addedAt: entry.addedAt.toIso8601String());
    state = state.copyWith(favoritePlaylists: [entry, ...state.favoritePlaylists]);
    return true;
  }

}
