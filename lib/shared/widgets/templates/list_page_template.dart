import 'package:flutter/material.dart';
import '../organisms/app_scaffold.dart';
import '../organisms/bottom_nav_bar.dart';

class ListPageTemplate extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? searchBar;
  final List<Widget>? actions;
  final NavTab? currentTab;
  final ValueChanged<NavTab>? onTabSelected;
  final bool showNavBar;

  const ListPageTemplate({
    super.key,
    required this.title,
    required this.body,
    this.searchBar,
    this.actions,
    this.currentTab,
    this.onTabSelected,
    this.showNavBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      actions: actions,
      currentTab: currentTab,
      onTabSelected: onTabSelected,
      showNavBar: showNavBar,
      body: Column(
        children: [
          if (searchBar != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: searchBar!,
            ),
          ],
          Expanded(child: body),
        ],
      ),
    );
  }
}
