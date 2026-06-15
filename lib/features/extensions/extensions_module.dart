import 'package:get_it/get_it.dart';
import 'data/repositories/extension_repository.dart';
import 'data/repositories/store_repository.dart';
import '../../core/api/methods/extension_methods.dart' as rpc;
import '../../core/api/methods/store_methods.dart' as store_rpc;
import 'domain/usecases/get_installed_extensions.dart';
import 'domain/usecases/toggle_extension.dart';
import 'domain/usecases/install_extension.dart';
import 'domain/usecases/remove_extension.dart';
import 'domain/usecases/browse_store.dart';
import 'presentation/bloc/extensions_bloc/extensions_bloc.dart';
import 'presentation/bloc/store_bloc/store_bloc.dart';

class ExtensionsModule {
  static void register() {
    final sl = GetIt.instance;

    sl.registerLazySingleton<rpc.ExtensionMethods>(
      () => rpc.ExtensionMethods(client: sl()),
    );
    sl.registerLazySingleton<store_rpc.StoreMethods>(
      () => store_rpc.StoreMethods(client: sl()),
    );

    sl.registerLazySingleton<ExtensionRepository>(
      () => ExtensionRepository(sl<rpc.ExtensionMethods>()),
    );
    sl.registerLazySingleton<StoreRepository>(
      () => StoreRepository(sl<store_rpc.StoreMethods>()),
    );

    sl.registerLazySingleton<GetInstalledExtensions>(
      () => GetInstalledExtensions(sl<ExtensionRepository>()),
    );
    sl.registerLazySingleton<ToggleExtension>(
      () => ToggleExtension(sl<ExtensionRepository>()),
    );
    sl.registerLazySingleton<InstallExtension>(
      () => InstallExtension(sl<ExtensionRepository>()),
    );
    sl.registerLazySingleton<RemoveExtension>(
      () => RemoveExtension(sl<ExtensionRepository>()),
    );
    sl.registerLazySingleton<BrowseStore>(
      () => BrowseStore(sl<StoreRepository>()),
    );

    sl.registerFactory<ExtensionsBloc>(
      () => ExtensionsBloc(
        getInstalled: sl<GetInstalledExtensions>(),
        toggleExtension: sl<ToggleExtension>(),
        installExtension: sl<InstallExtension>(),
        removeExtension: sl<RemoveExtension>(),
      ),
    );

    sl.registerFactory<StoreBloc>(
      () => StoreBloc(browseStore: sl<BrowseStore>()),
    );
  }
}
