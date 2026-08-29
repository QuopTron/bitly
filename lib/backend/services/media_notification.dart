import 'dart:async';
import 'dart:isolate';

import 'package:audio_service/audio_service.dart';

import '../../injection.dart';
import 'player_cubit.dart';
import 'queue_cubit.dart';
import 'media_notification_handler.dart';

/// Bridges the OS media notification / system controls with the app's real
/// playback engine (which lives in the main isolate as [PlayerCubit] /
/// [QueueCubit]).
///
/// On Android this drives a foreground service (`mediaPlayback`) so playback
/// keeps running when the app is backgrounded; the media notification shows the
/// current track, elapsed time and prev / play / pause / next / shuffle /
/// repeat controls. On desktop (Windows/Linux/macOS/iOS/web) the same handler
/// reports to the system media layer where the platform supports it, and
/// playback keeps going whenever the app process is alive (i.e. it stops only
/// when the app is fully closed).
class MediaNotificationBridge {
  MediaNotificationBridge._();

  static final MediaNotificationBridge instance = MediaNotificationBridge._();

  AudioHandler? _handler;
  SendPort? _handlerStatePort;
  StreamSubscription<QueueState>? _queueSub;
  StreamSubscription<AudioPlayerState>? _playerSub;
  ReceivePort? _controlPort;

  /// The [AudioHandler] proxy used by `audio_service` (may be null if the
  /// platform has no media layer available).
  AudioHandler? get handler => _handler;

  QueueState? _lastQueue;
  AudioPlayerState? _lastPlayer;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  bool _initialized = false;

  /// Initialises [AudioService] and wires the cubits to the handler. Called
  /// once from [main] after GetIt is configured.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _controlPort = ReceivePort();
    final sendToHandler = _controlPort!.sendPort;

    try {
      _handler = await AudioService.init(
        builder: () => BitlyAudioHandler(sendToHandler),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.example.bitly.channel.audio',
          androidNotificationChannelName: 'Bitly Music',
          // Keep the service in the foreground even while paused so resuming
          // cannot hit the Android 12+ restriction that forbids starting a
          // foreground service from the background.
          androidStopForegroundOnPause: false,
          androidNotificationClickStartsActivity: true,
          androidResumeOnClick: true,
        ),
      );
    } catch (e) {
      // audio_service may be unavailable on some desktop setups. Playback in
      // the app itself always works; only the system media layer is skipped.
      // ignore: avoid_print
      print('[MediaNotificationBridge] init failed: $e');
      _initialized = false;
      return;
    }

    _controlPort!.listen(_onControlMessage);

    // Watch real playback state and mirror it to the handler.
    _queueSub = sl<QueueCubit>().stream.listen((q) {
      _lastQueue = q;
      _pushState(force: true);
    });
    _playerSub = sl<PlayerCubit>().stream.listen((p) {
      _lastPlayer = p;
      _pushState();
    });
  }

  void _onControlMessage(dynamic raw) {
    if (raw is! Map) return;
    final type = raw['@type'];
    if (type == 'register') {
      _handlerStatePort = raw['sendPort'] as SendPort?;
      _pushState(force: true);
      return;
    }
    if (type != 'command') return;
    final cmd = (raw['cmd'] ?? '').toString();
    final queue = sl<QueueCubit>();
    final player = sl<PlayerCubit>();
    switch (cmd) {
      case 'play':
        player.play();
      case 'pause':
        player.pause();
      case 'playPause':
        player.togglePlayPause();
      case 'next':
        queue.next();
      case 'prev':
        queue.previous();
      case 'stop':
        player.pause();
      case 'seek':
        final ms = (raw['ms'] as num?)?.toInt() ?? 0;
        if (ms >= 0) player.seek(Duration(milliseconds: ms));
      case 'shuffle':
        queue.setShuffleMode((raw['on'] == true));
      case 'repeat':
        queue.setRepeatModeStr((raw['mode'] ?? 'none').toString());
    }
  }

  /// Sends the current snapshot to the handler. Position updates are throttled
  /// to ~1 Hz unless [force] is set (track change, play/pause, seek, …).
  void _pushState({bool force = false}) {
    if (_handlerStatePort == null) return;
    final queue = _lastQueue;
    final player = _lastPlayer;
    if (queue == null || player == null) return;

    final now = DateTime.now();
    if (!force &&
        now.difference(_lastPush) < const Duration(milliseconds: 1000)) {
      return;
    }

    final track = queue.current;
    final media = track == null
        ? <String, dynamic>{
            'hasCurrent': false,
          }
        : <String, dynamic>{
            'hasCurrent': true,
            'id': track.id,
            'title': track.name,
            'artist': track.artists ?? '',
            'album': track.albumName ?? '',
            'durationMs': track.durationMs ?? player.duration.inMilliseconds,
            'artUri': track.coverUrl,
          };

    _handlerStatePort!.send({
      ...media,
      'playing': player.isPlaying,
      'processing': _processingFrom(player.playbackState),
      'positionMs': player.position.inMilliseconds,
      'bufferedMs': player.position.inMilliseconds,
      'shuffle': queue.shuffle,
      'repeat': _repeatFrom(queue.repeatMode),
      'queueIndex': queue.currentIndex,
    });
    _lastPush = now;
  }

  String _processingFrom(PlayerPlaybackState s) {
    switch (s) {
      case PlayerPlaybackState.buffering:
        return 'buffering';
      case PlayerPlaybackState.error:
        return 'error';
      default:
        return 'ready';
    }
  }

  String _repeatFrom(RepeatMode r) {
    switch (r) {
      case RepeatMode.one:
        return 'one';
      case RepeatMode.all:
        return 'all';
      default:
        return 'none';
    }
  }

  /// Stops background playback and shuts the service down.
  Future<void> dispose() async {
    await _queueSub?.cancel();
    await _playerSub?.cancel();
    _controlPort?.close();
  }
}