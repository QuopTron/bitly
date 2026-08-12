import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../../frontend/shared/models/detail_models.dart';
import 'playlist_generator_service.dart';

/// Result of a playlist export operation.
class PlaylistExportResult {
  final bool success;
  final List<String> files;
  final String? error;

  const PlaylistExportResult({
    this.success = false,
    this.files = const [],
    this.error,
  });
}

/// Service that exports playlists as M3U / M3U8 / CUE / NFO files on-device.
///
/// Wraps [PlaylistGeneratorService] and bridges the app's domain models
/// ([PlaylistDetail], [DetailTrack]) with the generator's [PlaylistConfig].
class PlaylistExportService {
  /// Export a playlist to a user-chosen directory.
  ///
  /// Prompts the user to pick a folder (using `file_picker`), then generates
  /// M3U, M3U8, CUE and NFO files for all tracks that have a local `filePath`.
  ///
  /// Returns a [PlaylistExportResult] describing what was generated.
  static Future<PlaylistExportResult> exportPlaylist({
    required String name,
    required List<DetailTrack> tracks,
    String? initialDirectory,
    String? artist,
  }) async {
    // 1. Prompt user for output directory
    final selectedDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Exportar playlist',
      initialDirectory: initialDirectory,
    );
    if (selectedDir == null) {
      return const PlaylistExportResult(error: 'Export cancelled');
    }

    return exportPlaylistToDir(
      name: name,
      tracks: tracks,
      outputDir: selectedDir,
      artist: artist,
    );
  }

  /// Export a playlist to a specific directory (no file picker prompt).
  ///
  /// Useful when the caller already knows the output path.
  static Future<PlaylistExportResult> exportPlaylistToDir({
    required String name,
    required List<DetailTrack> tracks,
    required String outputDir,
    String? artist,
  }) async {
    // 2. Filter tracks that have local files
    final localTracks = tracks
        .where((t) => t.filePath != null && t.filePath!.isNotEmpty)
        .toList();

    if (localTracks.isEmpty) {
      return const PlaylistExportResult(
        success: false,
        error: 'No hay canciones descargadas localmente para exportar',
      );
    }

    // 3. Convert to generator model
    final generatorTracks = localTracks
        .map((t) => PlaylistTrack(
              title: t.name,
              artist: t.artistName ?? '',
              album: t.albumName ?? '',
              durationMs: t.durationMs,
              filePath: t.filePath!,
              trackNum: t.trackNumber,
              isrc: t.isrc,
            ))
        .toList();

    final config = PlaylistConfig(
      name: name,
      artist: artist ?? localTracks.first.artistName ?? '',
      tracks: generatorTracks,
      outputDir: outputDir,
    );

    // 4. Generate files
    final paths =
        await PlaylistGeneratorService.generateBulkPlaylistFiles(config);

    if (paths.isEmpty) {
      return const PlaylistExportResult(
        success: false,
        error: 'No se pudieron generar los archivos de playlist',
      );
    }

    return PlaylistExportResult(success: true, files: paths);
  }

  /// Returns a human-readable summary of exported files.
  static String formatExportSummary(PlaylistExportResult result) {
    if (!result.success) return result.error ?? 'Error desconocido';

    final types = <String>[];
    for (final f in result.files) {
      final ext = f.split('.').last.toUpperCase();
      if (!types.contains(ext)) types.add(ext);
    }
    return '✓ Exportados: ${types.join(', ')} (${result.files.length} archivos)';
  }

  /// Run the full export flow and show a SnackBar with the result.
  ///
  /// Handles: empty-tracks check → file picker prompt → export →
  /// SnackBar with summary + "Abrir carpeta" action.
  ///
  /// Returns `true` if the export succeeded, `false` otherwise.
  /// If the user cancels the folder picker, returns `false` silently (no snack).
  static Future<bool> exportWithSnack({
    required BuildContext context,
    required String name,
    required List<DetailTrack> tracks,
    String? initialDirectory,
  }) async {
    if (tracks.isEmpty) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La colección está vacía'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    final result = await exportPlaylist(
      name: name,
      tracks: tracks,
      initialDirectory: initialDirectory,
    );

    if (!context.mounted) return result.success;

    final outputDir =
        result.files.isNotEmpty ? p.dirname(result.files.first) : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          formatExportSummary(result),
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black),
        ),
        backgroundColor: isDark
            ? const Color(0xFF2A2A3E)
            : const Color(0xFFE8E8F0),
        duration: const Duration(seconds: 4),
        action: result.success && outputDir != null
            ? SnackBarAction(
                label: 'Abrir carpeta',
                textColor:
                    isDark ? Colors.white70 : Colors.black87,
                onPressed: () => OpenFilex.open(outputDir),
              )
            : null,
      ),
    );

    return result.success;
  }
}


