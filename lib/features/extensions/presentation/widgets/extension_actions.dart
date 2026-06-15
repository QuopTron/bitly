import 'package:flutter/material.dart';

class ExtensionActions extends StatelessWidget {
  final String extensionId;
  final bool isEnabled;
  final VoidCallback? onToggle;
  final VoidCallback? onSettings;
  final VoidCallback? onRemove;

  const ExtensionActions({
    super.key,
    required this.extensionId,
    required this.isEnabled,
    this.onToggle,
    this.onSettings,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
      onSelected: (value) {
        switch (value) {
          case 'toggle':
            onToggle?.call();
            break;
          case 'settings':
            onSettings?.call();
            break;
          case 'remove':
            onRemove?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                isEnabled ? Icons.toggle_off : Icons.toggle_on,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(isEnabled ? 'Desactivar' : 'Activar'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              const Icon(Icons.settings, size: 20),
              const SizedBox(width: 8),
              const Text('Configuración'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}
