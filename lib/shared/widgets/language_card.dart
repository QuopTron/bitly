import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/helpers/responsive.dart';

class LanguageCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const LanguageCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: r.languageCardVPadding,
          horizontal: r.languageCardHPadding,
        ),
        margin: EdgeInsets.symmetric(
          horizontal: r.languageCardMargin,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1)
              : onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : onBg.withValues(alpha: 0.1),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: r.languageCardIconSize,
              height: r.languageCardIconSize,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: r.languageCardIconSize * 0.55),
            ),
            SizedBox(width: r.spacingM),
            Text(
              name,
              style: TextStyle(
                fontSize: r.subtitleSize,
                color: selected ? onBg : onBg.withValues(alpha: 0.7),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (selected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: r.languageCheckSize, color: isDark ? Colors.black : Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
