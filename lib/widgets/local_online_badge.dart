import 'package:flutter/material.dart';

class LocalOnlineBadge extends StatefulWidget {
  final bool isLocal;
  final double? progress;

  const LocalOnlineBadge({
    super.key,
    required this.isLocal,
    this.progress,
  });

  @override
  State<LocalOnlineBadge> createState() => _LocalOnlineBadgeState();
}

class _LocalOnlineBadgeState extends State<LocalOnlineBadge> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color bgColor;
    final Color fgColor;
    final String label;

    if (widget.isLocal) {
      bgColor = colorScheme.tertiaryContainer;
      fgColor = colorScheme.onTertiaryContainer;
      label = 'Local';
    } else {
      bgColor = colorScheme.secondaryContainer;
      fgColor = colorScheme.onSecondaryContainer;
      label = 'En línea';
    }

    final showProgress = !widget.isLocal && widget.progress != null;
    final progressValue = (widget.progress ?? 0.0).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: showProgress
          ? const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 2)
          : const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            showProgress ? '${(progressValue * 100).round()}%' : label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: fgColor,
              height: 1.0,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progressValue),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: fgColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                    minHeight: 3,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
