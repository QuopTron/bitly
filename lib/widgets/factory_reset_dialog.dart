import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitly/services/núcleo/app_reset_service.dart';
import 'package:bitly/l10n/l10n.dart';

class FactoryResetDialog extends StatefulWidget {
  const FactoryResetDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const FactoryResetDialog(),
    );
  }

  @override
  State<FactoryResetDialog> createState() => _FactoryResetDialogState();
}

class _FactoryResetDialogState extends State<FactoryResetDialog> {
  bool _deleteFiles = false;
  bool _isResetting = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    if (_isResetting) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Restableciendo aplicación...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Por favor, no cierres la aplicación.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 8),
          const Text('Restablecimiento de fábrica'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esto eliminará permanentemente todas tus configuraciones, historial de descargas y colecciones guardadas.',
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _deleteFiles,
            onChanged: (val) => setState(() => _deleteFiles = val ?? false),
            title: const Text('Eliminar también archivos de música'),
            subtitle: const Text(
              'Borra físicamente las canciones descargadas del almacenamiento.',
              style: TextStyle(fontSize: 11),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            'Esta acción NO se puede deshacer.',
            style: TextStyle(
              color: colorScheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.dialogCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () async {
            setState(() => _isResetting = true);
            try {
              await AppResetService.resetEverything(deleteFiles: _deleteFiles);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aplicación restablecida. Reiniciando...')),
                );
                // exit the process so the app reopens fresh
                await Future.delayed(const Duration(milliseconds: 500));
                exit(0);
              }
            } catch (e) {
              if (mounted) {
                setState(() => _isResetting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al restablecer: $e')),
                );
              }
            }
          },
          child: const Text('Restablecer ahora'),
        ),
      ],
    );
  }
}
