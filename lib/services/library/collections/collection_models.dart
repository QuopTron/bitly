/// Modelos de datos para colecciones de la biblioteca local.
/// [LibraryCollectionsSnapshot] representa el estado completo de todas
/// las colecciones y [PlaylistPickerSummaryRow] resume una playlist
/// para el selector de playlists.
library;

class LibraryCollectionsSnapshot {
  final List<Map<String, dynamic>> wishlistRows;
  final List<Map<String, dynamic>> lovedRows;
  final List<Map<String, dynamic>> playlistRows;
  final List<Map<String, dynamic>> playlistTrackRows;
  final List<Map<String, dynamic>> favoriteArtistRows;
  final List<Map<String, dynamic>> favoriteAlbumRows;
  final List<Map<String, dynamic>> favoritePlaylistRows;

  const LibraryCollectionsSnapshot({
    required this.wishlistRows,
    required this.lovedRows,
    required this.playlistRows,
    required this.playlistTrackRows,
    required this.favoriteArtistRows,
    this.favoriteAlbumRows = const [],
    this.favoritePlaylistRows = const [],
  });
}

class PlaylistPickerSummaryRow {
  final String id;
  final String name;
  final String? coverImagePath;
  final String? previewCover;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int trackCount;
  final bool containsAllRequestedTracks;

  const PlaylistPickerSummaryRow({
    required this.id,
    required this.name,
    this.coverImagePath,
    this.previewCover,
    required this.createdAt,
    required this.updatedAt,
    required this.trackCount,
    required this.containsAllRequestedTracks,
  });
}
