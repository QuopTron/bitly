import '../../data/repositories/extension_repository.dart';

class RemoveExtension {
  final ExtensionRepository repository;

  RemoveExtension(this.repository);

  Future<void> call(String id) async {
    await repository.remove(id);
  }
}
