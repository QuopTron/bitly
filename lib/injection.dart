import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'backend/rpc/backend_service.dart';
import 'backend/rpc/mixins/actions_mixin.dart';
import 'backend/rpc/android_backend.dart';
import 'backend/rpc/desktop_backend.dart';
import 'backend/rpc/ios_backend.dart';
import 'backend/database/app_database.dart';
import 'backend/cache/settings_cache.dart';
import 'backend/cache/premium_cache.dart';
import 'backend/cache/download_cache.dart';
import 'backend/cache/favorite_cache.dart';
import 'backend/cache/playback_cache.dart';
import 'backend/cache/detail_cache.dart';
import 'backend/cache/detail_memory_cache.dart';
import 'backend/cache/search_cache.dart';
import 'backend/cache/library_cache.dart';
import 'backend/cache/collection_cache.dart';
import 'backend/cache/feed_cache.dart';
import 'backend/services/queue_cubit.dart';
import 'backend/services/player_cubit.dart';
import 'backend/services/download_cubit.dart';
import 'backend/services/like_cubit.dart';
import 'backend/services/playlist_cubit.dart';
import 'backend/services/album_domain_service.dart';
import 'backend/services/playlist_domain_service.dart';
import 'frontend/shared/models/performance_profile.dart';
import 'frontend/features/splash/bloc/splash_bloc.dart';
import 'frontend/features/setup/bloc/setup_bloc.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // ── 1. Core values ───────────────────────────────────────────
  sl.registerLazySingleton<ValueNotifier<Locale>>(
    () => ValueNotifier(const Locale('es')),
  );
  sl.registerLazySingleton<ValueNotifier<PerformanceProfile>>(
    () => ValueNotifier(PerformanceProfile.medium),
  );

  // ── 2. Database ───────────────────────────────────────────────
  final db = await AppDatabase.create();
  await db.migrateLegacyCoverPaths();
  sl.registerLazySingleton<AppDatabase>(() => db);

  // ── 3. Caches (dependen de AppDatabase) ───────────────────────
  sl.registerLazySingleton<SettingsCache>(() => SettingsCache(db));
  sl.registerLazySingleton<PremiumCache>(() => PremiumCache(db));
  sl.registerLazySingleton<DownloadCache>(() => DownloadCache(db));
  sl.registerLazySingleton<FavoriteCache>(() => FavoriteCache(db));
  sl.registerLazySingleton<PlaybackCache>(() => PlaybackCache(db));
  sl.registerLazySingleton<DetailCache>(() => DetailCache(db));
  sl.registerLazySingleton<DetailMemoryCache>(() => DetailMemoryCache());
  sl.registerLazySingleton<SearchCache>(() => SearchCache(db));
  sl.registerLazySingleton<LibraryCache>(() => LibraryCache(db));
  sl.registerLazySingleton<CollectionCache>(() => CollectionCache(db));
  sl.registerLazySingleton<FeedCache>(() => FeedCache(db));

  // ── 4. Backend (plataforma) ───────────────────────────────────
  final sep = Platform.pathSeparator;
  BackendService backend;
  if (Platform.isAndroid) {
    backend = AndroidBackend();
  } else if (Platform.isIOS) {
    backend = IOSBackend();
  } else {
    String? exePath;
    if (Platform.isWindows) {
      exePath = '${Platform.resolvedExecutable}$sep..${sep}bitly-backend.exe';
    } else if (Platform.isMacOS) {
      exePath = '${Platform.resolvedExecutable}$sep..$sep..${sep}Frameworks${sep}Gobackend.framework${sep}Gobackend';
    } else if (Platform.isLinux) {
      exePath = '${Platform.resolvedExecutable}$sep..${sep}bitly-backend';
    }
    backend = DesktopBackend(
      executablePath: exePath,
      baseUrl: 'http://127.0.0.1:55009/rpc',
    );
  }
  sl.registerLazySingleton<BackendService>(() => backend);

  // ── 5. Domain Services (dependen de BackendService + caches) ──
  sl.registerLazySingleton<AlbumDomainService>(() => AlbumDomainService(backend));
  sl.registerLazySingleton<PlaylistDomainService>(() => PlaylistDomainService(backend));

  // ── 6. Cubits (orden: QueueCubit no tiene deps) ───────────────
  sl.registerLazySingleton<QueueCubit>(() => QueueCubit());
  sl.registerLazySingleton<PlayerCubit>(() => PlayerCubit(sl<QueueCubit>()));
  sl.registerLazySingleton<DownloadCubit>(() => DownloadCubit(backend));
  sl.registerLazySingleton<LikeCubit>(() => LikeCubit(backend));
  sl.registerLazySingleton<PlaylistCubit>(() => PlaylistCubit(sl<PlaylistDomainService>()));

  // ── 7. Blocs (factory para que cada screen tenga su instancia) ─
  sl.registerFactory(() => SplashBloc(backend));
  sl.registerFactory(() => SetupBloc(
    sl<ValueNotifier<Locale>>(),
  ));
}

/// Loads the saved performance profile into the global notifier and pushes
/// its concurrency/buffer settings to the Go backend.
Future<void> loadPerformanceProfile() async {
  final cache = sl<SettingsCache>();
  final level = await cache.getPerfLevel();
  final profile = PerformanceProfile.forLevel(level);
  sl<ValueNotifier<PerformanceProfile>>().value = profile;
  // Fire-and-forget: don't block the first frame waiting on a Go RPC that
  // may hang if the backend isn't initialized yet.
  (sl<BackendService>() as ActionsMixin).syncBackendConfig(
    mode: profile.level.key,
    streamCacheMaxMb: profile.streamCacheMaxMb,
    downloadConcurrency: profile.downloadConcurrency,
    streamChunkSize: profile.streamChunkSize,
  );
}
