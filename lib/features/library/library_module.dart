import 'package:get_it/get_it.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/scan_repository.dart';
import 'domain/usecases/get_library_tracks.dart';
import 'domain/usecases/get_library_albums.dart';
import 'domain/usecases/get_library_artists.dart';
import 'domain/usecases/scan_library.dart';
import 'domain/usecases/delete_library_item.dart';
import 'presentation/bloc/library_bloc/library_bloc.dart';
import 'presentation/bloc/scan_bloc/scan_bloc.dart';

class LibraryModule {
  static void register() {
    final di = GetIt.instance;

    di.registerLazySingleton<LibraryRepository>(() => LibraryRepository());
    di.registerLazySingleton<ScanRepository>(() => ScanRepository());

    di.registerLazySingleton<GetLibraryTracks>(() => GetLibraryTracks());
    di.registerLazySingleton<GetLibraryAlbums>(() => GetLibraryAlbums());
    di.registerLazySingleton<GetLibraryArtists>(() => GetLibraryArtists());
    di.registerLazySingleton<ScanLibrary>(() => ScanLibrary());
    di.registerLazySingleton<DeleteLibraryItem>(() => DeleteLibraryItem());

    di.registerFactory<LibraryBloc>(() => LibraryBloc());
    di.registerFactory<ScanBloc>(() => ScanBloc());
  }
}
