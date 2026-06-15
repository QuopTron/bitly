import 'package:get_it/get_it.dart';
import 'data/repositories/home_repository.dart';
import 'domain/usecases/get_recent_downloads.dart';
import 'domain/usecases/get_quick_actions.dart';
import 'presentation/bloc/home_bloc.dart';

class HomeModule {
  static void register() {
    final sl = GetIt.instance;

    sl.registerLazySingleton<HomeRepository>(
      () => HomeRepository(),
    );

    sl.registerLazySingleton<GetRecentDownloads>(
      () => GetRecentDownloads(sl<HomeRepository>()),
    );

    sl.registerLazySingleton<GetQuickActions>(
      () => GetQuickActions(sl<HomeRepository>()),
    );

    sl.registerFactory<HomeBloc>(
      () => HomeBloc(repository: sl<HomeRepository>()),
    );
  }
}
