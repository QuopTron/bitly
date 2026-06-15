import 'package:equatable/equatable.dart';
import '../../../../library/data/models/library_item_model.dart';

class MiniPlayerState extends Equatable {
  final bool isVisible;
  final LibraryItemModel? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const MiniPlayerState({
    this.isVisible = false,
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  MiniPlayerState copyWith({
    bool? isVisible,
    LibraryItemModel? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return MiniPlayerState(
      isVisible: isVisible ?? this.isVisible,
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }

  @override
  List<Object?> get props => [isVisible, currentTrack, isPlaying, position, duration];
}
