import 'package:flutter/material.dart';
import '../../data/models/download_item_model.dart';
import 'download_status_badge.dart';

class HistoryItemCard extends StatelessWidget {
  final DownloadItemModel item;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  const HistoryItemCard({
    super.key,
    required this.item,
    required this.onRetry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF282828),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.music_note,
            color: Color(0xFF1DB954)),
        title: Text(item.title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(item.artist,
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            DownloadStatusBadge(status: item.status),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.status == 'failed')
              IconButton(
                icon: const Icon(Icons.replay,
                    color: Color(0xFF1DB954), size: 20),
                onPressed: onRetry,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.grey, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
