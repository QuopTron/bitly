import 'package:equatable/equatable.dart';
import '../../data/repositories/queue_repository.dart';
import '../../data/models/queue_item_model.dart';

class GetQueue extends Equatable {
  final QueueRepository repository;

  const GetQueue(this.repository);

  Future<List<QueueItemModel>> call() async {
    return await repository.getQueue();
  }

  @override
  List<Object?> get props => [repository];
}
