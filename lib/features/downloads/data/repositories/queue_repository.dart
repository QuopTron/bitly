import 'package:equatable/equatable.dart';
import '../datasources/download_local_source.dart';
import '../models/queue_item_model.dart';

class QueueRepository extends Equatable {
  final DownloadLocalSource localSource;

  const QueueRepository(this.localSource);

  Future<List<QueueItemModel>> getQueue() async {
    return await localSource.getQueue();
  }

  Future<void> addToQueue(QueueItemModel item) async {
    await localSource.addToQueue(item);
  }

  Future<void> removeFromQueue(String itemId) async {
    await localSource.removeFromQueue(itemId);
  }

  Future<void> clearQueue() async {
    await localSource.clearQueue();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final queue = await localSource.getQueue();
    if (oldIndex < 0 ||
        oldIndex >= queue.length ||
        newIndex < 0 ||
        newIndex >= queue.length) {
      return;
    }
    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);
    await localSource.saveQueue(queue);
  }

  @override
  List<Object?> get props => [localSource];
}
