import '../../data/repositories/collections_repository.dart';

class CreateCollection {
  final CollectionsRepository repository;

  CreateCollection(this.repository);

  Future<void> call(String name, {String? description}) async {
    await repository.create(name, description: description);
  }
}
