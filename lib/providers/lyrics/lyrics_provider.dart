import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/lyrics.dart';
import 'package:bitly/providers/audio/audio_player_provider.dart';
import 'package:bitly/providers/lyrics/lyrics_service.dart';
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
  final _service = LyricsService();
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

    if (state.isReady) {
      _log.i('Lyrics for $trackName - $artistName already ready, skipping fetch');
      return;
    }
    if (state.isLoading && trackId == _lastTrackId) {
      _log.i('Lyrics for $trackName - $artistName already loading, skipping fetch');
      return;
    }

    _lastTrackId = trackId;
    _lastTrackName = trackName;
    _lastArtistName = artistName;
    state = state.copyWith(isLoading: true, error: null, response: null, clearTranslation: true, isReady: false);

    final result = await _service.fetchLyrics(
      trackId: trackId,
      trackName: trackName,
      artistName: artistName,
      durationMs: durationMs,
    );

    if (result != null) {
      state = state.copyWith(
        response: result,
        isLoading: false,
        error: null,
        isReady: true,
      );
      _updateAudioPlayerLyricsReady(true);
    } else {
      state = state.copyWith(isLoading: false, error: 'No lyrics found', isReady: false);
      _updateAudioPlayerLyricsReady(false);
    }
    _updateAudioPlayerLyricsReady(state.isReady);
  }

  Future<void> fetchTranslation({String language = 'es'}) async {
    final trackName = _lastTrackName;
    final artistName = _lastArtistName;
    final trackId = _lastTrackId;
    if (trackName == null || artistName == null || trackId == null) return;

    state = state.copyWith(isTranslating: true);

    final result = await _service.fetchTranslation(
      trackId: trackId,
      trackName: trackName,
      artistName: artistName,
      durationMs: ref.read(audioPlayerProvider).duration.inMilliseconds,
      language: language,
    );

    state = state.copyWith(
      translation: result,
      isTranslating: false,
    );
  }
}

final lyricsProvider = NotifierProvider<LyricsNotifier, LyricsState>(
  LyricsNotifier.new,
);