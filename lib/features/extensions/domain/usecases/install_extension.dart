import '../../data/repositories/extension_repository.dart';

class InstallExtension {
  final ExtensionRepository repository;

  InstallExtension(this.repository);

  Future<void> call(String path) async {
    await repository.install(path);
  }
}
