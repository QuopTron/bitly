import 'package:get_it/get_it.dart';
import '../../../../core/api/methods.dart';

class LibraryRepository {
  final LibraryMethods _api;

  LibraryRepository() : _api = GetIt.instance<LibraryMethods>();

  Future<Map<String, dynamic>> getLocalLibraryPage(int page, int perPage) async {
    return await _api.getLocalLibraryPage(page, perPage);
  }

  Future<int> getLibraryCount() async {
    return await _api.getLibraryCount();
  }

  Future<bool> deleteEntry(String id) async {
    return await _api.deleteEntry(id);
  }
}
