import 'package:equatable/equatable.dart';
import '../../domain/entities/collection.dart';
import '../../domain/entities/favorite_album.dart';
import '../../domain/entities/wishlist_item.dart';

class CollectionsState extends Equatable {
  final List<Collection> collections;
  final List<FavoriteAlbum> favoriteAlbums;
  final List<WishlistItem> wishlist;
  final bool isLoading;
  final String? error;

  const CollectionsState({
    this.collections = const [],
    this.favoriteAlbums = const [],
    this.wishlist = const [],
    this.isLoading = false,
    this.error,
  });

  CollectionsState copyWith({
    List<Collection>? collections,
    List<FavoriteAlbum>? favoriteAlbums,
    List<WishlistItem>? wishlist,
    bool? isLoading,
    String? error,
  }) =>
      CollectionsState(
        collections: collections ?? this.collections,
        favoriteAlbums: favoriteAlbums ?? this.favoriteAlbums,
        wishlist: wishlist ?? this.wishlist,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  @override
  List<Object?> get props =>
      [collections, favoriteAlbums, wishlist, isLoading, error];
}
