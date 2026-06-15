import 'package:flutter/material.dart';

class ArtistResultCard extends StatelessWidget {
  final Map<String, dynamic> artist;

  const ArtistResultCard({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['name'] as String? ?? 'Unknown';
    final imageUrl = artist['image_url'] as String? ?? '';
    final genre = artist['genre'] as String? ?? '';

    return Card(
      color: const Color(0xFF282828),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : null,
          backgroundColor: Colors.grey[800],
          child: imageUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.white54)
              : null,
        ),
        title: Text(name,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500)),
        subtitle: genre.isNotEmpty
            ? Text(genre,
                style: const TextStyle(color: Colors.grey))
            : null,
        trailing: const Icon(Icons.chevron_right,
            color: Colors.grey),
      ),
    );
  }
}
