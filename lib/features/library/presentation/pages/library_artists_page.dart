import 'package:flutter/material.dart';
import '../../domain/entities/library_artist.dart';
import '../widgets/library_artist_card.dart';

class LibraryArtistsPage extends StatelessWidget {
  final List<LibraryArtist> artists;

  const LibraryArtistsPage({super.key, required this.artists});

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const Center(
        child: Text('No artists found', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: artists.length,
      separatorBuilder: (_, _) => const Divider(color: Color(0xFF282828), height: 1),
      itemBuilder: (context, index) {
        return LibraryArtistCard(artist: artists[index]);
      },
    );
  }
}
