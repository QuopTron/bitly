import 'package:flutter/material.dart';

class MiniPlayerBar extends StatelessWidget {
  final String? trackTitle;
  final String? artistName;
  final String? coverUrl;
  final bool isPlaying;
  final double progress;
  final VoidCallback? onPlayPause;
  final VoidCallback? onTap;

  const MiniPlayerBar({
    super.key,
    this.trackTitle,
    this.artistName,
    this.coverUrl,
    this.isPlaying = false,
    this.progress = 0,
    this.onPlayPause,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: coverUrl != null
                        ? Image.network(coverUrl!, width: 44, height: 44, fit: BoxFit.cover)
                        : Container(
                            width: 44,
                            height: 44,
                            color: Colors.grey.withValues(alpha: 0.2),
                            child: const Icon(Icons.music_note, color: Colors.grey, size: 24),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trackTitle ?? 'No track',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artistName != null)
                          Text(
                            artistName!,
                            style: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.green,
                      size: 36,
                    ),
                    onPressed: onPlayPause,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
