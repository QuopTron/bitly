// ─────────────────────────────────────────────────────────────
// like_persistir.dart — PART de cubit_like.dart. Persistencia del
// like por tipo (track/álbum/artista/playlist) en favoritos (drift)
// y disparo del sync de tracks del álbum/playlist amados.
// Separado de acciones_like.dart para mantener el límite de líneas.
// Se conecta con: CacheFavoritos + sync de tracks (backend Go).
// Parte del flujo: botones de like en toda la app.
// ─────────────────────────────────────────────────────────────

part of 'cubit_like.dart';

/// Persistencia del like por tipo. Mixin combinado en CubitLikes.
mixin AccionesLikePersistencia on AccionesLike {
  @override
  Future<void> _persistirLike(ItemFeed item) async {
    switch (item.type) {
      case 'track':
        unawaited(_fav.alternarTrackAmado(
          trackId: item.id,
          trackName: item.name,
          artistName: item.artists ?? '',
          albumName: item.albumName,
          coverUrl: item.coverUrl,
          isrc: item.isrc,
          durationMs: item.durationMs,
          liked: true,
          source: item.source,
        ));
      case 'album':
        unawaited(_fav.alternarAlbumFavorito(
          albumId: item.id,
          name: item.name,
          artistId: item.artists ?? '',
          artistName: item.artists ?? '',
          coverUrl: item.coverUrl ?? '',
          liked: true,
          provider: item.source,
        ));
        // Fetch del detalle del álbum y sync de tracks + carátulas.
        unawaited(sincronizarTracksAlbum(
          item.id,
          item.source ?? '',
          item.artists ?? '',
          coverUrlPadre: item.coverUrl,
        ));
      case 'artist':
        unawaited(_fav.alternarArtistaFavorito(
          artistId: item.id,
          name: item.name,
          imageUrl: item.coverUrl ?? '',
          liked: true,
        ));
      case 'playlist':
        unawaited(_fav.alternarPlaylistFavorita(
          playlistId: item.id,
          name: item.name,
          coverUrl: item.coverUrl,
          provider: item.source,
          liked: true,
        ));
        // Fetch del detalle de playlist y sync de tracks + carátulas.
        unawaited(sincronizarTracksPlaylist(
          item.id,
          item.source ?? '',
          coverUrlPadre: item.coverUrl,
        ));
    }
  }
}