// ─────────────────────────────────────────────────────────────
// settings_sheet_performance.dart — Pestaña Rendimiento del sheet de Ajustes: perfil de rendimiento,
// animaciones y consumo (blur/efectos) de la app.
//
// Se conecta con: settings_sheet_new.dart (misma library) + cache de ajustes.
// Parte del flujo: Ajustes → pestaña Rendimiento.
// ─────────────────────────────────────────────────────────────

part of '../settings_sheet_new.dart';

class _PerformanceTab extends StatelessWidget {
  final Color glowColor;
  const _PerformanceTab({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = ColoresApp.enSuperficie(
      Theme.of(context).brightness == Brightness.dark,
    );
    final loc = AppLocalizations.of(context);

    // El rótulo de la pestaña queda FIJO y abajo se GIRA un ajuste por
    // pantalla (mismo carrusel que Apariencia): el que viene a prender el audio
    // en segundo plano no pasa por los tres perfiles ni por el modo fluido.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.spacingL, r.spacingS, r.spacingL, 0),
          child: _TituloApartado(
            titulo: loc.setup.performanceProfile,
            bajada: loc.setup.performanceHelp,
            glowColor: glowColor,
          ),
        ),
        Expanded(
          child: CarruselAjustes(
            key: const ValueKey('carrusel-rendimiento'),
            etiqueta: loc.setup.performanceProfile,
            glowColor: glowColor,
            onBg: onBg,
            r: r,
            paginas: [
              SettingsPerformanceSection(
                onBg: onBg,
                glowColor: glowColor,
                parte: ParteRendimiento.perfil,
              ),
              SettingsPerformanceSection(
                onBg: onBg,
                glowColor: glowColor,
                parte: ParteRendimiento.fluido,
              ),
              SettingsPerformanceSection(
                onBg: onBg,
                glowColor: glowColor,
                parte: ParteRendimiento.audio,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 4: Más — Premium, Google, Bug Report, Cache, Version
// ═══════════════════════════════════════════════════════
