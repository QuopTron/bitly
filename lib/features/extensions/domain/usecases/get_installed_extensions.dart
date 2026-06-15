import '../entities/extension.dart';
import '../../data/repositories/extension_repository.dart';

class GetInstalledExtensions {
  final ExtensionRepository repository;

  GetInstalledExtensions(this.repository);

  Future<List<Extension>> call() async {
    final models = await repository.getInstalled();
    return models.map((m) => m.toEntity()).toList();
  }
}
