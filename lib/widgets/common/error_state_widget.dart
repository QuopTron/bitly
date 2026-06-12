import 'package:flutter/material.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/constants/layout_constants.dart';

class ErrorStateWidget extends StatelessWidget {
  final String? title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colorScheme.error.withValues(alpha: 0.7)),
            LayoutConstants.gapH8,
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              LayoutConstants.gapH8,
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            if (onRetry != null) ...[
              LayoutConstants.gapH16,
              TextButton(
                onPressed: onRetry,
                child: Text(retryLabel ?? context.l10n.dialogRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
