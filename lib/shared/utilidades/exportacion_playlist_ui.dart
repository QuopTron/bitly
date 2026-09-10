// ─────────────────────────────────────────────────────────────
// exportacion_playlist_ui.dart — Helper de UI para la exportación
// de playlists: corre el flujo completo (chequeo de tracks vacíos →
// file picker → exportación) y muestra una SnackBar con el resumen
// + acción "Abrir carpeta" (open_filex). Devuelve true si la
// exportación tuvo éxito; si el usuario cancela el selector de
// carpeta devuelve false en silencio (sin snack).
// Se conecta con: core/servicios/exportacion_playlist.dart.
// Parte del flujo: playlists (botón de exportar en la UI).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../../core/modelos/detalle_track.dart';
import '../../core/servicios/exportacion_playlist.dart';

/// Corre el flujo completo de exportación con feedback en SnackBar.
/// Devuelve true si la exportación tuvo éxito.
Future<bool> exportarConSnack({
  required BuildContext context,
  required String name,
  required List<TrackDetalle> tracks,
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

  final result = await ServicioExportacionPlaylist.exportarPlaylist(
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
        ServicioExportacionPlaylist.formatearResumen(result),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
      backgroundColor: isDark
          ? const Color(0xFF2A2A3E)
          : const Color(0xFFE8E8F0),
      duration: const Duration(seconds: 4),
      action: result.success && outputDir != null
          ? SnackBarAction(
              label: 'Abrir carpeta',
              textColor: isDark ? Colors.white70 : Colors.black87,
              onPressed: () => OpenFilex.open(outputDir),
            )
          : null,
    ),
  );

  return result.success;
}