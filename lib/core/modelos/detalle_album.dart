// ─────────────────────────────────────────────────────────────
// detalle_album.dart — Modelo del detalle de un álbum: metadatos
// + lista de tracks, tal como lo devuelve la extensión vía Go.
// Se conecta con: backend_go (RPC fetchAlbumDetail).
// Parte del flujo: detalle de álbum.
// ─────────────────────────────────────────────────────────────

import 'detalle_track.dart';

/// Detalle completo de un álbum/EP/single.
class DetalleAlbum {
  final String id;
  final String name;
  final String? coverUrl;
  final String? coverPath;
  final String? artistName;
  final String? releaseDate;
  final String? albumType;
  final int totalTracks;
  final List<TrackDetalle> tracks;

  const DetalleAlbum({
    required this.id,
    required this.name,
    this.coverUrl,
    this.coverPath,
    this.artistName,
    this.releaseDate,
    this.albumType,
    this.totalTracks = 0,
    this.tracks = const [],
  });

  factory DetalleAlbum.desdeJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List<dynamic>?) ?? [];
    return DetalleAlbum(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      coverPath: json['coverPath'] as String?,
      artistName: json['artistName'] as String?,
      releaseDate: json['releaseDate'] as String?,
      albumType: json['albumType'] as String?,
      totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
      tracks: rawTracks.map((e) => TrackDetalle.desdeJson(e as Map<String, dynamic>)).toList(),
    );
  }
}