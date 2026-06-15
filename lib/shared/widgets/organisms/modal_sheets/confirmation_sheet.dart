import 'package:flutter/material.dart';
import 'base_bottom_sheet.dart';

class ConfirmationSheet extends StatelessWidget {
  final String title;
  final String message;
  final String acceptLabel;
  final String cancelLabel;
  final VoidCallback? onAccept;
  final VoidCallback? onCancel;
  final Color? acceptColor;

  const ConfirmationSheet({
    super.key,
    required this.title,
    required this.message,
    this.acceptLabel = 'Accept',
    this.cancelLabel = 'Cancel',
    this.onAccept,
    this.onCancel,
    this.acceptColor,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String acceptLabel = 'Accept',
    String cancelLabel = 'Cancel',
    Color? acceptColor,
  }) {
    return BaseBottomSheet.show<bool>(
      context,
      child: ConfirmationSheet(
        title: title,
        message: message,
        acceptLabel: acceptLabel,
        cancelLabel: cancelLabel,
        acceptColor: acceptColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.withValues(alpha: 0.8))),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  onCancel?.call();
                  Navigator.pop(context, false);
                },
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: acceptColor ?? Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  onAccept?.call();
                  Navigator.pop(context, true);
                },
                child: Text(acceptLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
