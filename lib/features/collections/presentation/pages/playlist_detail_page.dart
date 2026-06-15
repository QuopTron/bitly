import 'package:flutter/material.dart';
import '../../../../shared/widgets/atoms/empty_state.dart';

class PlaylistDetailPage extends StatelessWidget {
  final String playlistId;
  final String playlistName;

  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(playlistName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: const EmptyState(
        icon: Icons.music_note,
        title: 'Añade canciones a esta playlist',
      ),
    );
  }
}
