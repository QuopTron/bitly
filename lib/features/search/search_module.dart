import 'package:get_it/get_it.dart';
import 'data/repositories/search_repository.dart';
import 'domain/usecases/search_tracks.dart';
import 'domain/usecases/search_by_url.dart';
import 'domain/usecases/check_availability.dart';
import 'presentation/bloc/search_bloc.dart';
import '../../core/api/methods.dart';

class SearchModule {
  static void register() {
    final sl = GetIt.instance;

    sl.registerLazySingleton<SearchRepository>(
        () => SearchRepository(sl<SearchMethods>()));

    sl.registerLazySingleton<SearchTracks>(
        () => SearchTracks(sl<SearchRepository>()));
    sl.registerLazySingleton<SearchByUrl>(
        () => SearchByUrl(sl<SearchRepository>()));
    sl.registerLazySingleton<CheckAvailability>(
        () => CheckAvailability(sl<SearchRepository>()));

    sl.registerFactory<SearchBloc>(
        () => SearchBloc(sl<SearchRepository>()));
  }
}
