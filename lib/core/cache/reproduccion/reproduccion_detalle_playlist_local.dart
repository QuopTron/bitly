// ─────────────────────────────────────────────────────────────
// reproduccion_detalle_playlist_local.dart — PART de
// reproduccion_detalle_local.dart: arma el DetallePlaylist desde
// las tablas drift LOCALES (offline / respaldo sin red).
// Se conecta con: CollectionsDao + ContentDao + modelos de detalle.
// Parte del flujo: detalle de playlist (local/offline).
// ─────────────────────────────────────────────────────────────

part of 'reproduccion_detalle_local.dart';

/// Mixin con el detalle de playlist local, aplicado en ReproduccionDetalleLocal.
/// Accede a los DAOs vía getters abstractos que provee la clase base.
mixin ReproduccionDetallePlaylistLocal {
  /// DAO de colecciones (lo provee la clase base ReproduccionDetalleLocal).
  CollectionsDao get _colecciones;

  /// DAO de contenido (lo provee la clase base ReproduccionDetalleLocal).
  ContentDao get _contenido;

  /// Arma un DetallePlaylist desde drift local, o null si no existe.
  Future<DetallePlaylist?> getDetallePlaylistLocal(String collectionId) async {
    final coleccion = await _colecciones.get(collectionId);
  if (coleccion == null) return null;

  final items = await _colecciones.getTracks(collectionId);
  final tracks = <TrackDetalle>[];
  for (final item in items) {
    final trackId = item.trackId ?? item.itemId;
    final track = await _contenido.getTrack(trackId);
    if (track != null) {
      tracks.add(TrackDetalle(
        trackId: track.id,
        name: track.name,
        durationMs: track.durationMs ?? 0,
        trackNumber: track.trackNumber ?? 0,
        isrc: track.isrc ?? '',
        coverUrl: track.coverUrl,
        coverPath: track.coverPath,
        provider: track.source,
      ));
    }
  }

  // Respaldar con la carátula del primer track para que una playlist recién
  // creada sin coverPath persistido aún muestre arte en el header.
  var coverPath = coleccion.coverPath;
  if ((coverPath == null || coverPath.isEmpty) && tracks.isNotEmpty) {
    coverPath = (tracks.first.coverPath?.isNotEmpty ?? false)
        ? tracks.first.coverPath
        : tracks.first.coverUrl;
  }

    return DetallePlaylist(
      id: coleccion.id,
      name: coleccion.name,
      coverPath: coverPath,
      createdAt: coleccion.createdAt.toIso8601String(),
      updatedAt: coleccion.updatedAt.toIso8601String(),
      itemCount: tracks.length,
      tracks: tracks,
    );
  }
}