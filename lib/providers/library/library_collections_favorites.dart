part of 'package:bitly/providers/library/library_collections_provider.dart';

// ignore: library_private_types_in_public_api
mixin CollectionsFavoritesMixin on _LibraryCollectionsNotifierBase {
  Future<bool> toggleFavoriteArtist({required String artistId, required String? providerId, required String name, String? imageUrl}) async {
    await _ensureLoaded();
    final key = artistCollectionKey(artistId: artistId, providerId: providerId);
    final trimmedPid = providerId?.trim();
    final sourceSep = key.indexOf(':');
    final source = sourceSep > 0 ? key.substring(0, sourceSep) : '';
    final effectivePid = trimmedPid != null && trimmedPid.isNotEmpty ? trimmedPid : (source.isNotEmpty && source != 'builtin' ? source : null);
    final normName = normalizeForMatch(name);
    final sameName = state.favoriteArtists.where((e) => normalizeForMatch(e.name) == normName).toList();
    if (sameName.any((e) => e.key == key)) {
      await _db.deleteFavoriteArtistEntry(key);
      state = state.copyWith(favoriteArtists: state.favoriteArtists.where((e) => e.key != key).toList(growable: false));
      if (sameName.length <= 1) await _cleanupFoldersOnUnlikeArtist(name);
      return false;
    }
    if (sameName.isNotEmpty) {
      final existing = sameName.first;
      final merged = existing.mergeCover(imageUrl);
      state = state.copyWith(favoriteArtists: state.favoriteArtists.map((e) => e.key == existing.key ? merged : e).toList(growable: false));
      final savedCover = await _saveArtistCoverLocally(name, imageUrl);
      await _db.upsertFavoriteArtistEntry(artistKey: existing.key, artistJson: jsonEncode(merged.toJson()), addedAt: merged.addedAt.toIso8601String(), coverPath: savedCover ?? merged.coverPath);
      return true;
    }
    final savedCover = await _saveArtistCoverLocally(name, imageUrl);
    final entry = CollectionArtistEntry(key: key, artistId: stripCollectionResourcePrefix(artistId), providerId: effectivePid, name: name, imageUrl: imageUrl, coverPath: savedCover, addedAt: DateTime.now());
    await _db.upsertFavoriteArtistEntry(artistKey: key, artistJson: jsonEncode(entry.toJson()), addedAt: entry.addedAt.toIso8601String(), coverPath: savedCover);
    state = state.copyWith(favoriteArtists: [entry, ...state.favoriteArtists]);
    return true;
  }

  Future<bool> toggleFavoriteAlbum({required String albumId, required String? providerId, required String name, String? artistName, String? coverUrl, String? imageUrl, int? totalTracks}) async {
    await _ensureLoaded();
    final normName = normalizeForMatch(name);
    final existing = state.favoriteAlbums.where((e) => normalizeForMatch(e.name) == normName).toList();
    if (existing.isNotEmpty) {
      final keys = existing.map((e) => e.key).toSet();
      for (final k in keys) { await _db.deleteFavoriteAlbumEntry(k); }
      state = state.copyWith(favoriteAlbums: state.favoriteAlbums.where((e) => !keys.contains(e.key)).toList(growable: false));
      await _cleanupFoldersOnUnlikeAlbum(name, artistName ?? 'Unknown');
      return false;
    }
    final key = albumCollectionKey(albumId: albumId, providerId: providerId);
    String? savedCover;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      try {
        final settings = ref.read(settingsProvider);
        final baseDir = settings.storageMode == 'saf' && settings.downloadTreeUri.isNotEmpty ? settings.downloadTreeUri : settings.downloadDirectory;
        final ad = Directory(p.join(baseDir, sanitizeFolderName(artistName ?? 'Unknown')));
        if (!await ad.exists()) await ad.create(recursive: true);
        final ald = Directory(p.join(ad.path, sanitizeFolderName(name)));
        if (!await ald.exists()) await ald.create(recursive: true);
        final cp = p.join(ald.path, 'cover.jpg');
        if (!await File(cp).exists()) {
          final uri = Uri.parse(coverUrl);
          final r = await http.get(uri, headers: {'User-Agent': 'Mozilla/5.0', 'Referer': '${uri.scheme}://${uri.host}/'});
          if (r.statusCode == 200) await File(cp).writeAsBytes(r.bodyBytes);
        }
        if (await File(cp).exists()) savedCover = cp;
      } catch (_) {}
    }
    final entry = CollectionAlbumEntry(key: key, albumId: stripCollectionResourcePrefix(albumId), providerId: providerId, name: name, artistName: artistName, coverUrl: coverUrl, imageUrl: imageUrl, coverPath: savedCover, addedAt: DateTime.now(), totalTracks: totalTracks);
    await _db.upsertFavoriteAlbumEntry(albumKey: key, albumJson: jsonEncode(entry.toJson()), addedAt: entry.addedAt.toIso8601String(), coverPath: savedCover);
    state = state.copyWith(favoriteAlbums: [entry, ...state.favoriteAlbums]);
    return true;
  }

  Future<bool> toggleFavoritePlaylist({required String playlistId, required String? providerId, required String name, String? imageUrl, int? trackCount, List<CollectionTrackEntry>? tracks}) async {
    await _ensureLoaded();
    final key = playlistCollectionKey(playlistId: playlistId, providerId: providerId);
    if (state.containsFavoritePlaylistKey(key)) {
      await _db.deleteFavoritePlaylistEntry(key);
      state = state.copyWith(favoritePlaylists: state.favoritePlaylists.where((e) => e.key != key).toList(growable: false));
      await _cleanupFoldersOnUnlikePlaylist(name);
      return false;
    }
    final entry = CollectionPlaylistEntry(key: key, playlistId: stripCollectionResourcePrefix(playlistId), providerId: providerId, name: name, imageUrl: imageUrl, addedAt: DateTime.now(), tracks: tracks);
    await _db.upsertFavoritePlaylistEntry(playlistKey: key, playlistJson: jsonEncode(entry.toJson()), addedAt: entry.addedAt.toIso8601String());
    state = state.copyWith(favoritePlaylists: [entry, ...state.favoritePlaylists]);
    return true;
  }

}
