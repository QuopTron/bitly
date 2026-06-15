import 'package:equatable/equatable.dart';
import '../../data/repositories/search_repository.dart';

class SearchByUrl extends Equatable {
  final SearchRepository repository;

  const SearchByUrl(this.repository);

  Future<Map<String, dynamic>> call(String url) async {
    return repository.searchByUrl(url);
  }

  @override
  List<Object?> get props => [repository];
}
