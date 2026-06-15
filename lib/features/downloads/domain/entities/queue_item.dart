import 'package:equatable/equatable.dart';
import 'download_item.dart';

class QueueItem extends Equatable {
  final String id;
  final DownloadItem downloadItem;
  final int priority;
  final DateTime addedAt;

  const QueueItem({
    required this.id,
    required this.downloadItem,
    this.priority = 0,
    required this.addedAt,
  });

  @override
  List<Object?> get props => [id, downloadItem, priority, addedAt];
}
