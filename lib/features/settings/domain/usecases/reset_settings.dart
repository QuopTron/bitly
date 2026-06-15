import '../../data/repositories/settings_repository.dart';

class ResetSettings {
  final SettingsRepository repository;

  ResetSettings(this.repository);

  Future<void> call() async {
    await repository.reset();
  }
}
