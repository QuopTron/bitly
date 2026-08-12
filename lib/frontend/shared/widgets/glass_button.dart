import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassButton extends StatelessWidget {
  final String? label;
  final Widget? icon;
  final Widget? customChild;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double borderRadius;
  final Color accent;

  const GlassButton({
    super.key,
    this.label,
    this.icon,
    this.customChild,
    required this.onPressed,
    this.isLoading = false,
    this.height = 38,
    this.borderRadius = 22,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent.withValues(alpha: enabled ? 0.15 : 0.04),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(
              color: accent.withValues(alpha: enabled ? 0.4 : 0.08),
              width: 1,
            ),
          ),
        ),
        onPressed: onPressed,
        child: customChild ?? _content(accent, enabled),
      ),
    );
  }

  Widget _content(Color accent, bool enabled) {
    if (isLoading) {
      return SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: accent.withValues(alpha: 0.7)),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 6)],
        if (label != null)
          Text(label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: enabled ? 1 : 0.35),
            ),
          ),
      ],
    );
  }
}


