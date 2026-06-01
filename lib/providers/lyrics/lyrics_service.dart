import 'package:bitly/models/lyrics.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('LyricsService');

class LyricsService {
  Future<LyricsResponse?> fetchLyrics({
    required String trackId,
    required String trackName,
    required String artistName,
    required int durationMs,
  }) async {
    const maxRetries = 2;
    const baseDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        String lrcText = '';
        try {
          lrcText = await PlatformBridge.getLyricsLRC(
            trackId, trackName, artistName,
            durationMs: durationMs,
          ).timeout(const Duration(seconds: 10));
        } catch (e) {
          _log.w('getLyricsLRC failed (attempt $attempt/$maxRetries), trying fetchLyrics: $e');
          try {
            final result = await PlatformBridge.fetchLyrics(
              trackId, trackName, artistName,
              durationMs: durationMs,
            ).timeout(const Duration(seconds: 10));
            final resp = LyricsResponse.fromFetchLyricsResult(result);
            if (resp.lines.isNotEmpty) {
              _log.i('Lyrics loaded successfully from fetchLyrics (attempt $attempt)');
              return resp;
            }
          } catch (e2) {
            _log.w('fetchLyrics also failed (attempt $attempt/$maxRetries): $e2');
            if (attempt < maxRetries) {
              await Future.delayed(baseDelay * attempt);
              continue;
            } else {
              _log.e('All lyrics sources failed after $maxRetries attempts: $e2');
              return null;
            }
          }
          if (attempt < maxRetries) {
            await Future.delayed(baseDelay * attempt);
            continue;
          } else {
            return null;
          }
        }

        if (lrcText == '[instrumental:true]') {
          _log.i('Track is instrumental, no lyrics available');
          return LyricsResponse(lines: [], syncType: 'LINE_SYNCED');
        }

        if (lrcText.isEmpty) {
          if (attempt < maxRetries) {
            await Future.delayed(baseDelay * attempt);
            continue;
          } else {
            return null;
          }
        }

        final lines = _parseLRCLines(lrcText);
        if (lines.isEmpty) {
          if (attempt < maxRetries) {
            await Future.delayed(baseDelay * attempt);
            continue;
          } else {
            return null;
          }
        }

        final hasTimestamps = lines.any((l) => l.startTimeMs > 0);
        _log.i('Lyrics loaded successfully (attempt $attempt)');
        return LyricsResponse(
          lines: lines,
          syncType: hasTimestamps ? 'LINE_SYNCED' : 'UNSYNCED',
        );
      } catch (e) {
        _log.w('Lyrics fetch attempt $attempt/$maxRetries failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(baseDelay * attempt);
        } else {
          _log.e('Lyrics fetch failed after $maxRetries attempts: $e');
          return null;
        }
      }
    }
    return null;
  }

  Future<LyricsResponse?> fetchTranslation({
    required String trackId,
    required String trackName,
    required String artistName,
    required int durationMs,
    String language = 'es',
  }) async {
    try {
      final lrcText = await PlatformBridge.getTranslatedLyricsLRC(
        trackId, trackName, artistName,
        durationMs: durationMs,
        language: language,
      );

      if (lrcText == '[instrumental:true]' || lrcText.isEmpty) {
        return null;
      }

      final lines = _parseLRCLines(lrcText);
      if (lines.isEmpty) return null;

      final hasTimestamps = lines.any((l) => l.startTimeMs > 0);
      return LyricsResponse(
        lines: lines,
        syncType: hasTimestamps ? 'LINE_SYNCED' : 'UNSYNCED',
        source: 'Musixmatch ($language)',
      );
    } catch (e) {
      _log.w('Translate lyrics failed: $e');
      return null;
    }
  }

  List<LyricsLine> _parseLRCLines(String lrc) {
    final linePattern = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$', multiLine: true);
    final matches = linePattern.allMatches(lrc);

    if (matches.isEmpty) {
      return lrc
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('['))
          .map((l) => LyricsLine(startTimeMs: 0, words: l, endTimeMs: 0))
          .toList();
    }

    final parsed = <LyricsLine>[];
    for (final m in matches) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final cs = int.parse(m.group(3)!);
      final text = m.group(4)!.trim();
      if (text.isEmpty || text.startsWith('ti:') || text.startsWith('ar:') || text.startsWith('by:')) continue;

      final ms = min * 60000 + sec * 1000 + (m.group(3)!.length == 2 ? cs * 10 : cs);
      parsed.add(LyricsLine(startTimeMs: ms, words: text, endTimeMs: ms + 5000));
    }

    for (var i = 0; i < parsed.length - 1; i++) {
      parsed[i] = LyricsLine(
        startTimeMs: parsed[i].startTimeMs,
        words: parsed[i].words,
        endTimeMs: parsed[i + 1].startTimeMs,
      );
    }

    return parsed;
  }
}