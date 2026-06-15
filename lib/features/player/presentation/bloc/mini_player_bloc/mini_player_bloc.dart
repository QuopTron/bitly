import 'package:flutter_bloc/flutter_bloc.dart';
import 'mini_player_event.dart';
import 'mini_player_state.dart';
import '../../../domain/entities/playback_state.dart';

class MiniPlayerBloc extends Bloc<MiniPlayerEvent, MiniPlayerState> {
  MiniPlayerBloc() : super(const MiniPlayerState()) {
    on<ShowMiniPlayer>((_, e) => e(state.copyWith(isVisible: true)));
    on<HideMiniPlayer>((_, e) => e(state.copyWith(isVisible: false)));
    on<UpdateMiniPlayer>(_onUpdate);
  }

  void _onUpdate(UpdateMiniPlayer event, Emitter<MiniPlayerState> emit) {
    emit(state.copyWith(
      currentTrack: event.track ?? state.currentTrack,
      isPlaying: event.status == PlaybackStatus.playing,
      position: event.position ?? state.position,
      duration: event.duration ?? state.duration,
    ));
  }
}
