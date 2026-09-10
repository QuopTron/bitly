// ─────────────────────────────────────────────────────────────
// exportacion_playlist.dart — Exporta una playlist como archivos
// M3U / M3U8 / CUE / NFO en el dispositivo. Pide al usuario elegir
// el directorio de salida (file_picker) y convierte los tracks del
// dominio (TrackDetalle) al modelo del generador (TrackPlaylist),
// filtrando solo los que tienen archivo local. El helper de UI con
// SnackBar vive en shared/utilidades/exportacion_playlist_ui.dart.
// Se conecta con: generador_playlists.dart + modelos de detalle.
// Parte del flujo: playlists (exportar a archivos).
// ─────────────────────────────────────────────────────────────

import 'package:file_picker/file_picker.dart';
import '../modelos/detalle_track.dart';
import '../modelos/track_playlist.dart';
import 'generador_playlists.dart';

/// Resultado de una operación de exportación de playlist.
class ResultadoExportacionPlaylist {
  final bool success;
  final List<String> files;
  final String? error;

  const ResultadoExportacionPlaylist({
    this.success = false,
    this.files = const [],
    this.error,
  });
}

/// Servicio que exporta playlists como archivos en el dispositivo.
class ServicioExportacionPlaylist {
  /// Exporta una playlist a un directorio elegido por el usuario.
  /// Devuelve un [ResultadoExportacionPlaylist] con lo generado.
  static Future<ResultadoExportacionPlaylist> exportarPlaylist({
    required String name,
    required List<TrackDetalle> tracks,
    String? initialDirectory,
    String? artist,
  }) async {
    // 1. Pedir el directorio de salida.
    final selectedDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Exportar playlist',
      initialDirectory: initialDirectory,
    );
    if (selectedDir == null) {
      return const ResultadoExportacionPlaylist(error: 'Export cancelled');
    }

    return exportarPlaylistADirectorio(
      name: name,
      tracks: tracks,
      outputDir: selectedDir,
      artist: artist,
    );
  }

  /// Exporta a un directorio específico (sin prompt de file picker).
  static Future<ResultadoExportacionPlaylist> exportarPlaylistADirectorio({
    required String name,
    required List<TrackDetalle> tracks,
    required String outputDir,
    String? artist,
  }) async {
    // 2. Filtrar tracks con archivo local.
    final localTracks = tracks
        .where((t) => t.filePath != null && t.filePath!.isNotEmpty)
        .toList();

    if (localTracks.isEmpty) {
      return const ResultadoExportacionPlaylist(
        success: false,
        error: 'No hay canciones descargadas localmente para exportar',
      );
    }

    // 3. Convertir al modelo del generador.
    final generatorTracks = localTracks
        .map((t) => TrackPlaylist(
              title: t.name,
              artist: t.artistName ?? '',
              album: t.albumName ?? '',
              durationMs: t.durationMs,
              filePath: t.filePath!,
              trackNum: t.trackNumber,
              isrc: t.isrc,
            ))
        .toList();

    final config = ConfigPlaylist(
      name: name,
      artist: artist ?? localTracks.first.artistName ?? '',
      tracks: generatorTracks,
      outputDir: outputDir,
    );

    // 4. Generar los archivos.
    final paths = await GeneradorPlaylists.generarLoteArchivos(config);

    if (paths.isEmpty) {
      return const ResultadoExportacionPlaylist(
        success: false,
        error: 'No se pudieron generar los archivos de playlist',
      );
    }

    return ResultadoExportacionPlaylist(success: true, files: paths);
  }

  /// Devuelve un resumen legible de los archivos exportados.
  static String formatearResumen(ResultadoExportacionPlaylist result) {
    if (!result.success) return result.error ?? 'Error desconocido';

    final types = <String>[];
    for (final f in result.files) {
      final ext = f.split('.').last.toUpperCase();
      if (!types.contains(ext)) types.add(ext);
    }
    return '✓ Exportados: ${types.join(', ')} (${result.files.length} archivos)';
  }
}