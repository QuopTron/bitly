import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  final String? coverPath;

  const AlbumArt({super.key, this.coverPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1DB954).withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: coverPath != null
            ? Image.network(coverPath!, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFF282828),
                child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 80),
              ),
      ),
    );
  }
}
