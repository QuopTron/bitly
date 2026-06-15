import 'package:flutter/material.dart';
import '../organisms/bottom_nav_bar.dart';

class TabInfo {
  final String label;
  final Widget content;
  final IconData? icon;

  TabInfo({required this.label, required this.content, this.icon});
}

class TabbedPageTemplate extends StatefulWidget {
  final String title;
  final List<TabInfo> tabs;
  final NavTab? currentTab;
  final ValueChanged<NavTab>? onTabSelected;
  final List<Widget>? actions;

  const TabbedPageTemplate({
    super.key,
    required this.title,
    required this.tabs,
    this.currentTab,
    this.onTabSelected,
    this.actions,
  });

  @override
  State<TabbedPageTemplate> createState() => _TabbedPageTemplateState();
}

class _TabbedPageTemplateState extends State<TabbedPageTemplate>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.actions,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.green,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          tabs: widget.tabs.map((t) => Tab(text: t.label, icon: t.icon != null ? Icon(t.icon) : null)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: widget.tabs.map((t) => t.content).toList(),
      ),
      bottomNavigationBar: widget.currentTab != null && widget.onTabSelected != null
          ? BottomNavBar(
              currentTab: widget.currentTab!,
              onTabSelected: widget.onTabSelected!,
            )
          : null,
    );
  }
}
