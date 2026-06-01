// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

part of 'audio_player_provider.dart';

extension AudioQueueExtension on AudioPlayerNotifier {
  Future<void> playFromQueue() async {
    final queue = ref.read(playbackQueueProvider);
    final current = queue.currentItem;
    if (current == null) return;

    await play(
      trackId: current.track.id,
      trackName: current.track.name,
      artistName: current.track.artistName,
      albumName: current.track.albumName,
      coverUrl: current.track.coverUrl,
      provider: current.track.source ?? 'deezer',
      isrc: current.track.isrc,
      audioPath: current.localPath,
    );
  }

  Future<void> playQueueNext() async {
    await _logPlayIfQualified();
    final queueNotifier = ref.read(playbackQueueProvider.notifier);
    queueNotifier.next();
    await playFromQueue();
  }

  Future<void> playQueuePrevious() async {
    await _logPlayIfQualified();
    final queueNotifier = ref.read(playbackQueueProvider.notifier);
    queueNotifier.previous();
    await playFromQueue();
  }

  Future<void> _autoAdvance() async {
    final queue = ref.read(playbackQueueProvider);
    if (queue.canGoNext) {
      await playQueueNext();
    } else {
      await _player?.pause();
    }
  }

  Future<void> playTrackList(List<Track> tracks, {int startIndex = 0, Map<String, String>? localPaths}) async {
    final items = <PlaybackQueueItem>[];
    for (final track in tracks) {
      final localPath = localPaths?[track.id];
      items.add(PlaybackQueueItem(
        track: track,
        localPath: localPath,
        isAvailableOffline: localPath != null,
      ));
    }

    ref.read(playbackQueueProvider.notifier).setQueue(items, startIndex: startIndex);
    await playFromQueue();
  }

  void next() {
    ref.read(playbackQueueProvider.notifier).next();
  }

  void previous() {
    ref.read(playbackQueueProvider.notifier).previous();
  }

  void toggleShuffle() {
    ref.read(playbackQueueProvider.notifier).toggleShuffle();
  }

  void setQueue(List<PlaybackQueueItem> items, {int startIndex = 0}) {
    ref.read(playbackQueueProvider.notifier).setQueue(items, startIndex: startIndex);
  }

  void clearQueue() {
    ref.read(playbackQueueProvider.notifier).clear();
  }
}
