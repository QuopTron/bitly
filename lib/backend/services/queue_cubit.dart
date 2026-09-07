export '../cache/queue_state.dart';

import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../cache/queue_state.dart';

class QueueCubit extends Cubit<QueueState> {
  /// Indices of previously played tracks (recorded while shuffle is on), so
  /// `previous()` steps back to the ACTUAL last-played track instead of a
  /// random one. Bounded to avoid unbounded growth; cleared whenever the
  /// queue is replaced with a new context.
  final List<int> _history = [];

  QueueCubit() : super(const QueueState());

  void play(FeedItem item) {
    _history.clear();
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
    _history.clear();
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
    _history.clear();
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
    _history.clear();
    emit(const QueueState());
  }

  /// Avanza al siguiente track. Retorna `true` si hay un track para reproducir,
  /// `false` si la cola se agotó (sin más tracks y sin repeat).
  ///
  /// Repeat-one NO se maneja aquí a propósito: re-emitir el mismo índice
  /// produce un estado idéntico que bloc ≥ 9 descarta silenciosamente, así que
  /// el replay al terminar la canción lo hace PlayerCubit reabriendo el track
  /// directamente (ver _onTrackCompleted). Por eso un toque MANUAL de
  /// "siguiente" con repeat-one activo avanza a otra canción (como Spotify) en
  /// vez de quedarse atascado en un emit que nadie recibe.
  bool next() {
    if (state.tracks.isEmpty) return false;
    final from = state.currentIndex;
    int nextIndex;
    if (state.shuffle) {
      if (from >= 0) {
        _history.add(from);
        if (_history.length > 100) _history.removeAt(0);
      }
      if (state.tracks.length <= 1) {
        // Una sola canción en shuffle no puede "elegir otra". Con repeat-all
        // el replay del mismo track lo maneja PlayerCubit en EOF; sin repeat
        // la cola simplemente se agota.
        if (state.repeatMode == RepeatMode.all) {
          emit(state.copyWith(currentIndex: from));
          return true;
        }
        emit(state.copyWith(currentIndex: -1));
        return false;
      }
      nextIndex = _randomIndex();
    } else {
      nextIndex = from + 1;
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
      // Con shuffle, "anterior" vuelve al track que realmente sonó antes
      // (historial) en lugar de saltar a un índice aleatorio.
      while (_history.isNotEmpty) {
        final last = _history.removeLast();
        if (last >= 0 &&
            last < state.tracks.length &&
            last != state.currentIndex) {
          emit(state.copyWith(currentIndex: last));
          return;
        }
      }
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

  /// Sets shuffle on/off to a specific value (from the OS media controls).
  void setShuffleMode(bool value) {
    if (state.shuffle != value) {
      emit(state.copyWith(shuffle: value));
    }
  }

  /// Sets the repeat mode from the OS media controls ('none' | 'one' | 'all').
  void setRepeatModeStr(String mode) {
    final RepeatMode next;
    switch (mode) {
      case 'one':
        next = RepeatMode.one;
      case 'all':
        next = RepeatMode.all;
      default:
        next = RepeatMode.none;
    }
    if (state.repeatMode != next) {
      emit(state.copyWith(repeatMode: next));
    }
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
    _history.clear();
    emit(QueueState(
      tracks: items,
      currentIndex: items.isNotEmpty ? 0 : -1,
      repeatMode: state.repeatMode,
      shuffle: state.shuffle,
    ));
  }
}




