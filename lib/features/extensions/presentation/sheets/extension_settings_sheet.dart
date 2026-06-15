import 'package:flutter/material.dart';

class ExtensionSettingsSheet extends StatelessWidget {
  final String extensionId;
  final String extensionName;

  const ExtensionSettingsSheet({
    super.key,
    required this.extensionId,
    required this.extensionName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.7,
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
              Text('Configuración de $extensionName',
                  style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              )),
              const SizedBox(height: 24),
              Text('No hay opciones de configuración disponibles.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
            ],
          ),
        );
      },
    );
  }
}
