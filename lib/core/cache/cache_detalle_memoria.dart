// ─────────────────────────────────────────────────────────────
// cache_detalle_memoria.dart — Caché en memoria (no persistente)
// de detalles de álbum/artista/playlist con TTL y límite de
// entradas, para evitar re-fetches a las extensiones.
// Se conecta con: vistas de detalle (a través de servicios).
// Parte del flujo: detalle de álbum/artista/playlist.
// ─────────────────────────────────────────────────────────────

import '../modelos/detalle_album.dart';
import '../modelos/detalle_artista.dart';
import '../modelos/detalle_playlist.dart';

class _Entrada<T> {
  final T valor;
  final int expiraEn;
  _Entrada(this.valor, this.expiraEn);
}

/// Caché en memoria de detalles (TTL 5 min, máx 50 entradas por tipo).
class CacheDetalleMemoria {
  static const int _ttlPorDefectoMs = 5 * 60 * 1000;
  static const int _maxEntradas = 50;

  final _playlists = <String, _Entrada<DetallePlaylist>>{};
  final _albums = <String, _Entrada<DetalleAlbum>>{};
  final _artists = <String, _Entrada<DetalleArtista>>{};

  void _desalojarSiNecesario(Map mapa) {
    while (mapa.length > _maxEntradas) {
      final clave = mapa.keys.first;
      mapa.remove(clave);
    }
  }

  bool _estaFresca(_Entrada e) => DateTime.now().millisecondsSinceEpoch < e.expiraEn;

  // ── Playlist ──

  DetallePlaylist? getPlaylist(String id) {
    final e = _playlists[id];
    if (e == null) return null;
    if (!_estaFresca(e)) {
      _playlists.remove(id);
      return null;
    }
    return e.valor;
  }

  void setPlaylist(String id, DetallePlaylist detalle, {int? ttlMs}) {
    _playlists[id] = _Entrada(detalle, DateTime.now().millisecondsSinceEpoch + (ttlMs ?? _ttlPorDefectoMs));
    _desalojarSiNecesario(_playlists);
  }

  void invalidarPlaylist(String id) => _playlists.remove(id);

  // ── Álbum ──

  DetalleAlbum? getAlbum(String id) {
    final e = _albums[id];
    if (e == null) return null;
    if (!_estaFresca(e)) {
      _albums.remove(id);
      return null;
    }
    return e.valor;
  }

  void setAlbum(String id, DetalleAlbum detalle, {int? ttlMs}) {
    _albums[id] = _Entrada(detalle, DateTime.now().millisecondsSinceEpoch + (ttlMs ?? _ttlPorDefectoMs));
    _desalojarSiNecesario(_albums);
  }

  void invalidarAlbum(String id) => _albums.remove(id);

  // ── Artista ──

  DetalleArtista? getArtista(String id) {
    final e = _artists[id];
    if (e == null) return null;
    if (!_estaFresca(e)) {
      _artists.remove(id);
      return null;
    }
    return e.valor;
  }

  void setArtista(String id, DetalleArtista detalle, {int? ttlMs}) {
    _artists[id] = _Entrada(detalle, DateTime.now().millisecondsSinceEpoch + (ttlMs ?? _ttlPorDefectoMs));
    _desalojarSiNecesario(_artists);
  }

  void invalidarArtista(String id) => _artists.remove(id);

  void invalidarTodo() {
    _playlists.clear();
    _albums.clear();
    _artists.clear();
  }
}