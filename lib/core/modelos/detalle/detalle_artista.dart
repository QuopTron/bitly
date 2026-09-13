// ─────────────────────────────────────────────────────────────
// detalle_artista.dart — Modelo del detalle de un artista: imagen,
// top tracks y top álbumes, tal como lo devuelve la extensión vía Go.
// Se conecta con: backend_go (RPC fetchArtistDetail).
// Parte del flujo: detalle de artista.
// ─────────────────────────────────────────────────────────────

import 'dart:convert' show jsonDecode;

import 'detalle_album_ligero.dart';
import 'detalle_track.dart';

/// Detalle completo de un artista.
class DetalleArtista {
  final String id;
  final String name;
  final String? imageUrl;
  final String? imagePath;
  final List<TrackDetalle> topTracks;
  final List<DetalleAlbumLigero> topAlbums;

  const DetalleArtista({
    required this.id,
    required this.name,
    this.imageUrl,
    this.imagePath,
    this.topTracks = const [],
    this.topAlbums = const [],
  });

  factory DetalleArtista.desdeJson(Map<String, dynamic> json) {
    final rawTracks = _parseLista(json['topTracks']);
    final rawAlbums = _parseLista(json['topAlbums']);
    return DetalleArtista(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      topTracks: rawTracks.map((e) => TrackDetalle.desdeJson(e as Map<String, dynamic>)).toList(),
      topAlbums: rawAlbums.map((e) => DetalleAlbumLigero.desdeJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// El backend a veces serializa las listas como JSON string.
  static List<dynamic> _parseLista(dynamic v) {
    if (v is String) {
      try {
        return jsonDecode(v) as List<dynamic>;
      } catch (_) {
        return [];
      }
    }
    if (v is List) return v;
    return [];
  }
}