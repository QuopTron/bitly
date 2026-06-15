import 'package:flutter/material.dart';

class AlbumCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? coverUrl;
  final VoidCallback? onTap;

  const AlbumCard({
    super.key,
    required this.title,
    required this.artist,
    this.coverUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: coverUrl != null
                  ? Image.network(coverUrl!, fit: BoxFit.cover, width: double.infinity)
                  : Container(
                      color: Colors.grey.withValues(alpha: 0.2),
                      child: const Center(
                        child: Icon(Icons.album, size: 48, color: Colors.grey),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            artist,
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
