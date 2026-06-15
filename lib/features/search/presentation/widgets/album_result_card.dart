import 'package:flutter/material.dart';

class AlbumResultCard extends StatelessWidget {
  final Map<String, dynamic> album;

  const AlbumResultCard({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    final title = album['title'] as String? ?? 'Unknown';
    final artist = album['artist'] as String? ?? 'Unknown';
    final coverUrl = album['cover_url'] as String? ?? '';
    final trackCount = album['track_count'] as int? ?? 0;

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
                  child: const Icon(Icons.album,
                      color: Colors.white54)),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
        subtitle: Text('$artist  •  $trackCount tracks',
            style: const TextStyle(color: Colors.grey),
            overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right,
            color: Colors.grey),
      ),
    );
  }
}
