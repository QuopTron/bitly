import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../domain/entities/store_extension.dart';

class StoreExtensionCard extends StatelessWidget {
  final StoreExtension extension;
  final VoidCallback? onInstall;

  const StoreExtensionCard({
    super.key,
    required this.extension,
    this.onInstall,
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
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.extension, color: theme.colorScheme.primary),
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
                    '${extension.author} - ${extension.category}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.download, size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${extension.downloads}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.star, size: 14,
                          color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        extension.rating.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onInstall,
              child: const Text('Instalar'),
            ),
          ],
        ),
      ),
    );
  }
}
