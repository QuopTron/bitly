import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:bitly/theme/app_theme.dart';

/// Glassmorphism widget container with blur and transparency effects
/// Updated with NEON design and 10% margin for modals
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsets padding;
  final double opacity;
  final Color? borderColor;
  final Gradient? gradient;
  final bool enableShadow;
  final bool isModal;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = 20,
    this.padding = const EdgeInsets.all(20),
    this.opacity = 0.08,
    this.borderColor,
    this.gradient,
    this.enableShadow = true,
    this.isModal = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorderColor = borderColor ?? 
        (isDark ? AppTheme.modalBorderDark : AppTheme.modalBorderLight);
    
    final effectiveGradient = gradient ??
        (isModal
            ? (isDark ? AppTheme.modalGradientDark : AppTheme.modalGradientLight)
            : (isDark ? AppTheme.gradientDark : AppTheme.gradientLight));

    final effectiveBlur = isModal ? AppTheme.modalBlurSigma : blur;
    final effectiveOpacity = isModal ? AppTheme.modalGlassOpacity : opacity;

    final container = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: effectiveGradient,
            border: Border.all(color: effectiveBorderColor, width: 1.5),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: enableShadow
                ? [
                    BoxShadow(
                      color: (isDark ? AppTheme.glowDark : AppTheme.glowLight).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    // Inner glow for futuristic effect
                    BoxShadow(
                      color: (isDark ? AppTheme.primaryDark : AppTheme.primaryLight).withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 0),
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );

    // For modals, add 10% margin from edges
    if (isModal) {
      return Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.1),
        child: container,
      );
    }

    return container;
  }
}

/// Glass card widget for list items
class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double borderRadius;
  final double blur;
  final bool selected;
  final bool isDarkMode;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.blur = 15,
    this.selected = false,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode || Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected
            ? (isDark ? colorScheme.primaryContainer : colorScheme.primaryContainer)
            : (isDark 
                ? colorScheme.surfaceContainerHighest.withOpacity(0.4)
                : colorScheme.surfaceContainerHighest.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: selected
              ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
              : (isDark ? AppTheme.glassBorderDark : AppTheme.glassBorderLight),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: isDark ? AppTheme.primaryDark.withOpacity(0.2) : AppTheme.primaryLight.withOpacity(0.2),
          highlightColor: isDark ? AppTheme.primaryDark.withOpacity(0.1) : AppTheme.primaryLight.withOpacity(0.1),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Floating action button with glassmorphism
class GlassActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double size;
  final double blur;
  final bool isSelected;

  const GlassActionButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.size = 56,
    this.blur = 20,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        splashColor: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.3),
        highlightColor: isDark ? AppTheme.primaryDark.withOpacity(0.2) : AppTheme.primaryLight.withOpacity(0.2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
                  : (isDark ? AppTheme.glassBorderDark : AppTheme.glassBorderLight),
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? AppTheme.primaryDark.withOpacity(0.2) : AppTheme.primaryLight.withOpacity(0.2),
                blurRadius: blur,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                color: Colors.transparent,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass divider
class GlassDivider extends StatelessWidget {
  final double height;
  final double indent;
  final double endIndent;
  final bool vertical;

  const GlassDivider({
    super.key,
    this.height = 1,
    this.indent = 0,
    this.endIndent = 0,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (vertical) {
      return Container(
        width: height,
        height: indent,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
      );
    }
    
    return Container(
      height: height,
      margin: EdgeInsets.symmetric(horizontal: indent),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            (isDark ? Colors.white : Colors.black).withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Modal Base Widget - Futuristic Glassmorphism with 10% margin
class FuturisticModal extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? header;
  final bool showDragHandle;
  final double maxHeight;
  final EdgeInsets? padding;
  final bool isScrollControlled;
  final Widget? floatingActionButton;

  const FuturisticModal({
    super.key,
    required this.child,
    this.title,
    this.header,
    this.showDragHandle = true,
    this.maxHeight = 0.85,
    this.padding,
    this.isScrollControlled = true,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    
    return Container(
      padding: padding ?? EdgeInsets.all(mediaQuery.size.width * 0.1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppTheme.modalBlurSigma,
            sigmaY: AppTheme.modalBlurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.modalGradientDark : AppTheme.modalGradientLight,
              border: Border.all(
                color: isDark ? AppTheme.modalBorderDark : AppTheme.modalBorderLight,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 20),
                ),
                // Inner glow
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.1) : AppTheme.primaryLight.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDragHandle)
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        shadows: [
                          Shadow(
                            color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (header != null) header!,
                Expanded(
                  child: isScrollControlled
                      ? SingleChildScrollView(child: child)
                      : child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Futuristic Card with Neon Glow
class NeonCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double elevation;
  final double borderRadius;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Color? glowColor;

  const NeonCard({
    super.key,
    required this.child,
    this.onTap,
    this.elevation = 0,
    this.borderRadius = 20,
    this.margin = const EdgeInsets.all(8),
    this.padding = const EdgeInsets.all(16),
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveGlow = glowColor ?? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight);
    
    final cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark 
            ? colorScheme.surfaceContainerHighest.withOpacity(0.25)
            : colorScheme.surfaceContainerHighest.withOpacity(0.25),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveGlow.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveGlow.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          // Inner glow
          BoxShadow(
            color: effectiveGlow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 0),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: effectiveGlow.withOpacity(0.2),
          highlightColor: effectiveGlow.withOpacity(0.1),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
