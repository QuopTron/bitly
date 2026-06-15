import 'package:equatable/equatable.dart';
import '../../../../library/data/models/library_item_model.dart';
import '../../../domain/entities/playback_state.dart';

abstract class MiniPlayerEvent extends Equatable {
  const MiniPlayerEvent();

  @override
  List<Object?> get props => [];
}

class ShowMiniPlayer extends MiniPlayerEvent {}
class HideMiniPlayer extends MiniPlayerEvent {}

class UpdateMiniPlayer extends MiniPlayerEvent {
  final LibraryItemModel? track;
  final PlaybackStatus? status;
  final Duration? position;
  final Duration? duration;

  const UpdateMiniPlayer({this.track, this.status, this.position, this.duration});

  @override
  List<Object?> get props => [track, status, position, duration];
}
