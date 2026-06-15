import '../../data/repositories/settings_repository.dart';
import '../entities/app_settings.dart';

class UpdateSetting {
  final SettingsRepository repository;

  UpdateSetting(this.repository);

  Future<void> call(AppSettings Function(AppSettings) updater) async {
    final current = await repository.load();
    final updated = updater(current);
    await repository.save(updated);
  }
}
