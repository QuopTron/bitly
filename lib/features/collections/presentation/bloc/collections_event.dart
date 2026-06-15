import 'package:equatable/equatable.dart';

abstract class CollectionsEvent extends Equatable {
  const CollectionsEvent();

  @override
  List<Object?> get props => [];
}

class LoadCollections extends CollectionsEvent {}

class CreateCollectionEvent extends CollectionsEvent {
  final String name;
  final String? description;

  const CreateCollectionEvent(this.name, this.description);

  @override
  List<Object?> get props => [name, description];
}

class DeleteCollectionEvent extends CollectionsEvent {
  final String id;

  const DeleteCollectionEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class AddItemToCollection extends CollectionsEvent {
  final String collectionId;
  final String itemId;

  const AddItemToCollection(this.collectionId, this.itemId);

  @override
  List<Object?> get props => [collectionId, itemId];
}

class RemoveItemFromCollection extends CollectionsEvent {
  final String collectionId;
  final String itemId;

  const RemoveItemFromCollection(this.collectionId, this.itemId);

  @override
  List<Object?> get props => [collectionId, itemId];
}
