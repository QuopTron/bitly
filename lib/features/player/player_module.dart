import 'package:get_it/get_it.dart';
import 'data/repositories/player_repository.dart';
import 'domain/usecases/play_track.dart';
import 'domain/usecases/control_playback.dart';
import 'domain/usecases/manage_queue.dart';
import 'presentation/bloc/player_bloc/player_bloc.dart';
import 'presentation/bloc/mini_player_bloc/mini_player_bloc.dart';

class PlayerModule {
  static void register() {
    final di = GetIt.instance;

    di.registerLazySingleton<PlayerRepository>(() => PlayerRepository());

    di.registerLazySingleton<PlayTrack>(() => PlayTrack());
    di.registerLazySingleton<ControlPlayback>(() => ControlPlayback());
    di.registerLazySingleton<ManageQueue>(() => ManageQueue());

    di.registerFactory<PlayerBloc>(() => PlayerBloc());
    di.registerFactory<MiniPlayerBloc>(() => MiniPlayerBloc());
  }
}
