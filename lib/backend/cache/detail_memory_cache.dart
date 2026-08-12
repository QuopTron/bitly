import 'dart:collection';
import '../../frontend/shared/models/detail_models.dart';

class _Entry<T> {
  final T value;
  final int expiresAt;
  _Entry(this.value, this.expiresAt);
}

class DetailMemoryCache {
  static const int _defaultTtlMs = 5 * 60 * 1000;
  static const int _maxEntries = 50;

  final _playlists = LinkedHashMap<String, _Entry<PlaylistDetail>>();
  final _albums = LinkedHashMap<String, _Entry<AlbumDetail>>();
  final _artists = LinkedHashMap<String, _Entry<ArtistDetail>>();

  void _evictIfNeeded(LinkedHashMap map) {
    while (map.length > _maxEntries) {
      final key = map.keys.first;
      map.remove(key);
    }
  }

  bool _isFresh(_Entry e) => DateTime.now().millisecondsSinceEpoch < e.expiresAt;

  // ── Playlist ──

  PlaylistDetail? getPlaylist(String id) {
    final e = _playlists[id];
    if (e == null) return null;
    if (!_isFresh(e)) { _playlists.remove(id); return null; }
    return e.value;
  }

  void setPlaylist(String id, PlaylistDetail detail, {int? ttlMs}) {
    _playlists[id] = _Entry(detail, DateTime.now().millisecondsSinceEpoch + (ttlMs ?? _defaultTtlMs));
    _evictIfNeeded(_playlists);
  }

  void invalidatePlaylist(String id) => _playlists.remove(id);

  // ── Album ──

  AlbumDetail? getAlbum(String id) {
    final e = _albums[id];
    if (e == null) return null;
    if (!_isFresh(e)) { _albums.remove(id); return null; }
    return e.value;
  }

  void setAlbum(String id, AlbumDetail detail, {int? ttlMs}) {
    _albums[id] = _Entry(detail, DateTime.now().millisecondsSinceEpoch + (ttlMs ?? _defaultTtlMs));
    _evictIfNeeded(_albums);
  }

  void invalidateAlbum(String id) => _albums.remove(id);

  // ── Artist ──

  ArtistDetail? getArtist(String id) {
    final e = _artists[id];
    if (e == null) return null;
    if (!_isFresh(e)) { _artists.remove(id); return null; }
    return e.value;
  }

  void setArtist(String id, ArtistDetail detail, {int? ttlMs}) {
    _artists[id] = _Entry(detail, DateTime.now().millisecondsSinceEpoch + (ttlMs ?? _defaultTtlMs));
    _evictIfNeeded(_artists);
  }

  void invalidateArtist(String id) => _artists.remove(id);

  void invalidateAll() {
    _playlists.clear();
    _albums.clear();
    _artists.clear();
  }
}
