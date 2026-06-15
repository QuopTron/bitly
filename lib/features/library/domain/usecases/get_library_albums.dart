import 'package:get_it/get_it.dart';
import '../../data/repositories/library_repository.dart';
import '../entities/library_album.dart';

class GetLibraryAlbums {
  final LibraryRepository _repository;

  GetLibraryAlbums() : _repository = GetIt.instance<LibraryRepository>();

  Future<List<LibraryAlbum>> call() async {
    final result = await _repository.getLocalLibraryPage(0, 100);
    final groups = (result['album_groups'] as List<dynamic>?) ?? [];
    return groups.map((json) {
      final m = json as Map<String, dynamic>;
      return LibraryAlbum(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        artist: m['artist'] as String? ?? '',
        coverPath: m['cover_path'] as String?,
        trackCount: (m['track_count'] as num?)?.toInt() ?? 0,
        year: (m['year'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}
