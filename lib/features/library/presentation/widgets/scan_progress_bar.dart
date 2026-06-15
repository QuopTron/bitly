import 'package:flutter/material.dart';
import '../../domain/entities/scan_progress.dart';

class ScanProgressBar extends StatelessWidget {
  final ScanProgress? progress;
  final VoidCallback onCancel;

  const ScanProgressBar({
    super.key,
    this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final pct = progress?.percentage ?? 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1DB954).withValues(alpha: 0.15),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF1DB954),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: const Color(0xFF282828),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                if (progress != null)
                  Text(
                    progress!.currentFile.isNotEmpty
                        ? progress!.currentFile
                        : 'Scanning...',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
