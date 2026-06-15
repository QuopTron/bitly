import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../domain/entities/extension.dart';

class ExtensionListTile extends StatelessWidget {
  final Extension extension;
  final VoidCallback? onTap;

  const ExtensionListTile({
    super.key,
    required this.extension,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: extension.isEnabled
            ? theme.colorScheme.primaryContainer
            : AppColors.surfaceHigh,
        child: Icon(
          Icons.extension,
          color: extension.isEnabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(extension.name,
          style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
      )),
      subtitle: Text('v${extension.version}',
          style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      )),
      trailing: Icon(Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
