import 'package:equatable/equatable.dart';
import '../../data/repositories/queue_repository.dart';
import '../../data/models/queue_item_model.dart';

class AddToQueueUseCase extends Equatable {
  final QueueRepository repository;

  const AddToQueueUseCase(this.repository);

  Future<void> call(QueueItemModel item) async {
    await repository.addToQueue(item);
  }

  @override
  List<Object?> get props => [repository];
}
