import '../../data/repositories/collections_repository.dart';
import '../entities/collection.dart';

class GetCollections {
  final CollectionsRepository repository;

  GetCollections(this.repository);

  Future<List<Collection>> call() async {
    return repository.getAll();
  }
}
