import 'package:flutter/material.dart';
import '../../domain/entities/library_album.dart';
import '../widgets/library_album_card.dart';

class LibraryAlbumsPage extends StatelessWidget {
  final List<LibraryAlbum> albums;

  const LibraryAlbumsPage({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const Center(
        child: Text('No albums found', style: TextStyle(color: Colors.grey)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        return LibraryAlbumCard(album: albums[index]);
      },
    );
  }
}
