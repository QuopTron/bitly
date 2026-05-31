import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/lyrics.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('LyricsProvider');

class LyricsState {
  final LyricsResponse? response;
  final bool isLoading;
  final String? error;
  final LyricsResponse? translation;
  final bool isTranslating;
  final bool isReady;

  const LyricsState({
    this.response,
    this.isLoading = false,
    this.error,
    this.translation,
    this.isTranslating = false,
    this.isReady = false,
  });

  LyricsState copyWith({
    LyricsResponse? response,
    bool? isLoading,
    String? error,
    LyricsResponse? translation,
    bool? isTranslating,
    bool? isReady,
    bool clearTranslation = false,
  }) {
    return LyricsState(
      response: response ?? this.response,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      translation: clearTranslation ? null : (translation ?? this.translation),
      isTranslating: isTranslating ?? this.isTranslating,
      isReady: isReady ?? this.isReady,
    );
  }
}

class LyricsNotifier extends Notifier<LyricsState> {
  String? _lastTrackId;
  String? _lastTrackName;
  String? _lastArtistName;

  @override
  LyricsState build() {
    ref.listen(audioPlayerProvider, (prev, next) {
      final newTrackId = next.trackId;
      if (newTrackId != null && newTrackId != _lastTrackId) {
        _lastTrackId = newTrackId;
        _lastTrackName = next.trackName;
        _lastArtistName = next.artistName;
        fetchForTrack(
          trackId: newTrackId,
          trackName: next.trackName ?? '',
          artistName: next.artistName ?? '',
          durationMs: next.duration.inMilliseconds,
        );
      }
    });
    return const LyricsState();
  }

  void _updateAudioPlayerLyricsReady(bool isReady) {
    try {
      final audioNotifier = ref.read(audioPlayerProvider.notifier);
      audioNotifier.setLyricsReady(isReady);
    } catch (e) {
      _log.w('Failed to update audio player lyrics ready state: $e');
    }
  }

  Future<void> fetchForTrack({
    required String trackId,
    required String trackName,
    required String artistName,
    required int durationMs,
  }) async {
    if (trackName.isEmpty || artistName.isEmpty) return;

    // Si ya está lista, no hacer nada
    if (state.isReady) {
      _log.i('Lyrics for $trackName - $artistName already ready, skipping fetch');
      return;
    }
    // Si ya se está cargando Y es para la misma canción, no hacer nada
    if (state.isLoading && trackId == _lastTrackId) {
      _log.i('Lyrics for $trackName - $artistName already loading, skipping fetch');
      return;
    }

    _lastTrackId = trackId;
    _lastTrackName = trackName;
    _lastArtistName = artistName;

    const maxRetries = 2;
    const baseDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (attempt == 1) {
          state = state.copyWith(isLoading: true, error: null, response: null, clearTranslation: true, isReady: false);
        }

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
              state = state.copyWith(
                response: resp,
                isLoading: false,
                error: null,
                isReady: true,
              );
              _updateAudioPlayerLyricsReady(true);
              _log.i('Lyrics loaded successfully from fetchLyrics (attempt $attempt)');
              return;
            }
          } catch (e2) {
            _log.w('fetchLyrics also failed (attempt $attempt/$maxRetries): $e2');
            if (attempt < maxRetries) {
              final delay = baseDelay * attempt;
              _log.i('Retrying lyrics fetch in ${delay.inSeconds}s...');
              await Future.delayed(delay);
              continue;
            } else {
              _log.e('All lyrics sources failed after $maxRetries attempts: $e2');
              state = state.copyWith(isLoading: false, error: '$e2', isReady: false);
              _updateAudioPlayerLyricsReady(false);
              return;
            }
          }
          if (attempt < maxRetries) {
            final delay = baseDelay * attempt;
            _log.i('Retrying lyrics fetch in ${delay.inSeconds}s...');
            await Future.delayed(delay);
            continue;
          } else {
            state = state.copyWith(isLoading: false, error: 'No lyrics found', isReady: false);
            _updateAudioPlayerLyricsReady(false);
            return;
          }
        }

        if (lrcText == '[instrumental:true]') {
          state = state.copyWith(isLoading: false, isReady: true);
          _updateAudioPlayerLyricsReady(true);
          _log.i('Track is instrumental, no lyrics available');
          return;
        }

        if (lrcText.isEmpty) {
          if (attempt < maxRetries) {
            final delay = baseDelay * attempt;
            _log.i('Empty LRC, retrying in ${delay.inSeconds}s... (attempt $attempt/$maxRetries)');
            await Future.delayed(delay);
            continue;
          } else {
            state = state.copyWith(isLoading: false, error: 'Empty lyrics', isReady: false);
            _updateAudioPlayerLyricsReady(false);
            return;
          }
        }

        final lines = _parseLRCLines(lrcText);
        if (lines.isEmpty) {
          if (attempt < maxRetries) {
            final delay = baseDelay * attempt;
            _log.i('No lyrics lines parsed, retrying in ${delay.inSeconds}s... (attempt $attempt/$maxRetries)');
            await Future.delayed(delay);
            continue;
          } else {
            state = state.copyWith(isLoading: false, error: 'No lyrics lines', isReady: false);
            _updateAudioPlayerLyricsReady(false);
            return;
          }
        }

        final hasTimestamps = lines.any((l) => l.startTimeMs > 0);
        state = state.copyWith(
          response: LyricsResponse(
            lines: lines,
            syncType: hasTimestamps ? 'LINE_SYNCED' : 'UNSYNCED',
          ),
          isLoading: false,
          error: null,
          isReady: true,
        );
        _updateAudioPlayerLyricsReady(true);
        _log.i('Lyrics loaded successfully (attempt $attempt)');
        return;
      } catch (e) {
        _log.w('Lyrics fetch attempt $attempt/$maxRetries failed: $e');
        if (attempt < maxRetries) {
          final delay = baseDelay * attempt;
          _log.i('Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        } else {
          _log.e('Lyrics fetch failed after $maxRetries attempts: $e');
          state = state.copyWith(isLoading: false, error: '$e', isReady: false);
          _updateAudioPlayerLyricsReady(false);
        }
      }
    }
    _updateAudioPlayerLyricsReady(state.isReady);
  }

  Future<void> fetchTranslation({String language = 'es'}) async {
    final trackName = _lastTrackName;
    final artistName = _lastArtistName;
    final trackId = _lastTrackId;
    if (trackName == null || artistName == null || trackId == null) return;

    state = state.copyWith(isTranslating: true);

    try {
      final lrcText = await PlatformBridge.getTranslatedLyricsLRC(
        trackId, trackName, artistName,
        durationMs: ref.read(audioPlayerProvider).duration.inMilliseconds,
        language: language,
      );

      if (lrcText == '[instrumental:true]' || lrcText.isEmpty) {
        state = state.copyWith(isTranslating: false);
        return;
      }

      final lines = _parseLRCLines(lrcText);
      if (lines.isEmpty) {
        state = state.copyWith(isTranslating: false);
        return;
      }

      final hasTimestamps = lines.any((l) => l.startTimeMs > 0);
      state = state.copyWith(
        translation: LyricsResponse(
          lines: lines,
          syncType: hasTimestamps ? 'LINE_SYNCED' : 'UNSYNCED',
          source: 'Musixmatch ($language)',
        ),
        isTranslating: false,
      );
    } catch (e) {
      _log.w('Translate lyrics failed: $e');
      state = state.copyWith(isTranslating: false);
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

final lyricsProvider = NotifierProvider<LyricsNotifier, LyricsState>(
  LyricsNotifier.new,
);
