import 'package:get_it/get_it.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/models/library_item_model.dart';
import '../entities/library_track.dart';

class GetLibraryTracks {
  final LibraryRepository _repository;

  GetLibraryTracks() : _repository = GetIt.instance<LibraryRepository>();

  Future<List<LibraryTrack>> call({int page = 0, int perPage = 50}) async {
    final result = await _repository.getLocalLibraryPage(page, perPage);
    final items = (result['items'] as List<dynamic>?) ?? [];
    return items.map((json) {
      final model = LibraryItemModel.fromJson(json as Map<String, dynamic>);
      return LibraryTrack(
        id: model.id,
        title: model.title,
        artist: model.artist,
        album: model.album,
        duration: model.duration,
        fileSize: model.fileSize,
        format: model.format,
        addedAt: model.addedAt,
        coverPath: model.coverPath,
      );
    }).toList();
  }
}
