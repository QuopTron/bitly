import 'package:equatable/equatable.dart';
import '../../../../core/api/methods.dart';

class SearchRepository extends Equatable {
  final SearchMethods _methods;

  const SearchRepository(this._methods);

  Future<List<Map<String, dynamic>>> searchTracks(String query,
      {String type = 'track', int page = 1, int limit = 20}) async {
    final tracks = await _methods.searchTracks(query);
    return tracks;
  }

  Future<Map<String, dynamic>> searchByUrl(String url) async {
    return await _methods.searchByUrl(url);
  }

  Future<bool> checkAvailability(String trackId) async {
    return await _methods.checkAvailability(trackId, 'auto');
  }

  Future<List<String>> getSearchProviders() async {
    return await _methods.getSearchProviders();
  }

  @override
  List<Object?> get props => [_methods];
}
