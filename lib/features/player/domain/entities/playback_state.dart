enum PlaybackStatus { playing, paused, stopped }

enum RepeatMode { none, one, all }

class PlaybackState {
  final PlaybackStatus status;
  final dynamic currentTrack;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final RepeatMode repeatMode;

  PlaybackState({
    required this.status,
    this.currentTrack,
    required this.position,
    required this.duration,
    required this.shuffle,
    required this.repeatMode,
  });
}
