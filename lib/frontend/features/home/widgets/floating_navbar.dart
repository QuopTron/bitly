import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';

class FloatingNavbar extends StatefulWidget {
  final bool isDark;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const FloatingNavbar({
    super.key,
    required this.isDark,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  State<FloatingNavbar> createState() => _FloatingNavbarState();
}

class _FloatingNavbarState extends State<FloatingNavbar> {
  late int _selected;

  static const _items = [
    _NavItem(Icons.search_rounded, 'Search'),
    _NavItem(Icons.home_rounded, 'Home'),
    _NavItem(Icons.grid_view_rounded, 'My Space'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = AppColors.onSurface(widget.isDark);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: GlassContainer(
          borderRadius: 0,
          blurSigma: 20,
          borderColor: onBg.withValues(alpha: 0.08),
          bgColor: AppColors.surface(widget.isDark).withValues(alpha: 0.80),
          padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS * 0.7),
          child: Row(
            children: List.generate(_items.length, (i) => Expanded(child: _navItem(i, r, onBg))),
          ),
        ),
    );
  }

  Widget _navItem(int i, Responsive r, Color onBg) {
    final sel = _selected == i;
    return GestureDetector(
      onTap: () {
        setState(() => _selected = i);
        widget.onTap?.call(i);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: r.spacingS * 0.8),
        decoration: BoxDecoration(
          color: sel ? onBg.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: sel ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                _items[i].icon,
                size: r.subtitleSize + 4,
                color: sel ? onBg : onBg.withValues(alpha: 0.35),
              ),
            ),
            SizedBox(height: r.spacingXS * 0.7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: sel ? 5 : 0,
              height: sel ? 5 : 0,
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
