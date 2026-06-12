import 'package:flutter/material.dart';
import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/widgets/glass_container.dart';

class NeonSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;
  final double padding;

  const NeonSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
    this.padding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
      child: Row(
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 20),
            ),
          if (icon != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    shadows: [
                      Shadow(
                        color: isDark ? AppTheme.primaryDark.withOpacity(0.2) : AppTheme.primaryLight.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: action!,
            ),
        ],
      ),
    );
  }
}

class NeonGridContainer extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets? padding;
  final double itemBorderRadius;

  const NeonGridContainer({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.padding,
    this.itemBorderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
        children: children.map((child) =>
          NeonCard(
            margin: EdgeInsets.zero,
            borderRadius: itemBorderRadius,
            child: child,
          )
        ).toList(),
      ),
    );
  }
}

class NeonListItem extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final EdgeInsets? padding;

  const NeonListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 16,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onTap,
      borderRadius: borderRadius,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) const SizedBox(height: 4),
                if (subtitle != null) subtitle!,
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: trailing!,
            ),
        ],
      ),
    );
  }
}

class NeonEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final double iconSize;

  const NeonEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: NeonCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: colorScheme.onSurfaceVariant,
              shadows: [
                Shadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.2) : AppTheme.primaryLight.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class NeonLoadingState extends StatelessWidget {
  final String? message;
  final double size;

  const NeonLoadingState({
    super.key,
    this.message,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: NeonCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: colorScheme.primary,
                backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NeonErrorState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;

  const NeonErrorState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.error;

    return Center(
      child: NeonCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: effectiveIconColor,
              shadows: [
                Shadow(
                  color: effectiveIconColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

extension NeonColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get primaryNeon => isDarkMode ? AppTheme.primaryDark : AppTheme.primaryLight;
  Color get glowNeon => isDarkMode ? AppTheme.glowDark : AppTheme.glowLight;
  Color get surfaceNeon => isDarkMode ? AppTheme.surfaceDark : AppTheme.surfaceLight;
  Color get backgroundNeon => isDarkMode ? AppTheme.bgPrimaryDark : AppTheme.bgPrimaryLight;
}

class NeonShadows {
  static BoxShadow get primary => BoxShadow(
    color: AppTheme.primaryDark.withOpacity(0.3),
    blurRadius: 20,
    offset: const Offset(0, 8),
    spreadRadius: 2,
  );

  static BoxShadow get light => BoxShadow(
    color: AppTheme.primaryLight.withOpacity(0.3),
    blurRadius: 20,
    offset: const Offset(0, 8),
    spreadRadius: 2,
  );

  static BoxShadow get innerGlowDark => BoxShadow(
    color: AppTheme.primaryDark.withOpacity(0.1),
    blurRadius: 10,
    offset: const Offset(0, 0),
    spreadRadius: 2,
  );

  static BoxShadow get innerGlowLight => BoxShadow(
    color: AppTheme.primaryLight.withOpacity(0.1),
    blurRadius: 10,
    offset: const Offset(0, 0),
    spreadRadius: 2,
  );
}
