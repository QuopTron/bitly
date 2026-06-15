import 'package:get_it/get_it.dart';
import '../../domain/entities/collection.dart';
import '../../domain/entities/favorite_album.dart';
import '../../domain/entities/wishlist_item.dart';

class CollectionsRepository {
  static CollectionsRepository get instance =>
      GetIt.I<CollectionsRepository>();

  Future<List<Collection>> getAll() async {
    // TODO: Integrate with backend RPC methods
    return [];
  }

  Future<Collection?> getById(String id) async {
    // TODO: Integrate with backend
    return null;
  }

  Future<void> create(String name, {String? description}) async {
    // TODO: Integrate with backend
  }

  Future<void> delete(String id) async {
    // TODO: Integrate with backend
  }

  Future<void> addItem(String collectionId, String itemId,
      {Map<String, dynamic>? itemData}) async {
    // TODO: Integrate with backend
  }

  Future<void> removeItem(String collectionId, String itemId) async {
    // TODO: Integrate with backend
  }

  Future<List<FavoriteAlbum>> getFavoriteAlbums() async {
    return [];
  }

  Future<void> addFavoriteAlbum(FavoriteAlbum album) async {
    // TODO: Integrate with backend
  }

  Future<void> removeFavoriteAlbum(String id) async {
    // TODO: Integrate with backend
  }

  Future<List<WishlistItem>> getWishlist() async {
    return [];
  }

  Future<void> addToWishlist(WishlistItem item) async {
    // TODO: Integrate with backend
  }

  Future<void> removeFromWishlist(String id) async {
    // TODO: Integrate with backend
  }
}
