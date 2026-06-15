import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  const ErrorDialog({
    super.key,
    this.title = 'Error',
    required this.message,
    this.retryLabel,
    this.onRetry,
    this.onClose,
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Error',
    required String message,
    String? retryLabel,
    VoidCallback? onRetry,
    VoidCallback? onClose,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ErrorDialog(
        title: title,
        message: message,
        retryLabel: retryLabel,
        onRetry: onRetry,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 20),
            if (onRetry != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(retryLabel ?? 'Retry'),
                  onPressed: () {
                    onRetry?.call();
                    Navigator.pop(context);
                  },
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                onClose?.call();
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
