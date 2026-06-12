import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:bitly/theme/app_theme.dart';

class NeonScaffold extends StatelessWidget {
  final Widget body;
  final AppBar? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool useGradient;

  const NeonScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = backgroundColor ??
        (isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimaryLight);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: useGradient
          ? Container(
              decoration: BoxDecoration(
                gradient: isDark ? AppTheme.gradientDark : AppTheme.gradientLight,
              ),
              child: body,
            )
          : body,
    );
  }
}

class NeonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? flexibleSpace;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final Color? backgroundColor;
  final bool withGlassEffect;

  const NeonAppBar({
    super.key,
    this.title,
    this.flexibleSpace,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation = 0,
    this.backgroundColor,
    this.withGlassEffect = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final bgColor = backgroundColor ??
        (isDark ? AppTheme.surfaceDark.withOpacity(0.8) : AppTheme.surfaceLight.withOpacity(0.8));

    if (withGlassEffect) {
      return AppBar(
        title: title != null ? Text(
          title!,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            shadows: [
              Shadow(
                color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ) : null,
        actions: actions,
        leading: leading,
        centerTitle: centerTitle,
        elevation: elevation,
        backgroundColor: bgColor,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: flexibleSpace != null
            ? ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: flexibleSpace!,
                ),
              )
            : null,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      );
    }

    return AppBar(
      title: title != null ? Text(title!) : null,
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: bgColor,
      foregroundColor: colorScheme.onSurface,
    );
  }
}
