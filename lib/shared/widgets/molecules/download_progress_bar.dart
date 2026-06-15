import 'package:flutter/material.dart';
import '../atoms/status_indicator.dart';

class DownloadProgressBar extends StatelessWidget {
  final double progress;
  final String status;
  final int? downloadedBytes;
  final int? totalBytes;

  const DownloadProgressBar({
    super.key,
    required this.progress,
    required this.status,
    this.downloadedBytes,
    this.totalBytes,
  });

  StatusType _statusType() {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'complete':
        return StatusType.success;
      case 'failed':
      case 'error':
        return StatusType.error;
      case 'paused':
      case 'pending':
        return StatusType.warning;
      default:
        return StatusType.info;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            StatusIndicator(status: _statusType(), size: 8),
            const SizedBox(width: 8),
            Text(status, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            if (progress > 0)
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        if (downloadedBytes != null && totalBytes != null) ...[
          const SizedBox(height: 2),
          Text(
            '${_formatBytes(downloadedBytes!)} / ${_formatBytes(totalBytes!)}',
            style: TextStyle(fontSize: 10, color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ],
      ],
    );
  }
}
