import 'package:flutter/material.dart';
import '../../domain/entities/library_track.dart';
import '../widgets/library_track_tile.dart';
import '../widgets/empty_library_state.dart';

class LibraryTracksPage extends StatelessWidget {
  final List<LibraryTrack> tracks;

  const LibraryTracksPage({super.key, required this.tracks});

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const EmptyLibraryState();
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const Divider(color: Color(0xFF282828), height: 1),
      itemBuilder: (context, index) {
        return LibraryTrackTile(track: tracks[index]);
      },
    );
  }
}
