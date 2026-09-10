// ─────────────────────────────────────────────────────────────
// cache_favoritos.dart — Caché local de favoritos (wrapper sobre
// FavoritesDao): tracks amados, álbumes, artistas y playlists
// favoritas + actualización de carátulas locales.
// Se conecta con: base_datos (FavoritesDao) + LikeCubit/UI.
// Parte del flujo: Mi Espacio → Favoritos.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../base_datos/app_database.dart';
import '../base_datos/daos/favorites_dao.dart';

part 'cache_favoritos_artistas.dart';
part 'cache_favoritos_playlists.dart';

/// Caché local de favoritos — wrappers sobre [FavoritesDao].
class CacheFavoritos with CacheFavoritosArtistas, CacheFavoritosPlaylists {
  @override
  final FavoritesDao _dao;
  CacheFavoritos(AppDatabase db) : _dao = FavoritesDao(db);

  // ── Tracks amados ──────────────────────────────────────────

  Future<bool> esTrackAmado(String trackId) => _dao.isLoved(trackId);

  Future<String> getTracksAmados() async {
    final items = await _dao.getLovedTracks();
    final lista = items.map((e) => <String, dynamic>{
      'trackId': e.trackId, 'trackName': e.trackName,
      'artistName': e.artistName, 'albumName': e.albumName ?? '',
      'coverUrl': e.coverUrl ?? '', 'coverPath': e.coverPath ?? '',
      'isrc': e.isrc ?? '', 'durationMs': e.durationMs ?? 0,
      'provider': e.provider ?? '',
      'addedAt': e.addedAt.toIso8601String(),
      'track_id': e.trackId, 'track_name': e.trackName,
      'artist_name': e.artistName, 'album_name': e.albumName ?? '',
      'cover_url': e.coverUrl ?? '', 'duration_ms': e.durationMs ?? 0,
    }).toList();
    return jsonEncode(lista);
  }

  Future<void> alternarTrackAmado({
    required String trackId,
    required String trackName,
    required String artistName,
    String? albumName,
    String? coverUrl,
    String? coverPath,
    String? isrc,
    int? durationMs,
    bool liked = true,
    String? source,
  }) async {
    if (liked) {
      await _dao.addLovedTrack(
        trackId: trackId,
        trackName: trackName,
        artistName: artistName,
        albumName: albumName,
        coverUrl: coverUrl,
        coverPath: coverPath,
        isrc: isrc,
        durationMs: durationMs,
        source: source,
      );
    } else {
      await _dao.removeLovedTrack(trackId);
    }
  }

  // ── Álbumes favoritos ──────────────────────────────────────

  Future<String> getAlbumesFavoritos() async {
    final items = await _dao.getFavoriteAlbums();
    final lista = items.map((e) => <String, dynamic>{
      'albumId': e.albumId, 'name': e.name,
      'artistId': e.artistId, 'artistName': e.artistName,
      'coverUrl': e.coverUrl, 'coverPath': e.coverPath ?? '',
      'provider': e.provider ?? '',
      'addedAt': e.addedAt.toIso8601String(),
      'album_id': e.albumId, 'artist_name': e.artistName,
      'cover_url': e.coverUrl,
    }).toList();
    return jsonEncode(lista);
  }

  Future<void> alternarAlbumFavorito({
    required String albumId,
    required String name,
    required String artistId,
    required String artistName,
    required String coverUrl,
    String? coverPath,
    String? provider,
    bool liked = true,
  }) async {
    if (liked) {
      await _dao.addFavoriteAlbum(
        albumId: albumId,
        name: name,
        artistId: artistId,
        artistName: artistName,
        coverUrl: coverUrl,
        coverPath: coverPath,
        provider: provider,
      );
    } else {
      await _dao.removeFavoriteAlbum(albumId);
    }
  }

  // ── Artistas favoritos (ver cache_favoritos_artistas.dart) ─

  // ── Actualización de carátulas locales (tras saveCover) ────

  /// Persiste la ruta local de carátula de un álbum amado para que
  /// sobreviva al reinicio.
  Future<void> actualizarCaratulaAlbum(String albumId, String coverPath) =>
      _dao.updateFavoriteAlbumCoverPath(albumId, coverPath);

  Future<void> actualizarImagenArtista(String artistId, String imagePath) =>
      _dao.updateFavoriteArtistImagePath(artistId, imagePath);

  Future<void> actualizarCaratulaPlaylist(String playlistId, String coverPath) =>
      _dao.updateFavoritePlaylistCoverPath(playlistId, coverPath);

  Future<void> actualizarCaratulaTrack(String trackId, String coverPath) =>
      _dao.updateLovedTrackCoverPath(trackId, coverPath);

  // ── Playlists favoritas (ver cache_favoritos_playlists.dart) ─
}