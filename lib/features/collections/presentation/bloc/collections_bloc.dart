import 'package:flutter_bloc/flutter_bloc.dart';
import 'collections_event.dart';
import 'collections_state.dart';
import '../../domain/usecases/get_collections.dart';
import '../../domain/usecases/create_collection.dart';
import '../../domain/usecases/add_to_collection.dart';
import '../../domain/usecases/manage_favorites.dart';

class CollectionsBloc extends Bloc<CollectionsEvent, CollectionsState> {
  final GetCollections _getCollections;
  final CreateCollection _createCollection;
  final AddToCollection _addToCollection;
  final ManageFavorites _manageFavorites;

  CollectionsBloc({
    required GetCollections getCollections,
    required CreateCollection createCollection,
    required AddToCollection addToCollection,
    required ManageFavorites manageFavorites,
  })  : _getCollections = getCollections,
        _createCollection = createCollection,
        _addToCollection = addToCollection,
        _manageFavorites = manageFavorites,
        super(const CollectionsState()) {
    on<LoadCollections>(_onLoad);
    on<CreateCollectionEvent>(_onCreate);
    on<DeleteCollectionEvent>(_onDelete);
    on<AddItemToCollection>(_onAddItem);
    on<RemoveItemFromCollection>(_onRemoveItem);
  }

  Future<void> _onLoad(
      LoadCollections event, Emitter<CollectionsState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final collections = await _getCollections.call();
      final albums = await _manageFavorites.getAlbums();
      emit(state.copyWith(
        collections: collections,
        favoriteAlbums: albums,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onCreate(
      CreateCollectionEvent event, Emitter<CollectionsState> emit) async {
    try {
      await _createCollection.call(event.name, description: event.description);
      final collections = await _getCollections.call();
      emit(state.copyWith(collections: collections));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDelete(
      DeleteCollectionEvent event, Emitter<CollectionsState> emit) async {
    try {
      final collections = await _getCollections.call();
      emit(state.copyWith(collections: collections));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onAddItem(
      AddItemToCollection event, Emitter<CollectionsState> emit) async {
    try {
      await _addToCollection.call(event.collectionId, event.itemId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRemoveItem(
      RemoveItemFromCollection event, Emitter<CollectionsState> emit) async {
    try {
      // await repository.removeItem(event.collectionId, event.itemId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
