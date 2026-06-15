import 'package:flutter/material.dart';

class TrackResultCard extends StatelessWidget {
  final Map<String, dynamic> track;

  const TrackResultCard({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final title = track['title'] as String? ?? 'Unknown';
    final artist = track['artist'] as String? ?? 'Unknown';
    final coverUrl = track['cover_url'] as String? ?? '';
    final duration = track['duration'] as int? ?? 0;
    final quality = track['quality'] as String? ?? '128';
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).toString().padLeft(2, '0');

    return Card(
      color: const Color(0xFF282828),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: coverUrl.isNotEmpty
              ? Image.network(coverUrl,
                  width: 48, height: 48, fit: BoxFit.cover)
              : Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note,
                      color: Colors.white54)),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
        subtitle: Text('$artist  •  $minutes:$seconds',
            style: const TextStyle(color: Colors.grey),
            overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(quality,
                  style: const TextStyle(
                      color: Color(0xFF1DB954), fontSize: 11)),
            ),
            IconButton(
              icon: const Icon(Icons.download,
                  color: Color(0xFF1DB954), size: 20),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
