import '../../data/repositories/home_repository.dart';
import '../entities/home_section.dart';

class GetQuickActions {
  final HomeRepository _repository;

  GetQuickActions(this._repository);

  Future<List<SectionItem>> call() {
    return _repository.getQuickActions();
  }
}
