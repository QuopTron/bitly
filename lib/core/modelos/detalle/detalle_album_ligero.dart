// ─────────────────────────────────────────────────────────────
// detalle_album_ligero.dart — Modelo ligero de álbum (sin tracks)
// usado en las listas de "top álbumes" del detalle de artista.
// Se conecta con: backend_go (detalle de artista vía extensiones).
// Parte del flujo: detalle de artista.
// ─────────────────────────────────────────────────────────────

/// Referencia a un álbum sin expandir (solo metadatos).
class DetalleAlbumLigero {
  final String albumId;
  final String name;
  final String? coverUrl;
  final String? coverPath;
  final String? releaseDate;
  final int totalTracks;
  final int playCount;

  const DetalleAlbumLigero({
    required this.albumId,
    required this.name,
    this.coverUrl,
    this.coverPath,
    this.releaseDate,
    this.totalTracks = 0,
    this.playCount = 0,
  });

  factory DetalleAlbumLigero.desdeJson(Map<String, dynamic> json) => DetalleAlbumLigero(
    albumId: json['albumId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    coverUrl: json['coverUrl'] as String?,
    coverPath: json['coverPath'] as String?,
    releaseDate: json['releaseDate'] as String?,
    totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
    playCount: (json['playCount'] as num?)?.toInt() ?? 0,
  );
}