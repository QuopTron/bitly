// ─────────────────────────────────────────────────────────────
// cubit_playlists.dart — Cubit de playlists: mantiene la LISTA de
// playlists del usuario y sus stats. Las operaciones sobre una
// playlist (crear, agregar/quitar canciones, carátula, borrar) las
// hace la UI contra ServicioEditorPlaylist / ServicioDominioPlaylist;
// acá solo se recarga la lista después.
// El estado y ItemPlaylist viven en playlists_estado.dart.
// Se conecta con: ServicioDominioPlaylist.
// Parte del flujo: playlists (Mi Espacio).
// ─────────────────────────────────────────────────────────────

import "package:flutter/foundation.dart";
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/modelos/playlist/dominio_playlist.dart';
import '../../core/modelos/usuario/perfil/estadisticas_usuario.dart';
import '../../core/servicios/playlist/dominio/servicio_dominio_playlist.dart';

part 'playlists_estado.dart';

/// Cubit de playlists — usa el servicio de dominio.
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
      emit(state.copiarCon(playlists: dominios.map(_dominioAItem).toList()));
    } catch (e) {
      debugPrint("[App] $e");
    }
  }

  /// Carga las stats del usuario (conteos, nivel, progreso).
  Future<void> cargarStats() async {
    try {
      final stats = await _servicioDominio.getStats();
      if (stats != null) {
        emit(state.copiarCon(stats: stats));
      }
    } catch (e) {
      debugPrint("[App] $e");
    }
  }
}
