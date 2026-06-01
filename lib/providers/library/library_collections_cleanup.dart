part of 'package:bitly/providers/library/library_collections_provider.dart';

extension on _LibraryCollectionsNotifierBase {
  Future<void> _cleanupFoldersOnUnlike(Track track) async {
    try { final s = ref.read(settingsProvider); final b = s.storageMode == 'saf' && s.downloadTreeUri.isNotEmpty ? s.downloadTreeUri : s.downloadDirectory; if (b.isEmpty) return;
      String? lf; final i = track.isrc?.trim(); if (i != null && i.isNotEmpty) { final x = await HistoryDatabase.instance.getByIsrc(i); if (x != null) lf = DownloadHistoryItem.fromJson(x).filePath; } if (lf == null) { final x = await HistoryDatabase.instance.findByTrackAndArtist(track.name, track.artistName); if (x != null) lf = DownloadHistoryItem.fromJson(x).filePath; } if (lf == null && track.id.isNotEmpty) { final x = await HistoryDatabase.instance.getBySpotifyId(track.id); if (x != null) lf = DownloadHistoryItem.fromJson(x).filePath; }
      if (lf != null && await fileExists(lf)) return;
      final pa = primaryArtistName(track.artistName); final sa = sanitizeFolderName(pa); final sal = track.albumName.trim().isNotEmpty ? sanitizeFolderName(track.albumName) : null; final ss = sanitizeFolderName(track.name); final sco = sal ?? ss;
      final ad = Directory(p.join(b, sa)); final cd = Directory(p.join(ad.path, sco)); final sd = Directory(p.join(cd.path, ss));
      final sc = File(p.join(sd.path, 'cover.jpg')); if (await sc.exists()) await sc.delete();
      final dia = await cd.exists() ? (await cd.list().toList()).whereType<Directory>().toList() : <Directory>[];
      if (dia.where((d) => d.path != sd.path).isEmpty) { final ac = File(p.join(cd.path, 'cover.jpg')); if (await ac.exists()) await ac.delete(); }
      final dba = await ad.exists() ? (await ad.list().toList()).whereType<Directory>().toList() : <Directory>[];
      if (dba.where((d) => d.path != cd.path).isEmpty && !state.favoriteArtists.any((a) => a.name.toLowerCase().trim() == pa.toLowerCase().trim())) { final ac = File(p.join(ad.path, 'cover.jpg')); if (await ac.exists()) await ac.delete(); }
      if (await sd.exists()) { final ct = await sd.list().toList(); if (ct.isEmpty) await sd.delete(recursive: true); }
      await _cleanupEmptyParentDir(cd, ad);
    } catch (_) {}
  }

  Future<void> _cleanupFoldersOnUnlikeArtist(String artistName) async {
    try { final s = ref.read(settingsProvider); final b = s.storageMode == 'saf' && s.downloadTreeUri.isNotEmpty ? s.downloadTreeUri : s.downloadDirectory; if (b.isEmpty) return; final a = sanitizeFolderName(primaryArtistName(artistName)); final d = Directory(p.join(b, a)); final c = File(p.join(d.path, 'cover.jpg')); if (await c.exists()) await c.delete(); if (await d.exists()) { final l = await d.list().toList(); if (!l.any((e) => e is Directory)) await d.delete(recursive: true); } } catch (_) {}
  }

  Future<void> _cleanupFoldersOnUnlikeAlbum(String an, String artist) async {
    try { final s = ref.read(settingsProvider); final b = s.storageMode == 'saf' && s.downloadTreeUri.isNotEmpty ? s.downloadTreeUri : s.downloadDirectory; if (b.isEmpty) return; final sa = sanitizeFolderName(primaryArtistName(artist)); final san = sanitizeFolderName(an); final ad = Directory(p.join(b, sa)); final ald = Directory(p.join(ad.path, san)); final ac = File(p.join(ald.path, 'cover.jpg')); if (await ac.exists()) await ac.delete(); if (await ald.exists() && (await ald.list().toList()).isEmpty) { await ald.delete(recursive: true); await _cleanupEmptyParentDir(ald, ad); } } catch (_) {}
  }

  Future<void> _cleanupFoldersOnUnlikePlaylist(String pn) async {
    try { final ad = await getApplicationSupportDirectory(); final cd = Directory(p.join(ad.path, 'playlist_covers')); if (!await cd.exists()) return; for (final f in await cd.list().toList()) { if (f is File) { final n = p.basenameWithoutExtension(f.path); if (n == pn || n.contains(pn)) await f.delete(); } } } catch (_) {}
  }

  Future<void> _cleanupEmptyParentDir(Directory cd, Directory ad) async {
    try { if (await cd.exists()) { final c = await cd.list().toList(); if (c.isEmpty) { await cd.delete(recursive: true); if (await ad.exists()) { final a = await ad.list().toList(); if (a.isEmpty) await ad.delete(recursive: true); } } } } catch (_) {}
  }

  Future<String?> _saveArtistCoverLocally(String name, String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final settings = ref.read(settingsProvider);
      final baseDir = settings.storageMode == 'saf' && settings.downloadTreeUri.isNotEmpty ? settings.downloadTreeUri : settings.downloadDirectory;
      final ad = Directory(p.join(baseDir, sanitizeFolderName(name)));
      if (!await ad.exists()) await ad.create(recursive: true);
      var cp = p.join(ad.path, 'cover.jpg');
      if (await File(cp).exists()) { var i = 0; do { i++; cp = p.join(ad.path, 'cover_$i.jpg'); } while (await File(cp).exists()); }
      final uri = Uri.parse(imageUrl);
      final r = await http.get(uri, headers: {'User-Agent': 'Mozilla/5.0', 'Referer': '${uri.scheme}://${uri.host}/'});
      if (r.statusCode == 200) await File(cp).writeAsBytes(r.bodyBytes);
      if (await File(cp).exists()) return cp;
    } catch (_) {}
    return null;
  }
}
