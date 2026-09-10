// ─────────────────────────────────────────────────────────────
// cubit_playlists.dart — Cubit de playlists: orquesta la gestión de
// playlists del usuario vía ServicioDominioPlaylist (crear, cargar
// lista/stats/detalle, agregar/quitar tracks, actualizar carátula,
// borrar) y la exportación a archivos M3U/M3U8/CUE/NFO vía
// ServicioExportacionPlaylist (la playlist actual o una por ID).
// El estado y ItemPlaylist viven en playlists_estado.dart.
// Se conecta con: ServicioDominioPlaylist + ServicioExportacionPlaylist.
// Parte del flujo: playlists (Mi Espacio, detalle y exportar).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/modelos/detalle_playlist.dart';
import '../core/modelos/dominio_playlist.dart';
import '../core/modelos/estadisticas_usuario.dart';
import '../core/servicios/exportacion_playlist.dart';
import '../core/servicios/servicio_dominio_playlist.dart';

part 'playlists_estado.dart';

/// Cubit de playlists — usa el servicio de dominio y el exportador.
class CubitPlaylists extends Cubit<EstadoPlaylists> {
  final ServicioDominioPlaylist _servicioDominio;

  CubitPlaylists(this._servicioDominio) : super(const EstadoPlaylists());

  /// Carga inicial: playlists del usuario + stats, con flag de carga.
  Future<void> inicializar() async {
    emit(state.copiarCon(cargando: true));
    await Future.wait([cargarPlaylists(), cargarStats()]);
    emit(state.copiarCon(cargando: false));
  }

  /// Carga la lista de playlists del usuario.
  Future<void> cargarPlaylists() async {
    try {
      final dominios = await _servicioDominio.getPorUsuario();
      emit(state.copiarCon(
        playlists: dominios.map(_dominioAItem).toList(),
      ));
    } catch (_) {}
  }

  /// Carga las stats del usuario (conteos, nivel, progreso).
  Future<void> cargarStats() async {
    try {
      final stats = await _servicioDominio.getStats();
      if (stats != null) {
        emit(state.copiarCon(stats: stats));
      }
    } catch (_) {}
  }

  /// Crea una playlist nueva. Devuelve su ID o null si falló.
  Future<String?> crearPlaylist(String name, {String? coverPath}) async {
    try {
      final dominio = await _servicioDominio.crear(name, coverPath: coverPath);
      if (dominio != null) {
        await cargarPlaylists();
        return dominio.id;
      }
    } catch (_) {}
    return null;
  }

  /// Agrega un track a una playlist (recarga el detalle si es el actual).
  Future<void> agregarTrack(String playlistId, String trackId) async {
    try {
      await _servicioDominio.agregarTrack(playlistId, trackId);
      if (state.detalleActual?.id == playlistId) await cargarDetalle(playlistId);
      await cargarPlaylists();
    } catch (_) {}
  }

  /// Quita un track de una playlist (recarga el detalle si es el actual).
  Future<void> quitarTrack(String playlistId, String trackId) async {
    try {
      await _servicioDominio.quitarTrack(playlistId, trackId);
      if (state.detalleActual?.id == playlistId) await cargarDetalle(playlistId);
      await cargarPlaylists();
    } catch (_) {}
  }

  /// Carga el detalle completo (con tracks) de una playlist.
  Future<void> cargarDetalle(String collectionId) async {
    try {
      final detalle = await _servicioDominio.getDetalle(collectionId);
      if (detalle != null) {
        emit(state.copiarCon(detalleActual: detalle));
      }
    } catch (_) {}
  }

  /// Actualiza la carátula local de una playlist.
  Future<void> actualizarCaratula(String playlistId, String coverPath) async {
    try {
      await _servicioDominio.actualizarCaratula(playlistId, coverPath);
      await cargarPlaylists();
    } catch (_) {}
  }

  /// Borra una playlist y limpia el detalle si estaba abierto.
  Future<void> borrarPlaylist(String playlistId) async {
    try {
      await _servicioDominio.borrar(playlistId);
      emit(state.copiarCon(detalleActual: null));
      await cargarPlaylists();
    } catch (_) {}
  }

  /// Limpia el detalle actual de la UI.
  void limpiarDetalle() => emit(state.copiarCon(detalleActual: null));

  /// Exporta la playlist actual (detalle cargado) como archivos.
  /// Pide el directorio de salida al usuario. null si no hay detalle.
  Future<ResultadoExportacionPlaylist?> exportarPlaylistActual({
    String? initialDirectory,
  }) async {
    final detalle = state.detalleActual;
    if (detalle == null || detalle.tracks.isEmpty) return null;

    return ServicioExportacionPlaylist.exportarPlaylist(
      name: detalle.name,
      tracks: detalle.tracks,
      initialDirectory: initialDirectory,
    );
  }

  /// Exporta una playlist específica por ID (carga el detalle primero).
  Future<ResultadoExportacionPlaylist?> exportarPlaylistPorId(
      String playlistId,
      {String? initialDirectory}) async {
    try {
      await cargarDetalle(playlistId);
      return exportarPlaylistActual(initialDirectory: initialDirectory);
    } catch (_) {
      return const ResultadoExportacionPlaylist(error: 'No se pudo cargar la playlist');
    }
  }
}