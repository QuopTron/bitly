// ─────────────────────────────────────────────────────────────
// exportacion_playlist.dart — Exporta una playlist como archivos
// M3U / M3U8 / CUE / NFO en el dispositivo. Pide al usuario elegir
// el directorio de salida (file_picker) y convierte los tracks del
// dominio (TrackDetalle) al modelo del generador (TrackPlaylist),
// filtrando solo los que tienen archivo local.
//
// No arma texto para el usuario: devuelve un CÓDIGO de error y la UI
// lo traduce con l10n (antes devolvía frases fijas en español que se
// veían tal cual con la app en inglés).
//
// Se conecta con: generador_playlists.dart + modelos de detalle +
// shared/utilidades/descarga/exportacion_playlist_ui.dart.
// Parte del flujo: playlists (exportar a archivos).
// ─────────────────────────────────────────────────────────────

import 'package:file_picker/file_picker.dart';

import '../../../shared/utilidades/formato/l10n_servicio.dart';
import '../../modelos/detalle/detalle_track.dart';
import '../../modelos/playlist/track_playlist.dart';
import 'generador_playlists.dart';

/// Por qué falló una exportación. Código, no texto: la UI lo traduce.
enum ErrorExportacionPlaylist {
  /// El usuario cerró el selector de carpeta: no es un error que se avise.
  cancelada,

  /// La colección no tiene ninguna canción con archivo local.
  sinDescargas,

  /// El generador no produjo ningún archivo.
  generacion,

  /// No se pudo cargar el detalle de la playlist antes de exportar.
  carga,
}

/// Resultado de una operación de exportación de playlist.
class ResultadoExportacionPlaylist {
  final bool success;
  final List<String> files;
  final ErrorExportacionPlaylist? error;

  const ResultadoExportacionPlaylist({
    this.success = false,
    this.files = const [],
    this.error,
  });

  /// Extensiones únicas de los archivos generados (M3U, CUE, NFO...).
  List<String> get tipos {
    final tipos = <String>[];
    for (final f in files) {
      final ext = f.split('.').last.toUpperCase();
      if (!tipos.contains(ext)) tipos.add(ext);
    }
    return tipos;
  }
}

/// Servicio que exporta playlists como archivos en el dispositivo.
class ServicioExportacionPlaylist {
  /// Exporta una playlist a un directorio elegido por el usuario.
  static Future<ResultadoExportacionPlaylist> exportarPlaylist({
    required String name,
    required List<TrackDetalle> tracks,
    String? initialDirectory,
    String? artist,
  }) async {
    // 1. Pedir el directorio de salida (diálogo nativo, en el idioma activo).
    final selectedDir = await FilePicker.getDirectoryPath(
      dialogTitle: L10n.actual.acciones.exportarTitulo,
      initialDirectory: initialDirectory,
    );
    if (selectedDir == null) {
      return const ResultadoExportacionPlaylist(
        error: ErrorExportacionPlaylist.cancelada,
      );
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
    final localTracks =
        tracks
            .where((t) => t.filePath != null && t.filePath!.isNotEmpty)
            .toList();

    if (localTracks.isEmpty) {
      return const ResultadoExportacionPlaylist(
        error: ErrorExportacionPlaylist.sinDescargas,
      );
    }

    // 3. Convertir al modelo del generador.
    final generatorTracks =
        localTracks
            .map(
              (t) => TrackPlaylist(
                title: t.name,
                artist: t.artistName ?? '',
                album: t.albumName ?? '',
                durationMs: t.durationMs,
                filePath: t.filePath!,
                trackNum: t.trackNumber,
                isrc: t.isrc,
              ),
            )
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
        error: ErrorExportacionPlaylist.generacion,
      );
    }

    return ResultadoExportacionPlaylist(success: true, files: paths);
  }
}
