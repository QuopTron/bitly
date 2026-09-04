import 'package:equatable/equatable.dart';

enum PlayerPlaybackState { playing, paused, buffering, error }

class AudioPlayerState extends Equatable {
  final Duration position;
  final Duration duration;
  double get progress =>
      duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;
  final double volume;

  /// Playback speed multiplier (0.5x–2.0x). Persisted in state so the UI can
  /// show/cycle it and it is re-applied every time a new track is opened.
  final double rate;
  final PlayerPlaybackState playbackState;

  /// Human-readable reason playback is stalled/failed, surfaceable in the UI
  /// (e.g. "Sesión de Deezer no verificada") so a failed resolve is not silent.
  final String? errorMessage;

  bool get isPlaying => playbackState == PlayerPlaybackState.playing;

  const AudioPlayerState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.rate = 1.0,
    this.playbackState = PlayerPlaybackState.paused,
    this.errorMessage,
  });

  AudioPlayerState copyWith({
    Duration? position,
    Duration? duration,
    double? volume,
    double? rate,
    PlayerPlaybackState? playbackState,
    String? errorMessage,
  }) =>
      AudioPlayerState(
        position: position ?? this.position,
        duration: duration ?? this.duration,
        volume: volume ?? this.volume,
        rate: rate ?? this.rate,
        playbackState: playbackState ?? this.playbackState,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [position, duration, volume, rate, playbackState, errorMessage];
}
