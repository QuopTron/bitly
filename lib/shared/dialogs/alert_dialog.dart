import 'package:flutter/material.dart';

class AppAlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback? onConfirm;
  final IconData? icon;

  const AppAlertDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel = 'OK',
    this.onConfirm,
    this.icon,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'OK',
    VoidCallback? onConfirm,
    IconData? icon,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AppAlertDialog(
        title: title,
        message: message,
        buttonLabel: buttonLabel,
        onConfirm: onConfirm,
        icon: icon,
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
            if (icon != null) ...[
              Icon(icon, size: 48, color: Colors.green),
              const SizedBox(height: 12),
            ],
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  onConfirm?.call();
                  Navigator.pop(context);
                },
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
