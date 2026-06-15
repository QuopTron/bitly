import 'package:equatable/equatable.dart';
import '../../data/repositories/search_repository.dart';

class SearchTracks extends Equatable {
  final SearchRepository repository;

  const SearchTracks(this.repository);

  Future<List<Map<String, dynamic>>> call(String query,
      {String type = 'track', int page = 1, int limit = 20}) async {
    return repository.searchTracks(query,
        type: type, page: page, limit: limit);
  }

  @override
  List<Object?> get props => [repository];
}
