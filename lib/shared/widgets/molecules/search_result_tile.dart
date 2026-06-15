import 'package:flutter/material.dart';
import '../atoms/source_icon.dart';

class SearchResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String source;
  final String? coverUrl;
  final VoidCallback? onTap;

  const SearchResultTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.source,
    this.coverUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: coverUrl != null
            ? Image.network(coverUrl!, width: 48, height: 48, fit: BoxFit.cover)
            : Container(
                width: 48,
                height: 48,
                color: Colors.grey.withValues(alpha: 0.2),
                child: SourceIcon(source: source, size: 24),
              ),
      ),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
      trailing: SourceIcon(source: source),
      onTap: onTap,
    );
  }
}
