import '../../data/repositories/collections_repository.dart';
import '../entities/favorite_album.dart';

class ManageFavorites {
  final CollectionsRepository repository;

  ManageFavorites(this.repository);

  Future<List<FavoriteAlbum>> getAlbums() async {
    return repository.getFavoriteAlbums();
  }

  Future<void> addAlbum(FavoriteAlbum album) async {
    await repository.addFavoriteAlbum(album);
  }

  Future<void> removeAlbum(String id) async {
    await repository.removeFavoriteAlbum(id);
  }
}
