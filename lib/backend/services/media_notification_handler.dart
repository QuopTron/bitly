import 'dart:isolate';

import 'package:audio_service/audio_service.dart';

/// A thin, isolate-safe proxy [AudioHandler] that runs inside the
/// `audio_service` background isolate (the one that owns the Android
/// foreground service / media notification / lock-screen controls).
///
/// The actual audio playback lives in the MAIN isolate (the `PlayerCubit`
/// media_kit `Player`). This handler therefore only:
///
///  * Forwards control requests coming from the OS media notification /
///    system controls (play, pause, seek, next, previous, shuffle, repeat) to
///    the main isolate via [sendToMain].
///  * Receives the real playback/media state pushed from the main isolate on
///    [statePort] and re-broadcasts it so the notification reflects reality.
///
/// Communication is done with plain [SendPort]/[ReceivePort] messages which
/// are safe to pass between isolates.
class BitlyAudioHandler extends BaseAudioHandler {
  final SendPort _sendToMain;
  final ReceivePort _statePort = ReceivePort();

  BitlyAudioHandler(this._sendToMain) {
    // Tell the main isolate how to push state back to us.
    _sendToMain.send({
      '@type': 'register',
      'sendPort': _statePort.sendPort,
    });
    _statePort.listen((dynamic msg) {
      if (msg is Map) _applyStateMessage(msg);
    });
  }

  // ── OS → main isolate (control) ──────────────────────────────────────────
  @override
  Future<void> play() async => _send('play');
  @override
  Future<void> pause() async => _send('pause');
  @override
  Future<void> skipToNext() async => _send('next');
  @override
  Future<void> skipToPrevious() async => _send('prev');
  @override
  Future<void> seek(Duration position) async {
    _send('seek', {'ms': position.inMilliseconds});
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _send('shuffle', {'on': shuffleMode == AudioServiceShuffleMode.all});
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _send('repeat', {'mode': _repeatModeToStr(repeatMode)});
  }

  @override
  Future<void> stop() async => _send('stop');

  void _send(String command, [Map<String, dynamic>? extra]) {
    _sendToMain.send({
      '@type': 'command',
      'cmd': command,
      ...?extra,
    });
  }

  // ── Main isolate → OS (state, to render the notification) ───────────────
  void _applyStateMessage(Map<dynamic, dynamic> m) {
    final hasCurrent = m['hasCurrent'] == true;
    if (hasCurrent) {
      final id = (m['id'] ?? '').toString();
      mediaItem.add(
        MediaItem(
          id: id,
          title: (m['title'] ?? '').toString(),
          artist: (m['artist'] ?? '').toString().isNotEmpty
              ? (m['artist']).toString()
              : (m['album'] ?? '').toString(),
          album: (m['album'] ?? '').toString(),
          duration: Duration(
            milliseconds: (m['durationMs'] as int?) ?? 0,
          ),
          artUri: (m['artUri'] as String?)?.isNotEmpty == true
              ? Uri.tryParse(m['artUri'] as String)
              : null,
        ),
      );
    } else {
      mediaItem.add(null);
    }

    final playing = m['playing'] == true;
    final processing = _processingFromStr(
      (m['processing'] ?? 'idle').toString(),
    );
    final controls = <MediaControl>[
      const MediaControl(
        androidIcon: 'drawable/bitly_shuffle',
        label: 'Shuffle',
        action: MediaAction.setShuffleMode,
      ),
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      const MediaControl(
        androidIcon: 'drawable/bitly_repeat',
        label: 'Repeat',
        action: MediaAction.setRepeatMode,
      ),
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        // Compact (collapsed) media notification shows previous, play/pause,
        // next — max 3 allowed by audio_service assertion.
        androidCompactActionIndices: const [1, 2, 3],
        processingState: hasCurrent ? processing : AudioProcessingState.idle,
        playing: hasCurrent && playing,
        updatePosition: Duration(
          milliseconds: (m['positionMs'] as int?) ?? 0,
        ),
        bufferedPosition: Duration(
          milliseconds: (m['bufferedMs'] as int?) ?? 0,
        ),
        speed: 1.0,
        shuffleMode: (m['shuffle'] == true)
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: _repeatModeFromStr((m['repeat'] ?? 'none').toString()),
        queueIndex: (m['queueIndex'] as int?) ?? 0,
      ),
    );
  }

  AudioProcessingState _processingFromStr(String s) {
    switch (s) {
      case 'buffering':
        return AudioProcessingState.buffering;
      case 'ready':
        return AudioProcessingState.ready;
      case 'completed':
        return AudioProcessingState.completed;
      case 'error':
        return AudioProcessingState.error;
      case 'loading':
        return AudioProcessingState.loading;
      default:
        return AudioProcessingState.idle;
    }
  }

  String _repeatModeToStr(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.one:
        return 'one';
      case AudioServiceRepeatMode.all:
        return 'all';
      default:
        return 'none';
    }
  }

  AudioServiceRepeatMode _repeatModeFromStr(String s) {
    switch (s) {
      case 'one':
        return AudioServiceRepeatMode.one;
      case 'all':
        return AudioServiceRepeatMode.all;
      default:
        return AudioServiceRepeatMode.none;
    }
  }
}