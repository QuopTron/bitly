import 'package:equatable/equatable.dart';
import '../../../../library/data/models/library_item_model.dart';
import '../../../domain/entities/playback_state.dart';

class PlayerState extends Equatable {
  final LibraryItemModel? currentTrack;
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final RepeatMode repeatMode;
  final List<LibraryItemModel> queue;
  final int queueIndex;

  const PlayerState({
    this.currentTrack,
    this.status = PlaybackStatus.stopped,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffle = false,
    this.repeatMode = RepeatMode.none,
    this.queue = const [],
    this.queueIndex = -1,
  });

  PlayerState copyWith({
    LibraryItemModel? currentTrack,
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool? shuffle,
    RepeatMode? repeatMode,
    List<LibraryItemModel>? queue,
    int? queueIndex,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
    );
  }

  @override
  List<Object?> get props => [
    currentTrack,
    status,
    position,
    duration,
    shuffle,
    repeatMode,
    queue,
    queueIndex,
  ];
}
