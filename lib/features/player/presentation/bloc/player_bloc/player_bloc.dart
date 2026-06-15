import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'player_event.dart';
import 'player_state.dart';
import '../../../domain/entities/playback_state.dart';
import '../../../domain/usecases/play_track.dart';
import '../../../domain/usecases/control_playback.dart';
import '../../../domain/usecases/manage_queue.dart';
import '../../../../library/data/models/library_item_model.dart';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final PlayTrack _playTrack;
  final ControlPlayback _controlPlayback;
  final ManageQueue _manageQueue;
  Timer? _positionTimer;

  PlayerBloc()
      : _playTrack = GetIt.instance<PlayTrack>(),
        _controlPlayback = GetIt.instance<ControlPlayback>(),
        _manageQueue = GetIt.instance<ManageQueue>(),
        super(const PlayerState()) {
    on<PlayTrackEvent>(_onPlay);
    on<PauseEvent>((_, e) => _control(PlaybackAction.pause, e));
    on<ResumeEvent>((_, e) => _control(PlaybackAction.resume, e));
    on<StopEvent>((_, e) => _control(PlaybackAction.stop, e));
    on<NextEvent>((_, e) => _control(PlaybackAction.next, e));
    on<PreviousEvent>((_, e) => _control(PlaybackAction.previous, e));
    on<SeekEvent>(_onSeek);
    on<SetShuffleEvent>(_onSetShuffle);
    on<SetRepeatEvent>(_onSetRepeat);
    on<SetQueueEvent>(_onSetQueue);
    on<AddToQueueEvent>(_onAddToQueue);
    on<RemoveFromQueueEvent>(_onRemoveFromQueue);
    on<ClearQueueEvent>(_onClearQueue);
  }

  Future<void> _onPlay(PlayTrackEvent event, Emitter<PlayerState> emit) async {
    final newQueue = List<LibraryItemModel>.from(state.queue);
    final idx = newQueue.indexWhere((t) => t.id == event.track.id);
    if (idx == -1) {
      newQueue.add(event.track);
    }
    emit(state.copyWith(
      currentTrack: event.track,
      status: PlaybackStatus.playing,
      queue: newQueue,
      queueIndex: idx == -1 ? newQueue.length - 1 : idx,
    ));
    await _playTrack.call(event.track);
    _startPositionTimer(emit);
  }

  Future<void> _control(PlaybackAction action, Emitter<PlayerState> emit) async {
    await _controlPlayback.call(action);
    switch (action) {
      case PlaybackAction.pause:
        emit(state.copyWith(status: PlaybackStatus.paused));
        _positionTimer?.cancel();
      case PlaybackAction.resume:
        emit(state.copyWith(status: PlaybackStatus.playing));
        _startPositionTimer(emit);
      case PlaybackAction.stop:
        emit(state.copyWith(status: PlaybackStatus.stopped, position: Duration.zero));
        _positionTimer?.cancel();
      case PlaybackAction.next:
      case PlaybackAction.previous:
        break;
    }
  }

  Future<void> _onSeek(SeekEvent event, Emitter<PlayerState> emit) async {
    await _controlPlayback.seek(event.position);
    emit(state.copyWith(position: event.position));
  }

  void _onSetShuffle(SetShuffleEvent event, Emitter<PlayerState> emit) {
    emit(state.copyWith(shuffle: event.shuffle));
  }

  void _onSetRepeat(SetRepeatEvent event, Emitter<PlayerState> emit) {
    emit(state.copyWith(repeatMode: event.repeatMode));
  }

  Future<void> _onSetQueue(SetQueueEvent event, Emitter<PlayerState> emit) async {
    emit(state.copyWith(queue: event.tracks, queueIndex: 0));
    await _manageQueue.setQueue(event.tracks);
  }

  void _onAddToQueue(AddToQueueEvent event, Emitter<PlayerState> emit) {
    final newQueue = List<LibraryItemModel>.from(state.queue)..add(event.track);
    emit(state.copyWith(queue: newQueue));
  }

  void _onRemoveFromQueue(RemoveFromQueueEvent event, Emitter<PlayerState> emit) {
    final newQueue = List<LibraryItemModel>.from(state.queue)..removeAt(event.index);
    emit(state.copyWith(queue: newQueue));
  }

  void _onClearQueue(ClearQueueEvent event, Emitter<PlayerState> emit) {
    emit(state.copyWith(queue: [], queueIndex: -1));
  }

  void _startPositionTimer(Emitter<PlayerState> emit) {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(state.copyWith(
        position: state.position + const Duration(seconds: 1),
      ));
    });
  }

  @override
  Future<void> close() {
    _positionTimer?.cancel();
    return super.close();
  }
}
