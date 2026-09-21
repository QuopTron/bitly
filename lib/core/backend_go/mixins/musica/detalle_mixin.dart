// ─────────────────────────────────────────────────────────────
// detalle_mixin.dart — Mixin de vistas de detalle: obtiene álbum,
// playlist y artista desde las extensiones (RPC) y sincroniza a
// drift local para uso offline futuro.
// Se conecta con: backend_go (fetchAlbumDetail, fetchPlaylistDetail,
// fetchArtistDetail) + caches (PlaybackCache, DetailCache).
// Parte del flujo: detalle de álbum/playlist/artista.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../../../../app/inyeccion/inyeccion.dart' as di;
import '../../../cache/almacenes/musica/cache_detalle.dart';
import '../../../cache/reproduccion/base/reproduccion_sync.dart';
import '../../../modelos/detalle/contenido/detalle_album.dart';
import '../../../modelos/detalle/contenido/detalle_artista.dart';
import '../../../modelos/detalle/contenido/detalle_playlist.dart';
import '../../nucleo/base/contrato_backend.dart';

import 'package:flutter/foundation.dart';
/// Vistas de detalle — fetch por extensión (RPC) con sync local a drift.
mixin DetalleMixin on BackendService {
  ReproduccionSync? _pbCache;
  ReproduccionSync get _pb => _pbCache ??= di.sl<ReproduccionSync>();
  CacheDetalle? _cache;
  CacheDetalle get _c => _cache ??= di.sl<CacheDetalle>();

  // ── Fetch por extensión con sync local ──────────────────

  @override
  Future<String> fetchAlbumDetail(String albumId, String source) async {
    try {
      final json =
          await rpcCall('fetchAlbumDetail', {
                'album_id': albumId,
                'source': source,
              })
              as String;
      if (json.isNotEmpty && json != '{}') {
        try {
          final detalle = DetalleAlbum.desdeJson(
            jsonDecode(json) as Map<String, dynamic>,
          );
          await _pb.sincronizarDetalleAlbum(detalle, fuente: source);
          await _c.invalidarAlbum(albumId);
        } catch (e) {
          debugPrint('[DetalleMixin] $e');
          /* el sync es best-effort */
        }
      }
      return json;
    } catch (e) {
      debugPrint('[DetalleMixin] $e');
      return '{}';
    }
  }

  @override
  Future<String> fetchPlaylistDetail(String collectionId, String source) async {
    try {
      final json =
          await rpcCall('fetchPlaylistDetail', {
                'collection_id': collectionId,
                'source': source,
              })
              as String;
      if (json.isNotEmpty && json != '{}') {
        try {
          final detalle = DetallePlaylist.desdeJson(
            jsonDecode(json) as Map<String, dynamic>,
          );
          await _pb.sincronizarDetallePlaylist(detalle, fuente: source);
          await _c.invalidarPlaylist(collectionId);
        } catch (e) {
          debugPrint('[DetalleMixin] $e');
          /* el sync es best-effort */
        }
      }
      return json;
    } catch (e) {
      debugPrint('[DetalleMixin] $e');
      return '{}';
    }
  }

  @override
  Future<String> fetchArtistDetail(String artistId, String source) async {
    try {
      final json =
          await rpcCall('fetchArtistDetail', {
                'artist_id': artistId,
                'source': source,
              })
              as String;
      // Sincroniza los datos de la extensión a drift local para uso offline.
      if (json.isNotEmpty && json != '{}') {
        try {
          final detalle = DetalleArtista.desdeJson(
            jsonDecode(json) as Map<String, dynamic>,
          );
          await _pb.sincronizarDetalleArtista(detalle, fuente: source);
          // Invalida DetailCache para que el próximo getArtistDetail use datos frescos.
          await _c.invalidarArtista(artistId);
        } catch (e) {
          debugPrint('[DetalleMixin] $e');
          /* el sync es best-effort */
        }
      }
      return json;
    } catch (e) {
      debugPrint('[DetalleMixin] $e');
      return '{}';
    }
  }
}
