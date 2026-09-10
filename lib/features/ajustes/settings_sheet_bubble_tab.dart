// Parte del split de settings_sheet_new.dart — widget _BubbleTab (extraído
// del método _bubble de _SettingsSheetState). No editar a mano.
part of 'settings_sheet_new.dart';

/// One circular icon bubble: a small glowing circle with the icon, and a
/// tiny label underneath. Active bubble gets a filled glow + ring.
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  active
                      ? LinearGradient(
                        colors: [
                          glowColor.withValues(alpha: 0.95),
                          glowColor.withValues(alpha: 0.55),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              color: active ? null : onBg.withValues(alpha: 0.06),
              border: Border.all(
                color:
                    active
                        ? Colors.white.withValues(alpha: 0.35)
                        : onBg.withValues(alpha: 0.1),
              ),
              boxShadow:
                  active
                      ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                      : null,
            ),
            child: Icon(
              _bubbleTabs[index].icon,
              size: r.footerSize + 2,
              color: active ? Colors.white : onBg.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 4),
          Text(
            _bubbleTabs[index].label,
            style: TextStyle(
              fontSize: r.footerSize - 3,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? glowColor : onBg.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
