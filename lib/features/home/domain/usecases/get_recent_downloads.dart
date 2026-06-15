import '../../data/repositories/home_repository.dart';
import '../entities/home_section.dart';

class GetRecentDownloads {
  final HomeRepository _repository;

  GetRecentDownloads(this._repository);

  Future<List<SectionItem>> call() {
    return _repository.getRecentDownloads();
  }
}
