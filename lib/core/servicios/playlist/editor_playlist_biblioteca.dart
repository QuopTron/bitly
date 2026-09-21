// ─────────────────────────────────────────────────────────────
// editor_playlist_biblioteca.dart — PART de editor_playlist.dart:
// deja cada canción de la playlist en la biblioteca local
// (drift): asegura su artista y su fila en `tracks`, sin pisar lo
// que ya estaba bajado (carátula, letra, video).
// Se conecta con: editor_playlist.dart (misma library) + ContentDao.
// Parte del flujo: Mi Espacio → playlists (crear/editar).
// ─────────────────────────────────────────────────────────────

part of 'editor_playlist.dart';

/// Sincronización de items hacia la biblioteca local.
mixin ServicioEditorPlaylistBiblioteca {
  /// DAO de contenido (lo provee la clase base).
  ContentDao get _contenido;

  /// Deja [item] en la biblioteca local para que el detalle de la playlist
  /// pueda mostrar su nombre, su artista y su carátula.
  ///
  /// Si la canción ya existía solo se rellenan los huecos: la carátula, la
  /// letra y el video ya descargados no se pisan.
  Future<void> sincronizarItemEnBiblioteca(ItemFeed item) async {
    if (item.id.isEmpty) return;
    final actual = await _contenido.getTrack(item.id);
    final url = _urlDeCaratula(item);
    final ruta = _rutaLocalDeCaratula(item);

    if (actual == null) {
      final artistaId = await _asegurarArtista(item);
      await _contenido.upsertTrack(
        TracksCompanion(
          id: Value(item.id),
          name: Value(item.name),
          artistId: Value(artistaId),
          albumId: Value(item.albumId ?? ''),
          isrc: Value(item.isrc ?? ''),
          durationMs: Value(item.durationMs ?? 0),
          coverUrl: Value(url),
          coverPath: Value(ruta),
          source: Value(item.source ?? ''),
          createdAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    await _contenido.upsertTrack(
      TracksCompanion(
        id: Value(actual.id),
        name: Value(actual.name.isEmpty ? item.name : actual.name),
        artistId: Value(actual.artistId),
        albumId: Value(
          actual.albumId.isNotEmpty ? actual.albumId : (item.albumId ?? ''),
        ),
        isrc: Value(actual.isrc ?? item.isrc ?? ''),
        durationMs: Value(actual.durationMs ?? item.durationMs ?? 0),
        coverUrl: Value(actual.coverUrl ?? url),
        coverPath: Value(actual.coverPath ?? ruta),
        source: Value(actual.source ?? item.source ?? ''),
        createdAt: Value(actual.createdAt),
      ),
    );
  }

  /// Crea (o refresca) el artista del item y devuelve su id. El id se deriva
  /// del nombre para que dos canciones del mismo artista compartan fila.
  Future<String> _asegurarArtista(ItemFeed item) async {
    final artista =
        (item.artists?.trim().isNotEmpty ?? false)
            ? item.artists!.trim()
            : item.name;
    final id = idArtistaLocal(artista);
    await _contenido.upsertArtist(
      ArtistsCompanion(
        id: Value(id),
        name: Value(artista),
        normalizedName: Value(artista.toLowerCase()),
        provider: Value(item.source ?? ''),
        createdAt: Value(DateTime.now()),
      ),
    );
    return id;
  }
}

/// Id estable y legible de un artista local a partir de su nombre.
String idArtistaLocal(String nombre) {
  final limpio = nombre
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final recortado = limpio.length > 60 ? limpio.substring(0, 60) : limpio;
  return 'art_${recortado.isEmpty ? 'desconocido' : recortado}';
}

/// Carátula remota del item (vacía si la que trae es un archivo local).
String _urlDeCaratula(ItemFeed item) {
  final cover = item.coverUrl?.trim() ?? '';
  if (cover.isEmpty) return '';
  return esRutaDeArchivo(cover) ? '' : cover;
}

/// Carátula local del item (vacía si la que trae es una URL).
String _rutaLocalDeCaratula(ItemFeed item) {
  final cover = item.coverUrl?.trim() ?? '';
  if (cover.isEmpty) return '';
  return esRutaDeArchivo(cover) ? cover : '';
}
