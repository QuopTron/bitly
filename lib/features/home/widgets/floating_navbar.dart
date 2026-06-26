import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/helpers/responsive.dart';
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
    _NavItem(Icons.home_rounded, 'Inicio'),
    _NavItem(Icons.search_rounded, 'Buscar'),
    _NavItem(Icons.library_music_rounded, 'Biblioteca'),
    _NavItem(Icons.person_rounded, 'Perfil'),
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL, vertical: r.spacingS),
      child: GlassContainer(
        borderRadius: 28,
        borderColor: glowColor.withValues(alpha: 0.15),
        bgColor: (widget.isDark ? const Color(0xFF1A1A1A) : Colors.white).withValues(alpha: 0.85),
        padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_items.length, (i) => _navItem(i, r, onBg, glowColor)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(horizontal: r.spacingXS),
        padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
        decoration: BoxDecoration(
          color: sel ? glowColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_items[i].icon, size: r.subtitleSize + 2,
              color: sel ? glowColor : onBg.withValues(alpha: 0.4)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(top: r.spacingXS),
              width: sel ? 16 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: sel ? glowColor : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
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
