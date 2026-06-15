import 'package:get_it/get_it.dart';
import '../../data/repositories/library_repository.dart';
import '../entities/library_artist.dart';

class GetLibraryArtists {
  final LibraryRepository _repository;

  GetLibraryArtists() : _repository = GetIt.instance<LibraryRepository>();

  Future<List<LibraryArtist>> call() async {
    final result = await _repository.getLocalLibraryPage(0, 100);
    final items = (result['items'] as List<dynamic>?) ?? [];
    final Map<String, Map<String, dynamic>> artistMap = {};
    for (final json in items) {
      final m = json as Map<String, dynamic>;
      final artist = m['artist'] as String? ?? '';
      if (artist.isEmpty) continue;
      if (!artistMap.containsKey(artist)) {
        artistMap[artist] = {
          'id': m['id'] as String? ?? '',
          'name': artist,
          'cover_path': m['cover_path'] as String?,
          'track_count': 0,
        };
      }
      artistMap[artist]!['track_count'] = (artistMap[artist]!['track_count'] as int) + 1;
    }
    return artistMap.values.map((m) => LibraryArtist(
      id: m['id'] as String,
      name: m['name'] as String,
      imagePath: m['cover_path'] as String?,
      albumCount: 0,
      trackCount: m['track_count'] as int,
    )).toList();
  }
}
