import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../domain/entities/collection.dart';

class PlaylistTile extends StatelessWidget {
  final Collection playlist;
  final VoidCallback? onTap;

  const PlaylistTile({
    super.key,
    required this.playlist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceHigh,
        child: Icon(Icons.playlist_play, color: theme.colorScheme.primary),
      ),
      title: Text(playlist.name,
          style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
      )),
      subtitle: Text(
        '${playlist.itemCount} canciones',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
