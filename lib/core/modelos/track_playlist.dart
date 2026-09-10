// ─────────────────────────────────────────────────────────────
// track_playlist.dart — Modelos de exportación de playlists:
// TrackPlaylist (track con ruta local de archivo) y ConfigPlaylist
// (datos de la playlist a generar). Los usa el GeneradorPlaylists
// para escribir los archivos M3U/CUE/NFO. La conversión desde
// TrackDetalle la hace ServicioExportacionPlaylist.
// Se conecta con: generador_playlists.dart + exportacion_playlist.dart.
// Parte del flujo: playlists (exportar a archivos).
// ─────────────────────────────────────────────────────────────

/// Un track dentro de la playlist a exportar, con su ruta local.
class TrackPlaylist {
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String filePath;
  final int trackNum;
  final int discNum;
  final String isrc;

  const TrackPlaylist({
    required this.title,
    this.artist = '',
    this.album = '',
    this.durationMs = 0,
    this.filePath = '',
    this.trackNum = 0,
    this.discNum = 0,
    this.isrc = '',
  });

  factory TrackPlaylist.desdeJson(Map<String, dynamic> json) => TrackPlaylist(
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        album: json['album'] as String? ?? '',
        durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
        filePath: json['file_path'] as String? ?? '',
        trackNum: (json['track_number'] as num?)?.toInt() ?? 0,
        discNum: (json['disc_number'] as num?)?.toInt() ?? 0,
        isrc: json['isrc'] as String? ?? '',
      );

  Map<String, dynamic> aJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'duration_ms': durationMs,
        'file_path': filePath,
        'track_number': trackNum,
        'disc_number': discNum,
        'isrc': isrc,
      };
}

/// Configuración para generar los archivos de una playlist.
class ConfigPlaylist {
  final String name;
  final String artist;
  final String year;
  final String genre;
  final List<TrackPlaylist> tracks;
  final String outputDir;

  const ConfigPlaylist({
    this.name = '',
    this.artist = '',
    this.year = '',
    this.genre = '',
    this.tracks = const [],
    this.outputDir = '',
  });
}