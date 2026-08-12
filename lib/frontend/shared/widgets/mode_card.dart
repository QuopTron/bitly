import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onInfoTap;
  final Color glowColor;

  const ModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.selected = false,
    this.onTap,
    this.onInfoTap,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.languageCardMargin, vertical: r.spacingXS),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: r.spacingM, horizontal: r.spacingL),
          decoration: BoxDecoration(
            color: selected ? glowColor.withValues(alpha: 0.1) : onBg.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? glowColor.withValues(alpha: 0.5) : onBg.withValues(alpha: 0.06),
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              _iconBox(r),
              SizedBox(width: r.spacingS),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg)),
                  SizedBox(height: 1),
                  Text(subtitle, style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.5))),
                ],
              )),
              if (onInfoTap != null) _infoBtn(r, onBg),
              if (selected)
                Padding(
                  padding: EdgeInsets.only(left: r.spacingS),
                  child: Icon(Icons.check_circle, color: glowColor, size: r.languageCheckSize + 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.spacingXS),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: r.languageCardIconSize * 0.7),
    );
  }

  Widget _infoBtn(Responsive r, Color onBg) {
    return Padding(
      padding: EdgeInsets.only(left: r.spacingXS),
      child: GestureDetector(
        onTap: onInfoTap,
        child: Container(
          padding: EdgeInsets.all(r.spacingXS),
          decoration: BoxDecoration(
            color: onBg.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.info_outline, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}


