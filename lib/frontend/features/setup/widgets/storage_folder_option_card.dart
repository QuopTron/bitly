import 'package:flutter/material.dart';
import '../../../shared/utils/responsive.dart';

class StorageOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  final Color onBg;
  final Color glowColor;

  const StorageOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.disabled,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? glowColor.withValues(alpha: 0.08) : Colors.transparent,
          border: Border.all(
            color: selected ? glowColor.withValues(alpha: 0.4) : onBg.withValues(alpha: 0.08),
            width: selected ? 1.2 : 0.6,
          ),
        ),
        padding: EdgeInsets.all(r.spacingM),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(r.spacingXS),
            decoration: BoxDecoration(
              color: selected ? glowColor.withValues(alpha: 0.12) : onBg.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: r.subtitleSize,
              color: selected ? glowColor : onBg.withValues(alpha: 0.4)),
          ),
          SizedBox(width: r.spacingM),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: TextStyle(fontSize: r.footerSize + 1,
                  fontWeight: FontWeight.w600, color: selected ? glowColor : onBg)),
              SizedBox(height: 2),
              Text(subtitle,
                style: TextStyle(fontSize: r.footerSize - 2,
                  color: onBg.withValues(alpha: 0.4))),
            ]),
          ),
          if (selected)
            Icon(Icons.check_circle, size: r.footerSize + 2, color: glowColor),
        ]),
      ),
    );
  }
}


