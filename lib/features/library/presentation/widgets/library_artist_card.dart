import 'package:flutter/material.dart';
import '../../domain/entities/library_artist.dart';

class LibraryArtistCard extends StatelessWidget {
  final LibraryArtist artist;

  const LibraryArtistCard({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF282828),
        backgroundImage: artist.imagePath != null ? NetworkImage(artist.imagePath!) : null,
        child: artist.imagePath == null
            ? const Icon(Icons.person, color: Color(0xFF1DB954), size: 28)
            : null,
      ),
      title: Text(
        artist.name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${artist.albumCount} albums · ${artist.trackCount} tracks',
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
    );
  }
}
