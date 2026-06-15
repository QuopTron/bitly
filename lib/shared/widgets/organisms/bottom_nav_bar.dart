import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum NavTab { home, search, library, downloads, more }

class BottomNavBar extends StatelessWidget {
  final NavTab currentTab;
  final ValueChanged<NavTab> onTabSelected;

  const BottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home', tab: NavTab.home),
    (icon: Icons.search_rounded, label: 'Search', tab: NavTab.search),
    (icon: Icons.library_music_rounded, label: 'Library', tab: NavTab.library),
    (icon: Icons.download_rounded, label: 'Downloads', tab: NavTab.downloads),
    (icon: Icons.more_horiz_rounded, label: 'More', tab: NavTab.more),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: _tabs.map((t) {
              final selected = t.tab == currentTab;
              return Expanded(
                child: InkWell(
                  onTap: () => onTabSelected(t.tab),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        t.icon,
                        color: selected ? Colors.green : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: selected ? Colors.green : Colors.grey,
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
