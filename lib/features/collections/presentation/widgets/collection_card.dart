import 'package:flutter/material.dart';
import '../../domain/entities/collection.dart';

class CollectionCard extends StatelessWidget {
  final Collection collection;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const CollectionCard({
    super.key,
    required this.collection,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            collection.type == 'playlist'
                ? Icons.playlist_play
                : Icons.folder,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(collection.name,
            style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        subtitle: Text(
          '${collection.itemCount} elementos',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: Icon(Icons.delete_outline,
                    color: theme.colorScheme.error),
                onPressed: onDelete,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
