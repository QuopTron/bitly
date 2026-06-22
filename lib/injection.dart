import 'dart:io' show Platform, Directory;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'core/backend/backend_service.dart';
import 'core/backend/android_backend.dart';
import 'core/backend/desktop_backend.dart';
import 'features/splash/bloc/splash_bloc.dart';
import 'features/setup/bloc/setup_bloc.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl.registerLazySingleton<ValueNotifier<Locale>>(
    () => ValueNotifier(const Locale('es')),
  );

  BackendService backend;
  if (Platform.isAndroid) {
    backend = AndroidBackend();
  } else if (Platform.isWindows) {
    final exePath =
        '${Directory.current.path}\\windows\\backend\\bitly-backend.exe';
    backend = DesktopBackend(executablePath: exePath);
  } else {
    const host = '127.0.0.1';
    backend = DesktopBackend(baseUrl: 'http://$host:8080/rpc');
  }
  sl.registerLazySingleton<BackendService>(() => backend);

  sl.registerFactory(() => SplashBloc(sl<BackendService>()));
  sl.registerFactory(() => SetupBloc(
    sl<BackendService>(),
    sl<ValueNotifier<Locale>>(),
  ));
}
