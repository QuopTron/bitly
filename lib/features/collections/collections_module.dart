import 'package:get_it/get_it.dart';
import 'data/repositories/collections_repository.dart';
import 'domain/usecases/get_collections.dart';
import 'domain/usecases/create_collection.dart';
import 'domain/usecases/add_to_collection.dart';
import 'domain/usecases/manage_favorites.dart';
import 'presentation/bloc/collections_bloc.dart';

class CollectionsModule {
  static void register() {
    final sl = GetIt.instance;

    sl.registerLazySingleton<CollectionsRepository>(
      () => CollectionsRepository(),
    );

    sl.registerLazySingleton<GetCollections>(
      () => GetCollections(sl<CollectionsRepository>()),
    );
    sl.registerLazySingleton<CreateCollection>(
      () => CreateCollection(sl<CollectionsRepository>()),
    );
    sl.registerLazySingleton<AddToCollection>(
      () => AddToCollection(sl<CollectionsRepository>()),
    );
    sl.registerLazySingleton<ManageFavorites>(
      () => ManageFavorites(sl<CollectionsRepository>()),
    );

    sl.registerFactory<CollectionsBloc>(
      () => CollectionsBloc(
        getCollections: sl<GetCollections>(),
        createCollection: sl<CreateCollection>(),
        addToCollection: sl<AddToCollection>(),
        manageFavorites: sl<ManageFavorites>(),
      ),
    );
  }
}
