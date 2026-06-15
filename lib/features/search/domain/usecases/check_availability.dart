import 'package:equatable/equatable.dart';
import '../../data/repositories/search_repository.dart';

class CheckAvailability extends Equatable {
  final SearchRepository repository;

  const CheckAvailability(this.repository);

  Future<bool> call(String trackId) async {
    return repository.checkAvailability(trackId);
  }

  @override
  List<Object?> get props => [repository];
}
