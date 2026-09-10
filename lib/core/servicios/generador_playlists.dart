// ─────────────────────────────────────────────────────────────
// generador_playlists.dart — Generador de archivos de playlist:
// escribe M3U y M3U8 (listas de reproducción con rutas absolutas de
// los archivos locales), además de orquestar la generación de TODOS
// los formatos (M3U, M3U8, CUE, NFO) tolerando fallos individuales.
// Migrado del paquete `internal/playlist/` de Go. La generación de
// CUE y NFO vive en el part generador_playlists_cue_nfo.dart.
// Se conecta con: exportacion_playlist.dart (lo invoca).
// Parte del flujo: playlists (exportar a archivos).
// ─────────────────────────────────────────────────────────────

import 'dart:io';
import '../modelos/track_playlist.dart';

part 'generador_playlists_cue_nfo.dart';

/// Genera los archivos de playlist en disco.
class GeneradorPlaylists {
  static final _charsInvalidos = RegExp(r'[<>:"/\\|?*\x00-\x1f]');

  /// Sanitiza un string para usarlo como nombre de archivo.
  static String sanitizar(String name) {
    var result = name.replaceAll('/', ' ');
    result = result.replaceAll(_charsInvalidos, ' ');
    return result.trim();
  }

  /// Formatea segundos a "m:ss".
  static String formatearDuracion(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Genera un archivo M3U. Devuelve la ruta de salida; lanza si falla.
  static Future<String> generarM3U(ConfigPlaylist config) async {
    if (config.tracks.isEmpty) {
      throw ArgumentError('no tracks for M3U');
    }

    final b = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#PLAYLIST: ${config.name}')
      ..writeln('#GENRE: ${config.genre}')
      ..writeln('#DATE: ${config.year}')
      ..writeln();

    for (final t in config.tracks) {
      b.writeln('#EXTINF:${t.durationMs ~/ 1000},${t.artist} - ${t.title}');
      final absPath = File(t.filePath).absolute.path; // Ruta absoluta
      b.writeln(absPath);
    }

    final filename = '${sanitizar(config.name)}.m3u';
    final outputPath = '${config.outputDir}${Platform.pathSeparator}$filename';
    await File(outputPath).writeAsString(b.toString());
    return outputPath;
  }

  /// Genera un archivo M3U8. Devuelve la ruta de salida; lanza si falla.
  static Future<String> generarM3U8(ConfigPlaylist config) async {
    if (config.tracks.isEmpty) {
      throw ArgumentError('no tracks for M3U8');
    }

    final b = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#PLAYLIST: ${config.name}');

    for (final t in config.tracks) {
      b.writeln('#EXTINF:${t.durationMs ~/ 1000},${t.artist} - ${t.title}');
      final absPath = File(t.filePath).absolute.path;
      b.writeln(absPath);
    }

    final filename = '${sanitizar(config.name)}.m3u8';
    final outputPath = '${config.outputDir}${Platform.pathSeparator}$filename';
    await File(outputPath).writeAsString(b.toString());
    return outputPath;
  }

  /// Genera TODOS los tipos de archivo (M3U, M3U8, CUE, NFO).
  /// Devuelve la lista de rutas generadas exitosamente.
  static Future<List<String>> generarLoteArchivos(ConfigPlaylist config) async {
    final generados = <String>[];

    try {
      generados.add(await generarM3U(config));
    } catch (_) {}

    try {
      generados.add(await generarM3U8(config));
    } catch (_) {}

    try {
      generados.add(await generarCUE(config));
    } catch (_) {}

    try {
      generados.add(await generarNFO(config));
    } catch (_) {}

    return generados;
  }
}