import 'package:equatable/equatable.dart';
import '../../../../library/data/models/library_item_model.dart';
import '../../../domain/entities/playback_state.dart';

abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

class PlayTrackEvent extends PlayerEvent {
  final LibraryItemModel track;
  const PlayTrackEvent(this.track);

  @override
  List<Object?> get props => [track];
}

class PauseEvent extends PlayerEvent {
  const PauseEvent();
}

class ResumeEvent extends PlayerEvent {
  const ResumeEvent();
}

class StopEvent extends PlayerEvent {
  const StopEvent();
}

class NextEvent extends PlayerEvent {
  const NextEvent();
}

class PreviousEvent extends PlayerEvent {
  const PreviousEvent();
}

class SeekEvent extends PlayerEvent {
  final Duration position;
  const SeekEvent(this.position);

  @override
  List<Object?> get props => [position];
}

class SetShuffleEvent extends PlayerEvent {
  final bool shuffle;
  const SetShuffleEvent(this.shuffle);

  @override
  List<Object?> get props => [shuffle];
}

class SetRepeatEvent extends PlayerEvent {
  final RepeatMode repeatMode;
  const SetRepeatEvent(this.repeatMode);

  @override
  List<Object?> get props => [repeatMode];
}

class SetQueueEvent extends PlayerEvent {
  final List<LibraryItemModel> tracks;
  const SetQueueEvent(this.tracks);

  @override
  List<Object?> get props => [tracks];
}

class AddToQueueEvent extends PlayerEvent {
  final LibraryItemModel track;
  const AddToQueueEvent(this.track);

  @override
  List<Object?> get props => [track];
}

class RemoveFromQueueEvent extends PlayerEvent {
  final int index;
  const RemoveFromQueueEvent(this.index);

  @override
  List<Object?> get props => [index];
}

class ClearQueueEvent extends PlayerEvent {
  const ClearQueueEvent();
}
