import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart';
import 'mini_player_bar.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final bool showNavBar;
  final bool showMiniPlayer;
  final NavTab? currentTab;
  final ValueChanged<NavTab>? onTabSelected;
  final Widget? miniPlayer;
  final Widget? bottomSheet;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.showNavBar = true,
    this.showMiniPlayer = false,
    this.currentTab,
    this.onTabSelected,
    this.miniPlayer,
    this.bottomSheet,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFF0D0D1A),
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              actions: actions,
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: body,
      bottomSheet: bottomSheet,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMiniPlayer) miniPlayer ?? const MiniPlayerBar(),
          if (showNavBar && currentTab != null && onTabSelected != null)
            BottomNavBar(currentTab: currentTab!, onTabSelected: onTabSelected!),
        ],
      ),
    );
  }
}
