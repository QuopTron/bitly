export '../cache/queue_state.dart';

import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../cache/queue_state.dart';

class QueueCubit extends Cubit<QueueState> {
  QueueCubit() : super(const QueueState());

  void play(FeedItem item) {
    emit(state.copyWith(
      tracks: [item],
      currentIndex: 0,
    ));
  }

  /// Seeds the queue with a visible context list starting from [item], so the
  /// player can pre-cache neighbors and next/prev navigate the surrounding list.
  /// Falls back to a single-item queue when the item isn't in [items].
  ///
  /// The tapped [item] may be a *different object* than the entries in [items]
  /// (grids rebuild fresh FeedItems), so the current index is matched by stable
  /// identity (id+source), NOT reference equality — otherwise indexOf returns -1
  /// and the queue shows the first track while the audio plays the tapped one.
  void playWithContext(List<FeedItem> items, FeedItem item) {
    if (items.isEmpty) {
      play(item);
      return;
    }
    final idx = items.indexWhere(
      (t) => t.id == item.id && t.source == item.source,
    );
    emit(state.copyWith(
      tracks: List<FeedItem>.from(items),
      currentIndex: idx >= 0 ? idx : 0,
    ));
  }

  void playList(List<FeedItem> items, {int startIndex = 0}) {
    if (items.isEmpty) return;
    emit(state.copyWith(
      tracks: items,
      currentIndex: startIndex.clamp(0, items.length - 1),
    ));
  }

  void addNext(FeedItem item) {
    final tracks = List<FeedItem>.from(state.tracks);
    final insertAt = state.hasCurrent ? state.currentIndex + 1 : tracks.length;
    tracks.insert(insertAt, item);
    final idx = state.currentIndex >= insertAt ? state.currentIndex + 1 : state.currentIndex;
    emit(state.copyWith(tracks: tracks, currentIndex: idx >= 0 ? idx : 0));
  }

  void addToEnd(FeedItem item) {
    final tracks = List<FeedItem>.from(state.tracks)..add(item);
    emit(state.copyWith(tracks: tracks));
  }

  void remove(int index) {
    if (index < 0 || index >= state.tracks.length) return;
    final tracks = List<FeedItem>.from(state.tracks)..removeAt(index);
    int newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    } else if (index == state.currentIndex) {
      newIndex = tracks.isEmpty ? -1 : newIndex.clamp(0, tracks.length - 1);
    }
    emit(state.copyWith(tracks: tracks, currentIndex: newIndex));
  }

  void clear() {
    emit(const QueueState());
  }

  /// Avanza al siguiente track. Retorna `true` si hay un track para reproducir,
  /// `false` si la cola se agotó (sin más tracks y sin repeat).
  bool next() {
    if (state.tracks.isEmpty) return false;
    if (state.repeatMode == RepeatMode.one) {
      emit(state.copyWith(currentIndex: state.currentIndex));
      return true;
    }
    int nextIndex;
    if (state.shuffle) {
      nextIndex = _randomIndex();
    } else {
      nextIndex = state.currentIndex + 1;
      if (nextIndex >= state.tracks.length) {
        if (state.repeatMode == RepeatMode.all) {
          nextIndex = 0;
        } else {
          emit(state.copyWith(currentIndex: -1));
          return false; // cola agotada
        }
      }
    }
    emit(state.copyWith(currentIndex: nextIndex));
    return true;
  }

  void previous() {
    if (state.tracks.isEmpty || !state.hasCurrent) return;
    if (state.shuffle) {
      emit(state.copyWith(currentIndex: _randomIndex()));
      return;
    }
    final prevIndex = state.currentIndex - 1;
    if (prevIndex < 0) {
      if (state.repeatMode == RepeatMode.all) {
        emit(state.copyWith(currentIndex: state.tracks.length - 1));
      } else {
        emit(state.copyWith(currentIndex: 0));
      }
    } else {
      emit(state.copyWith(currentIndex: prevIndex));
    }
  }

  void seekTo(int index) {
    if (index < 0 || index >= state.tracks.length) return;
    emit(state.copyWith(currentIndex: index));
  }

  void toggleShuffle() {
    emit(state.copyWith(shuffle: !state.shuffle));
  }

  void cycleRepeatMode() {
    final modes = RepeatMode.values;
    final next = (modes.indexOf(state.repeatMode) + 1) % modes.length;
    emit(state.copyWith(repeatMode: modes[next]));
  }

  int _randomIndex() {
    if (state.tracks.length <= 1) return 0;
    int idx;
    do {
      idx = Random().nextInt(state.tracks.length);
    } while (idx == state.currentIndex);
    return idx;
  }

  void reorder(int oldIndex, int newIndex) {
    final tracks = List<FeedItem>.from(state.tracks);
    final item = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, item);
    int currentIndex = state.currentIndex;
    if (oldIndex == currentIndex) {
      currentIndex = newIndex;
    } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
      currentIndex--;
    } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
      currentIndex++;
    }
    emit(state.copyWith(tracks: tracks, currentIndex: currentIndex));
  }

  /// Añade una lista de tracks al final de la cola (para autoplay/radio).
  void addTracks(List<FeedItem> items) {
    if (items.isEmpty) return;
    final tracks = List<FeedItem>.from(state.tracks)..addAll(items);
    emit(state.copyWith(tracks: tracks));
  }

  /// Reemplaza toda la cola con nuevos tracks (para autoplay/radio cuando se
  /// acaba la cola anterior). Arranca desde el primer track.
  void replaceQueue(List<FeedItem> items) {
    emit(QueueState(
      tracks: items,
      currentIndex: items.isNotEmpty ? 0 : -1,
      repeatMode: state.repeatMode,
      shuffle: state.shuffle,
    ));
  }
}




