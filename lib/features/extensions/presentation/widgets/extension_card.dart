import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../domain/entities/extension.dart';

class ExtensionCard extends StatelessWidget {
  final Extension extension;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  const ExtensionCard({
    super.key,
    required this.extension,
    this.onTap,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: extension.isEnabled
                  ? theme.colorScheme.primaryContainer
                  : AppColors.surfaceHigh,
              child: Icon(
                Icons.extension,
                color: extension.isEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(extension.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 2),
                  Text(
                    'v${extension.version} - ${extension.author}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (extension.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      extension.description,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: extension.isEnabled,
              activeThumbColor: theme.colorScheme.primary,
              onChanged: onToggle != null ? (_) => onToggle!() : null,
            ),
          ],
        ),
      ),
    );
  }
}
