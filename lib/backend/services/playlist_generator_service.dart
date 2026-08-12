import 'dart:io';

/// Data class for a track in a playlist.
class PlaylistTrack {
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String filePath;
  final int trackNum;
  final int discNum;
  final String isrc;

  const PlaylistTrack({
    required this.title,
    this.artist = '',
    this.album = '',
    this.durationMs = 0,
    this.filePath = '',
    this.trackNum = 0,
    this.discNum = 0,
    this.isrc = '',
  });

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) => PlaylistTrack(
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        album: json['album'] as String? ?? '',
        durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
        filePath: json['file_path'] as String? ?? '',
        trackNum: (json['track_number'] as num?)?.toInt() ?? 0,
        discNum: (json['disc_number'] as num?)?.toInt() ?? 0,
        isrc: json['isrc'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
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

/// Configuration for generating playlist files.
class PlaylistConfig {
  final String name;
  final String artist;
  final String year;
  final String genre;
  final List<PlaylistTrack> tracks;
  final String outputDir;

  const PlaylistConfig({
    this.name = '',
    this.artist = '',
    this.year = '',
    this.genre = '',
    this.tracks = const [],
    this.outputDir = '',
  });
}

/// Service that generates playlist files (M3U, M3U8, CUE, NFO).
///
/// Migrated from Go's `internal/playlist/` package.
class PlaylistGeneratorService {
  static final _invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1f]');

  /// Sanitize a string for use as a filename.
  static String sanitize(String name) {
    var result = name.replaceAll('/', ' ');
    result = result.replaceAll(_invalidChars, ' ');
    return result.trim();
  }

  /// Format seconds to "m:ss" format.
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Generate an M3U playlist file.
  ///
  /// Returns the output file path, or throws on error.
  static Future<String> generateM3U(PlaylistConfig config) async {
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
      final absPath =
          File(t.filePath).absolute.path; // Resolve to absolute path
      b.writeln(absPath);
    }

    final filename = '${sanitize(config.name)}.m3u';
    final outputPath = '${config.outputDir}${Platform.pathSeparator}$filename';
    await File(outputPath).writeAsString(b.toString());
    return outputPath;
  }

  /// Generate an M3U8 playlist file.
  ///
  /// Returns the output file path, or throws on error.
  static Future<String> generateM3U8(PlaylistConfig config) async {
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

    final filename = '${sanitize(config.name)}.m3u8';
    final outputPath = '${config.outputDir}${Platform.pathSeparator}$filename';
    await File(outputPath).writeAsString(b.toString());
    return outputPath;
  }

  /// Generate a CUE sheet file.
  ///
  /// Returns the output file path, or throws on error.
  static Future<String> generateCUE(PlaylistConfig config) async {
    if (config.tracks.isEmpty) {
      throw ArgumentError('no tracks for CUE');
    }

    final performer =
        config.artist.isNotEmpty ? config.artist : config.tracks[0].artist;
    final title =
        config.name.isNotEmpty ? config.name : 'Unknown Album';

    final b = StringBuffer()
      ..writeln('REM GENRE ${config.genre}')
      ..writeln('REM DATE ${config.year}')
      ..writeln('PERFORMER "$performer"')
      ..writeln('TITLE "$title"')
      ..writeln('FILE "dummy.flac" FLAC');

    var currentDisc = 0;
    for (var i = 0; i < config.tracks.length; i++) {
      final t = config.tracks[i];
      if (t.discNum > 0 && t.discNum != currentDisc) {
        if (currentDisc > 0) {
          b.writeln('  REM END_DISC');
        }
        currentDisc = t.discNum;
      }

      var idx = i + 1;
      if (t.trackNum > 0) {
        idx = t.trackNum;
      }
      b.writeln('  TRACK ${idx.toString().padLeft(2, '0')} AUDIO');
      b.writeln('    TITLE "${t.title}"');
      b.writeln('    PERFORMER "${t.artist}"');
      if (t.isrc.isNotEmpty) {
        b.writeln('    ISRC ${t.isrc}');
      }
      b.writeln('    INDEX 01 00:00:00');
    }

    final filename = '${sanitize(config.name)}.cue';
    final outputPath = '${config.outputDir}${Platform.pathSeparator}$filename';
    await File(outputPath).writeAsString(b.toString());
    return outputPath;
  }

  /// Generate an NFO info file.
  ///
  /// Returns the output file path, or throws on error.
  static Future<String> generateNFO(PlaylistConfig config) async {
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final b = StringBuffer()
      ..writeln('Generated by Bitly')
      ..writeln('Date: $date $time')
      ..writeln('Album: ${config.name}')
      ..writeln('Artist: ${config.artist}')
      ..writeln('Genre: ${config.genre}')
      ..writeln('Year: ${config.year}')
      ..writeln('Tracks: ${config.tracks.length}')
      ..writeln()
      ..writeln('--- Track Listing ---');

    for (var i = 0; i < config.tracks.length; i++) {
      final t = config.tracks[i];
      final dur = formatDuration(t.durationMs ~/ 1000);
      b.writeln(
          '${(i + 1).toString().padLeft(2, '0')}. ${t.artist} - ${t.title} [$dur]');
    }

    final filename = '${sanitize(config.name)}.nfo';
    final outputPath = '${config.outputDir}${Platform.pathSeparator}$filename';
    await File(outputPath).writeAsString(b.toString());
    return outputPath;
  }

  /// Generate all playlist file types (M3U, M3U8, CUE, NFO).
  ///
  /// Returns a list of successfully generated file paths.
  static Future<List<String>> generateBulkPlaylistFiles(
      PlaylistConfig config) async {
    final generated = <String>[];

    try {
      generated.add(await generateM3U(config));
    } catch (_) {}

    try {
      generated.add(await generateM3U8(config));
    } catch (_) {}

    try {
      generated.add(await generateCUE(config));
    } catch (_) {}

    try {
      generated.add(await generateNFO(config));
    } catch (_) {}

    return generated;
  }
}

