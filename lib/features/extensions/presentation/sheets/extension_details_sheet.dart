import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../domain/entities/extension.dart';

class ExtensionDetailsSheet extends StatelessWidget {
  final Extension extension;

  const ExtensionDetailsSheet({
    super.key,
    required this.extension,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(extension.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              )),
              const SizedBox(height: 4),
              Text(
                'v${extension.version} por ${extension.author}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (extension.description.isNotEmpty) ...[
                Text('Descripción',
                    style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                )),
                const SizedBox(height: 4),
                Text(extension.description),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Chip(
                    label: Text(
                      extension.type,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      extension.isEnabled ? 'Activada' : 'Desactivada',
                      style: TextStyle(
                        fontSize: 12,
                        color: extension.isEnabled
                            ? AppColors.success
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
