import 'package:get_it/get_it.dart';
import 'core/api/client/rpc_client.dart';
import 'core/api/methods.dart';
import 'core/services/storage/shared_prefs.dart';
import 'features/onboarding/onboarding_module.dart';
import 'features/home/home_module.dart';
import 'features/search/search_module.dart';
import 'features/downloads/downloads_module.dart';
import 'features/library/library_module.dart';
import 'features/player/player_module.dart';
import 'features/extensions/extensions_module.dart';
import 'features/settings/settings_module.dart';
import 'features/collections/collections_module.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies() async {
  await _registerCore();
  await _registerServices();
  await _registerFeatures();
}

Future<void> _registerCore() async {
  sl.registerLazySingleton<RpcClient>(() => RpcClient(
    baseUrl: 'http://127.0.0.1:8080/rpc',
  ));

  // Register all RPC method classes
  sl.registerLazySingleton<SystemMethods>(() => SystemMethods(client: sl()));
  sl.registerLazySingleton<SearchMethods>(() => SearchMethods(client: sl()));
  sl.registerLazySingleton<DownloadMethods>(() => DownloadMethods(client: sl()));
  sl.registerLazySingleton<LibraryMethods>(() => LibraryMethods(client: sl()));
  sl.registerLazySingleton<LyricsMethods>(() => LyricsMethods(client: sl()));
  sl.registerLazySingleton<MetadataMethods>(() => MetadataMethods(client: sl()));
  sl.registerLazySingleton<PlaybackMethods>(() => PlaybackMethods(client: sl()));
  sl.registerLazySingleton<PlaylistMethods>(() => PlaylistMethods(client: sl()));
  sl.registerLazySingleton<SettingsMethods>(() => SettingsMethods(client: sl()));
  sl.registerLazySingleton<StoreMethods>(() => StoreMethods(client: sl()));
  sl.registerLazySingleton<StatsMethods>(() => StatsMethods(client: sl()));
}

Future<void> _registerServices() async {
  final prefs = SharedPrefs();
  await prefs.init();
  sl.registerLazySingleton<SharedPrefs>(() => prefs);
}

Future<void> _registerFeatures() async {
  OnboardingModule.register();
  HomeModule.register();
  SearchModule.register();
  DownloadsModule.register();
  LibraryModule.register();
  PlayerModule.register();
  ExtensionsModule.register();
  SettingsModule.register();
  CollectionsModule.register();
}
