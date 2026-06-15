import 'package:flutter/material.dart';
import '../../domain/entities/home_section.dart';
import '../widgets/recent_download_card.dart';

class RecentTab extends StatelessWidget {
  final List<SectionItem> items;

  const RecentTab({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Sin descargas recientes',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      );
    }
    return Column(
      children: items.map((item) => RecentDownloadCard(item: item)).toList(),
    );
  }
}
