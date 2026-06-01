import 'package:bitly/models/track.dart';

enum QueueRepeatMode { none, all, one }

class PlaybackQueueItem {
  final Track track;
  final String? localPath;
  final bool isAvailableOffline;

  const PlaybackQueueItem({
    required this.track,
    this.localPath,
    required this.isAvailableOffline,
  });

  Map<String, dynamic> toJson() => {
    'id': track.id,
    'name': track.name,
    'artist_name': track.artistName,
    'album_name': track.albumName,
    'cover_url': track.coverUrl,
    'isrc': track.isrc,
    'duration_ms': track.duration * 1000,
    'local_path': localPath ?? '',
    'source': track.source ?? 'unknown',
  };
}

class PlaybackQueueState {
  final List<PlaybackQueueItem> items;
  final int currentIndex;
  final bool isShuffled;
  final QueueRepeatMode repeatMode;
  final List<int>? shuffleIndices;

  const PlaybackQueueState({
    this.items = const [],
    this.currentIndex = -1,
    this.isShuffled = false,
    this.repeatMode = QueueRepeatMode.none,
    this.shuffleIndices,
  });

  bool get hasItems => items.isNotEmpty && currentIndex >= 0;

  PlaybackQueueItem? get currentItem =>
      hasItems ? items[_actualIndex] : null;

  Track? get currentTrack => currentItem?.track;

  int get _actualIndex {
    if (isShuffled && shuffleIndices != null && currentIndex < shuffleIndices!.length) {
      return shuffleIndices![currentIndex];
    }
    return currentIndex;
  }

  bool get canGoNext {
    if (items.isEmpty) return false;
    if (repeatMode == QueueRepeatMode.one || repeatMode == QueueRepeatMode.all) return true;
    return currentIndex < items.length - 1;
  }

  bool get canGoPrevious {
    if (items.isEmpty) return false;
    if (repeatMode == QueueRepeatMode.one || repeatMode == QueueRepeatMode.all) return true;
    return currentIndex > 0;
  }

  PlaybackQueueState copyWith({
    List<PlaybackQueueItem>? items,
    int? currentIndex,
    bool? isShuffled,
    QueueRepeatMode? repeatMode,
    List<int>? shuffleIndices,
  }) {
    return PlaybackQueueState(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleIndices: shuffleIndices ?? this.shuffleIndices,
    );
  }
}
