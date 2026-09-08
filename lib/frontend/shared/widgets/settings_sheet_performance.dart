// Parte del split de settings_sheet_new.dart — _PerformanceTab.
// Extraído del archivo original (ver git log). No editar a mano.
part of 'settings_sheet_new.dart';

class _PerformanceTab extends StatelessWidget {
  final Color glowColor;
  const _PerformanceTab({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = AppColors.onSurface(
      Theme.of(context).brightness == Brightness.dark,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: r.spacingS),
          // Header row (no nested box — the section below is the card).
          Row(
            children: [
              Icon(Icons.speed_rounded, color: glowColor, size: r.subtitleSize),
              SizedBox(width: r.spacingS),
              Text(
                'Rendimiento',
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.w700,
                  color: onBg,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Equilibra calidad de audio y consumo de datos según tu dispositivo y conexión.',
            style: TextStyle(
              fontSize: r.footerSize - 1,
              color: onBg.withValues(alpha: 0.5),
              height: 1.3,
            ),
          ),
          SizedBox(height: r.spacingM),
          SettingsPerformanceSection(onBg: onBg, glowColor: glowColor),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 4: Más — Premium, Google, Bug Report, Cache, Version
// ═══════════════════════════════════════════════════════
