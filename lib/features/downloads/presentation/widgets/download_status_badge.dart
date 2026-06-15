import 'package:flutter/material.dart';

class DownloadStatusBadge extends StatelessWidget {
  final String status;

  const DownloadStatusBadge({super.key, required this.status});

  Color _getColor() {
    switch (status) {
      case 'completed':
        return const Color(0xFF1DB954);
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.amber;
      case 'downloading':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      case 'paused':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getIcon() {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'pending':
        return Icons.hourglass_empty;
      case 'downloading':
        return Icons.downloading;
      case 'cancelled':
        return Icons.cancel;
      case 'paused':
        return Icons.pause_circle;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 12, color: _getColor()),
          const SizedBox(width: 4),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              color: _getColor(),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
