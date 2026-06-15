import '../../data/repositories/settings_repository.dart';
import '../entities/app_settings.dart';

class SaveSettings {
  final SettingsRepository repository;

  SaveSettings(this.repository);

  Future<void> call(AppSettings settings) async {
    await repository.save(settings);
  }
}
