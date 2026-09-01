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
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;

    // 5% horizontal padding from screen edges
    final padH = r.width * 0.05;

    return Padding(
      padding: EdgeInsets.fromLTRB(padH, 0, padH, r.spacingS),
      child: GlassContainer(
        borderRadius: 20,
        blurSigma: 20,
        borderColor: glowColor.withValues(alpha: 0.12),
        bgColor: (widget.isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.80),
        glowBorder: true,
        glowSpread: 2,
        glowBlur: 16,
        padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS * 0.7),
        child: Row(
          children: List.generate(_items.length, (i) => Expanded(child: _navItem(i, r, onBg, glowColor))),
        ),
      ),
    );
  }

  Widget _navItem(int i, Responsive r, Color onBg, Color glowColor) {
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
        padding: EdgeInsets.symmetric(vertical: r.spacingS * 0.7),
        decoration: BoxDecoration(
          color: sel ? glowColor.withValues(alpha: 0.10) : Colors.transparent,
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
                size: r.subtitleSize + 2,
                color: sel ? glowColor : onBg.withValues(alpha: 0.35),
              ),
            ),
            SizedBox(height: r.spacingXS * 0.6),
            // Glow dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: sel ? 5 : 0,
              height: sel ? 5 : 0,
              decoration: BoxDecoration(
                color: glowColor,
                shape: BoxShape.circle,
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
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
