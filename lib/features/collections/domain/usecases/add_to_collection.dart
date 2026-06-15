import '../../data/repositories/collections_repository.dart';

class AddToCollection {
  final CollectionsRepository repository;

  AddToCollection(this.repository);

  Future<void> call(String collectionId, String itemId,
      {Map<String, dynamic>? itemData}) async {
    await repository.addItem(collectionId, itemId, itemData: itemData);
  }
}
