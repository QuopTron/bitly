// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_piezas.dart — PART de
// settings_sheet_new.dart: las dos piezas chicas del espacio Barras.
//
//   _SelectorBarraEditada → elige si se edita el navbar o el miniplayer
//   _AyudaControl         → la línea de ayuda corta bajo un control
// La vista previa vive en _barras_previa: UNA sola que alterna entre las dos
// barras, en vez de mostrarlas a la vez.
//
// Se conecta con: settings_sheet_appearance_barras.dart (misma library).
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Elige qué barra se está editando; el control de esquinas la sigue.
class _SelectorBarraEditada extends StatelessWidget {
  final bool navbar;
  final StringsApariencia t;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final ValueChanged<bool> onCambio;

  const _SelectorBarraEditada({
    required this.navbar,
    required this.t,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final esNavbar in const [true, false])
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onCambio(esNavbar),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingXS / 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: r.spacingS * 0.8),
                decoration: BoxDecoration(
                  color:
                      navbar == esNavbar
                          ? glowColor.withValues(alpha: 0.12)
                          : onBg.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        navbar == esNavbar
                            ? glowColor
                            : onBg.withValues(alpha: 0.12),
                    width: navbar == esNavbar ? 1.6 : 1,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    esNavbar ? t.barras.navbar : t.barras.miniplayer,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      fontWeight:
                          navbar == esNavbar
                              ? FontWeight.w700
                              : FontWeight.w500,
                      color:
                          navbar == esNavbar
                              ? glowColor
                              : onBg.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Línea de ayuda corta, alineada con el texto del control (no con el slider).
class _AyudaControl extends StatelessWidget {
  final String texto;
  final Responsive r;
  final Color onBg;

  const _AyudaControl({
    required this.texto,
    required this.r,
    required this.onBg,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: r.width * 0.24, top: 2),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: r.footerSize - 2,
        color: onBg.withValues(alpha: 0.4),
      ),
    ),
  );
}
