import 'package:get_it/get_it.dart';
import '../../data/repositories/library_repository.dart';

class DeleteLibraryItem {
  final LibraryRepository _repository;

  DeleteLibraryItem() : _repository = GetIt.instance<LibraryRepository>();

  Future<bool> call(String id) async {
    return await _repository.deleteEntry(id);
  }
}
