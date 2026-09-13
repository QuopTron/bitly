// ─────────────────────────────────────────────────────────────
// detalle_playlist.dart — Modelo del detalle de una playlist
// (lista de reproducción) con sus tracks, vía extensión/Go.
// Se conecta con: backend_go (RPC fetchPlaylistDetail).
// Parte del flujo: detalle de playlist.
// ─────────────────────────────────────────────────────────────

import 'detalle_track.dart';

/// Detalle completo de una playlist.
class DetallePlaylist {
  final String id;
  final String name;
  final String? coverPath;
  final String? createdAt;
  final String? updatedAt;
  final int itemCount;
  final List<TrackDetalle> tracks;

  const DetallePlaylist({
    required this.id,
    required this.name,
    this.coverPath,
    this.createdAt,
    this.updatedAt,
    this.itemCount = 0,
    this.tracks = const [],
  });

  factory DetallePlaylist.desdeJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List<dynamic>?) ?? [];
    return DetallePlaylist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      coverPath: json['coverPath'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      tracks: rawTracks.map((e) => TrackDetalle.desdeJson(e as Map<String, dynamic>)).toList(),
    );
  }
}