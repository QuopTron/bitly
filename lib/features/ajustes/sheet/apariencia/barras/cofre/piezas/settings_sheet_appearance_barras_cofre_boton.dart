// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_boton.dart — PART de
// settings_sheet_new.dart: el BOTÓN del cofre de paletas.
//
// Es la fila que se ve en Ajustes → Apariencia → Barras: el ícono, el título,
// cuántos regalos hay por abrir y el chevron que gira al abrir. Late en
// dorado cuando hay algo nuevo, así el usuario ve que hay un regalo sin
// entrar. Va aparte de _cofre para que cada archivo haga una sola cosa: uno
// dibuja el botón, el otro maneja los datos y el despliegue.
//
// Se conecta con: settings_sheet_appearance_barras_cofre.dart (lo usa y le
// pasa el estado abierto/cerrado) + _ChipPersonalizado (el mininumerito).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of '../../../../settings_sheet_new.dart';

/// Fila tocable que abre (y cierra) el cofre.
class _BotonCofre extends StatelessWidget {
  final StringsCofrePaletas t;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  /// Cuántos regalos se pueden abrir ahora.
  final int pendientes;

  /// ¿Está abierto el submodal?
  final bool abierto;

  final VoidCallback onTap;

  const _BotonCofre({
    required this.t,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.pendientes,
    required this.abierto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingS,
          vertical: r.spacingS,
        ),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                pendientes > 0
                    ? glowColor.withValues(alpha: 0.45)
                    : onBg.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.redeem_rounded, color: glowColor, size: 18),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.titulo,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      fontWeight: FontWeight.w700,
                      color: onBg.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    pendientes > 0 ? t.regalos(pendientes) : t.todoVisto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            if (pendientes > 0)
              _ChipPersonalizado(
                texto: '$pendientes',
                glowColor: glowColor,
                r: r,
              ),
            AnimatedRotation(
              turns: abierto ? 0.5 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: onBg.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
