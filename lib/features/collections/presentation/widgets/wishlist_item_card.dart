import 'package:flutter/material.dart';
import '../../domain/entities/wishlist_item.dart';

class WishlistItemCard extends StatelessWidget {
  final WishlistItem item;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const WishlistItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.music_note, color: theme.colorScheme.primary),
        ),
        title: Text(item.trackName,
            style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        subtitle: Text(item.artistName,
            style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
        trailing: onRemove != null
            ? IconButton(
                icon: Icon(Icons.remove_circle_outline,
                    color: theme.colorScheme.error),
                onPressed: onRemove,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
