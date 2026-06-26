import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'core/backend/backend_service.dart';
import 'core/backend/android_backend.dart';
import 'core/backend/desktop_backend.dart';
import 'core/backend/ios_backend.dart';
import 'features/splash/bloc/splash_bloc.dart';
import 'features/setup/bloc/setup_bloc.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl.registerLazySingleton<ValueNotifier<Locale>>(
    () => ValueNotifier(const Locale('es')),
  );

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

  sl.registerFactory(() => SplashBloc(sl<BackendService>()));
  sl.registerFactory(() => SetupBloc(
    sl<BackendService>(),
    sl<ValueNotifier<Locale>>(),
  ));
}
