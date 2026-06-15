import '../../data/repositories/extension_repository.dart';

class ToggleExtension {
  final ExtensionRepository repository;

  ToggleExtension(this.repository);

  Future<void> call(String id, bool enabled) async {
    await repository.setEnabled(id, enabled);
  }
}
