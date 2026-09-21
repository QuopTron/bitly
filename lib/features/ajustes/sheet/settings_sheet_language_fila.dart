// ─────────────────────────────────────────────────────────────
// settings_sheet_language_fila.dart — PART de settings_sheet_new.dart:
// una fila del selector de idioma (nombre + tilde del que está puesto).
//
// El tilde va SIEMPRE en el mismo lugar y sólo cambia de color: los dos
// idiomas quedan alineados y se ve de un vistazo cuál está activo.
//
// Se conecta con: settings_sheet_language.dart (la usa) y idioma_helper.
// Parte del flujo: Ajustes → Apariencia → Idioma.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Una fila del selector: nombre del idioma y tilde si es el actual.
class _IdiomaFila extends StatelessWidget {
  final Locale idioma;
  final String nombre;
  final bool seleccionado;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _IdiomaFila({
    super.key,
    required this.idioma,
    required this.nombre,
    required this.seleccionado,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(vertical: r.spacingXS / 2),
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingM,
          vertical: r.spacingS + r.spacingXS / 2,
        ),
        decoration: BoxDecoration(
          color:
              seleccionado
                  ? glowColor.withValues(alpha: 0.12)
                  : onBg.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                seleccionado
                    ? glowColor.withValues(alpha: 0.45)
                    : onBg.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                  color: onBg,
                ),
              ),
            ),
            Icon(
              Icons.check_rounded,
              size: r.subtitleSize + 2,
              color: seleccionado ? glowColor : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
