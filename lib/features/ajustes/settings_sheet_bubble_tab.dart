// Parte del split de settings_sheet_new.dart — widget _BubbleTab (extraído
// del método _bubble de _SettingsSheetState). No editar a mano.
part of 'settings_sheet_new.dart';

/// One circular icon bubble: a small glowing circle with the icon, and a
/// tiny label underneath. Active bubble gets a filled glow + ring + dot indicator.
class _BubbleTab extends StatelessWidget {
  final int index;
  final bool active;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _BubbleTab({
    required this.index,
    required this.active,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        scale: active ? 1.0 : 0.92,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    active
                        ? LinearGradient(
                          colors: [
                            glowColor.withValues(alpha: 0.9),
                            glowColor.withValues(alpha: 0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : null,
                color: active ? null : onBg.withValues(alpha: 0.05),
                border: Border.all(
                  color:
                      active
                          ? Colors.white.withValues(alpha: 0.3)
                          : onBg.withValues(alpha: 0.08),
                  width: active ? 1.5 : 1.0,
                ),
                boxShadow:
                    active
                        ? [
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.3),
                            blurRadius: 16,
                            spreadRadius: 0,
                          ),
                        ]
                        : null,
              ),
              child: Icon(
                _bubbleTabs[index].icon,
                size: r.footerSize + 3,
                color: active ? Colors.white : onBg.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 6),
            Text(
              _bubbleTabs[index].label,
              style: TextStyle(
                fontSize: r.footerSize - 3,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? glowColor : onBg.withValues(alpha: 0.45),
                letterSpacing: active ? 0.2 : 0,
              ),
            ),
            // Active dot indicator.
            SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: active ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: glowColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
