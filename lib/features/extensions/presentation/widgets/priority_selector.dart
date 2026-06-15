import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';

class PrioritySelector extends StatelessWidget {
  final String extensionId;
  final int currentPriority;
  final ValueChanged<int>? onChanged;

  const PrioritySelector({
    super.key,
    required this.extensionId,
    required this.currentPriority,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.low_priority,
            size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('Prioridad: ', style: theme.textTheme.bodySmall),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$currentPriority',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
