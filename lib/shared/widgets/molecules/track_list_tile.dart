import 'package:flutter/material.dart';
import '../atoms/quality_badge.dart';

class TrackListTile extends StatelessWidget {
  final String title;
  final String artist;
  final String duration;
  final String? quality;
  final String? coverUrl;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  const TrackListTile({
    super.key,
    required this.title,
    required this.artist,
    required this.duration,
    this.quality,
    this.coverUrl,
    this.isPlaying = false,
    this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: coverUrl != null
            ? Image.network(coverUrl!, width: 48, height: 48, fit: BoxFit.cover)
            : Container(
                width: 48,
                height: 48,
                color: Colors.grey.withValues(alpha: 0.2),
                child: const Icon(Icons.music_note, color: Colors.grey),
              ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
          color: isPlaying ? Colors.green : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(artist, overflow: TextOverflow.ellipsis),
          ),
          if (quality != null) ...[
            const SizedBox(width: 8),
            QualityBadge(quality: quality!),
          ],
          const SizedBox(width: 8),
          Text(duration, style: const TextStyle(fontSize: 12)),
        ],
      ),
      onTap: onTap,
      trailing: onMenu != null
          ? IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: onMenu,
            )
          : null,
    );
  }
}
