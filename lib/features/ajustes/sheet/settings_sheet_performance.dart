// ─────────────────────────────────────────────────────────────
// settings_sheet_performance.dart — Pestaña Rendimiento del sheet de Ajustes: perfil de rendimiento,
// animaciones y consumo (blur/efectos) de la app.
//
// Se conecta con: settings_sheet_new.dart (misma library) + cache de ajustes.
// Parte del flujo: Ajustes → pestaña Rendimiento.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

class _PerformanceTab extends StatelessWidget {
  final Color glowColor;
  const _PerformanceTab({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = ColoresApp.enSuperficie(
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
