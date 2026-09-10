// ─────────────────────────────────────────────────────────────
// servicio_dominio_playlist.dart — Operaciones de dominio de
// playlists del lado Flutter: crear, obtener detalle (local primero
// / extensión como respaldo), agregar/quitar tracks, carátula y
// borrado. Persistencia local en colecciones + favoritos.
// Se conecta con: backend_go + caches (colecciones/detalle/favoritos).
// Parte del flujo: Mi Espacio → Playlists.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../../app/inyeccion.dart' as di;
import '../backend_go/contrato_backend.dart';
import '../cache/cache_colecciones.dart';
import '../cache/cache_detalle.dart';
import '../cache/cache_favoritos.dart';
import '../modelos/detalle_playlist.dart';
import '../modelos/detalle_track.dart';
import '../modelos/dominio_playlist.dart';
import '../modelos/estadisticas_usuario.dart';
import 'utilidades_carga.dart';

part 'servicio_dominio_playlist_consultas.dart';

/// Servicio de dominio de playlists (envuelve caches + RPCs de Go).
class ServicioDominioPlaylist with ServicioDominioPlaylistConsultas {
  @override
  final BackendService _backend;
  final CacheColecciones _colecciones;
  @override
  final CacheFavoritos _fav;

  ServicioDominioPlaylist(this._backend)
      : _colecciones = di.sl<CacheColecciones>(),
        _fav = di.sl<CacheFavoritos>();

  /// Crea una playlist nueva. Devuelve la [PlaylistDominio] creada o null.
  Future<PlaylistDominio?> crear(String name, {String description = '', String? coverPath}) async {
    final id = await _colecciones.crearColeccion(name, coverPath ?? '');
    if (id == null || id.isEmpty) return null;
    return PlaylistDominio(
      id: id,
      name: name,
      description: description,
      coverUrl: coverPath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ── Consultas (servicio_dominio_playlist_consultas.dart) ──

  /// Agrega un track a una playlist.
  Future<bool> agregarTrack(String playlistId, String trackId) async {
    try {
      await _colecciones.agregarTrackColeccion(playlistId, trackId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quita un track de una playlist.
  Future<bool> quitarTrack(String playlistId, String trackId) async {
    try {
      await _colecciones.quitarTrackColeccion(playlistId, trackId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Tracks (servicio_dominio_playlist_consultas.dart) ──

  /// Actualiza la carátula de la playlist.
  Future<bool> actualizarCaratula(String playlistId, String coverPath) async {
    try {
      await _colecciones.actualizarCaratulaColeccion(playlistId, coverPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Garantiza que una playlist creada tenga carátula: prueba [covers] en
  /// orden, guardando la primera URL resoluble a disco y persistiéndola en la
  /// colección. No-op si ya existe. Devuelve la ruta absoluta persistida o null.
  Future<String?> garantizarCaratula(String playlistId, List<String?> covers) async {
    try {
      final existente = await _colecciones.getCaratulaPlaylist(playlistId);
      if (existente != null && existente.isNotEmpty) return existente;
    } catch (_) {}
    for (final c in covers) {
      final url = c?.trim() ?? '';
      if (url.isEmpty) continue;
      try {
        final ruta = await _backend.saveCover(url);
        if (ruta != null && ruta.isNotEmpty) {
          await _colecciones.actualizarCaratulaColeccion(playlistId, ruta);
          return ruta;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Borra una playlist y todos sus items.
  Future<bool> borrar(String id) async {
    try {
      await _colecciones.borrarColeccion(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Stats (servicio_dominio_playlist_consultas.dart) ──
}