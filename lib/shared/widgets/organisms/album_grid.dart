import 'package:flutter/material.dart';
import '../molecules/album_card.dart';

class Album {
  final String id;
  final String title;
  final String artist;
  final String? coverUrl;

  Album({
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl,
  });
}

class AlbumGrid extends StatelessWidget {
  final List<Album> albums;
  final void Function(Album album)? onAlbumTap;
  final int crossAxisCount;

  const AlbumGrid({
    super.key,
    required this.albums,
    this.onAlbumTap,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const Center(child: Text('No albums'));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return AlbumCard(
          title: album.title,
          artist: album.artist,
          coverUrl: album.coverUrl,
          onTap: () => onAlbumTap?.call(album),
        );
      },
    );
  }
}
