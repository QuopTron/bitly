import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/providers/playback/playback_queue_state.dart';

export 'package:bitly/providers/playback/playback_queue_state.dart';

final _log = AppLogger('PlaybackQueue');

class PlaybackQueueNotifier extends Notifier<PlaybackQueueState> {
  final _random = Random();

  @override
  PlaybackQueueState build() {
    return const PlaybackQueueState();
  }

  Future<void> _syncQueueWithBackend() async {
    try {
      final tracksJson = jsonEncode(state.items.map((i) => i.toJson()).toList());
      await PlatformBridge.playbackSetQueue(tracksJson);
    } catch (e) {
      _log.w('Failed to sync queue with backend: $e');
    }
  }

  void setQueue(List<PlaybackQueueItem> items, {int startIndex = 0}) {
    if (items.isEmpty) {
      state = const PlaybackQueueState();
      return;
    }
    final validStart = startIndex.clamp(0, items.length - 1);
    List<int>? shuffleIndices;
    if (state.isShuffled) {
      shuffleIndices = _generateShuffleIndices(items.length, validStart);
    }
    state = PlaybackQueueState(
      items: items,
      currentIndex: validStart,
      isShuffled: state.isShuffled,
      repeatMode: state.repeatMode,
      shuffleIndices: shuffleIndices,
    );
    _syncQueueWithBackend();
  }

  void setQueueFromTracks(List<Track> tracks, {int startIndex = 0, Map<String, String>? localPaths}) {
    final items = tracks.map((track) {
      final localPath = localPaths?[track.id];
      return PlaybackQueueItem(
        track: track,
        localPath: localPath,
        isAvailableOffline: localPath != null,
      );
    }).toList();
    setQueue(items, startIndex: startIndex);
  }

  void next() {
    if (state.items.isEmpty) return;

    if (state.repeatMode == QueueRepeatMode.one) {
      return;
    }

    if (state.currentIndex < state.items.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    } else if (state.repeatMode == QueueRepeatMode.all) {
      state = state.copyWith(currentIndex: 0);
    }
    _syncQueueWithBackend();
  }

  void previous() {
    if (state.items.isEmpty) return;

    if (state.repeatMode == QueueRepeatMode.one) {
      return;
    }

    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    } else if (state.repeatMode == QueueRepeatMode.all) {
      state = state.copyWith(currentIndex: state.items.length - 1);
    }
    _syncQueueWithBackend();
  }

  void goToIndex(int index) {
    if (index < 0 || index >= state.items.length) return;
    state = state.copyWith(currentIndex: index);
    _syncQueueWithBackend();
  }

  void toggleShuffle() {
    final newShuffled = !state.isShuffled;
    List<int>? newShuffleIndices;
    if (newShuffled && state.items.isNotEmpty) {
      newShuffleIndices = _generateShuffleIndices(state.items.length, state.currentIndex);
    }
    state = state.copyWith(
      isShuffled: newShuffled,
      shuffleIndices: newShuffleIndices,
    );
    _syncQueueWithBackend();
  }

  void cycleQueueRepeatMode() {
    final next = QueueRepeatMode.values[(state.repeatMode.index + 1) % QueueRepeatMode.values.length];
    state = state.copyWith(repeatMode: next);
    _syncQueueWithBackend();
  }

  void clear() {
    state = const PlaybackQueueState();
    _syncQueueWithBackend();
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = [...state.items]..removeAt(index);
    var newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    } else if (index == state.currentIndex) {
      if (newIndex >= newItems.length) {
        newIndex = newItems.isEmpty ? -1 : newItems.length - 1;
      }
    }
    state = state.copyWith(items: newItems, currentIndex: newIndex);
    _syncQueueWithBackend();
  }

  List<int> _generateShuffleIndices(int length, int currentIndex) {
    final indices = List<int>.generate(length, (i) => i);
    if (currentIndex >= 0 && currentIndex < length) {
      indices.remove(currentIndex);
      indices.shuffle(_random);
      indices.insert(0, currentIndex);
    } else {
      indices.shuffle(_random);
    }
    return indices;
  }
}

final playbackQueueProvider =
    NotifierProvider<PlaybackQueueNotifier, PlaybackQueueState>(
  PlaybackQueueNotifier.new,
);