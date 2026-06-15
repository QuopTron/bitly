import 'package:flutter/material.dart';

class QueueList extends StatelessWidget {
  final List<dynamic> tracks;
  final int currentIndex;

  const QueueList({super.key, required this.tracks, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const Divider(color: Color(0xFF282828), height: 1),
      itemBuilder: (context, index) {
        final isCurrent = index == currentIndex;
        return Container(
          color: isCurrent ? const Color(0xFF1DB954).withValues(alpha: 0.1) : null,
          child: ListTile(
            leading: Icon(
              isCurrent ? Icons.play_arrow : Icons.music_note,
              color: isCurrent ? const Color(0xFF1DB954) : Colors.grey,
            ),
            title: Text(
              tracks[index].toString(),
              style: TextStyle(
                color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }
}
