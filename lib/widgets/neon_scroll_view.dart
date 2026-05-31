import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/theme/app_theme.dart';

/// A scrollable view with NEON glassmorphism background
/// Use this to wrap your content for automatic theming
class NeonScrollView extends ConsumerWidget {
  final Widget? sliverAppBar;
  final List<Widget> slivers;
  final Widget? body;
  final EdgeInsets? padding;
  final bool withScrollbar;
  final Color? backgroundColor;
  final bool useGradient;
  final bool transparent;
  final Widget? floatingActionButton;

  NeonScrollView({
    super.key,
    this.sliverAppBar,
    this.slivers = const [],
    this.body,
    this.padding,
    this.withScrollbar = true,
    this.backgroundColor,
    this.useGradient = true,
    this.transparent = false,
    this.floatingActionButton,
  }) : assert(slivers.isNotEmpty || body != null, 'Either slivers or body must be provided');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    final bgColor = backgroundColor ?? 
        (isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimaryLight);

    final scrollContent = CustomScrollView(
      slivers: [
        if (sliverAppBar != null) sliverAppBar!,
        ...slivers,
        if (body != null) 
          SliverFillRemaining(
            hasScrollBody: true,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(0),
              child: body!,
            ),
          ),
      ],
    );

    final contentWithScrollbar = withScrollbar
        ? ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: WidgetStatePropertyAll(isDark ? AppTheme.primaryDark : AppTheme.primaryLight),
              trackColor: WidgetStatePropertyAll(isDark ? AppTheme.surfaceDark.withOpacity(0.5) : AppTheme.surfaceLight.withOpacity(0.5)),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              radius: const Radius.circular(10),
              child: scrollContent,
            ),
          )
        : scrollContent;

    if (transparent) return contentWithScrollbar;

    final contentWithBackground = useGradient
        ? Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.gradientDark : AppTheme.gradientLight,
            ),
            child: contentWithScrollbar,
          )
        : Container(
            color: bgColor,
            child: contentWithScrollbar,
          );

    return contentWithBackground;
  }
}

/// A list view with NEON glassmorphism styling
class NeonListView extends ConsumerWidget {
  final List<Widget> children;
  final Widget Function(BuildContext, int)? itemBuilder;
  final int? itemCount;
  final EdgeInsets? padding;
  final bool withScrollbar;
  final bool useGradient;
  final bool transparent;
  final Widget? header;
  final Widget? footer;

  NeonListView({
    super.key,
    this.children = const [],
    this.itemBuilder,
    this.itemCount,
    this.padding,
    this.withScrollbar = true,
    this.useGradient = true,
    this.transparent = false,
    this.header,
    this.footer,
  }) : assert(itemBuilder != null || children.isNotEmpty, 'Either itemBuilder or children must be provided');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final listContent = ListView.builder(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount ?? children.length,
      itemBuilder: itemBuilder ?? (context, index) => children[index],
    );

    final contentWithScrollbar = withScrollbar
        ? ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: WidgetStatePropertyAll(isDark ? AppTheme.primaryDark : AppTheme.primaryLight),
              trackColor: WidgetStatePropertyAll(isDark ? AppTheme.surfaceDark.withOpacity(0.5) : AppTheme.surfaceLight.withOpacity(0.5)),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              radius: const Radius.circular(10),
              child: listContent,
            ),
          )
        : listContent;

    if (transparent) {
      return Column(
        children: [
          if (header != null) header!,
          Expanded(child: contentWithScrollbar),
          if (footer != null) footer!,
        ],
      );
    }

    return useGradient
        ? Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.gradientDark : AppTheme.gradientLight,
            ),
            child: Column(
              children: [
                if (header != null) header!,
                Expanded(child: contentWithScrollbar),
                if (footer != null) footer!,
              ],
            ),
          )
        : Column(
            children: [
              if (header != null) header!,
              Expanded(child: contentWithScrollbar),
              if (footer != null) footer!,
            ],
          );
  }
}

/// A grid view with NEON glassmorphism styling
class NeonGridView extends ConsumerWidget {
  final List<Widget> children;
  final Widget Function(BuildContext, int)? itemBuilder;
  final int? itemCount;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets? padding;
  final bool withScrollbar;
  final bool useGradient;
  final bool transparent;

  NeonGridView({
    super.key,
    this.children = const [],
    this.itemBuilder,
    this.itemCount,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.padding,
    this.withScrollbar = true,
    this.useGradient = true,
    this.transparent = false,
  }) : assert(itemBuilder != null || children.isNotEmpty, 'Either itemBuilder or children must be provided');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final gridContent = GridView.builder(
      padding: padding ?? const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: itemCount ?? children.length,
      itemBuilder: itemBuilder ?? (context, index) => children[index],
    );

    if (transparent) return gridContent;

    if (withScrollbar) {
      final scrollContent = ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(isDark ? AppTheme.primaryDark : AppTheme.primaryLight),
          trackColor: WidgetStatePropertyAll(isDark ? AppTheme.surfaceDark.withOpacity(0.5) : AppTheme.surfaceLight.withOpacity(0.5)),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          trackVisibility: true,
          radius: const Radius.circular(10),
          child: gridContent,
        ),
      );

      if (useGradient) {
        return Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppTheme.gradientDark : AppTheme.gradientLight,
          ),
          child: scrollContent,
        );
      }
      return scrollContent;
    }

    if (useGradient) {
      return Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.gradientDark : AppTheme.gradientLight,
        ),
        child: gridContent,
      );
    }
    
    return gridContent;
  }
}

/// You can gradually migrate your screens by using these wrappers.
/// Example usage:
///
/// class MyScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: NeonScrollView(
///         slivers: [
///           SliverToBoxAdapter(child: MyHeader()),
///           NeonGridView(
///             itemCount: items.length,
///             itemBuilder: (context, index) => MyItemWidget(items[index]),
///           ),
///         ],
///       ),
///     );
///   }
/// }
