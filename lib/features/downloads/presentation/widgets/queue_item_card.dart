import 'package:flutter/material.dart';
import '../../data/models/queue_item_model.dart';
import 'progress_indicator.dart';

class QueueItemCard extends StatelessWidget {
  final QueueItemModel item;
  final VoidCallback onCancel;

  const QueueItemCard({
    super.key,
    required this.item,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF282828),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.music_note,
            color: Color(0xFF1DB954)),
        title: Text('Download #${item.downloadItemId}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Priority: ${item.priority}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            const DownloadProgressIndicator(progress: 0),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close,
              color: Colors.red, size: 20),
          onPressed: onCancel,
        ),
      ),
    );
  }
}
