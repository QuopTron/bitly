import 'package:flutter/material.dart';

class DownloadProgressIndicator extends StatelessWidget {
  final double progress;
  final bool circular;

  const DownloadProgressIndicator({
    super.key,
    required this.progress,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    if (circular) {
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress / 100 : null,
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF1DB954)),
              backgroundColor: const Color(0xFF282828),
            ),
          ),
          Text('${progress.toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress / 100 : null,
            minHeight: 4,
            valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1DB954)),
            backgroundColor: const Color(0xFF121212),
          ),
        ),
        const SizedBox(height: 2),
        Text('${progress.toStringAsFixed(0)}%',
            style: const TextStyle(
                color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}
