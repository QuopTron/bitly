import 'package:flutter/material.dart';
import '../../domain/entities/home_section.dart';

class RecentDownloadCard extends StatelessWidget {
  final SectionItem item;

  const RecentDownloadCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1DB954).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, color: const Color(0xFF1DB954)),
        ),
        title: Text(
          item.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          item.subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        trailing: const Icon(Icons.play_circle_outline, color: Color(0xFF1DB954)),
        onTap: () {},
      ),
    );
  }
}
