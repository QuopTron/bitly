import '../../data/repositories/settings_repository.dart';
import '../entities/app_settings.dart';

class LoadSettings {
  final SettingsRepository repository;

  LoadSettings(this.repository);

  Future<AppSettings> call() async {
    return repository.load();
  }
}
