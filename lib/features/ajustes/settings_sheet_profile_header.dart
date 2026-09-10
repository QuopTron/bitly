// Parte del split de settings_sheet_new.dart — _ProfileHeader.
// Extraído del archivo original (ver git log). No editar a mano.
part of 'settings_sheet_new.dart';

class _ProfileHeader extends StatelessWidget {
  final String username;
  final Color glowColor;
  final String likedCount;
  final String downloadedCount;
  final EstadoPremium? premium;

  const _ProfileHeader({
    required this.username,
    required this.glowColor,
    required this.likedCount,
    required this.downloadedCount,
    this.premium,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [glowColor, glowColor.withValues(alpha: 0.5)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: r.spacingS),
          // Name + premium
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username.isNotEmpty ? username : 'Guest',
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.bold,
                    color: onBg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(
                      (premium?.esPremium ?? false)
                          ? Icons.workspace_premium_rounded
                          : Icons.person_outline_rounded,
                      size: r.footerSize - 1,
                      color:
                          (premium?.esPremium ?? false)
                              ? glowColor
                              : onBg.withValues(alpha: 0.5),
                    ),
                    SizedBox(width: 3),
                    Text(
                      (premium?.esPremium ?? false)
                          ? AppLocalizations.of(context).setup.premium
                          : 'Free',
                      style: TextStyle(
                        fontSize: r.footerSize - 2,
                        color:
                            (premium?.esPremium ?? false)
                                ? glowColor
                                : onBg.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Mini stats
          _miniStat(context, Icons.favorite, Colors.redAccent, likedCount),
          SizedBox(width: r.spacingM),
          _miniStat(
            context,
            Icons.download_done,
            const Color(0xFF4CAF50),
            downloadedCount,
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    IconData icon,
    Color color,
    String value,
  ) {
    final r = Responsive(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: r.footerSize, color: color),
        SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: r.subtitleSize - 1,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Profile / Stats view (shown when no tab is selected)
// ═══════════════════════════════════════════════════════
