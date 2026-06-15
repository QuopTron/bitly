import 'package:flutter/material.dart';
import '../../../library/data/models/library_item_model.dart';

class QueueSheet extends StatelessWidget {
  final List<LibraryItemModel> tracks;
  final int currentIndex;
  final ValueChanged<int> onRemove;

  const QueueSheet({
    super.key,
    required this.tracks,
    required this.currentIndex,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Playback Queue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${tracks.length} tracks', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
          const Divider(color: Color(0xFF282828)),
          Expanded(
            child: ListView.separated(
              itemCount: tracks.length,
              separatorBuilder: (_, _) => const Divider(color: Color(0xFF282828), height: 1),
              itemBuilder: (context, index) {
                final isCurrent = index == currentIndex;
                return ListTile(
                  leading: Icon(
                    isCurrent ? Icons.play_arrow : Icons.music_note,
                    color: isCurrent ? const Color(0xFF1DB954) : Colors.grey,
                  ),
                  title: Text(
                    tracks[index].title,
                    style: TextStyle(
                      color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(tracks[index].artist, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                    onPressed: () => onRemove(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
