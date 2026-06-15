import 'package:flutter/material.dart';
import '../../domain/entities/library_track.dart';

class LibraryTrackTile extends StatelessWidget {
  final LibraryTrack track;

  const LibraryTrackTile({super.key, required this.track});

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 48,
          height: 48,
          color: const Color(0xFF282828),
          child: track.coverPath != null
              ? Image.network(track.coverPath!, fit: BoxFit.cover)
              : const Icon(Icons.music_note, color: Color(0xFF1DB954)),
        ),
      ),
      title: Text(
        track.title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.artist,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDuration(track.duration),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
            onSelected: (v) {},
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'play', child: Text('Play')),
              const PopupMenuItem(value: 'add', child: Text('Add to queue')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
