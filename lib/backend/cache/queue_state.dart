import 'package:equatable/equatable.dart';
import '../../frontend/shared/models/feed_models.dart';

enum RepeatMode { none, one, all }

class QueueState extends Equatable {
  final List<FeedItem> tracks;
  final int currentIndex;
  final RepeatMode repeatMode;
  final bool shuffle;

  bool get hasCurrent => currentIndex >= 0 && currentIndex < tracks.length;

  FeedItem? get current => hasCurrent ? tracks[currentIndex] : null;

  const QueueState({
    this.tracks = const [],
    this.currentIndex = -1,
    this.repeatMode = RepeatMode.none,
    this.shuffle = false,
  });

  QueueState copyWith({
    List<FeedItem>? tracks,
    int? currentIndex,
    RepeatMode? repeatMode,
    bool? shuffle,
  }) =>
      QueueState(
        tracks: tracks ?? this.tracks,
        currentIndex: currentIndex ?? this.currentIndex,
        repeatMode: repeatMode ?? this.repeatMode,
        shuffle: shuffle ?? this.shuffle,
      );

  @override
  List<Object?> get props => [tracks, currentIndex, repeatMode, shuffle];
}
