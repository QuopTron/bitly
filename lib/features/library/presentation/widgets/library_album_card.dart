import 'package:flutter/material.dart';
import '../../domain/entities/library_album.dart';

class LibraryAlbumCard extends StatelessWidget {
  final LibraryAlbum album;

  const LibraryAlbumCard({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                width: double.infinity,
                color: const Color(0xFF282828),
                child: album.coverPath != null
                    ? Image.network(album.coverPath!, fit: BoxFit.cover)
                    : const Icon(Icons.album, color: Color(0xFF1DB954), size: 48),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '${album.trackCount} tracks',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
