import 'package:get_it/get_it.dart';
import 'data/repositories/settings_repository.dart';
import 'domain/usecases/load_settings.dart';
import 'domain/usecases/save_settings.dart';
import 'domain/usecases/reset_settings.dart';
import 'domain/usecases/update_setting.dart';
import 'presentation/bloc/settings_bloc/settings_bloc.dart';
import 'presentation/bloc/appearance_bloc/appearance_bloc.dart';

class SettingsModule {
  static void register() {
    final sl = GetIt.instance;

    sl.registerLazySingleton<SettingsRepository>(
      () => SettingsRepository(),
    );

    sl.registerLazySingleton<LoadSettings>(
      () => LoadSettings(sl<SettingsRepository>()),
    );
    sl.registerLazySingleton<SaveSettings>(
      () => SaveSettings(sl<SettingsRepository>()),
    );
    sl.registerLazySingleton<ResetSettings>(
      () => ResetSettings(sl<SettingsRepository>()),
    );
    sl.registerLazySingleton<UpdateSetting>(
      () => UpdateSetting(sl<SettingsRepository>()),
    );

    sl.registerFactory<SettingsBloc>(
      () => SettingsBloc(
        loadSettings: sl<LoadSettings>(),
        saveSettings: sl<SaveSettings>(),
        resetSettings: sl<ResetSettings>(),
      ),
    );

    sl.registerFactory<AppearanceBloc>(
      () => AppearanceBloc(sl<SettingsRepository>()),
    );
  }
}
